import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/ride_model.dart';

enum NotificationType {
  statusChange,
  driverArrived,
  pickupReady,
  dropoffReady,
  rideStarted,
  rideCompleted,
  requestAccepted,
  requestDeclined,
  etaUpdate,
}

class RideNotification {
  final String id;
  final String rideId;
  final String recipientId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;
  final bool requiresAction;

  RideNotification({
    required this.id,
    required this.rideId,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.timestamp,
    this.isRead = false,
    this.requiresAction = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rideId': rideId,
      'recipientId': recipientId,
      'type': type.name,
      'title': title,
      'message': message,
      'data': data,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'requiresAction': requiresAction,
    };
  }

  factory RideNotification.fromMap(Map<String, dynamic> map) {
    return RideNotification(
      id: map['id'] ?? '',
      rideId: map['rideId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.statusChange,
      ),
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      requiresAction: map['requiresAction'] ?? false,
    );
  }
}

class RideNotificationService {
  static final RideNotificationService _instance = RideNotificationService._internal();
  factory RideNotificationService() => _instance;
  RideNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  CollectionReference get _notificationsCollection => 
      _firestore.collection('ride_notifications');

  /// Send notification to specific user
  Future<void> sendNotification({
    required String rideId,
    required String recipientId,
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    bool requiresAction = false,
  }) async {
    try {
      final notificationId = '${rideId}_${recipientId}_${DateTime.now().millisecondsSinceEpoch}';
      
      final notification = RideNotification(
        id: notificationId,
        rideId: rideId,
        recipientId: recipientId,
        type: type,
        title: title,
        message: message,
        data: data ?? {},
        timestamp: DateTime.now(),
        requiresAction: requiresAction,
      );

      await _notificationsCollection.doc(notificationId).set(notification.toMap());
      
      _logger.i('Notification sent to $recipientId: $title');
    } catch (e) {
      _logger.e('Error sending notification: $e');
    }
  }

  /// Send notification to multiple users
  Future<void> sendBulkNotification({
    required String rideId,
    required List<String> recipientIds,
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    bool requiresAction = false,
  }) async {
    try {
      final batch = _firestore.batch();
      final timestamp = DateTime.now();

      for (final recipientId in recipientIds) {
        final notificationId = '${rideId}_${recipientId}_${timestamp.millisecondsSinceEpoch}';
        
        final notification = RideNotification(
          id: notificationId,
          rideId: rideId,
          recipientId: recipientId,
          type: type,
          title: title,
          message: message,
          data: data ?? {},
          timestamp: timestamp,
          requiresAction: requiresAction,
        );

        batch.set(
          _notificationsCollection.doc(notificationId),
          notification.toMap(),
        );
      }

      await batch.commit();
      
      _logger.i('Bulk notification sent to ${recipientIds.length} users: $title');
    } catch (e) {
      _logger.e('Error sending bulk notification: $e');
    }
  }

  /// Send notification to all ride participants
  Future<void> sendRideNotification({
    required RideOffer ride,
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    bool requiresAction = false,
    bool excludeDriver = false,
  }) async {
    try {
      final recipientIds = <String>[];
      
      if (!excludeDriver) {
        recipientIds.add(ride.driverId);
      }
      
      recipientIds.addAll(ride.passengerIds);

      await sendBulkNotification(
        rideId: ride.id,
        recipientIds: recipientIds,
        type: type,
        title: title,
        message: message,
        data: data,
        requiresAction: requiresAction,
      );
    } catch (e) {
      _logger.e('Error sending ride notification: $e');
    }
  }

  /// Notify driver arrival
  Future<void> notifyDriverArrival({
    required String rideId,
    required String passengerId,
    required String driverName,
    required String pickupAddress,
  }) async {
    await sendNotification(
      rideId: rideId,
      recipientId: passengerId,
      type: NotificationType.driverArrived,
      title: 'Driver Arrived',
      message: '$driverName has arrived at $pickupAddress',
      data: {
        'action': 'driverArrived',
        'driverName': driverName,
        'pickupAddress': pickupAddress,
      },
    );
  }

