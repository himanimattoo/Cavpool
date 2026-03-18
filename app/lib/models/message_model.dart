import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String rideId;
  final String senderId;
  final String? recipientId; // null for group messages
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final String? senderName; // Cached sender name for display

  Message({
    required this.id,
    required this.rideId,
    required this.senderId,
    this.recipientId,
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.isRead = false,
    this.senderName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rideId': rideId,
      'senderId': senderId,
      'recipientId': recipientId,
      'content': content,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'senderName': senderName,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    return Message(
      id: id,
      rideId: map['rideId'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'],
      content: map['content'] ?? '',
      type: MessageType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
      senderName: map['senderName'],
    );
  }

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message.fromMap(data, doc.id);
  }

  Message copyWith({
    String? id,
    String? rideId,
    String? senderId,
    String? recipientId,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
    String? senderName,
  }) {
    return Message(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      senderName: senderName ?? this.senderName,
    );
  }
}

enum MessageType {
  text,
  system, // System notifications
  quickMessage, // Pre-defined quick messages
}

