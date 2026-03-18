import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RideStatus {
  active,
  full,
  inProgress,
  completed,
  cancelled,
  expired,
}

enum RequestStatus {
  pending,
  matched,
  accepted,
  declined,
  completed,
  cancelled,
}

enum PickupStatus {
  pending,
  driverArrived,
  passengerPickedUp,
  completed,
}

class RideLocation {
  final LatLng coordinates;
  final String address;
  final String? name;

  RideLocation({
    required this.coordinates,
    required this.address,
    this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'coordinates': {
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude,
      },
      'address': address,
      'name': name,
    };
  }

  factory RideLocation.fromMap(Map<String, dynamic> map) {
    return RideLocation(
      coordinates: LatLng(
        (map['coordinates']['latitude'] ?? 0.0).toDouble(),
        (map['coordinates']['longitude'] ?? 0.0).toDouble(),
      ),
      address: map['address'] ?? '',
      name: map['name'],
    );
  }
}

class RidePreferences {
  final bool allowSmoking;
  final bool allowPets;
  final String musicPreference;
  final String communicationStyle;
  final List<String> preferredGenders;
  final int maxPassengers;

  RidePreferences({
    required this.allowSmoking,
    required this.allowPets,
    required this.musicPreference,
    required this.communicationStyle,
    required this.preferredGenders,
    required this.maxPassengers,
  });

  Map<String, dynamic> toMap() {
    return {
      'allowSmoking': allowSmoking,
      'allowPets': allowPets,
      'musicPreference': musicPreference,
      'communicationStyle': communicationStyle,
      'preferredGenders': preferredGenders,
      'maxPassengers': maxPassengers,
    };
  }

  factory RidePreferences.fromMap(Map<String, dynamic> map) {
    return RidePreferences(
      allowSmoking: map['allowSmoking'] ?? false,
      allowPets: map['allowPets'] ?? false,
      musicPreference: map['musicPreference'] ?? 'driver_choice',
      communicationStyle: map['communicationStyle'] ?? 'friendly',
      preferredGenders: List<String>.from(map['preferredGenders'] ?? []),
      maxPassengers: map['maxPassengers'] ?? 4,
    );
  }
}

