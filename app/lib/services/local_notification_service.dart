import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

/// Local in-memory notification service for development and testing
/// This service stores notifications in memory and simulates real-time updates
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  // In-memory storage
  final Map<String, List<AppNotification>> _userNotifications = {};
  
  // Stream controllers for real-time updates
  final Map<String, StreamController<List<AppNotification>>> _notificationControllers = {};
  final Map<String, StreamController<List<AppNotification>>> _urgentControllers = {};
  final Map<String, StreamController<int>> _countControllers = {};

  int _idCounter = 1;

  // Create a new notification
  Future<String?> createNotification(AppNotification notification) async {
    try {
      final id = 'local_${_idCounter++}';
      final notificationWithId = notification.copyWith(id: id);
      
      // Add to user's notifications
      _userNotifications.putIfAbsent(notification.userId, () => []);
      _userNotifications[notification.userId]!.insert(0, notificationWithId);
      
      // Trigger updates
      _updateStreams(notification.userId);
      
      debugPrint('Created local notification: $id');
      return id;
    } catch (e) {
      debugPrint('Error creating local notification: $e');
      return null;
    }
  }

  // Get notifications for a user
  Stream<List<AppNotification>> getUserNotifications(String userId, {int limit = 50}) {
    _notificationControllers.putIfAbsent(userId, () => StreamController.broadcast());
    
    // Send initial data
    final notifications = _userNotifications[userId] ?? [];
    final filteredNotifications = notifications
        .where((n) => !n.isExpired)
        .take(limit)
        .toList();
    
    _notificationControllers[userId]!.add(filteredNotifications);
    
    return _notificationControllers[userId]!.stream;
  }

  // Get unread notification count
  Stream<int> getUnreadCount(String userId) {
    _countControllers.putIfAbsent(userId, () => StreamController.broadcast());
    
    // Send initial count
    final notifications = _userNotifications[userId] ?? [];
    final unreadCount = notifications
        .where((n) => !n.isRead && !n.isExpired)
        .length;
    
    _countControllers[userId]!.add(unreadCount);
    
    return _countControllers[userId]!.stream;
  }

  // Get urgent notifications
  Stream<List<AppNotification>> getUrgentNotifications(String userId) {
    _urgentControllers.putIfAbsent(userId, () => StreamController.broadcast());
    
    // Send initial data
    final notifications = _userNotifications[userId] ?? [];
    final urgentNotifications = notifications
        .where((n) => n.priority == NotificationPriority.urgent && !n.isRead && !n.isExpired)
        .toList();
    
    _urgentControllers[userId]!.add(urgentNotifications);
    
    return _urgentControllers[userId]!.stream;
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      for (var userNotifications in _userNotifications.values) {
        final index = userNotifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          userNotifications[index] = userNotifications[index].copyWith(isRead: true);
          _updateStreams(userNotifications[index].userId);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error marking local notification as read: $e');
      return false;
    }
  }

  // Mark all notifications as read for a user
  Future<bool> markAllAsRead(String userId) async {
    try {
      final notifications = _userNotifications[userId] ?? [];
      for (int i = 0; i < notifications.length; i++) {
        notifications[i] = notifications[i].copyWith(isRead: true);
      }
      _updateStreams(userId);
      return true;
    } catch (e) {
      debugPrint('Error marking all local notifications as read: $e');
      return false;
    }
  }

  // Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      for (var userNotifications in _userNotifications.values) {
        final index = userNotifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          final userId = userNotifications[index].userId;
          userNotifications.removeAt(index);
          _updateStreams(userId);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting local notification: $e');
      return false;
    }
  }

  // Delete expired notifications for a user
  Future<void> cleanupExpiredNotifications(String userId) async {
    try {
      final notifications = _userNotifications[userId] ?? [];
      final beforeCount = notifications.length;
      notifications.removeWhere((n) => n.isExpired);
      final afterCount = notifications.length;
      
      if (beforeCount != afterCount) {
        _updateStreams(userId);
        debugPrint('Cleaned up ${beforeCount - afterCount} expired local notifications');
      }
    } catch (e) {
      debugPrint('Error cleaning up expired local notifications: $e');
    }
  }

  // Helper method to update all streams for a user
  void _updateStreams(String userId) {
    final notifications = _userNotifications[userId] ?? [];
    final activeNotifications = notifications.where((n) => !n.isExpired).toList();
    
    // Update notifications stream
    if (_notificationControllers.containsKey(userId)) {
      _notificationControllers[userId]!.add(activeNotifications);
    }
    
    // Update unread count stream
    if (_countControllers.containsKey(userId)) {
      final unreadCount = activeNotifications.where((n) => !n.isRead).length;
      _countControllers[userId]!.add(unreadCount);
    }
    
    // Update urgent notifications stream
    if (_urgentControllers.containsKey(userId)) {
      final urgentNotifications = activeNotifications
          .where((n) => n.priority == NotificationPriority.urgent && !n.isRead)
          .toList();
      _urgentControllers[userId]!.add(urgentNotifications);
    }
  }

  // Get notification statistics
  Future<Map<String, int>> getNotificationStats(String userId) async {
    try {
      final notifications = _userNotifications[userId] ?? [];
      final activeNotifications = notifications.where((n) => !n.isExpired).toList();

      return {
        'total': activeNotifications.length,
        'unread': activeNotifications.where((n) => !n.isRead).length,
        'urgent': activeNotifications.where((n) => n.isUrgent && !n.isRead).length,
        'actionable': activeNotifications.where((n) => n.isActionable && !n.isRead).length,
      };
    } catch (e) {
      debugPrint('Error getting local notification stats: $e');
      return {'total': 0, 'unread': 0, 'urgent': 0, 'actionable': 0};
    }
  }

  // Cleanup method
  void dispose() {
    for (var controller in _notificationControllers.values) {
      controller.close();
    }
    for (var controller in _urgentControllers.values) {
      controller.close();
    }
    for (var controller in _countControllers.values) {
      controller.close();
    }
    
    _notificationControllers.clear();
    _urgentControllers.clear();
    _countControllers.clear();
    _userNotifications.clear();
  }

  // Add some sample notifications for testing
  void addSampleNotifications(String userId) async {
    final sampleNotifications = [
      AppNotification(
        id: '',
        userId: userId,
        type: NotificationType.newRideRequest,
        title: 'New Ride Request',
        message: 'Sarah wants a ride from Campus to Downtown',
        priority: NotificationPriority.high,
        isActionable: true,
        actionText: 'View Request',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      AppNotification(
        id: '',
        userId: userId,
        type: NotificationType.requestAccepted,
        title: 'Ride Request Accepted!',
        message: 'Mike accepted your ride request to the airport',
        priority: NotificationPriority.high,
        isActionable: true,
        actionText: 'View Ride',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      AppNotification(
        id: '',
        userId: userId,
        type: NotificationType.departureReminder,
        title: 'Ride Starting Soon',
        message: 'Your ride to the mall departs in 15 minutes',
        priority: NotificationPriority.urgent,
        isActionable: true,
        actionText: 'View Details',
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ];

    for (var notification in sampleNotifications) {
      await createNotification(notification);
      await Future.delayed(const Duration(milliseconds: 100)); // Small delay for realism
    }
  }
}