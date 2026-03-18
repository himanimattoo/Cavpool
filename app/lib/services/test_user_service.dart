import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';
import '../models/driver_verification_model.dart';

/// Service for creating and managing test users for development and testing
class TestUserService {
  static final TestUserService _instance = TestUserService._internal();
  factory TestUserService() => _instance;
  TestUserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  /// Predefined test driver users
  static const List<Map<String, dynamic>> testDrivers = [
    {
      'email': 'alex.driver@virginia.edu',
      'password': 'TestPass123!',
      'displayName': 'Alex Rodriguez',
      'phone': '+1-434-555-0101',
      'year': 'Graduate',
      'bio': 'Reliable driver with 5+ years experience. Honda Civic 2020, Blue.',
      'photoURL': 'https://api.dicebear.com/7.x/avataaars/png?seed=alex&size=150',
      'vehicleInfo': {
        'make': 'Honda',
        'model': 'Civic',
        'year': 2020,
        'color': 'Blue',
        'licensePlate': 'VA-TEST-01',
        'capacity': 4,
      },
      'preferences': {
        'smokingAllowed': false,
        'petsAllowed': true,
        'musicPreference': 'Ask passenger',
        'chattiness': 'moderate',
      }
    },
    {
      'email': 'maria.driver@virginia.edu',
      'password': 'TestPass123!',
      'displayName': 'Maria Chen',
      'phone': '+1-434-555-0102',
      'year': 'Senior',
      'bio': 'Economics major, safe driver. Toyota Prius 2021, Silver.',
      'photoURL': 'https://api.dicebear.com/7.x/avataaars/png?seed=maria&size=150',
      'vehicleInfo': {
        'make': 'Toyota',
        'model': 'Prius',
        'year': 2021,
        'color': 'Silver',
        'licensePlate': 'VA-TEST-02',
        'capacity': 4,
      },
      'preferences': {
        'smokingAllowed': false,
        'petsAllowed': false,
        'musicPreference': 'Quiet rides',
        'chattiness': 'quiet',
      }
    },
    {
      'email': 'mike.driver@virginia.edu',
      'password': 'TestPass123!',
      'displayName': 'Mike Johnson',
      'phone': '+1-434-555-0103',
      'year': 'Junior',
      'bio': 'Computer Science student. Ford Explorer 2019, Black. Spacious SUV.',
      'photoURL': 'https://api.dicebear.com/7.x/avataaars/png?seed=mike&size=150',
      'vehicleInfo': {
        'make': 'Ford',
        'model': 'Explorer',
        'year': 2019,
        'color': 'Black',
        'licensePlate': 'VA-TEST-03',
        'capacity': 6,
      },
      'preferences': {
        'smokingAllowed': false,
        'petsAllowed': true,
        'musicPreference': 'Open to suggestions',
        'chattiness': 'chatty',
      }
    },
  ];

  /// Predefined test passenger users  
  static const List<Map<String, dynamic>> testPassengers = [
    {
      'email': 'sarah.student@virginia.edu',
      'password': 'TestPass123!',
      'displayName': 'Sarah Williams',
      'phone': '+1-434-555-0201',
      'year': 'Sophomore',
      'bio': 'Psychology major, friendly and punctual.',
      'photoURL': 'https://api.dicebear.com/7.x/avataaars/png?seed=sarah&size=150',
      'preferences': {
        'smokingAllowed': false,
        'petsOkay': true,
        'musicPreference': 'Any',
        'chattiness': 'moderate',
        'preferredSeating': 'back',
      }
    },
    {
      'email': 'david.passenger@virginia.edu',
      'password': 'TestPass123!',
      'displayName': 'David Park',
      'phone': '+1-434-555-0202',
      'year': 'Freshman',
      'bio': 'Engineering student, quiet rider.',
      'photoURL': 'https://api.dicebear.com/7.x/avataaars/png?seed=david&size=150',
      'preferences': {
        'smokingAllowed': false,
        'petsOkay': false,
        'musicPreference': 'Quiet',
        'chattiness': 'quiet',
        'preferredSeating': 'front',
      }
    },
    {
      'email': 'emma.rider@virginia.edu',
      'password': 'TestPass123!',
      'displayName': 'Emma Thompson',
      'phone': '+1-434-555-0203',
      'year': 'Junior',
      'bio': 'Art History major, loves conversations and music.',
      'photoURL': 'https://api.dicebear.com/7.x/avataaars/png?seed=emma&size=150',
      'preferences': {
        'smokingAllowed': false,
        'petsOkay': true,
        'musicPreference': 'Indie/Alternative',
        'chattiness': 'chatty',
        'preferredSeating': 'any',
      }
    },
    {
      'email': 'james.commuter@virginia.edu',
      'password': 'TestPass123!',
      'displayName': 'James Wilson',
      'phone': '+1-434-555-0204',
      'year': 'Graduate',
      'bio': 'MBA student, commutes from downtown.',
      'photoURL': 'https://api.dicebear.com/7.x/avataaars/png?seed=james&size=150',
      'preferences': {
        'smokingAllowed': false,
        'petsOkay': false,
        'musicPreference': 'News/Podcasts',
        'chattiness': 'moderate',
        'preferredSeating': 'front',
      }
    },
    {
      'email': 'lisa.student@virginia.edu',
      'password': 'TestPass123!',
      'displayName': 'Lisa Chang',
      'phone': '+1-434-555-0205',
      'year': 'Senior',
      'bio': 'Pre-med student, always has early morning classes.',
      'photoURL': 'https://api.dicebear.com/7.x/avataaars/png?seed=lisa&size=150',
      'preferences': {
        'smokingAllowed': false,
        'petsOkay': true,
        'musicPreference': 'Classical',
        'chattiness': 'quiet',
        'preferredSeating': 'back',
      }
    },
  ];

