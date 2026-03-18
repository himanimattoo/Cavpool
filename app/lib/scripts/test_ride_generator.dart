import '../models/ride_model.dart';
import '../services/ride_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Automated test data generator for ride booking system
/// Creates realistic test scenarios with multiple passengers and routes
class TestRideGenerator {
  final RideService _rideService = RideService();

  // Test User IDs (provided by user)
  static const String driverUid = '0V55sbIpRNNvOD2ekBPRqDVyLMk1';
  static const List<String> riderUids = [
    '4HddyRh70GSk9TwQ3r8GAy4I0NK2',
    'rCUu3nNHPlgbSr4tLCfHRncnKAv2',
  ];

  // Test Locations (provided by user)
  static const Map<String, TestLocation> startLocations = {
    'jpa_1920': TestLocation(
      address: '1920 Jefferson Park Ave, Charlottesville, VA 22903',
      lat: 38.0336,
      lng: -78.5080,
      name: 'Jefferson Park Ave (1920)',
    ),
    'jpa_1620': TestLocation(
      address: '1620 Jefferson Park Ave, Charlottesville, VA 22903', 
      lat: 38.0356,
      lng: -78.5090,
      name: 'Jefferson Park Ave (1620)',
    ),
    '15th_st': TestLocation(
      address: '301 15th St NW, Charlottesville, VA 22903',
      lat: 38.0345,
      lng: -78.4889,
      name: '15th Street NW',
    ),
  };

  static const Map<String, TestLocation> endLocations = {
    'historic_manassas': TestLocation(
      address: 'Historic District, 8812 Cather Ave, Manassas, VA 20110',
      lat: 38.7509,
      lng: -77.4753,
      name: 'Historic District Manassas',
    ),
    'arlington': TestLocation(
      address: '2401 Smith Blvd, Arlington, VA 22202',
      lat: 38.8462,
      lng: -77.0468,
      name: 'Arlington Smith Blvd',
    ),
    'dulles_airport': TestLocation(
      address: 'Dulles International Airport, Saarinen Circle, Dulles, VA',
      lat: 38.9445,
      lng: -77.4558,
      name: 'Dulles Airport',
    ),
  };

  /// Generate test scenario with multiple rides and passengers
  Future<TestScenario> generateTestScenario() async {
    final scenarios = <RideTestCase>[];
    
    // Scenario 1: Dulles Airport Run (Multiple passengers, same destination)
    scenarios.add(await _createDullesAirportRide());
    
    // Scenario 2: Arlington Business Trip (Different pickup/dropoff combos)
    scenarios.add(await _createArlingtonRide());
    
    // Scenario 3: Manassas Historic District (Route optimization test)
    scenarios.add(await _createManassasRide());

    return TestScenario(
      name: 'Multi-Passenger Ride Booking Test',
      description: 'Tests core booking system with real UVA area locations',
      testCases: scenarios,
      generatedAt: DateTime.now(),
    );
  }