class RideOffer {
  final String id;
  final String driverId;
  final RideLocation startLocation;
  final RideLocation endLocation;
  final DateTime departureTime;
  final int availableSeats;
  final int totalSeats;
  final double pricePerSeat;
  final List<String> passengerIds;
  final List<String> pendingRequestIds;
  final RideStatus status;
  final Map<String, PickupStatus> passengerPickupStatus;
  final Map<String, double> passengerSeatPrices;
  final Map<String, RideLocation> passengerPickupLocations;
  final Map<String, RideLocation> passengerDropoffLocations;
  final Map<String, int> passengerSeatCounts;
  final RidePreferences preferences;
  final String? notes;
  final List<RideLocation>? waypoints;
  final double estimatedDistance;
  final Duration estimatedDuration;
  final bool isArchived;
  final String? verificationCode;
  final DateTime? codeExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  RideOffer({
    required this.id,
    required this.driverId,
    required this.startLocation,
    required this.endLocation,
    required this.departureTime,
    required this.availableSeats,
    required this.totalSeats,
    required this.pricePerSeat,
    required this.passengerIds,
    required this.pendingRequestIds,
    required this.status,
    required this.passengerPickupStatus,
    required this.passengerSeatPrices,
    required this.passengerPickupLocations,
    required this.passengerDropoffLocations,
    required this.passengerSeatCounts,
    required this.preferences,
    this.notes,
    this.waypoints,
    required this.estimatedDistance,
    required this.estimatedDuration,
    this.isArchived = false,
    this.verificationCode,
    this.codeExpiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driverId': driverId,
      'startLocation': startLocation.toMap(),
      'endLocation': endLocation.toMap(),
      'departureTime': Timestamp.fromDate(departureTime),
      'availableSeats': availableSeats,
      'totalSeats': totalSeats,
      'pricePerSeat': pricePerSeat,
      'passengerIds': passengerIds,
      'pendingRequestIds': pendingRequestIds,
      'status': status.name,
      'passengerPickupStatus': passengerPickupStatus.map((k, v) => MapEntry(k, v.name)),
      'passengerSeatPrices': passengerSeatPrices,
      'passengerPickupLocations': passengerPickupLocations.map((k, v) => MapEntry(k, v.toMap())),
      'passengerDropoffLocations': passengerDropoffLocations.map((k, v) => MapEntry(k, v.toMap())),
      'passengerSeatCounts': passengerSeatCounts,
      'preferences': preferences.toMap(),
      'notes': notes,
      'waypoints': waypoints?.map((w) => w.toMap()).toList(),
      'estimatedDistance': estimatedDistance,
      'estimatedDuration': estimatedDuration.inMinutes,
      'isArchived': isArchived,
      'verificationCode': verificationCode,
      'codeExpiresAt': codeExpiresAt != null ? Timestamp.fromDate(codeExpiresAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory RideOffer.fromMap(Map<String, dynamic> map) {
    return RideOffer(
      id: map['id'] ?? '',
      driverId: map['driverId'] ?? '',
      startLocation: RideLocation.fromMap(map['startLocation'] ?? {}),
      endLocation: RideLocation.fromMap(map['endLocation'] ?? {}),
      departureTime: map['departureTime'] != null 
          ? (map['departureTime'] as Timestamp).toDate() 
          : DateTime.now(),
      availableSeats: map['availableSeats'] ?? 0,
      totalSeats: map['totalSeats'] ?? 0,
      pricePerSeat: (map['pricePerSeat'] ?? 0.0).toDouble(),
      passengerIds: List<String>.from(map['passengerIds'] ?? []),
      pendingRequestIds: List<String>.from(map['pendingRequestIds'] ?? []),
      status: RideStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => RideStatus.active,
      ),
      passengerPickupStatus: Map<String, PickupStatus>.from(
        (map['passengerPickupStatus'] ?? <String, dynamic>{}).map(
          (k, v) => MapEntry(k, PickupStatus.values.firstWhere(
            (status) => status.name == v,
            orElse: () => PickupStatus.pending,
          )),
        ),
      ),
      passengerSeatPrices: Map<String, double>.from(
        (map['passengerSeatPrices'] ?? <String, dynamic>{}).map(
          (k, v) => MapEntry(k, (v ?? 0).toDouble()),
        ),
      ),
      passengerSeatCounts: Map<String, int>.from(
        (map['passengerSeatCounts'] ?? <String, dynamic>{}).map(
          (k, v) => MapEntry(k, (v ?? 1) as int),
        ),
      ),
      passengerPickupLocations: Map<String, RideLocation>.from(
        (map['passengerPickupLocations'] ?? <String, dynamic>{}).map(
          (k, v) => MapEntry(k, RideLocation.fromMap(Map<String, dynamic>.from(v ?? {}))),
        ),
      ),
      passengerDropoffLocations: Map<String, RideLocation>.from(
        (map['passengerDropoffLocations'] ?? <String, dynamic>{}).map(
          (k, v) => MapEntry(k, RideLocation.fromMap(Map<String, dynamic>.from(v ?? {}))),
        ),
      ),
      preferences: RidePreferences.fromMap(map['preferences'] ?? {}),
      notes: map['notes'],
      waypoints: map['waypoints'] != null
          ? List<RideLocation>.from(
              (map['waypoints'] as List).map((w) => RideLocation.fromMap(w)),
            )
          : null,
      estimatedDistance: (map['estimatedDistance'] ?? 0.0).toDouble(),
      estimatedDuration: Duration(minutes: map['estimatedDuration'] ?? 0),
      isArchived: map['isArchived'] ?? false,
      verificationCode: map['verificationCode'],
      codeExpiresAt: map['codeExpiresAt'] != null 
          ? (map['codeExpiresAt'] as Timestamp).toDate() 
          : null,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory RideOffer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RideOffer.fromMap({...data, 'id': doc.id});
  }

  RideOffer copyWith({
    String? id,
    String? driverId,
    RideLocation? startLocation,
    RideLocation? endLocation,
    DateTime? departureTime,
    int? availableSeats,
    int? totalSeats,
    double? pricePerSeat,
    List<String>? passengerIds,
    List<String>? pendingRequestIds,
    RideStatus? status,
    Map<String, PickupStatus>? passengerPickupStatus,
    Map<String, double>? passengerSeatPrices,
    Map<String, RideLocation>? passengerPickupLocations,
    Map<String, RideLocation>? passengerDropoffLocations,
    Map<String, int>? passengerSeatCounts,
    RidePreferences? preferences,
    String? notes,
    List<RideLocation>? waypoints,
    double? estimatedDistance,
    Duration? estimatedDuration,
    bool? isArchived,
    String? verificationCode,
    DateTime? codeExpiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return RideOffer(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      departureTime: departureTime ?? this.departureTime,
      availableSeats: availableSeats ?? this.availableSeats,
      totalSeats: totalSeats ?? this.totalSeats,
      pricePerSeat: pricePerSeat ?? this.pricePerSeat,
      passengerIds: passengerIds ?? this.passengerIds,
      pendingRequestIds: pendingRequestIds ?? this.pendingRequestIds,
      status: status ?? this.status,
      passengerPickupStatus: passengerPickupStatus ?? this.passengerPickupStatus,
      passengerSeatPrices: passengerSeatPrices ?? this.passengerSeatPrices,
      passengerPickupLocations: passengerPickupLocations ?? this.passengerPickupLocations,
      passengerDropoffLocations: passengerDropoffLocations ?? this.passengerDropoffLocations,
      passengerSeatCounts: passengerSeatCounts ?? this.passengerSeatCounts,
      preferences: preferences ?? this.preferences,
      notes: notes ?? this.notes,
      waypoints: waypoints ?? this.waypoints,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      isArchived: isArchived ?? this.isArchived,
      verificationCode: verificationCode ?? this.verificationCode,
      codeExpiresAt: codeExpiresAt ?? this.codeExpiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class RideRequest {
  final String id;
  final String requesterId;
  final String? driverId;
  final RideLocation startLocation;
  final RideLocation endLocation;
  final DateTime preferredDepartureTime;
  final Duration flexibilityWindow;
  final int seatsNeeded;
  final double maxPricePerSeat;
  final RequestStatus status;
  final String? matchedOfferId;
  final List<String> declinedOfferIds;
  final RidePreferences preferences;
  final String? notes;
  final double estimatedDistance;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  RideRequest({
    required this.id,
    required this.requesterId,
    this.driverId,
    required this.startLocation,
    required this.endLocation,
    required this.preferredDepartureTime,
    required this.flexibilityWindow,
    required this.seatsNeeded,
    required this.maxPricePerSeat,
    required this.status,
    this.matchedOfferId,
    required this.declinedOfferIds,
    required this.preferences,
    this.notes,
    this.estimatedDistance = 0.0,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requesterId': requesterId,
      'driverId': driverId,
      'startLocation': startLocation.toMap(),
      'endLocation': endLocation.toMap(),
      'preferredDepartureTime': Timestamp.fromDate(preferredDepartureTime),
      'flexibilityWindow': flexibilityWindow.inMinutes,
      'seatsNeeded': seatsNeeded,
      'maxPricePerSeat': maxPricePerSeat,
      'status': status.name,
      'matchedOfferId': matchedOfferId,
      'declinedOfferIds': declinedOfferIds,
      'preferences': preferences.toMap(),
      'notes': notes,
      'estimatedDistance': estimatedDistance,
      'isArchived': isArchived,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RideRequest.fromMap(Map<String, dynamic> map) {
    return RideRequest(
      id: map['id'] ?? '',
      requesterId: map['requesterId'] ?? '',
      driverId: map['driverId'],
      startLocation: RideLocation.fromMap(map['startLocation'] ?? {}),
      endLocation: RideLocation.fromMap(map['endLocation'] ?? {}),
      preferredDepartureTime: (map['preferredDepartureTime'] as Timestamp).toDate(),
      flexibilityWindow: Duration(minutes: map['flexibilityWindow'] ?? 30),
      seatsNeeded: map['seatsNeeded'] ?? 1,
      maxPricePerSeat: (map['maxPricePerSeat'] ?? 0.0).toDouble(),
      status: RequestStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => RequestStatus.pending,
      ),
      matchedOfferId: map['matchedOfferId'],
      declinedOfferIds: List<String>.from(map['declinedOfferIds'] ?? []),
      preferences: RidePreferences.fromMap(map['preferences'] ?? {}),
      notes: map['notes'],
      estimatedDistance: (map['estimatedDistance'] ?? 0.0).toDouble(),
      isArchived: map['isArchived'] ?? false,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  factory RideRequest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RideRequest.fromMap({...data, 'id': doc.id});
  }

  RideRequest copyWith({
    String? id,
    String? requesterId,
    String? driverId,
    RideLocation? startLocation,
    RideLocation? endLocation,
    DateTime? preferredDepartureTime,
    Duration? flexibilityWindow,
    int? seatsNeeded,
    double? maxPricePerSeat,
    RequestStatus? status,
    String? matchedOfferId,
    List<String>? declinedOfferIds,
    RidePreferences? preferences,
    String? notes,
    double? estimatedDistance,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RideRequest(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      driverId: driverId ?? this.driverId,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      preferredDepartureTime: preferredDepartureTime ?? this.preferredDepartureTime,
      flexibilityWindow: flexibilityWindow ?? this.flexibilityWindow,
      seatsNeeded: seatsNeeded ?? this.seatsNeeded,
      maxPricePerSeat: maxPricePerSeat ?? this.maxPricePerSeat,
      status: status ?? this.status,
      matchedOfferId: matchedOfferId ?? this.matchedOfferId,
      declinedOfferIds: declinedOfferIds ?? this.declinedOfferIds,
      preferences: preferences ?? this.preferences,
      notes: notes ?? this.notes,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
