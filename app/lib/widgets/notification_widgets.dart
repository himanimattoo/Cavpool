import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

// Notification Badge - shows unread count
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const NotificationBadge({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final unreadCount = notificationProvider.unreadCount;
        
        return GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              child,
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Individual notification card
class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _getNotificationIcon(),
        title: Text(
          notification.title,
          style: GoogleFonts.inter(
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              notification.formattedTime,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getPriorityColor(),
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 8),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        onTap: onTap,
        tileColor: notification.isRead ? null : Colors.blue.shade50,
      ),
    );
  }

  Widget _getNotificationIcon() {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.newRideRequest:
        iconData = Icons.directions_car;
        iconColor = Colors.blue;
        break;
      case NotificationType.requestAccepted:
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case NotificationType.requestDeclined:
        iconData = Icons.cancel;
        iconColor = Colors.red;
        break;
      case NotificationType.driverArrived:
        iconData = Icons.location_on;
        iconColor = Colors.orange;
        break;
      case NotificationType.rideCancelled:
        iconData = Icons.cancel_outlined;
        iconColor = Colors.red;
        break;
      case NotificationType.departureReminder:
        iconData = Icons.schedule;
        iconColor = Colors.orange;
        break;
      case NotificationType.rideCompleted:
        iconData = Icons.flag;
        iconColor = Colors.green;
        break;
      case NotificationType.newRatingReceived:
        iconData = Icons.star;
        iconColor = Colors.amber;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withValues(alpha: 0.1),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  Color _getPriorityColor() {
    switch (notification.priority) {
      case NotificationPriority.urgent:
        return Colors.red;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.normal:
        return Colors.blue;
      case NotificationPriority.low:
        return Colors.grey;
    }
  }
}

// Notifications list screen
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, _) {
              if (notificationProvider.unreadCount > 0) {
                return TextButton(
                  onPressed: () async {
                    await notificationProvider.markAllAsRead();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All notifications marked as read')),
                      );
                    }
                  },
                  child: Text(
                    'Mark All Read',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, _) {
          if (notificationProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = notificationProvider.notifications;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New notifications will appear here',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Notifications are automatically refreshed via streams
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return NotificationCard(
                  notification: notification,
                  onTap: () => _onNotificationTap(context, notification, notificationProvider),
                  onDismiss: () => _onNotificationDismiss(context, notification, notificationProvider),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onNotificationTap(BuildContext context, AppNotification notification, NotificationProvider provider) async {
    // Mark as read
    await provider.markAsRead(notification.id);

    // Handle action if applicable
    if (notification.isActionable && notification.actionRoute != null) {
      if (context.mounted) {
        Navigator.of(context).pushNamed(notification.actionRoute!);
      }
    }
  }

  void _onNotificationDismiss(BuildContext context, AppNotification notification, NotificationProvider provider) async {
    await provider.deleteNotification(notification.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification dismissed')),
      );
    }
  }
}

// Urgent notification overlay
class UrgentNotificationOverlay extends StatelessWidget {
  const UrgentNotificationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final urgentNotifications = notificationProvider.urgentNotifications;
        
        if (urgentNotifications.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Column(
            children: urgentNotifications.map((notification) {
              return Card(
                color: Colors.red.shade50,
                elevation: 8,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.priority_high, color: Colors.red.shade600),
                  title: Text(
                    notification.title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  subtitle: Text(
                    notification.message,
                    style: GoogleFonts.inter(
                      color: Colors.red.shade700,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.close, color: Colors.red.shade600),
                    onPressed: () => notificationProvider.markAsRead(notification.id),
                  ),
                  onTap: () {
                    notificationProvider.markAsRead(notification.id);
                    if (notification.actionRoute != null) {
                      Navigator.of(context).pushNamed(notification.actionRoute!);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// Mini notification banner for high priority notifications
class NotificationBanner extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onDismiss;

  const NotificationBanner({
    super.key,
    required this.notification,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getBannerColor(),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          Icons.notifications_active,
          color: Colors.white,
        ),
        title: Text(
          notification.title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          notification.message,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: onDismiss != null
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onDismiss,
              )
            : null,
      ),
    );
  }

  Color _getBannerColor() {
    switch (notification.priority) {
      case NotificationPriority.urgent:
        return Colors.red.shade600;
      case NotificationPriority.high:
        return Colors.orange.shade600;
      case NotificationPriority.normal:
        return Colors.blue.shade600;
      case NotificationPriority.low:
        return Colors.grey.shade600;
    }
  }
}