import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';

class IncomingRequestNotification {
  final String id;
  final String requestId;
  final String driverId;
  final String passengerId;
  final RideRequest request;
  final UserModel passenger;
  final DateTime timestamp;
  final bool isActive;
  final Duration timeoutDuration;

  IncomingRequestNotification({
    required this.id,
    required this.requestId,
    required this.driverId,
    required this.passengerId,
    required this.request,
    required this.passenger,
    required this.timestamp,
    this.isActive = true,
    this.timeoutDuration = const Duration(minutes: 2),
  });

  bool get isExpired => DateTime.now().difference(timestamp) > timeoutDuration;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestId': requestId,
      'driverId': driverId,
      'passengerId': passengerId,
      'request': request.toMap(),
      'passenger': passenger.toMap(),
      'timestamp': Timestamp.fromDate(timestamp),
      'isActive': isActive,
      'timeoutDuration': timeoutDuration.inMilliseconds,
    };
  }

  factory IncomingRequestNotification.fromMap(Map<String, dynamic> map) {
    return IncomingRequestNotification(
      id: map['id'] ?? '',
      requestId: map['requestId'] ?? '',
      driverId: map['driverId'] ?? '',
      passengerId: map['passengerId'] ?? '',
      request: RideRequest.fromMap(map['request']),
      passenger: UserModel.fromMap(map['passenger']),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
      timeoutDuration: Duration(milliseconds: map['timeoutDuration'] ?? 120000),
    );
  }
}

class RequestNotificationService {
  static final RequestNotificationService _instance = RequestNotificationService._internal();
  factory RequestNotificationService() => _instance;
  RequestNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, Timer> _timeoutTimers = {};
  bool _soundEnabled = true;
  bool _hapticEnabled = true;

  CollectionReference get _incomingRequestsCollection => 
      _firestore.collection('incoming_requests');

  /// Send incoming request notification to driver
  Future<void> sendIncomingRequestNotification({
    required String driverId,
    required RideRequest request,
    required UserModel passenger,
  }) async {
    try {
      final notificationId = '${request.id}_${driverId}_${DateTime.now().millisecondsSinceEpoch}';
      
      final notification = IncomingRequestNotification(
        id: notificationId,
        requestId: request.id,
        driverId: driverId,
        passengerId: passenger.uid,
        request: request,
        passenger: passenger,
        timestamp: DateTime.now(),
      );

      // Store notification in Firestore
      await _incomingRequestsCollection.doc(notificationId).set(notification.toMap());

      // Trigger sound and haptic feedback
      await _triggerNotificationAlert();

      // Set timeout for auto-dismiss
      _setNotificationTimeout(notificationId, notification.timeoutDuration);

      _logger.i('Incoming request notification sent to driver: $driverId');
    } catch (e) {
      _logger.e('Error sending incoming request notification: $e');
      rethrow;
    }
  }