  /// Create all test users (drivers and passengers)
  Future<void> createAllTestUsers() async {
    _logger.i('Creating all test users...');
    
    try {
      // Create test drivers
      for (final driverData in testDrivers) {
        await _createTestUser(driverData, 'driver');
      }
      
      // Create test passengers
      for (final passengerData in testPassengers) {
        await _createTestUser(passengerData, 'passenger');
      }
      
      _logger.i('All test users created successfully');
    } catch (e) {
      _logger.e('Error creating test users: $e');
      rethrow;
    }
  }

  /// Create individual test user
  Future<UserModel?> _createTestUser(Map<String, dynamic> userData, String accountType) async {
    try {
      final email = userData['email'] as String;
      final password = userData['password'] as String;
      final displayName = userData['displayName'] as String;
      
      _logger.i('Creating test user: $displayName ($email)');

      // Check if user already exists
      final existingUser = await _checkIfUserExists(email);
      if (existingUser != null) {
        _logger.i('User $email already exists, skipping creation');
        return existingUser;
      }

      // Create Firebase Auth user
      UserCredential? userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        if (e.toString().contains('email-already-in-use')) {
          _logger.w('Email $email already in use in Firebase Auth, attempting to fetch existing user data');
          // Try to get existing user data from Firestore
          final existingUser = await _checkIfUserExists(email);
          if (existingUser != null) {
            return existingUser;
          }
          // If not in Firestore but in Auth, we can't proceed safely
          _logger.e('Email exists in Auth but not in Firestore for $email');
          return null;
        }
        rethrow;
      }

      if (userCredential.user == null) {
        throw Exception('Failed to create auth user');
      }

      // Update display name
      await userCredential.user!.updateDisplayName(displayName);

      // Split display name for first/last name
      final nameParts = displayName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : displayName;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // Create user profile
      final userModel = UserModel(
        uid: userCredential.user!.uid,
        email: email,
        profile: UserProfile(
          firstName: firstName,
          lastName: lastName,
          displayName: displayName,
          phoneNumber: userData['phone'] as String,
          photoURL: userData['photoURL'] as String? ?? '',
          bio: userData['bio'] as String? ?? '',
          pronouns: 'they/them', // Default pronouns for test users
        ),
        accountType: accountType,
        isVerified: true, // Auto-verify test users
        emergencyContacts: [], // Empty for test users
        preferences: UserPreferences(
          allowSmoking: userData['preferences']?['smokingAllowed'] ?? false,
          allowPets: userData['preferences']?['petsAllowed'] ?? false,
          musicPreference: _mapMusicPreference(userData['preferences']?['musicPreference']),
          maxDetourTime: 15,
          communicationStyle: userData['preferences']?['chattiness'] ?? 'friendly',
          defaultSeatsNeeded: 1,
          defaultFlexibilityMinutes: 30,
          preferredUnits: DistanceUnit.imperial, // Default to imperial for test users
        ),
        ratings: UserRatings(
          averageRating: 5.0, // Give test users good ratings
          totalRatings: 10,
          asDriver: RoleRatings(averageRating: 5.0, totalRatings: accountType == 'driver' ? 5 : 0),
          asRider: RoleRatings(averageRating: 5.0, totalRatings: 5),
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        driverVerificationStatus: accountType == 'driver' ? VerificationStatus.approved : null,
        vehicleInfo: null, // Will be set later for drivers
      );

      // Save to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set(userModel.toMap());

      // Add vehicle info for drivers
      if (accountType == 'driver' && userData['vehicleInfo'] != null) {
        await _addVehicleInfo(userCredential.user!.uid, userData['vehicleInfo'] as Map<String, dynamic>);
      }

      _logger.i('Successfully created test user: $displayName');
      return userModel;
      
    } catch (e) {
      _logger.e('Error creating test user ${userData['email']}: $e');
      return null;
    }
  }

