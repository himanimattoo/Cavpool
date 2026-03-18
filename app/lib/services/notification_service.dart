import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'local_notification_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'notifications';
  final LocalNotificationService _localService = LocalNotificationService();
  bool _useLocalFallback = false;
  
  // Force local mode (useful for development)
  void enableLocalMode() {
    _useLocalFallback = true;
    debugPrint('Notification service switched to local mode');
  }

  // Create a new notification
  Future<String?> createNotification(AppNotification notification) async {
    if (_useLocalFallback) {
      return await _localService.createNotification(notification);
    }
    
    try {
      final docRef = await _firestore.collection(_collection).add(notification.toMap());
      debugPrint('Created notification: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        debugPrint('Firestore permission denied, using local storage for notifications');
        _useLocalFallback = true;
        return await _localService.createNotification(notification);
      }
      debugPrint('Error creating notification: $e');
      return null;
    }
  }

  // Get notifications for a user
  Stream<List<AppNotification>> getUserNotifications(String userId, {int limit = 50}) {
    if (_useLocalFallback) {
      debugPrint('Using local service for getUserNotifications');
      return _localService.getUserNotifications(userId, limit: limit);
    }
    
    try {
      return _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .handleError((error) {
            if (error.toString().contains('permission-denied')) {
              debugPrint('Firestore permission denied in getUserNotifications, switching to local storage');
              _useLocalFallback = true;
            }
          })
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .where((notification) => !notification.isExpired)
            .toList();
      });
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        debugPrint('Firestore permission denied, fallback to local service');
        _useLocalFallback = true;
        return _localService.getUserNotifications(userId, limit: limit);
      }
      rethrow;
    }
  }

  // Get unread notification count
  Stream<int> getUnreadCount(String userId) {
    if (_useLocalFallback) {
      return _localService.getUnreadCount(userId);
    }
    
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .handleError((error) {
          if (error.toString().contains('permission-denied')) {
            debugPrint('Firestore permission denied, switching to local storage');
            _useLocalFallback = true;
          }
        })
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .where((notification) => !notification.isExpired)
          .length;
    });
  }

  // Get urgent notifications
  Stream<List<AppNotification>> getUrgentNotifications(String userId) {
    if (_useLocalFallback) {
      return _localService.getUrgentNotifications(userId);
    }
    
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('priority', isEqualTo: NotificationPriority.urgent.name)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          if (error.toString().contains('permission-denied')) {
            debugPrint('Firestore permission denied, switching to local storage');
            _useLocalFallback = true;
          }
        })
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .where((notification) => !notification.isExpired)
          .toList();
    });
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).update({
        'isRead': true,
      });
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  // Mark all notifications as read for a user
  Future<bool> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  // Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  // Delete expired notifications for a user
  Future<void> cleanupExpiredNotifications(String userId) async {
    try {
      final now = Timestamp.now();
      final expiredNotifications = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isLessThan: now)
          .get();

      final batch = _firestore.batch();
      for (var doc in expiredNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Cleaned up ${expiredNotifications.docs.length} expired notifications');
    } catch (e) {
      debugPrint('Error cleaning up expired notifications: $e');
    }
  }

  // Helper methods for creating specific notification types

  Future<String?> notifyDriverOfRideRequest({
    required String driverId,
    required String requesterId,
    required String requesterName,
    required String pickup,
    required String dropoff,
    required String rideRequestId,
  }) async {
    final notification = NotificationFactory.createRideRequest(
      driverId: driverId,
      requesterId: requesterId,
      requesterName: requesterName,
      pickup: pickup,
      dropoff: dropoff,
      rideRequestId: rideRequestId,
    );
    return await createNotification(notification);
  }

  Future<String?> notifyRiderOfAcceptedRequest({
    required String riderId,
    required String driverName,
    required String pickup,
    required String rideId,
  }) async {
    final notification = NotificationFactory.createRequestAccepted(
      riderId: riderId,
      driverName: driverName,
      pickup: pickup,
      rideId: rideId,
    );
    return await createNotification(notification);
  }

  Future<String?> notifyRiderDriverArrived({
    required String riderId,
    required String driverName,
    required String pickup,
    required String rideId,
  }) async {
    final notification = NotificationFactory.createDriverArrived(
      riderId: riderId,
      driverName: driverName,
      pickup: pickup,
      rideId: rideId,
    );
    return await createNotification(notification);
  }

  Future<String?> notifyRiderOfDepartureReminder({
    required String riderId,
    required String pickup,
    required DateTime departureTime,
    required String rideId,
  }) async {
    final notification = NotificationFactory.createDepartureReminder(
      riderId: riderId,
      pickup: pickup,
      departureTime: departureTime,
      rideId: rideId,
    );
    return await createNotification(notification);
  }

  Future<String?> notifyOfCancellation({
    required String userId,
    required String cancelledBy,
    required String reason,
    String? rideId,
  }) async {
    final notification = NotificationFactory.createRideCancelled(
      userId: userId,
      cancelledBy: cancelledBy,
      reason: reason,
      rideId: rideId,
    );
    return await createNotification(notification);
  }

  // Send bulk notifications (useful for system announcements)
  Future<int> sendBulkNotifications(List<AppNotification> notifications) async {
    int successCount = 0;
    final batch = _firestore.batch();

    for (var notification in notifications) {
      final docRef = _firestore.collection(_collection).doc();
      batch.set(docRef, notification.copyWith(id: docRef.id).toMap());
    }

    try {
      await batch.commit();
      successCount = notifications.length;
      debugPrint('Sent $successCount bulk notifications');
    } catch (e) {
      debugPrint('Error sending bulk notifications: $e');
    }

    return successCount;
  }

  // Get notification statistics
  Future<Map<String, int>> getNotificationStats(String userId) async {
    try {
      final allNotifications = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      final notifications = allNotifications.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .where((n) => !n.isExpired)
          .toList();

      return {
        'total': notifications.length,
        'unread': notifications.where((n) => !n.isRead).length,
        'urgent': notifications.where((n) => n.isUrgent && !n.isRead).length,
        'actionable': notifications.where((n) => n.isActionable && !n.isRead).length,
      };
    } catch (e) {
      debugPrint('Error getting notification stats: $e');
      return {'total': 0, 'unread': 0, 'urgent': 0, 'actionable': 0};
    }
  }
}