  /// Create Dulles Airport ride scenario
  Future<RideTestCase> _createDullesAirportRide() async {
    final rideOffer = RideOffer(
      id: '', // Will be set by Firestore
      driverId: driverUid,
      startLocation: RideLocation(
        coordinates: LatLng(startLocations['jpa_1920']!.lat, startLocations['jpa_1920']!.lng),
        address: startLocations['jpa_1920']!.address,
        name: startLocations['jpa_1920']!.name,
      ),
      endLocation: RideLocation(
        coordinates: LatLng(endLocations['dulles_airport']!.lat, endLocations['dulles_airport']!.lng),
        address: endLocations['dulles_airport']!.address,
        name: endLocations['dulles_airport']!.name,
      ),
      departureTime: DateTime.now().add(const Duration(hours: 2)),
      availableSeats: 3,
      totalSeats: 4,
      pricePerSeat: 35.0,
      passengerIds: const <String>[],
      pendingRequestIds: const <String>[],
      passengerPickupStatus: const <String, PickupStatus>{},
      passengerSeatPrices: const <String, double>{},
      passengerPickupLocations: const <String, RideLocation>{},
      passengerDropoffLocations: const <String, RideLocation>{},
      passengerSeatCounts: const <String, int>{},
      status: RideStatus.active,
      isArchived: false,
      preferences: RidePreferences(
        allowSmoking: false,
        allowPets: true,
        musicPreference: 'pop',
        communicationStyle: 'friendly',
        preferredGenders: const [],
        maxPassengers: 3,
      ),
      notes: 'Dulles Airport run - early morning flight',
      waypoints: null,
      estimatedDistance: 0,
      estimatedDuration: Duration.zero,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create passenger requests
    final passengerRequests = <RideRequest>[
      _createRideRequest(
        riderUids[0],
        startLocations['jpa_1620']!, // Different pickup
        endLocations['dulles_airport']!,
        rideOffer.departureTime.subtract(const Duration(minutes: 15)),
        seatsNeeded: 1,
        maxPrice: 40.0,
        notes: 'Flight at 8 AM, need to be there by 6:30 AM',
      ),
      _createRideRequest(
        riderUids[1], 
        startLocations['15th_st']!, // Different pickup
        endLocations['dulles_airport']!,
        rideOffer.departureTime.add(const Duration(minutes: 10)),
        seatsNeeded: 2,
        maxPrice: 35.0,
        notes: 'Traveling with SO, flight at 9 AM',
      ),
    ];

    return RideTestCase(
      name: 'Dulles Airport Multi-Pickup',
      description: 'Driver picks up passengers from different locations, all going to airport',
      rideOffer: rideOffer,
      passengerRequests: passengerRequests,
      expectedOptimalRoute: [
        'Start: ${startLocations['jpa_1920']!.name}',
        'Pickup 1: ${startLocations['jpa_1620']!.name}',
        'Pickup 2: ${startLocations['15th_st']!.name}',
        'Destination: ${endLocations['dulles_airport']!.name}',
      ],
    );
  }

  /// Create Arlington business trip scenario
  Future<RideTestCase> _createArlingtonRide() async {
    final rideOffer = RideOffer(
      id: '',
      driverId: driverUid,
      startLocation: RideLocation(
        coordinates: LatLng(startLocations['15th_st']!.lat, startLocations['15th_st']!.lng),
        address: startLocations['15th_st']!.address,
        name: startLocations['15th_st']!.name,
      ),
      endLocation: RideLocation(
        coordinates: LatLng(endLocations['arlington']!.lat, endLocations['arlington']!.lng),
        address: endLocations['arlington']!.address,
        name: endLocations['arlington']!.name,
      ),
      departureTime: DateTime.now().add(const Duration(hours: 4)),
      availableSeats: 2,
      totalSeats: 3,
      pricePerSeat: 25.0,
      passengerIds: const <String>[],
      pendingRequestIds: const <String>[],
      passengerPickupStatus: const <String, PickupStatus>{},
      passengerSeatPrices: const <String, double>{},
      passengerPickupLocations: const <String, RideLocation>{},
      passengerDropoffLocations: const <String, RideLocation>{},
      passengerSeatCounts: const <String, int>{},
      status: RideStatus.active,
      isArchived: false,
      preferences: RidePreferences(
        allowSmoking: false,
        allowPets: false,
        musicPreference: 'classical',
        communicationStyle: 'professional',
        preferredGenders: const [],
        maxPassengers: 2,
      ),
      notes: 'Business meeting in Arlington',
      waypoints: null,
      estimatedDistance: 0,
      estimatedDuration: Duration.zero,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final passengerRequests = <RideRequest>[
      _createRideRequest(
        riderUids[0],
        startLocations['jpa_1920']!,
        endLocations['arlington']!,
        rideOffer.departureTime,
        seatsNeeded: 1,
        maxPrice: 30.0,
        notes: 'Business meeting at 2 PM',
      ),
    ];

    return RideTestCase(
      name: 'Arlington Business Trip',
      description: 'Professional ride to Arlington business district',
      rideOffer: rideOffer,
      passengerRequests: passengerRequests,
      expectedOptimalRoute: [
        'Start: ${startLocations['15th_st']!.name}',
        'Pickup: ${startLocations['jpa_1920']!.name}',
        'Destination: ${endLocations['arlington']!.name}',
      ],
    );
  }

  /// Create Manassas historic district scenario
  Future<RideTestCase> _createManassasRide() async {
    final rideOffer = RideOffer(
      id: '',
      driverId: driverUid,
      startLocation: RideLocation(
        coordinates: LatLng(startLocations['jpa_1620']!.lat, startLocations['jpa_1620']!.lng),
        address: startLocations['jpa_1620']!.address,
        name: startLocations['jpa_1620']!.name,
      ),
      endLocation: RideLocation(
        coordinates: LatLng(endLocations['historic_manassas']!.lat, endLocations['historic_manassas']!.lng),
        address: endLocations['historic_manassas']!.address,
        name: endLocations['historic_manassas']!.name,
      ),
      departureTime: DateTime.now().add(const Duration(hours: 6)),
      availableSeats: 4,
      totalSeats: 4,
      pricePerSeat: 20.0,
      passengerIds: const <String>[],
      pendingRequestIds: const <String>[],
      passengerPickupStatus: const <String, PickupStatus>{},
      passengerSeatPrices: const <String, double>{},
      passengerPickupLocations: const <String, RideLocation>{},
      passengerDropoffLocations: const <String, RideLocation>{},
      passengerSeatCounts: const <String, int>{},
      status: RideStatus.active,
      isArchived: false,
      preferences: RidePreferences(
        allowSmoking: false,
        allowPets: true,
        musicPreference: 'driver_choice',
        communicationStyle: 'friendly',
        preferredGenders: const [],
        maxPassengers: 4,
      ),
      notes: 'Weekend trip to historic Manassas',
      waypoints: null,
      estimatedDistance: 0,
      estimatedDuration: Duration.zero,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final passengerRequests = <RideRequest>[
      _createRideRequest(
        riderUids[1],
        startLocations['15th_st']!,
        endLocations['historic_manassas']!,
        rideOffer.departureTime.subtract(const Duration(minutes: 5)),
        seatsNeeded: 1,
        maxPrice: 22.0,
        notes: 'Visiting Civil War battlefields',
      ),
    ];

    return RideTestCase(
      name: 'Manassas Historic District',
      description: 'Weekend cultural trip to historic battlefield',
      rideOffer: rideOffer,
      passengerRequests: passengerRequests,
      expectedOptimalRoute: [
        'Start: ${startLocations['jpa_1620']!.name}',
        'Pickup: ${startLocations['15th_st']!.name}',
        'Destination: ${endLocations['historic_manassas']!.name}',
      ],
    );
  }

  /// Create a ride request for testing
  RideRequest _createRideRequest(
    String requesterId,
    TestLocation pickup,
    TestLocation dropoff,
    DateTime preferredTime,
    {
    int seatsNeeded = 1,
    double maxPrice = 30.0,
    String? notes,
  }) {
    return RideRequest(
      id: '',
      requesterId: requesterId,
      startLocation: RideLocation(
        coordinates: LatLng(pickup.lat, pickup.lng),
        address: pickup.address,
        name: pickup.name,
      ),
      endLocation: RideLocation(
        coordinates: LatLng(dropoff.lat, dropoff.lng),
        address: dropoff.address,
        name: dropoff.name,
      ),
      preferredDepartureTime: preferredTime,
      flexibilityWindow: const Duration(minutes: 30),
      seatsNeeded: seatsNeeded,
      maxPricePerSeat: maxPrice,
      status: RequestStatus.pending,
      matchedOfferId: null,
      declinedOfferIds: const [],
      preferences: RidePreferences(
        allowSmoking: false,
        allowPets: true,
        musicPreference: 'driver_choice',
        communicationStyle: 'friendly',
        preferredGenders: const [],
        maxPassengers: seatsNeeded,
      ),
      notes: notes,
      estimatedDistance: 0.0,
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Execute test scenario by creating all rides and requests
  Future<TestResults> executeTestScenario(TestScenario scenario) async {
    final results = TestResults();
    
    // ignore: avoid_print
    print('\n🚀 Executing Test Scenario: ${scenario.name}');
    // ignore: avoid_print
    print('📝 Description: ${scenario.description}');
    // ignore: avoid_print
    print('📅 Generated at: ${scenario.generatedAt}');
    // ignore: avoid_print
    print('🧪 Test cases: ${scenario.testCases.length}\n');

    for (int i = 0; i < scenario.testCases.length; i++) {
      final testCase = scenario.testCases[i];
      // ignore: avoid_print
      print('--- Test Case ${i + 1}: ${testCase.name} ---');
      
      try {
        // 1. Create the ride offer
        // ignore: avoid_print
        print('👤 Creating ride offer by driver $driverUid...');
        final rideId = await _rideService.createRideOffer(testCase.rideOffer);
        
        if (rideId == null) {
          throw Exception('Failed to create ride offer');
        }
        
        results.createdRides.add(rideId);
        // ignore: avoid_print
        print(' Ride created with ID: $rideId');
        // ignore: avoid_print
        print(' Route: ${testCase.rideOffer.startLocation.name} → ${testCase.rideOffer.endLocation.name}');
        // ignore: avoid_print
        print(' Price: \$${testCase.rideOffer.pricePerSeat} per seat');
        // ignore: avoid_print
        print(' Seats: ${testCase.rideOffer.availableSeats} available');

        // 2. Create passenger requests
        // ignore: avoid_print
        print('\n Creating passenger requests...');
        for (int j = 0; j < testCase.passengerRequests.length; j++) {
          final request = testCase.passengerRequests[j].copyWith(matchedOfferId: rideId);
          // ignore: avoid_print
          print(' Creating request for rider ${request.requesterId}...');
          
          final requestId = await _rideService.createRideRequest(request);
          if (requestId == null) {
            throw Exception('Failed to create ride request');
          }
          
          results.createdRequests.add(requestId);
          // ignore: avoid_print
          print(' Request created with ID: $requestId');
          // ignore: avoid_print
          print(' ${request.startLocation.name} → ${request.endLocation.name}');
          // ignore: avoid_print
          print(' Seats needed: ${request.seatsNeeded}');
          // ignore: avoid_print
          print(' Max price: \$${request.maxPricePerSeat}');
          if (request.notes?.isNotEmpty == true) {
            // ignore: avoid_print
            print(' Notes: ${request.notes}');
          }
        }

        // ignore: avoid_print
        print(' Test case ${i + 1} completed successfully\n');
        results.successfulTests.add(testCase.name);
        
      } catch (e) {
        // ignore: avoid_print
        print(' Test case ${i + 1} failed: $e\n');
        results.failedTests[testCase.name] = e.toString();
      }
    }

    // Print summary
    // ignore: avoid_print
    print('\n TEST EXECUTION SUMMARY');
    // ignore: avoid_print
    print('=' * 50);
    // ignore: avoid_print
    print(' Successful tests: ${results.successfulTests.length}');
    // ignore: avoid_print
    print(' Failed tests: ${results.failedTests.length}');
    // ignore: avoid_print
    print(' Rides created: ${results.createdRides.length}');
    // ignore: avoid_print
    print(' Requests created: ${results.createdRequests.length}');
    
    if (results.failedTests.isNotEmpty) {
      // ignore: avoid_print
      print('\n FAILED TESTS:');
      results.failedTests.forEach((name, error) {
        // ignore: avoid_print
        print('   • $name: $error');
      });
    }
    
    // ignore: avoid_print
    print('\n NEXT STEPS:');
    // ignore: avoid_print
    print('1. Open the driver app and check for pending requests');
    // ignore: avoid_print
    print('2. Accept/decline passenger requests to test workflow');
    // ignore: avoid_print
    print('3. Test route optimization with multiple pickups');
    // ignore: avoid_print
    print('4. Verify pickup/dropoff locations are correctly stored');
    // ignore: avoid_print
    print('5. Test passenger status updates (arrived → picked up → completed)');
    
    return results;
  }

  /// Clean up test data (optional)
  Future<void> cleanupTestData(TestResults results) async {
    // ignore: avoid_print
    print('\n🧹 Cleaning up test data...');
    
    for (final rideId in results.createdRides) {
      try {
        await _rideService.cancelRideOffer(rideId);
        // ignore: avoid_print
        print(' Cancelled ride: $rideId');
      } catch (e) {
        // ignore: avoid_print
        print(' Could not cancel ride $rideId: $e');
      }
    }
    
    for (final requestId in results.createdRequests) {
      try {
        await _rideService.cancelRideRequest(requestId);
        // ignore: avoid_print
        print(' Cancelled request: $requestId');
      } catch (e) {
        // ignore: avoid_print
        print(' Could not cancel request $requestId: $e');
      }
    }
    
    // ignore: avoid_print
    print(' Cleanup completed');
  }
}

/// Helper classes for test data structure

class TestLocation {
  final String address;
  final double lat;
  final double lng;
  final String name;

  const TestLocation({
    required this.address,
    required this.lat,
    required this.lng,
    required this.name,
  });
}

class TestScenario {
  final String name;
  final String description;
  final List<RideTestCase> testCases;
  final DateTime generatedAt;

  TestScenario({
    required this.name,
    required this.description,
    required this.testCases,
    required this.generatedAt,
  });
}

class RideTestCase {
  final String name;
  final String description;
  final RideOffer rideOffer;
  final List<RideRequest> passengerRequests;
  final List<String> expectedOptimalRoute;

  RideTestCase({
    required this.name,
    required this.description,
    required this.rideOffer,
    required this.passengerRequests,
    required this.expectedOptimalRoute,
  });
}

class TestResults {
  final List<String> createdRides = [];
  final List<String> createdRequests = [];
  final List<String> successfulTests = [];
  final Map<String, String> failedTests = {};
}