  /// Add vehicle information for driver
  Future<void> _addVehicleInfo(String userId, Map<String, dynamic> vehicleInfo) async {
    try {
      await _firestore.collection('vehicles').doc(userId).set({
        'userId': userId,
        'make': vehicleInfo['make'],
        'model': vehicleInfo['model'],
        'year': vehicleInfo['year'],
        'color': vehicleInfo['color'],
        'licensePlate': vehicleInfo['licensePlate'],
        'capacity': vehicleInfo['capacity'],
        'isVerified': true, // Auto-verify test vehicles
        'createdAt': FieldValue.serverTimestamp(),
      });
      _logger.i('Added vehicle info for user: $userId');
    } catch (e) {
      _logger.e('Error adding vehicle info: $e');
    }
  }

  /// Check if user already exists
  Future<UserModel?> _checkIfUserExists(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('profile.email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      _logger.e('Error checking if user exists: $e');
      return null;
    }
  }

  /// Get all test user emails for easy reference
  static List<String> getAllTestEmails() {
    final driverEmails = testDrivers.map((d) => d['email'] as String).toList();
    final passengerEmails = testPassengers.map((p) => p['email'] as String).toList();
    return [...driverEmails, ...passengerEmails];
  }

  /// Get test driver emails
  static List<String> getTestDriverEmails() {
    return testDrivers.map((d) => d['email'] as String).toList();
  }

  /// Get test passenger emails
  static List<String> getTestPassengerEmails() {
    return testPassengers.map((p) => p['email'] as String).toList();
  }

  /// Map test data music preferences to valid dropdown options
  static String _mapMusicPreference(String? testPreference) {
    if (testPreference == null) return 'driver_choice';
    
    switch (testPreference.toLowerCase()) {
      case 'ask passenger':
      case 'open to suggestions':
      case 'any':
        return 'driver_choice';
      case 'quiet rides':
      case 'quiet':
      case 'no music':
        return 'no_music';
      case 'indie/alternative':
      case 'rock':
        return 'rock';
      case 'classical':
        return 'classical';
      case 'news/podcasts':
        return 'pop';
      default:
        return 'driver_choice';
    }
  }

  /// Print test user credentials for easy login
  void printTestUserCredentials() {
    _logger.i('=== TEST USER CREDENTIALS ===');
    
    _logger.i('\n--- DRIVERS ---');
    for (final driver in testDrivers) {
      _logger.i('${driver['displayName']}: ${driver['email']} / ${driver['password']}');
      _logger.i('  Vehicle: ${driver['vehicleInfo']?['year']} ${driver['vehicleInfo']?['make']} ${driver['vehicleInfo']?['model']}');
    }
    
    _logger.i('\n--- PASSENGERS ---');
    for (final passenger in testPassengers) {
      _logger.i('${passenger['displayName']}: ${passenger['email']} / ${passenger['password']}');
    }
    
    _logger.i('\n=== END TEST USERS ===');
  }

  /// Delete all test users (for cleanup)
  Future<void> deleteAllTestUsers() async {
    _logger.i('Deleting all test users...');
    
    try {
      final allEmails = getAllTestEmails();
      
      for (final email in allEmails) {
        try {
          // Find user by email
          final userDoc = await _firestore
              .collection('users')
              .where('profile.email', isEqualTo: email)
              .limit(1)
              .get();

          if (userDoc.docs.isNotEmpty) {
            final userId = userDoc.docs.first.id;
            
            // Delete from Firestore
            await _firestore.collection('users').doc(userId).delete();
            await _firestore.collection('vehicles').doc(userId).delete();
            
            _logger.i('Deleted test user: $email');
          }
        } catch (e) {
          _logger.e('Error deleting user $email: $e');
        }
      }
      
      _logger.i('Test user cleanup completed');
    } catch (e) {
      _logger.e('Error during test user cleanup: $e');
    }
  }
}