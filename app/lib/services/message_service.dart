import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/message_model.dart';

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  /// Send a message to a ride's message thread
  /// Messages are stored in /ride_offers/{rideId}/messages/{messageId}
  Future<String?> sendMessage({
    required String rideId,
    required String senderId,
    String? recipientId, // null for group messages
    required String content,
    MessageType type = MessageType.text,
  }) async {
    try {
      // Get sender name for caching
      String? senderName;
      try {
        final senderDoc = await _firestore.collection('users').doc(senderId).get();
        if (senderDoc.exists) {
          final senderData = senderDoc.data()!;
          senderName = senderData['profile']?['displayName'] ?? 
                      '${senderData['profile']?['firstName'] ?? ''} ${senderData['profile']?['lastName'] ?? ''}'.trim();
        }
      } catch (e) {
        _logger.w('Could not fetch sender name: $e');
      }

      final message = Message(
        id: '', // Will be set by Firestore
        rideId: rideId,
        senderId: senderId,
        recipientId: recipientId,
        content: content,
        type: type,
        timestamp: DateTime.now(),
        isRead: false,
        senderName: senderName,
      );

      final docRef = await _firestore
          .collection('ride_offers')
          .doc(rideId)
          .collection('messages')
          .add(message.toMap());

      _logger.i('Message sent: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      _logger.e('Error sending message: $e');
      rethrow;
    }
  }

  /// Get messages for a ride
  Stream<List<Message>> getMessagesStream(String rideId, {int limit = 50}) {
    try {
      return _firestore
          .collection('ride_offers')
          .doc(rideId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Message.fromFirestore(doc))
            .toList()
            .reversed // Reverse to show oldest first
            .toList();
      });
    } catch (e) {
      _logger.e('Error getting messages stream: $e');
      return Stream.value([]);
    }
  }

  /// Get messages for a ride (one-time fetch)
  Future<List<Message>> getMessages(String rideId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('ride_offers')
          .doc(rideId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList()
          .reversed // Reverse to show oldest first
          .toList();
    } catch (e) {
      _logger.e('Error getting messages: $e');
      return [];
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String rideId, String userId) async {
    try {
      // Get all unread messages that are not from the current user
      final snapshot = await _firestore
          .collection('ride_offers')
          .doc(rideId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
        _logger.i('Marked ${snapshot.docs.length} messages as read');
      }
    } catch (e) {
      _logger.e('Error marking messages as read: $e');
    }
  }

  /// Get unread message count for a ride
  Future<int> getUnreadCount(String rideId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('ride_offers')
          .doc(rideId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      _logger.e('Error getting unread count: $e');
      return 0;
    }
  }

  /// Get unread message count stream
  Stream<int> getUnreadCountStream(String rideId, String userId) {
    try {
      return _firestore
          .collection('ride_offers')
          .doc(rideId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      _logger.e('Error getting unread count stream: $e');
      return Stream.value(0);
    }
  }

  /// Send a quick message (pre-defined template)
  Future<String?> sendQuickMessage({
    required String rideId,
    required String senderId,
    required String message,
  }) async {
    return sendMessage(
      rideId: rideId,
      senderId: senderId,
      content: message,
      type: MessageType.quickMessage,
    );
  }
}

