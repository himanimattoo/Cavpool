import 'package:cloud_firestore/cloud_firestore.dart';

enum RideSharingPreference {
  always, // Always share rides
  askEachTime, // Prompt before each ride
  manual, // Share specific rides on-demand
  never, // Never share rides
}

enum SharedRideStatus {
  preparing, // Ride booked, preparing to start
  active, // Ride in progress
  completed, // Ride finished
  cancelled, // Ride was cancelled
  emergency, // Emergency button activated
}

enum NotificationDeliveryStatus {
  pending,
  sent,
  delivered,
  failed,
}

class SharedRideModel {
  final String id;
  final String rideId;
  final String shareOwnerId; // User who is sharing the ride
  final List<String> sharedWithContactIds; // Emergency contacts receiving updates
  final SharedRideStatus status;
  final String secureTrackingToken; // Public tracking URL token
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime expiresAt; // When tracking link expires (endTime + 24h)
  final Map<String, dynamic> rideDetails;
  final Map<String, dynamic> driverDetails;
  final Map<String, dynamic> currentLocation;
  final bool isEmergencyActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SharedRideModel({
    required this.id,
    required this.rideId,
    required this.shareOwnerId,
    required this.sharedWithContactIds,
    required this.status,
    required this.secureTrackingToken,
    required this.startTime,
    this.endTime,
    required this.expiresAt,
    required this.rideDetails,
    required this.driverDetails,
    required this.currentLocation,
    this.isEmergencyActive = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rideId': rideId,
      'shareOwnerId': shareOwnerId,
      'sharedWithContactIds': sharedWithContactIds,
      'status': status.name,
      'secureTrackingToken': secureTrackingToken,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'rideDetails': rideDetails,
      'driverDetails': driverDetails,
      'currentLocation': currentLocation,
      'isEmergencyActive': isEmergencyActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SharedRideModel.fromMap(Map<String, dynamic> map) {
    return SharedRideModel(
      id: map['id'] ?? '',
      rideId: map['rideId'] ?? '',
      shareOwnerId: map['shareOwnerId'] ?? '',
      sharedWithContactIds: List<String>.from(map['sharedWithContactIds'] ?? []),
      status: SharedRideStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SharedRideStatus.preparing,
      ),
      secureTrackingToken: map['secureTrackingToken'] ?? '',
      startTime: map['startTime'] != null 
          ? (map['startTime'] as Timestamp).toDate() 
          : DateTime.now(),
      endTime: map['endTime'] != null 
          ? (map['endTime'] as Timestamp).toDate() 
          : null,
      expiresAt: map['expiresAt'] != null 
          ? (map['expiresAt'] as Timestamp).toDate() 
          : DateTime.now().add(const Duration(days: 1)),
      rideDetails: Map<String, dynamic>.from(map['rideDetails'] ?? {}),
      driverDetails: Map<String, dynamic>.from(map['driverDetails'] ?? {}),
      currentLocation: Map<String, dynamic>.from(map['currentLocation'] ?? {}),
      isEmergencyActive: map['isEmergencyActive'] ?? false,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  factory SharedRideModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SharedRideModel.fromMap({...data, 'id': doc.id});
  }

  SharedRideModel copyWith({
    String? id,
    String? rideId,
    String? shareOwnerId,
    List<String>? sharedWithContactIds,
    SharedRideStatus? status,
    String? secureTrackingToken,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? expiresAt,
    Map<String, dynamic>? rideDetails,
    Map<String, dynamic>? driverDetails,
    Map<String, dynamic>? currentLocation,
    bool? isEmergencyActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SharedRideModel(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      shareOwnerId: shareOwnerId ?? this.shareOwnerId,
      sharedWithContactIds: sharedWithContactIds ?? this.sharedWithContactIds,
      status: status ?? this.status,
      secureTrackingToken: secureTrackingToken ?? this.secureTrackingToken,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      expiresAt: expiresAt ?? this.expiresAt,
      rideDetails: rideDetails ?? this.rideDetails,
      driverDetails: driverDetails ?? this.driverDetails,
      currentLocation: currentLocation ?? this.currentLocation,
      isEmergencyActive: isEmergencyActive ?? this.isEmergencyActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RideSharingNotification {
  final String id;
  final String sharedRideId;
  final String contactId;
  final String notificationType; // 'started', 'route_deviation', 'stop_extended', 'completed', 'emergency'
  final String message;
  final Map<String, dynamic> data;
  final NotificationDeliveryStatus smsStatus;
  final NotificationDeliveryStatus emailStatus;
  final NotificationDeliveryStatus pushStatus;
  final DateTime scheduledAt;
  final DateTime? sentAt;
  final DateTime createdAt;
  final List<String> deliveryAttempts;

  RideSharingNotification({
    required this.id,
    required this.sharedRideId,
    required this.contactId,
    required this.notificationType,
    required this.message,
    required this.data,
    this.smsStatus = NotificationDeliveryStatus.pending,
    this.emailStatus = NotificationDeliveryStatus.pending,
    this.pushStatus = NotificationDeliveryStatus.pending,
    required this.scheduledAt,
    this.sentAt,
    required this.createdAt,
    this.deliveryAttempts = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sharedRideId': sharedRideId,
      'contactId': contactId,
      'notificationType': notificationType,
      'message': message,
      'data': data,
      'smsStatus': smsStatus.name,
      'emailStatus': emailStatus.name,
      'pushStatus': pushStatus.name,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'deliveryAttempts': deliveryAttempts,
    };
  }

  factory RideSharingNotification.fromMap(Map<String, dynamic> map) {
    return RideSharingNotification(
      id: map['id'] ?? '',
      sharedRideId: map['sharedRideId'] ?? '',
      contactId: map['contactId'] ?? '',
      notificationType: map['notificationType'] ?? '',
      message: map['message'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      smsStatus: NotificationDeliveryStatus.values.firstWhere(
        (s) => s.name == map['smsStatus'],
        orElse: () => NotificationDeliveryStatus.pending,
      ),
      emailStatus: NotificationDeliveryStatus.values.firstWhere(
        (s) => s.name == map['emailStatus'],
        orElse: () => NotificationDeliveryStatus.pending,
      ),
      pushStatus: NotificationDeliveryStatus.values.firstWhere(
        (s) => s.name == map['pushStatus'],
        orElse: () => NotificationDeliveryStatus.pending,
      ),
      scheduledAt: map['scheduledAt'] != null 
          ? (map['scheduledAt'] as Timestamp).toDate() 
          : DateTime.now(),
      sentAt: map['sentAt'] != null 
          ? (map['sentAt'] as Timestamp).toDate() 
          : null,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      deliveryAttempts: List<String>.from(map['deliveryAttempts'] ?? []),
    );
  }

  factory RideSharingNotification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RideSharingNotification.fromMap({...data, 'id': doc.id});
  }
}

class EnhancedEmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final String? email;
  final String relationship;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? verificationToken;
  final bool receivesSMS;
  final bool receivesEmail;
  final bool receivesEmergencyAlerts;
  final RideSharingPreference defaultSharingPreference;
  final DateTime createdAt;
  final DateTime updatedAt;

  EnhancedEmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.email,
    required this.relationship,
    this.isVerified = false,
    this.verifiedAt,
    this.verificationToken,
    this.receivesSMS = true,
    this.receivesEmail = true,
    this.receivesEmergencyAlerts = true,
    this.defaultSharingPreference = RideSharingPreference.askEachTime,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'relationship': relationship,
      'isVerified': isVerified,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'verificationToken': verificationToken,
      'receivesSMS': receivesSMS,
      'receivesEmail': receivesEmail,
      'receivesEmergencyAlerts': receivesEmergencyAlerts,
      'defaultSharingPreference': defaultSharingPreference.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EnhancedEmergencyContact.fromMap(Map<String, dynamic> map) {
    return EnhancedEmergencyContact(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'],
      relationship: map['relationship'] ?? '',
      isVerified: map['isVerified'] ?? false,
      verifiedAt: map['verifiedAt'] != null 
          ? (map['verifiedAt'] as Timestamp).toDate() 
          : null,
      verificationToken: map['verificationToken'],
      receivesSMS: map['receivesSMS'] ?? true,
      receivesEmail: map['receivesEmail'] ?? true,
      receivesEmergencyAlerts: map['receivesEmergencyAlerts'] ?? true,
      defaultSharingPreference: RideSharingPreference.values.firstWhere(
        (p) => p.name == map['defaultSharingPreference'],
        orElse: () => RideSharingPreference.askEachTime,
      ),
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  factory EnhancedEmergencyContact.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EnhancedEmergencyContact.fromMap({...data, 'id': doc.id});
  }

  EnhancedEmergencyContact copyWith({
    String? id,
    String? userId,
    String? name,
    String? phoneNumber,
    String? email,
    String? relationship,
    bool? isVerified,
    DateTime? verifiedAt,
    String? verificationToken,
    bool? receivesSMS,
    bool? receivesEmail,
    bool? receivesEmergencyAlerts,
    RideSharingPreference? defaultSharingPreference,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EnhancedEmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      relationship: relationship ?? this.relationship,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verificationToken: verificationToken ?? this.verificationToken,
      receivesSMS: receivesSMS ?? this.receivesSMS,
      receivesEmail: receivesEmail ?? this.receivesEmail,
      receivesEmergencyAlerts: receivesEmergencyAlerts ?? this.receivesEmergencyAlerts,
      defaultSharingPreference: defaultSharingPreference ?? this.defaultSharingPreference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}