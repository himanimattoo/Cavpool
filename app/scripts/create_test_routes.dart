// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Direct Firebase script to create test routes
/// Run with: dart run scripts/create_test_routes.dart
void main(List<String> args) async {
  print('Creating test routes in Firebase...');
  
  try {
    // Initialize Firebase (you may need to update this based on your setup)
    await Firebase.initializeApp();
    print('Firebase initialized');

    final creator = TestRouteCreator();
    
    // Parse command line arguments
    final shouldClear = args.contains('--clear');
    final rideCount = _parseIntArg(args, '--rides', 10);
    
    if (shouldClear) {
      await creator.clearTestRoutes();
    }
    
    await creator.createTestRideOffers(count: rideCount);
    
    print('Test routes creation completed!');
    print('You can now use these routes to test the navigation features');
    
  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

int _parseIntArg(List<String> args, String flag, int defaultValue) {
  final index = args.indexOf(flag);
  if (index != -1 && index + 1 < args.length) {
    return int.tryParse(args[index + 1]) ?? defaultValue;
  }
  return defaultValue;
}

class TestRouteCreator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();
  
  // Sample locations around UVA campus and Charlottesville
  final List<Map<String, dynamic>> _locations = [
    {
      'name': 'UVA Main Campus',
      'address': 'University of Virginia, Charlottesville, VA',
      'coordinates': {'latitude': 38.0356, 'longitude': -78.5034},
    },
    {
      'name': 'Downtown Mall',
      'address': '200 2nd St NE, Charlottesville, VA 22902',
      'coordinates': {'latitude': 38.0293, 'longitude': -78.4767},
    },
    {
      'name': 'Barracks Road Shopping Center',
      'address': '1117 Emmet St N, Charlottesville, VA 22903',
      'coordinates': {'latitude': 38.0625, 'longitude': -78.5089},
    },
    {
      'name': 'UVA Hospital',
      'address': '1215 Lee St, Charlottesville, VA 22908',
      'coordinates': {'latitude': 38.0247, 'longitude': -78.5005},
    },
    {
      'name': 'Walmart Supercenter',
      'address': '100 Zan Rd, Charlottesville, VA 22901',
      'coordinates': {'latitude': 38.0891, 'longitude': -78.5428},
    },
    {
      'name': 'Target Charlottesville',
      'address': '1941 Commonwealth Dr, Charlottesville, VA 22901',
      'coordinates': {'latitude': 38.0752, 'longitude': -78.5312},
    },
    {
      'name': 'Fashion Square Mall',
      'address': '1600 Rio Rd E, Charlottesville, VA 22901',
      'coordinates': {'latitude': 38.0701, 'longitude': -78.4889},
    },
    {
      'name': 'CHO Airport',
      'address': '100 Bowen Loop, Charlottesville, VA 22911',
      'coordinates': {'latitude': 38.1386, 'longitude': -78.4529},
    },
    {
      'name': 'Scott Stadium',
      'address': '295 Massie Rd, Charlottesville, VA 22903',
      'coordinates': {'latitude': 38.0457, 'longitude': -78.5113},
    },
  ];
  
  // Test driver IDs - these should be valid UVA email addresses
  final List<String> _testDriverIds = [
    'test_driver1@virginia.edu',
    'test_driver2@virginia.edu', 
    'test_driver3@virginia.edu',
    'demo_driver@virginia.edu',
  ];

  /// Clear existing test routes
  Future<void> clearTestRoutes() async {
    print('Clearing existing test routes...');
    
    // Clear test ride offers
    final rideOffers = await _firestore
        .collection('ride_offers')
        .where('driverId', whereIn: _testDriverIds)
        .get();
    
    for (final doc in rideOffers.docs) {
      await doc.reference.delete();
    }
    
    print('Test routes cleared');
  }

  /// Create test ride offers
  Future<void> createTestRideOffers({int count = 10}) async {
    print('Creating $count test ride offers...');
    
    for (int i = 0; i < count; i++) {
      try {
        final rideOffer = _generateRideOfferData();
        final docRef = await _firestore.collection('ride_offers').add(rideOffer);
        
        print('Created ride offer ${docRef.id}: ${rideOffer['startLocation']['name']} → ${rideOffer['endLocation']['name']}');
        
        // Small delay to avoid hitting rate limits
        await Future.delayed(const Duration(milliseconds: 200));
        
      } catch (e) {
        print('Error creating ride offer ${i + 1}: $e');
      }
    }
  }

  /// Generate ride offer data as Map
  Map<String, dynamic> _generateRideOfferData() {
    final startLocation = _getRandomLocation();
    final endLocation = _getRandomLocationExcluding(startLocation);
    final driverId = _testDriverIds[_random.nextInt(_testDriverIds.length)];
    final departureTime = _getRandomFutureTime();
    final now = DateTime.now();
    
    return {
      'driverId': driverId,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'departureTime': Timestamp.fromDate(departureTime),
      'availableSeats': _random.nextInt(3) + 1, // 1-3 seats
      'totalSeats': 4,
      'pricePerSeat': _generateRandomPrice(),
      'passengerIds': <String>[],
      'pendingRequestIds': <String>[],
      'status': 'active',
      'passengerPickupStatus': <String, String>{},
      'preferences': _generatePreferencesData(),
      'notes': _generateRandomNotes(),
      'estimatedDistance': _calculateDistance(startLocation, endLocation),
      'estimatedDuration': _calculateDuration(startLocation, endLocation),
      'isArchived': false,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  Map<String, dynamic> _getRandomLocation() {
    return _locations[_random.nextInt(_locations.length)];
  }

  Map<String, dynamic> _getRandomLocationExcluding(Map<String, dynamic> exclude) {
    Map<String, dynamic> location;
    do {
      location = _getRandomLocation();
    } while (location['name'] == exclude['name']);
    return location;
  }

  DateTime _getRandomFutureTime() {
    final now = DateTime.now();
    final hoursFromNow = _random.nextInt(72) + 1; // 1-72 hours from now
    return now.add(Duration(hours: hoursFromNow));
  }

  double _generateRandomPrice() {
    return double.parse((5.0 + (_random.nextDouble() * 15.0)).toStringAsFixed(2)); // $5.00 - $20.00
  }

  Map<String, dynamic> _generatePreferencesData() {
    final musicOptions = ['driver_choice', 'passenger_choice', 'no_music', 'low_volume'];
    final commOptions = ['chatty', 'friendly', 'quiet', 'business'];
    final genderOptions = [
      ['any'],
      ['male'],
      ['female'],
      ['male', 'female'],
    ];
    
    return {
      'allowSmoking': _random.nextBool(),
      'allowPets': _random.nextBool(),
      'musicPreference': musicOptions[_random.nextInt(musicOptions.length)],
      'communicationStyle': commOptions[_random.nextInt(commOptions.length)],
      'preferredGenders': genderOptions[_random.nextInt(genderOptions.length)],
      'maxPassengers': _random.nextInt(3) + 2, // 2-4 passengers
    };
  }

  String? _generateRandomNotes() {
    final notes = [
      null,
      'Please be on time!',
      'I have snacks and water',
      'Non-smoking vehicle',
      'Pet-friendly ride',
      'Quiet ride preferred',
      'Happy to chat during the ride',
      'Air conditioning available',
      'Large trunk space for luggage',
    ];
    return notes[_random.nextInt(notes.length)];
  }

  double _calculateDistance(Map<String, dynamic> start, Map<String, dynamic> end) {
    // Simple distance calculation (in miles)
    const double earthRadius = 3959; // Earth's radius in miles
    
    final lat1 = start['coordinates']['latitude'] * (pi / 180);
    final lat2 = end['coordinates']['latitude'] * (pi / 180);
    final deltaLat = (end['coordinates']['latitude'] - start['coordinates']['latitude']) * (pi / 180);
    final deltaLng = (end['coordinates']['longitude'] - start['coordinates']['longitude']) * (pi / 180);

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) *
        sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return double.parse((earthRadius * c).toStringAsFixed(2));
  }

  int _calculateDuration(Map<String, dynamic> start, Map<String, dynamic> end) {
    final distance = _calculateDistance(start, end);
    // Assume average speed of 25 mph in city, 45 mph highway
    final estimatedSpeed = distance > 10 ? 45.0 : 25.0;
    final hours = distance / estimatedSpeed;
    return (hours * 60).round(); // Return minutes
  }
}