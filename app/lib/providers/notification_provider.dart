import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  
  // Current user ID
  String? _currentUserId;
  
  // Notifications state
  List<AppNotification> _notifications = [];
  List<AppNotification> _urgentNotifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  
  // Stream subscriptions
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;
  StreamSubscription<List<AppNotification>>? _urgentSubscription;
  StreamSubscription<int>? _unreadCountSubscription;
  
  // Getters
  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get urgentNotifications => _urgentNotifications;
  List<AppNotification> get unreadNotifications => 
      _notifications.where((n) => !n.isRead).toList();
  List<AppNotification> get actionableNotifications => 
      _notifications.where((n) => n.isActionable && !n.isRead).toList();
  int get unreadCount => _unreadCount;
  bool get hasUrgentNotifications => _urgentNotifications.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get currentUserId => _currentUserId;
  
  // Initialize notifications for a user
  void initializeForUser(String userId) {
    if (_currentUserId == userId) return;
    
    _currentUserId = userId;
    _cleanup();
    
    // Enable local mode immediately due to permission issues
    _notificationService.enableLocalMode();
    
    _setupNotificationStreams(userId);
    _cleanupExpiredNotifications(userId);
  }
  
  // Enable local mode for development
  void enableLocalMode() {
    _notificationService.enableLocalMode();
  }
  
  // Setup notification streams
  void _setupNotificationStreams(String userId) {
    // Listen to all notifications
    _notificationsSubscription = _notificationService
        .getUserNotifications(userId)
        .listen((notifications) {
      _notifications = notifications;
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error in notifications stream: $error');
    });
    
    // Listen to urgent notifications
    _urgentSubscription = _notificationService
        .getUrgentNotifications(userId)
        .listen((urgentNotifications) {
      _urgentNotifications = urgentNotifications;
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error in urgent notifications stream: $error');
    });
    
    // Listen to unread count
    _unreadCountSubscription = _notificationService
        .getUnreadCount(userId)
        .listen((count) {
      _unreadCount = count;
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error in unread count stream: $error');
    });
  }
  
  // Cleanup expired notifications
  Future<void> _cleanupExpiredNotifications(String userId) async {
    await _notificationService.cleanupExpiredNotifications(userId);
  }
  
  // Create a new notification
  Future<bool> createNotification(AppNotification notification) async {
    _setLoading(true);
    final id = await _notificationService.createNotification(notification);
    _setLoading(false);
    return id != null;
  }
  
  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    final success = await _notificationService.markAsRead(notificationId);
    if (success) {
      // Update local state immediately for better UX
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        
        // Remove from urgent notifications if present
        _urgentNotifications.removeWhere((n) => n.id == notificationId);
        
        notifyListeners();
      }
    }
    return success;
  }
  
  // Mark all notifications as read
  Future<bool> markAllAsRead() async {
    if (_currentUserId == null) return false;
    
    _setLoading(true);
    final success = await _notificationService.markAllAsRead(_currentUserId!);
    _setLoading(false);
    
    if (success) {
      // Update local state
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _urgentNotifications.clear();
      _unreadCount = 0;
      notifyListeners();
    }
    
    return success;
  }
  
  // Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    final success = await _notificationService.deleteNotification(notificationId);
    if (success) {
      _notifications.removeWhere((n) => n.id == notificationId);
      _urgentNotifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    }
    return success;
  }
  
  // Helper methods for creating specific notifications
  
  Future<bool> notifyDriverOfRideRequest({
    required String driverId,
    required String requesterId,
    required String requesterName,
    required String pickup,
    required String dropoff,
    required String rideRequestId,
  }) async {
    final id = await _notificationService.notifyDriverOfRideRequest(
      driverId: driverId,
      requesterId: requesterId,
      requesterName: requesterName,
      pickup: pickup,
      dropoff: dropoff,
      rideRequestId: rideRequestId,
    );
    return id != null;
  }
  
  Future<bool> notifyRiderOfAcceptedRequest({
    required String riderId,
    required String driverName,
    required String pickup,
    required String rideId,
  }) async {
    final id = await _notificationService.notifyRiderOfAcceptedRequest(
      riderId: riderId,
      driverName: driverName,
      pickup: pickup,
      rideId: rideId,
    );
    return id != null;
  }
  
  Future<bool> notifyRiderDriverArrived({
    required String riderId,
    required String driverName,
    required String pickup,
    required String rideId,
  }) async {
    final id = await _notificationService.notifyRiderDriverArrived(
      riderId: riderId,
      driverName: driverName,
      pickup: pickup,
      rideId: rideId,
    );
    return id != null;
  }
  
  Future<bool> notifyRiderOfDepartureReminder({
    required String riderId,
    required String pickup,
    required DateTime departureTime,
    required String rideId,
  }) async {
    final id = await _notificationService.notifyRiderOfDepartureReminder(
      riderId: riderId,
      pickup: pickup,
      departureTime: departureTime,
      rideId: rideId,
    );
    return id != null;
  }
  
  Future<bool> notifyOfCancellation({
    required String userId,
    required String cancelledBy,
    required String reason,
    String? rideId,
  }) async {
    final id = await _notificationService.notifyOfCancellation(
      userId: userId,
      cancelledBy: cancelledBy,
      reason: reason,
      rideId: rideId,
    );
    return id != null;
  }
  
  // Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }
  
  // Get notifications by priority
  List<AppNotification> getNotificationsByPriority(NotificationPriority priority) {
    return _notifications.where((n) => n.priority == priority).toList();
  }
  
  // Get notification stats
  Future<Map<String, int>> getStats() async {
    if (_currentUserId == null) {
      return {'total': 0, 'unread': 0, 'urgent': 0, 'actionable': 0};
    }
    return await _notificationService.getNotificationStats(_currentUserId!);
  }
  
  // Show notification snackbar or dialog
  void showNotificationUI(BuildContext context, AppNotification notification) {
    if (notification.isUrgent) {
      _showUrgentNotificationDialog(context, notification);
    } else {
      _showNotificationSnackbar(context, notification);
    }
  }
  
  void _showUrgentNotificationDialog(BuildContext context, AppNotification notification) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.priority_high, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Expanded(child: Text(notification.title)),
          ],
        ),
        content: Text(notification.message),
        actions: [
          if (notification.isActionable) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                markAsRead(notification.id);
                // Navigate to action route if needed
                if (notification.actionRoute != null) {
                  Navigator.of(context).pushNamed(notification.actionRoute!);
                }
              },
              child: Text(notification.actionText ?? 'View'),
            ),
          ],
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              markAsRead(notification.id);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showNotificationSnackbar(BuildContext context, AppNotification notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(notification.message),
          ],
        ),
        action: notification.isActionable
            ? SnackBarAction(
                label: notification.actionText ?? 'View',
                onPressed: () {
                  markAsRead(notification.id);
                  if (notification.actionRoute != null) {
                    Navigator.of(context).pushNamed(notification.actionRoute!);
                  }
                },
              )
            : null,
        duration: Duration(seconds: notification.isHighPriority ? 6 : 4),
        backgroundColor: notification.isHighPriority 
            ? Colors.orange.shade800 
            : null,
      ),
    );
  }
  
  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _cleanup() {
    _notificationsSubscription?.cancel();
    _urgentSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    
    _notifications.clear();
    _urgentNotifications.clear();
    _unreadCount = 0;
    _isLoading = false;
  }

  /// Cancel all subscriptions (for logout cleanup)
  void cancelAllSubscriptions() {
    _cleanup();
  }
  
  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}