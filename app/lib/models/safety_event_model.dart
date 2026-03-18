import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum SafetyEventType {
  userReported,
  emergencyButton,
  rideCancellation,
  failedVerification,
  accountSuspension,
  routeDeviation,
  automaticDetection,
}

enum SafetyIncidentType {
  harassment,
  unsafeDriving,
  routeDeviation,
  inappropriateBehavior,
  vehicleIssue,
  identityMismatch,
  threatOrIntimidation,
  substanceUse,
  other,
}

enum SafetyEventStatus {
  pending,
  underReview,
  resolved,
  escalated,
  dismissed,
}

enum SafetyEventSeverity {
  low,
  medium,
  high,
  critical,
}

class SafetyEventLocation {
  final LatLng? coordinates;
  final String? address;
  final double? accuracy;

  SafetyEventLocation({
    this.coordinates,
    this.address,
    this.accuracy,
  });

  Map<String, dynamic> toMap() {
    return {
      'coordinates': coordinates != null ? {
        'latitude': coordinates!.latitude,
        'longitude': coordinates!.longitude,
      } : null,
      'address': address,
      'accuracy': accuracy,
    };
  }

  factory SafetyEventLocation.fromMap(Map<String, dynamic> map) {
    return SafetyEventLocation(
      coordinates: map['coordinates'] != null 
          ? LatLng(
              (map['coordinates']['latitude'] ?? 0.0).toDouble(),
              (map['coordinates']['longitude'] ?? 0.0).toDouble(),
            )
          : null,
      address: map['address'],
      accuracy: map['accuracy']?.toDouble(),
    );
  }
}

class SafetyEventEvidence {
  final String type; // 'image', 'audio', 'text', 'file'
  final String? url;
  final String? description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  SafetyEventEvidence({
    required this.type,
    this.url,
    this.description,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'url': url,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  factory SafetyEventEvidence.fromMap(Map<String, dynamic> map) {
    return SafetyEventEvidence(
      type: map['type'] ?? '',
      url: map['url'],
      description: map['description'],
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      metadata: map['metadata'],
    );
  }
}

class SafetyEventModel {
  final String id;
  final SafetyEventType eventType;
  final SafetyIncidentType? incidentType;
  final String reporterId;
  final String? reportedUserId;
  final String? rideId;
  final String title;
  final String description;
  final SafetyEventSeverity severity;
  final SafetyEventStatus status;
  final SafetyEventLocation? location;
  final List<SafetyEventEvidence> evidence;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final String? resolution;
  final List<String> tags;
  final bool isAnonymous;
  final Map<String, dynamic> systemData;

  SafetyEventModel({
    required this.id,
    required this.eventType,
    this.incidentType,
    required this.reporterId,
    this.reportedUserId,
    this.rideId,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    this.location,
    required this.evidence,
    required this.metadata,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
    this.resolution,
    required this.tags,
    this.isAnonymous = false,
    required this.systemData,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventType': eventType.name,
      'incidentType': incidentType?.name,
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'rideId': rideId,
      'title': title,
      'description': description,
      'severity': severity.name,
      'status': status.name,
      'location': location?.toMap(),
      'evidence': evidence.map((e) => e.toMap()).toList(),
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewNotes': reviewNotes,
      'resolution': resolution,
      'tags': tags,
      'isAnonymous': isAnonymous,
      'systemData': systemData,
    };
  }

  factory SafetyEventModel.fromMap(Map<String, dynamic> map) {
    return SafetyEventModel(
      id: map['id'] ?? '',
      eventType: SafetyEventType.values.firstWhere(
        (e) => e.name == map['eventType'],
        orElse: () => SafetyEventType.userReported,
      ),
      incidentType: map['incidentType'] != null
          ? SafetyIncidentType.values.firstWhere(
              (e) => e.name == map['incidentType'],
              orElse: () => SafetyIncidentType.other,
            )
          : null,
      reporterId: map['reporterId'] ?? '',
      reportedUserId: map['reportedUserId'],
      rideId: map['rideId'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      severity: SafetyEventSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => SafetyEventSeverity.medium,
      ),
      status: SafetyEventStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SafetyEventStatus.pending,
      ),
      location: map['location'] != null 
          ? SafetyEventLocation.fromMap(map['location'])
          : null,
      evidence: List<SafetyEventEvidence>.from(
        (map['evidence'] ?? []).map((e) => SafetyEventEvidence.fromMap(e)),
      ),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
      reviewedBy: map['reviewedBy'],
      reviewedAt: map['reviewedAt'] != null 
          ? (map['reviewedAt'] as Timestamp).toDate() 
          : null,
      reviewNotes: map['reviewNotes'],
      resolution: map['resolution'],
      tags: List<String>.from(map['tags'] ?? []),
      isAnonymous: map['isAnonymous'] ?? false,
      systemData: Map<String, dynamic>.from(map['systemData'] ?? {}),
    );
  }

  factory SafetyEventModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SafetyEventModel.fromMap({...data, 'id': doc.id});
  }

