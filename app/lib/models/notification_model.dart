import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  // Driver notifications
  newRideRequest,
  rideRequestCancelled,
  passengerPickedUp,
  rideCompleted,
  newRatingReceived,
  
  // Rider notifications
  requestAccepted,
  requestDeclined,
  driverArrived,
  rideCancelled,
  departureReminder,
  
  // System notifications
  accountVerified,
  securityAlert,
  appUpdate,
  
  // Safety notifications
  safety,
  safetyReportConfirmation,
  emergencyAlert,
  
  // General
  message,
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final NotificationPriority priority;
  final bool isRead;
  final bool isActionable;
  final String? actionText;
  final String? actionRoute;
  final DateTime createdAt;
  final DateTime? expiresAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    this.priority = NotificationPriority.normal,
    this.isRead = false,
    this.isActionable = false,
    this.actionText,
    this.actionRoute,
    required this.createdAt,
    this.expiresAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'title': title,
      'message': message,
      'data': data,
      'priority': priority.name,
      'isRead': isRead,
      'isActionable': isActionable,
      'actionText': actionText,
      'actionRoute': actionRoute,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => NotificationType.message,
      ),
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      data: map['data'],
      priority: NotificationPriority.values.firstWhere(
        (p) => p.name == map['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      isRead: map['isRead'] ?? false,
      isActionable: map['isActionable'] ?? false,
      actionText: map['actionText'],
      actionRoute: map['actionRoute'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null 
          ? (map['expiresAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppNotification.fromMap({...data, 'id': doc.id});
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    NotificationPriority? priority,
    bool? isRead,
    bool? isActionable,
    String? actionText,
    String? actionRoute,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      isActionable: isActionable ?? this.isActionable,
      actionText: actionText ?? this.actionText,
      actionRoute: actionRoute ?? this.actionRoute,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  // Helper methods
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isHighPriority => priority == NotificationPriority.high || priority == NotificationPriority.urgent;
  bool get isUrgent => priority == NotificationPriority.urgent;

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
    }
  }
}

// Factory methods for common notification types
class NotificationFactory {
  static AppNotification createRideRequest({
    required String driverId,
    required String requesterId,
    required String requesterName,
    required String pickup,
    required String dropoff,
    required String rideRequestId,
  }) {
    return AppNotification(
      id: '',
      userId: driverId,
      type: NotificationType.newRideRequest,
      title: 'New Ride Request',
      message: '$requesterName wants a ride from $pickup to $dropoff',
      data: {
        'requesterId': requesterId,
        'rideRequestId': rideRequestId,
        'pickup': pickup,
        'dropoff': dropoff,
      },
      priority: NotificationPriority.high,
      isActionable: true,
      actionText: 'View Request',
      actionRoute: '/driver/requests',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
    );
  }

  static AppNotification createRequestAccepted({
    required String riderId,
    required String driverName,
    required String pickup,
    required String rideId,
  }) {
    return AppNotification(
      id: '',
      userId: riderId,
      type: NotificationType.requestAccepted,
      title: 'Ride Request Accepted!',
      message: '$driverName accepted your ride request. Pickup at $pickup',
      data: {
        'rideId': rideId,
        'driverName': driverName,
      },
      priority: NotificationPriority.high,
      isActionable: true,
      actionText: 'View Ride',
      actionRoute: '/rides/$rideId',
      createdAt: DateTime.now(),
    );
  }

  static AppNotification createDriverArrived({
    required String riderId,
    required String driverName,
    required String pickup,
    required String rideId,
  }) {
    return AppNotification(
      id: '',
      userId: riderId,
      type: NotificationType.driverArrived,
      title: 'Driver Arrived',
      message: '$driverName has arrived at $pickup',
      data: {
        'rideId': rideId,
        'driverName': driverName,
      },
      priority: NotificationPriority.urgent,
      isActionable: true,
      actionText: 'View Ride',
      actionRoute: '/rides/$rideId',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    );
  }

  static AppNotification createDepartureReminder({
    required String riderId,
    required String pickup,
    required DateTime departureTime,
    required String rideId,
  }) {
    return AppNotification(
      id: '',
      userId: riderId,
      type: NotificationType.departureReminder,
      title: 'Ride Starting Soon',
      message: 'Your ride departs in 30 minutes from $pickup',
      data: {
        'rideId': rideId,
        'departureTime': departureTime.toIso8601String(),
      },
      priority: NotificationPriority.high,
      isActionable: true,
      actionText: 'View Ride',
      actionRoute: '/rides/$rideId',
      createdAt: DateTime.now(),
    );
  }

  static AppNotification createRideCancelled({
    required String userId,
    required String cancelledBy,
    required String reason,
    String? rideId,
  }) {
    return AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.rideCancelled,
      title: 'Ride Cancelled',
      message: 'Your ride was cancelled by $cancelledBy. $reason',
      data: {
        'rideId': rideId,
        'cancelledBy': cancelledBy,
        'reason': reason,
      },
      priority: NotificationPriority.high,
      createdAt: DateTime.now(),
    );
  }
}