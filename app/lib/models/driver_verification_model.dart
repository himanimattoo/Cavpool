class DriverVerificationRequest {
  final String uid;
  final String licenseNumber;
  final VehicleInfo vehicleInfo;
  final DateTime submittedAt;
  final VerificationStatus status;
  final String? rejectionReason;
  final DateTime? verifiedAt;

  DriverVerificationRequest({
    required this.uid,
    required this.licenseNumber,
    required this.vehicleInfo,
    required this.submittedAt,
    required this.status,
    this.rejectionReason,
    this.verifiedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'licenseNumber': licenseNumber,
      'vehicleInfo': vehicleInfo.toMap(),
      'submittedAt': submittedAt.toIso8601String(),
      'status': status.toString().split('.').last,
      'rejectionReason': rejectionReason,
      'verifiedAt': verifiedAt?.toIso8601String(),
    };
  }

  factory DriverVerificationRequest.fromMap(Map<String, dynamic> map) {
    return DriverVerificationRequest(
      uid: map['uid'] ?? '',
      licenseNumber: map['licenseNumber'] ?? '',
      vehicleInfo: VehicleInfo.fromMap(map['vehicleInfo'] ?? {}),
      submittedAt: DateTime.parse(map['submittedAt']),
      status: VerificationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => VerificationStatus.pending,
      ),
      rejectionReason: map['rejectionReason'],
      verifiedAt: map['verifiedAt'] != null ? DateTime.parse(map['verifiedAt']) : null,
    );
  }
}

class VehicleInfo {
  final String make;
  final String model;
  final int year;
  final String color;
  final String licensePlate;
  final int capacity;

  VehicleInfo({
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.licensePlate,
    this.capacity = 4,
  });

  Map<String, dynamic> toMap() {
    return {
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'licensePlate': licensePlate,
      'capacity': capacity,
    };
  }

  factory VehicleInfo.fromMap(Map<String, dynamic> map) {
    return VehicleInfo(
      make: map['make'] ?? '',
      model: map['model'] ?? '',
      year: map['year'] ?? 0,
      color: map['color'] ?? '',
      licensePlate: map['licensePlate'] ?? '',
      capacity: map['capacity'] ?? 4,
    );
  }

  String get displayName => '$year $make $model';
}

enum VerificationStatus {
  pending,
  underReview,
  approved,
  rejected,
}

extension VerificationStatusExtension on VerificationStatus {
  String get displayName {
    switch (this) {
      case VerificationStatus.pending:
        return 'Pending';
      case VerificationStatus.underReview:
        return 'Under Review';
      case VerificationStatus.approved:
        return 'Approved';
      case VerificationStatus.rejected:
        return 'Rejected';
    }
  }

  String get description {
    switch (this) {
      case VerificationStatus.pending:
        return 'Your verification request has been submitted and is waiting to be reviewed.';
      case VerificationStatus.underReview:
        return 'Our team is currently reviewing your verification documents.';
      case VerificationStatus.approved:
        return 'Your driver verification has been approved. You can now accept ride requests.';
      case VerificationStatus.rejected:
        return 'Your verification request was rejected. Please check the reason and resubmit.';
    }
  }
}