  /// Notify pickup ready confirmation needed
  Future<void> notifyPickupReady({
    required String rideId,
    required String driverId,
    required String passengerName,
  }) async {
    await sendNotification(
      rideId: rideId,
      recipientId: driverId,
      type: NotificationType.pickupReady,
      title: 'Pickup Confirmation',
      message: '$passengerName is ready for pickup - please confirm',
      data: {
        'action': 'confirmPickup',
        'passengerName': passengerName,
      },
      requiresAction: true,
    );
  }

  /// Notify dropoff ready confirmation needed
  Future<void> notifyDropoffReady({
    required String rideId,
    required String driverId,
    required String passengerName,
    required String dropoffAddress,
  }) async {
    await sendNotification(
      rideId: rideId,
      recipientId: driverId,
      type: NotificationType.dropoffReady,
      title: 'Dropoff Confirmation',
      message: 'Arrived at $dropoffAddress - confirm $passengerName dropoff',
      data: {
        'action': 'confirmDropoff',
        'passengerName': passengerName,
        'dropoffAddress': dropoffAddress,
      },
      requiresAction: true,
    );
  }

  /// Notify ride start
  Future<void> notifyRideStarted({
    required RideOffer ride,
  }) async {
    await sendRideNotification(
      ride: ride,
      type: NotificationType.rideStarted,
      title: 'Ride Started',
      message: 'Your ride has started - enjoy your journey!',
      data: {'action': 'rideStarted'},
    );
  }

  /// Notify ride completion
  Future<void> notifyRideCompleted({
    required RideOffer ride,
  }) async {
    await sendRideNotification(
      ride: ride,
      type: NotificationType.rideCompleted,
      title: 'Ride Completed',
      message: 'Your ride has been completed successfully',
      data: {'action': 'rideCompleted'},
    );
  }

  /// Notify request acceptance
  Future<void> notifyRequestAccepted({
    required String rideId,
    required String passengerId,
    required String driverName,
    required DateTime departureTime,
  }) async {
    await sendNotification(
      rideId: rideId,
      recipientId: passengerId,
      type: NotificationType.requestAccepted,
      title: 'Request Accepted',
      message: '$driverName accepted your ride request for ${_formatTime(departureTime)}',
      data: {
        'action': 'requestAccepted',
        'driverName': driverName,
        'departureTime': departureTime.toIso8601String(),
      },
    );
  }

  /// Notify request decline
  Future<void> notifyRequestDeclined({
    required String rideId,
    required String passengerId,
    required String reason,
  }) async {
    await sendNotification(
      rideId: rideId,
      recipientId: passengerId,
      type: NotificationType.requestDeclined,
      title: 'Request Declined',
      message: 'Your ride request was declined: $reason',
      data: {
        'action': 'requestDeclined',
        'reason': reason,
      },
    );
  }

  /// Notify ETA updates
  Future<void> notifyETAUpdate({
    required String rideId,
    required String recipientId,
    required String eta,
    required String context,
  }) async {
    await sendNotification(
      rideId: rideId,
      recipientId: recipientId,
      type: NotificationType.etaUpdate,
      title: 'ETA Update',
      message: '$context: $eta',
      data: {
        'action': 'etaUpdate',
        'eta': eta,
        'context': context,
      },
    );
  }

  /// Get notifications for user
  Stream<List<RideNotification>> getNotificationsStream(String userId) {
    try {
      return _notificationsCollection
          .where('recipientId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => RideNotification.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      _logger.e('Error getting notifications stream: $e');
      return Stream.value([]);
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({'isRead': true});
    } catch (e) {
      _logger.e('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for user
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _notificationsCollection
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      _logger.e('Error marking all notifications as read: $e');
    }
  }

  /// Delete old notifications
  Future<void> cleanupOldNotifications({Duration olderThan = const Duration(days: 30)}) async {
    try {
      final cutoffDate = DateTime.now().subtract(olderThan);
      final snapshot = await _notificationsCollection
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      _logger.i('Cleaned up ${snapshot.docs.length} old notifications');
    } catch (e) {
      _logger.e('Error cleaning up notifications: $e');
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$displayHour:$minute $period';
  }
}