// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Import your models and services
import 'package:capstone_orange_1/models/ride_model.dart';
import 'package:capstone_orange_1/services/ride_service.dart';
import 'package:capstone_orange_1/firebase_options.dart';

/// Script to populate the Firebase database with sample ride offers and requests
/// Run with: dart run scripts/populate_database.dart
void main(List<String> args) async {
  print('Starting database population script...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized');

    final populateScript = DatabasePopulator();
    
    // Parse command line arguments
    final shouldClear = args.contains('--clear');
    final rideCount = _parseIntArg(args, '--rides', 10);
    final requestCount = _parseIntArg(args, '--requests', 5);
    
    if (shouldClear) {
      await populateScript.clearDatabase();
    }
    
    await populateScript.populateRideOffers(count: rideCount);
    await populateScript.populateRideRequests(count: requestCount);
    
    print('Database population completed!');
    
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

class DatabasePopulator {
  final RideService _rideService = RideService();
  final Random _random = Random();
  
  // Sample locations around UVA campus and Charlottesville
  final List<LocationData> _locations = [
    LocationData(
      name: 'UVA Main Campus',
      address: 'University of Virginia, Charlottesville, VA',
      coordinates: const LatLng(38.0356, -78.5034),
    ),
    LocationData(
      name: 'Downtown Mall',
      address: '200 2nd St NE, Charlottesville, VA 22902',
      coordinates: const LatLng(38.0293, -78.4767),
    ),
    LocationData(
      name: 'Barracks Road Shopping Center',
      address: '1117 Emmet St N, Charlottesville, VA 22903',
      coordinates: const LatLng(38.0625, -78.5089),
    ),
    LocationData(
      name: 'UVA Hospital',
      address: '1215 Lee St, Charlottesville, VA 22908',
      coordinates: const LatLng(38.0247, -78.5005),
    ),
    LocationData(
      name: 'Walmart Supercenter',
      address: '100 Zan Rd, Charlottesville, VA 22901',
      coordinates: const LatLng(38.0891, -78.5428),
    ),
    LocationData(
      name: 'Target Charlottesville',
      address: '1941 Commonwealth Dr, Charlottesville, VA 22901',
      coordinates: const LatLng(38.0752, -78.5312),
    ),
    LocationData(
      name: 'CVS Pharmacy',
      address: '1025 Emmet St N, Charlottesville, VA 22903',
      coordinates: const LatLng(38.0598, -78.5069),
    ),
    LocationData(
      name: 'Whole Foods Market',
      address: '2065 Bond St, Charlottesville, VA 22901',
      coordinates: const LatLng(38.0741, -78.5242),
    ),
    LocationData(
      name: 'Fashion Square Mall',
      address: '1600 Rio Rd E, Charlottesville, VA 22901',
      coordinates: const LatLng(38.0701, -78.4889),
    ),
    LocationData(
      name: 'Piedmont Virginia Community College',
      address: '501 College Dr, Charlottesville, VA 22902',
      coordinates: const LatLng(38.0215, -78.4612),
    ),
    LocationData(
      name: 'CHO Airport',
      address: '100 Bowen Loop, Charlottesville, VA 22911',
      coordinates: const LatLng(38.1386, -78.4529),
    ),
    LocationData(
      name: 'Scott Stadium',
      address: '295 Massie Rd, Charlottesville, VA 22903',
      coordinates: const LatLng(38.0457, -78.5113),
    ),
  ];
  
  // Test driver UIDs from Firebase Auth
  final List<String> _sampleDriverIds = [
    '0V55sbIpRNNvOD2ekBPRqDVyLMk1',
    'U4gkfsAGyBgrMvT5GzSbiLOJ9xB2',
    'xhQAOJqaMXfGhDsvXFdu7qIIdKs2',
  ];
  
  // Test rider UIDs from Firebase Auth
  final List<String> _samplePassengerIds = [
    '4HddyRh70GSk9TwQ3r8GAy4I0NK2',
    '4p6HE6noIuUd7kBtwzT2NbFJLha2',
    '5kK4jfzWkdUWqmChMkNkk1ckwlc2',
    '8Ns4RQ7dkQPJJPMJB6usgGn5SNj1',
  ];

  /// Clear existing test data from database
  Future<void> clearDatabase() async {
    print('Clearing existing test data...');
    
    final firestore = FirebaseFirestore.instance;
    
    // Clear test ride offers
    final rideOffers = await firestore
        .collection('ride_offers')
        .where('driverId', whereIn: _sampleDriverIds)
        .get();
    
    for (final doc in rideOffers.docs) {
      await doc.reference.delete();
    }
    
    // Clear test ride requests
    final rideRequests = await firestore
        .collection('ride_requests')
        .where('requesterId', whereIn: _samplePassengerIds)
        .get();
    
    for (final doc in rideRequests.docs) {
      await doc.reference.delete();
    }
    
    print('Test data cleared');
  }

  /// Populate database with sample ride offers
  Future<void> populateRideOffers({int count = 10}) async {
    print('Creating $count sample ride offers...');
    
    for (int i = 0; i < count; i++) {
      try {
        final rideOffer = _generateRandomRideOffer();
        final rideId = await _rideService.createRideOffer(rideOffer);
        
        if (rideId != null) {
          print('Created ride offer $rideId: ${rideOffer.startLocation.name} → ${rideOffer.endLocation.name}');
        } else {
          print('Failed to create ride offer ${i + 1}');
        }
        
        // Small delay to avoid hitting rate limits
        await Future.delayed(const Duration(milliseconds: 100));
        
      } catch (e) {
        print('Error creating ride offer ${i + 1}: $e');
      }
    }
  }

  /// Populate database with sample ride requests
  Future<void> populateRideRequests({int count = 5}) async {
    print('Creating $count sample ride requests...');
    
    for (int i = 0; i < count; i++) {
      try {
        final rideRequest = _generateRandomRideRequest();
        final requestId = await _rideService.createRideRequest(rideRequest);
        
        if (requestId != null) {
          print('Created ride request $requestId: ${rideRequest.startLocation.name} → ${rideRequest.endLocation.name}');
        } else {
          print('Failed to create ride request ${i + 1}');
        }
        
        // Small delay to avoid hitting rate limits
        await Future.delayed(const Duration(milliseconds: 100));
        
      } catch (e) {
        print('Error creating ride request ${i + 1}: $e');
      }
    }
  }

  /// Generate a random ride offer
  RideOffer _generateRandomRideOffer() {
    final startLocation = _getRandomLocation();
    final endLocation = _getRandomLocationExcluding(startLocation);
    final driverId = _sampleDriverIds[_random.nextInt(_sampleDriverIds.length)];
    final departureTime = _getRandomFutureTime();
    
    return RideOffer(
      id: '', // Will be set by Firestore
      driverId: driverId,
      startLocation: RideLocation(
        coordinates: startLocation.coordinates,
        address: startLocation.address,
        name: startLocation.name,
      ),
      endLocation: RideLocation(
        coordinates: endLocation.coordinates,
        address: endLocation.address,
        name: endLocation.name,
      ),
      departureTime: departureTime,
      availableSeats: _random.nextInt(3) + 1, // 1-3 seats
      totalSeats: 4,
      pricePerSeat: _generateRandomPrice(),
      passengerIds: [],
      pendingRequestIds: [],
      status: RideStatus.active,
      passengerPickupStatus: const <String, PickupStatus>{},
      passengerSeatPrices: const <String, double>{},
      passengerSeatCounts: const <String, int>{},
      passengerPickupLocations: const <String, RideLocation>{},
      passengerDropoffLocations: const <String, RideLocation>{},
      preferences: _generateRandomPreferences(),
      notes: _generateRandomNotes(),
      estimatedDistance: _calculateEstimatedDistance(startLocation, endLocation),
      estimatedDuration: _calculateEstimatedDuration(startLocation, endLocation),
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Generate a random ride request
  RideRequest _generateRandomRideRequest() {
    final startLocation = _getRandomLocation();
    final endLocation = _getRandomLocationExcluding(startLocation);
    final requesterId = _samplePassengerIds[_random.nextInt(_samplePassengerIds.length)];
    final preferredTime = _getRandomFutureTime();
    
    return RideRequest(
      id: '', // Will be set by Firestore
      requesterId: requesterId,
      startLocation: RideLocation(
        coordinates: startLocation.coordinates,
        address: startLocation.address,
        name: startLocation.name,
      ),
      endLocation: RideLocation(
        coordinates: endLocation.coordinates,
        address: endLocation.address,
        name: endLocation.name,
      ),
      preferredDepartureTime: preferredTime,
      flexibilityWindow: Duration(minutes: 30 + _random.nextInt(60)), // 30-90 minutes
      seatsNeeded: _random.nextInt(2) + 1, // 1-2 seats
      maxPricePerSeat: _generateRandomPrice() + 2.0, // Slightly higher than offers
      status: RequestStatus.pending,
      matchedOfferId: null,
      declinedOfferIds: [],
      preferences: _generateRandomPreferences(),
      notes: _generateRandomRequestNotes(),
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  LocationData _getRandomLocation() {
    return _locations[_random.nextInt(_locations.length)];
  }

  LocationData _getRandomLocationExcluding(LocationData exclude) {
    LocationData location;
    do {
      location = _getRandomLocation();
    } while (location.name == exclude.name);
    return location;
  }

  DateTime _getRandomFutureTime() {
    final now = DateTime.now();
    final hoursFromNow = _random.nextInt(72) + 1; // 1-72 hours from now
    return now.add(Duration(hours: hoursFromNow));
  }

  double _generateRandomPrice() {
    return 5.0 + (_random.nextDouble() * 15.0); // $5.00 - $20.00
  }

  RidePreferences _generateRandomPreferences() {
    return RidePreferences(
      allowSmoking: _random.nextBool(),
      allowPets: _random.nextBool(),
      musicPreference: _getRandomMusicPreference(),
      communicationStyle: _getRandomCommunicationStyle(),
      preferredGenders: _getRandomGenderPreferences(),
      maxPassengers: _random.nextInt(3) + 2, // 2-4 passengers
    );
  }

  String _getRandomMusicPreference() {
    final options = ['driver_choice', 'passenger_choice', 'no_music', 'low_volume'];
    return options[_random.nextInt(options.length)];
  }

  String _getRandomCommunicationStyle() {
    final options = ['chatty', 'friendly', 'quiet', 'business'];
    return options[_random.nextInt(options.length)];
  }

  List<String> _getRandomGenderPreferences() {
    final options = [
      ['any'],
      ['male'],
      ['female'],
      ['male', 'female'],
    ];
    return options[_random.nextInt(options.length)];
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
      'Playing country music',
      'Air conditioning available',
      'Large trunk space for luggage',
    ];
    return notes[_random.nextInt(notes.length)];
  }

  String? _generateRandomRequestNotes() {
    final notes = [
      null,
      'Running a bit late, will text if delayed',
      'Have one small suitcase',
      'Prefer window seat if possible',
      'Happy to help with gas money',
      'Can be flexible with pickup time',
      'Traveling with one friend',
      'Need to make a quick stop at CVS',
    ];
    return notes[_random.nextInt(notes.length)];
  }

  double _calculateEstimatedDistance(LocationData start, LocationData end) {
    // Simple distance calculation (in miles)
    const double earthRadius = 3959; // Earth's radius in miles
    
    final lat1Rad = start.coordinates.latitude * (pi / 180);
    final lat2Rad = end.coordinates.latitude * (pi / 180);
    final deltaLatRad = (end.coordinates.latitude - start.coordinates.latitude) * (pi / 180);
    final deltaLngRad = (end.coordinates.longitude - start.coordinates.longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  Duration _calculateEstimatedDuration(LocationData start, LocationData end) {
    final distance = _calculateEstimatedDistance(start, end);
    // Assume average speed of 25 mph in city, 45 mph highway
    final estimatedSpeed = distance > 10 ? 45.0 : 25.0;
    final hours = distance / estimatedSpeed;
    return Duration(minutes: (hours * 60).round());
  }
}

class LocationData {
  final String name;
  final String address;
  final LatLng coordinates;

  LocationData({
    required this.name,
    required this.address,
    required this.coordinates,
  });
}