  SafetyEventModel copyWith({
    String? id,
    SafetyEventType? eventType,
    SafetyIncidentType? incidentType,
    String? reporterId,
    String? reportedUserId,
    String? rideId,
    String? title,
    String? description,
    SafetyEventSeverity? severity,
    SafetyEventStatus? status,
    SafetyEventLocation? location,
    List<SafetyEventEvidence>? evidence,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewNotes,
    String? resolution,
    List<String>? tags,
    bool? isAnonymous,
    Map<String, dynamic>? systemData,
  }) {
    return SafetyEventModel(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      incidentType: incidentType ?? this.incidentType,
      reporterId: reporterId ?? this.reporterId,
      reportedUserId: reportedUserId ?? this.reportedUserId,
      rideId: rideId ?? this.rideId,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      location: location ?? this.location,
      evidence: evidence ?? this.evidence,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      resolution: resolution ?? this.resolution,
      tags: tags ?? this.tags,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      systemData: systemData ?? this.systemData,
    );
  }
}

class SafetyEventSummary {
  final int totalEvents;
  final int pendingEvents;
  final int resolvedEvents;
  final int criticalEvents;
  final Map<SafetyIncidentType, int> eventsByType;
  final Map<String, int> eventsByUser;
  final DateTime? lastUpdated;

  SafetyEventSummary({
    required this.totalEvents,
    required this.pendingEvents,
    required this.resolvedEvents,
    required this.criticalEvents,
    required this.eventsByType,
    required this.eventsByUser,
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalEvents': totalEvents,
      'pendingEvents': pendingEvents,
      'resolvedEvents': resolvedEvents,
      'criticalEvents': criticalEvents,
      'eventsByType': eventsByType.map((k, v) => MapEntry(k.name, v)),
      'eventsByUser': eventsByUser,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    };
  }

  factory SafetyEventSummary.fromMap(Map<String, dynamic> map) {
    return SafetyEventSummary(
      totalEvents: map['totalEvents'] ?? 0,
      pendingEvents: map['pendingEvents'] ?? 0,
      resolvedEvents: map['resolvedEvents'] ?? 0,
      criticalEvents: map['criticalEvents'] ?? 0,
      eventsByType: Map<SafetyIncidentType, int>.from(
        (map['eventsByType'] ?? <String, dynamic>{}).map((k, v) => MapEntry(
          SafetyIncidentType.values.firstWhere(
            (e) => e.name == k,
            orElse: () => SafetyIncidentType.other,
          ),
          v as int,
        )),
      ),
      eventsByUser: Map<String, int>.from(map['eventsByUser'] ?? {}),
      lastUpdated: map['lastUpdated'] != null 
          ? (map['lastUpdated'] as Timestamp).toDate() 
          : null,
    );
  }
}