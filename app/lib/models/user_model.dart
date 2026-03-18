import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_verification_model.dart';

enum DistanceUnit { imperial, metric }

class UserProfile {
  final String firstName;
  final String lastName;
  final String displayName;
  final String photoURL;
  final String pronouns;
  final String bio;
  final String phoneNumber;

  UserProfile({
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.photoURL,
    required this.pronouns,
    required this.bio,
    required this.phoneNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName,
      'photoURL': photoURL,
      'pronouns': pronouns,
      'bio': bio,
      'phoneNumber': phoneNumber,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'] ?? '',
      pronouns: map['pronouns'] ?? '',
      bio: map['bio'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
    );
  }
}

class EmergencyContact {
  final String name;
  final String phoneNumber;
  final String relationship;

  EmergencyContact({
    required this.name,
    required this.phoneNumber,
    required this.relationship,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      relationship: map['relationship'] ?? '',
    );
  }
}

class UserPreferences {
  final bool allowSmoking;
  final bool allowPets;
  final String musicPreference;
  final int maxDetourTime;
  final String communicationStyle;
  // final List<String> preferredGenders; // Commented out for now
  final int defaultSeatsNeeded;
  final int defaultFlexibilityMinutes;
  final DistanceUnit preferredUnits;

  UserPreferences({
    required this.allowSmoking,
    required this.allowPets,
    required this.musicPreference,
    required this.maxDetourTime,
    required this.communicationStyle,
    // required this.preferredGenders, // Commented out for now
    required this.defaultSeatsNeeded,
    required this.defaultFlexibilityMinutes,
    required this.preferredUnits,
  });

  Map<String, dynamic> toMap() {
    return {
      'allowSmoking': allowSmoking,
      'allowPets': allowPets,
      'musicPreference': musicPreference,
      'maxDetourTime': maxDetourTime,
      'communicationStyle': communicationStyle,
      // 'preferredGenders': preferredGenders, // Commented out for now
      'defaultSeatsNeeded': defaultSeatsNeeded,
      'defaultFlexibilityMinutes': defaultFlexibilityMinutes,
      'preferredUnits': preferredUnits.name,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      allowSmoking: map['allowSmoking'] ?? false,
      allowPets: map['allowPets'] ?? false,
      musicPreference: map['musicPreference'] ?? 'driver_choice',
      maxDetourTime: map['maxDetourTime'] ?? 15,
      communicationStyle: map['communicationStyle'] ?? 'friendly',
      // preferredGenders: List<String>.from(map['preferredGenders'] ?? []), // Commented out for now
      defaultSeatsNeeded: map['defaultSeatsNeeded'] ?? 1,
      defaultFlexibilityMinutes: map['defaultFlexibilityMinutes'] ?? 30,
      preferredUnits: _parseDistanceUnit(map['preferredUnits']),
    );
  }

  static DistanceUnit _parseDistanceUnit(String? unitString) {
    switch (unitString) {
      case 'metric':
        return DistanceUnit.metric;
      case 'imperial':
      default:
        return DistanceUnit.imperial; // Default to imperial (feet/miles)
    }
  }
}

class UserRatings {
  final double averageRating;
  final int totalRatings;
  final RoleRatings asDriver;
  final RoleRatings asRider;

  UserRatings({
    required this.averageRating,
    required this.totalRatings,
    required this.asDriver,
    required this.asRider,
  });

  Map<String, dynamic> toMap() {
    return {
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'asDriver': asDriver.toMap(),
      'asRider': asRider.toMap(),
    };
  }

  factory UserRatings.fromMap(Map<String, dynamic> map) {
    return UserRatings(
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
      asDriver: RoleRatings.fromMap(map['asDriver'] ?? {}),
      asRider: RoleRatings.fromMap(map['asRider'] ?? {}),
    );
  }
}

class RoleRatings {
  final double averageRating;
  final int totalRatings;

  RoleRatings({
    required this.averageRating,
    required this.totalRatings,
  });

  Map<String, dynamic> toMap() {
    return {
      'averageRating': averageRating,
      'totalRatings': totalRatings,
    };
  }

  factory RoleRatings.fromMap(Map<String, dynamic> map) {
    return RoleRatings(
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
    );
  }
}

class UserModel {
  final String uid;
  final String email;
  final UserProfile profile;
  final String accountType;
  final bool isVerified;
  final List<EmergencyContact> emergencyContacts;
  final UserPreferences preferences;
  final UserRatings ratings;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final VerificationStatus? driverVerificationStatus;
  final VehicleInfo? vehicleInfo;

  UserModel({
    required this.uid,
    required this.email,
    required this.profile,
    required this.accountType,
    required this.isVerified,
    required this.emergencyContacts,
    required this.preferences,
    required this.ratings,
    this.createdAt,
    this.updatedAt,
    this.driverVerificationStatus,
    this.vehicleInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'profile': profile.toMap(),
      'accountType': accountType,
      'isVerified': isVerified,
      'emergencyContacts': emergencyContacts.map((e) => e.toMap()).toList(),
      'preferences': preferences.toMap(),
      'ratings': ratings.toMap(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'driverVerificationStatus': driverVerificationStatus?.toString().split('.').last,
      'vehicleInfo': vehicleInfo?.toMap(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      profile: UserProfile.fromMap(map['profile'] ?? {}),
      accountType: map['accountType'] ?? 'rider',
      isVerified: map['isVerified'] ?? false,
      emergencyContacts: List<EmergencyContact>.from(
        (map['emergencyContacts'] ?? []).map((x) => EmergencyContact.fromMap(x)),
      ),
      preferences: UserPreferences.fromMap(map['preferences'] ?? {}),
      ratings: UserRatings.fromMap(map['ratings'] ?? {}),
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      driverVerificationStatus: map['driverVerificationStatus'] != null 
        ? VerificationStatus.values.firstWhere(
            (e) => e.toString().split('.').last == map['driverVerificationStatus'],
            orElse: () => VerificationStatus.pending,
          )
        : null,
      vehicleInfo: map['vehicleInfo'] != null ? VehicleInfo.fromMap(map['vehicleInfo']) : null,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data);
  }
}