  /// Start listening for incoming requests for a driver
  Future<void> startListeningForRequests(String driverId) async {
    try {
      // Stop existing subscription if any
      await stopListeningForRequests(driverId);

      _logger.i('Starting to listen for incoming requests: $driverId');

      _activeSubscriptions[driverId] = _incomingRequestsCollection
          .where('driverId', isEqualTo: driverId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen(
            (snapshot) => _handleIncomingRequestSnapshot(snapshot),
            onError: (error) => _logger.e('Incoming request stream error: $error'),
          );

      _logger.i('Started listening for incoming requests: $driverId');
    } catch (e) {
      _logger.e('Error starting to listen for requests: $e');
      rethrow;
    }
  }

  /// Stop listening for incoming requests
  Future<void> stopListeningForRequests(String driverId) async {
    try {
      _activeSubscriptions[driverId]?.cancel();
      _activeSubscriptions.remove(driverId);
      
      // Cancel any active timeout timers for this driver
      final timersToCancel = _timeoutTimers.keys
          .where((key) => key.startsWith('${driverId}_'))
          .toList();
      
      for (final timerKey in timersToCancel) {
        _timeoutTimers[timerKey]?.cancel();
        _timeoutTimers.remove(timerKey);
      }

      _logger.i('Stopped listening for incoming requests: $driverId');
    } catch (e) {
      _logger.e('Error stopping listening for requests: $e');
    }
  }

  /// Accept incoming request
  Future<void> acceptRequest(String notificationId) async {
    try {
      await _incomingRequestsCollection.doc(notificationId).update({
        'isActive': false,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Cancel timeout timer
      final timerKey = 'timeout_$notificationId';
      _timeoutTimers[timerKey]?.cancel();
      _timeoutTimers.remove(timerKey);

      _logger.i('Request accepted: $notificationId');
    } catch (e) {
      _logger.e('Error accepting request: $e');
      rethrow;
    }
  }

  /// Decline incoming request
  Future<void> declineRequest(String notificationId, {String? reason}) async {
    try {
      await _incomingRequestsCollection.doc(notificationId).update({
        'isActive': false,
        'declinedAt': FieldValue.serverTimestamp(),
        'declineReason': reason ?? 'No reason provided',
      });

      // Cancel timeout timer
      final timerKey = 'timeout_$notificationId';
      _timeoutTimers[timerKey]?.cancel();
      _timeoutTimers.remove(timerKey);

      _logger.i('Request declined: $notificationId');
    } catch (e) {
      _logger.e('Error declining request: $e');
      rethrow;
    }
  }

  /// Get active incoming requests for driver
  Stream<List<IncomingRequestNotification>> getActiveRequestsStream(String driverId) {
    try {
      return _incomingRequestsCollection
          .where('driverId', isEqualTo: driverId)
          .where('isActive', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => IncomingRequestNotification.fromMap(doc.data() as Map<String, dynamic>))
            .where((notification) => !notification.isExpired)
            .toList();
      });
    } catch (e) {
      _logger.e('Error getting active requests stream: $e');
      return Stream.value([]);
    }
  }

  /// Trigger notification alert (sound + haptic feedback)
  Future<void> _triggerNotificationAlert() async {
    try {
      // Play notification sound
      if (_soundEnabled) {
        await _playNotificationSound();
      }

      // Trigger haptic feedback
      if (_hapticEnabled) {
        await _triggerHapticFeedback();
      }
    } catch (e) {
      _logger.e('Error triggering notification alert: $e');
    }
  }

  /// Play notification sound
  Future<void> _playNotificationSound() async {
    try {
      // Use system alert sound
      SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      _logger.e('Error playing notification sound: $e');
    }
  }

  /// Trigger haptic feedback
  Future<void> _triggerHapticFeedback() async {
    try {
      // Heavy impact haptic feedback for important notifications
      await HapticFeedback.heavyImpact();
      
      // Add a brief delay and another feedback for attention
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.mediumImpact();
    } catch (e) {
      _logger.e('Error triggering haptic feedback: $e');
    }
  }

  /// Handle incoming request snapshot changes
  void _handleIncomingRequestSnapshot(QuerySnapshot snapshot) {
    try {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final notification = IncomingRequestNotification.fromMap(
            change.doc.data() as Map<String, dynamic>
          );
          
          // Only trigger alert for new notifications (within last 30 seconds)
          if (DateTime.now().difference(notification.timestamp).inSeconds <= 30) {
            _triggerNotificationAlert();
          }
        }
      }
    } catch (e) {
      _logger.e('Error handling incoming request snapshot: $e');
    }
  }

  /// Set notification timeout
  void _setNotificationTimeout(String notificationId, Duration timeout) {
    final timerKey = 'timeout_$notificationId';
    
    _timeoutTimers[timerKey] = Timer(timeout, () async {
      try {
        await _incomingRequestsCollection.doc(notificationId).update({
          'isActive': false,
          'expiredAt': FieldValue.serverTimestamp(),
        });
        
        _timeoutTimers.remove(timerKey);
        _logger.i('Request notification expired: $notificationId');
      } catch (e) {
        _logger.e('Error handling notification timeout: $e');
      }
    });
  }

  /// Enable/disable sound notifications
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    _logger.i('Sound notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Enable/disable haptic feedback
  void setHapticEnabled(bool enabled) {
    _hapticEnabled = enabled;
    _logger.i('Haptic feedback ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Clean up expired notifications
  Future<void> cleanupExpiredNotifications() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 1));
      final snapshot = await _incomingRequestsCollection
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      if (snapshot.docs.isNotEmpty) {
        _logger.i('Cleaned up ${snapshot.docs.length} expired notifications');
      }
    } catch (e) {
      _logger.e('Error cleaning up expired notifications: $e');
    }
  }

  /// Get notification settings
  bool get isSoundEnabled => _soundEnabled;
  bool get isHapticEnabled => _hapticEnabled;

  /// Dispose resources
  Future<void> dispose() async {
    try {
      // Cancel all subscriptions
      for (final subscription in _activeSubscriptions.values) {
        await subscription.cancel();
      }
      _activeSubscriptions.clear();

      // Cancel all timers
      for (final timer in _timeoutTimers.values) {
        timer.cancel();
      }
      _timeoutTimers.clear();

      _logger.i('Request notification service disposed');
    } catch (e) {
      _logger.e('Error disposing notification service: $e');
    }
  }
}