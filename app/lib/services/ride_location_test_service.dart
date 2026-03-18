import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import '../models/ride_model.dart';
import 'ride_status_sync_service.dart';
import 'live_location_service.dart';
import 'driver_status_service.dart';

/// Service for testing ride status synchronization with actual location changes
class RideLocationTestService {
  static final RideLocationTestService _instance = RideLocationTestService._internal();
  factory RideLocationTestService() => _instance;
  RideLocationTestService._internal();

  final Logger _logger = Logger();
  final RideStatusSyncService _statusSyncService = RideStatusSyncService();
  final LiveLocationService _liveLocationService = LiveLocationService();
  final DriverStatusService _driverStatusService = DriverStatusService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Test ride status synchronization with simulated location changes
  Future<RideLocationTestResult> testRideStatusSynchronization() async {
    final stopwatch = Stopwatch()..start();
    final testId = DateTime.now().millisecondsSinceEpoch.toString();
    final testDriverId = 'test_driver_$testId';
    final testPassengerId = 'test_passenger_$testId';
    final testRideId = 'test_ride_$testId';

    final testSteps = <String>[];
    final locations = <String, LatLng>{};

    try {
      _logger.i('[CAR] Starting ride status synchronization test...');

      // Step 1: Define test locations
      final campusLocation = const LatLng(38.0336, -78.5076); // UVA Campus
      final pickupLocation = const LatLng(38.0340, -78.5080); // Pickup point
      final dropoffLocation = const LatLng(38.0450, -78.5050); // Downtown
      
      locations['campus'] = campusLocation;
      locations['pickup'] = pickupLocation;
      locations['dropoff'] = dropoffLocation;

      testSteps.add('[PASS] Test locations defined');

      // Step 2: Set up driver online
      await _driverStatusService.setDriverOnlineById(testDriverId, location: {
        'latitude': campusLocation.latitude,
        'longitude': campusLocation.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      testSteps.add('[PASS] Driver set online');

      // Step 3: Create test ride offer
      // Create a simple test ride document directly
      final testRideData = {
        'id': testRideId,
        'driverId': testDriverId,
        'status': RideStatus.inProgress.name,
        'passengerPickupStatus': {testPassengerId: PickupStatus.pending.name},
        'startLocation': {
          'coordinates': {
            'latitude': pickupLocation.latitude,
            'longitude': pickupLocation.longitude,
          },
          'address': 'Test Pickup Location',
          'placeId': 'test_pickup',
        },
        'endLocation': {
          'coordinates': {
            'latitude': dropoffLocation.latitude,
            'longitude': dropoffLocation.longitude,
          },
          'address': 'Test Dropoff Location',
          'placeId': 'test_dropoff',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('ride_offers').doc(testRideId).set(testRideData);
      testSteps.add('[PASS] Test ride created');

      // Step 4: Start ride status monitoring
      await _statusSyncService.startRideStatusMonitoring(testRideId);
      testSteps.add('[PASS] Started ride status monitoring');

      // Step 5: Start location sharing
      await _liveLocationService.startLocationSharing(userId: testDriverId, rideId: testRideId);
      testSteps.add('[PASS] Started location sharing');

      // Step 6: Simulate driver movement towards pickup
      testSteps.add('[ROCKET] Testing location-based status updates...');

      // Position 1: Driver far from pickup (100m away)
      var currentLocation = _offsetLocation(pickupLocation, 100.0);
      await _simulateLocationUpdate(testDriverId, currentLocation);
      await Future.delayed(const Duration(seconds: 2));
      
      var rideSnapshot = await _firestore.collection('ride_offers').doc(testRideId).get();
      var currentRideData = rideSnapshot.data()!;
      var currentStatusName = currentRideData['passengerPickupStatus']?[testPassengerId] as String?;
      var currentStatus = currentStatusName != null 
          ? PickupStatus.values.firstWhere((e) => e.name == currentStatusName, orElse: () => PickupStatus.pending)
          : PickupStatus.pending;
      
      testSteps.add('[LOCATION] Driver 100m away: Status = ${currentStatus.name}');

      // Position 2: Driver approaching pickup (within arrival threshold - 40m)
      currentLocation = _offsetLocation(pickupLocation, 40.0);
      await _simulateLocationUpdate(testDriverId, currentLocation);
      await Future.delayed(const Duration(seconds: 3));
      
      rideSnapshot = await _firestore.collection('ride_offers').doc(testRideId).get();
      currentRideData = rideSnapshot.data()!;
      currentStatusName = currentRideData['passengerPickupStatus']?[testPassengerId] as String?;
      currentStatus = currentStatusName != null 
          ? PickupStatus.values.firstWhere((e) => e.name == currentStatusName, orElse: () => PickupStatus.pending)
          : PickupStatus.pending;
      
      testSteps.add('[LOCATION] Driver 40m away: Status = ${currentStatus.name}');

      // Position 3: Driver arrived at pickup (within pickup threshold - 15m)
      currentLocation = _offsetLocation(pickupLocation, 15.0);
      await _simulateLocationUpdate(testDriverId, currentLocation);
      await Future.delayed(const Duration(seconds: 3));
      
      rideSnapshot = await _firestore.collection('ride_offers').doc(testRideId).get();
      currentRideData = rideSnapshot.data()!;
      currentStatusName = currentRideData['passengerPickupStatus']?[testPassengerId] as String?;
      currentStatus = currentStatusName != null 
          ? PickupStatus.values.firstWhere((e) => e.name == currentStatusName, orElse: () => PickupStatus.pending)
          : PickupStatus.pending;
      
      testSteps.add('[LOCATION] Driver 15m away: Status = ${currentStatus.name}');

      // Position 4: Driver very close to pickup (5m)
      currentLocation = _offsetLocation(pickupLocation, 5.0);
      await _simulateLocationUpdate(testDriverId, currentLocation);
      await Future.delayed(const Duration(seconds: 3));
      
      rideSnapshot = await _firestore.collection('ride_offers').doc(testRideId).get();
      currentRideData = rideSnapshot.data()!;
      currentStatusName = currentRideData['passengerPickupStatus']?[testPassengerId] as String?;
      final finalStatus = currentStatusName != null 
          ? PickupStatus.values.firstWhere((e) => e.name == currentStatusName, orElse: () => PickupStatus.pending)
          : PickupStatus.pending;
      
      testSteps.add('[LOCATION] Driver 5m away: Status = ${finalStatus.name}');

      // Step 7: Test movement towards dropoff
      testSteps.add('[TARGET] Testing movement towards dropoff...');

      // Manually update status to picked up for dropoff test
      await _firestore.collection('ride_offers').doc(testRideId).update({
        'passengerPickupStatus.$testPassengerId': PickupStatus.passengerPickedUp.name,
      });

      // Position 5: Moving towards dropoff
      currentLocation = _interpolateLocation(pickupLocation, dropoffLocation, 0.5); // Halfway
      await _simulateLocationUpdate(testDriverId, currentLocation);
      await Future.delayed(const Duration(seconds: 2));
      
      testSteps.add('[LOCATION] Halfway to dropoff');

      // Position 6: Near dropoff
      currentLocation = _offsetLocation(dropoffLocation, 20.0);
      await _simulateLocationUpdate(testDriverId, currentLocation);
      await Future.delayed(const Duration(seconds: 2));
      
      testSteps.add('[LOCATION] Near dropoff location');

      // Step 8: Clean up
      await _statusSyncService.stopRideStatusMonitoring(testRideId);
      await _liveLocationService.stopLocationSharing();
      await _driverStatusService.setDriverOfflineById(testDriverId);
      await _firestore.collection('ride_offers').doc(testRideId).delete();

      testSteps.add('[CLEANUP] Cleanup completed');

      stopwatch.stop();

      // Evaluate test results
      final statusChanged = finalStatus != PickupStatus.pending;
      final success = statusChanged;

      return RideLocationTestResult(
        success: success,
        message: success 
            ? 'Status synchronized correctly with location changes'
            : 'Status did not update based on location proximity',
        duration: stopwatch.elapsed,
        testSteps: testSteps,
        finalStatus: finalStatus,
        locations: locations,
        details: {
          'initialStatus': PickupStatus.pending.name,
          'finalStatus': finalStatus.name,
          'statusChanged': statusChanged,
          'locationUpdates': 6,
        },
      );

    } catch (e) {
      stopwatch.stop();
      
      // Cleanup on error
      try {
        await _statusSyncService.stopRideStatusMonitoring(testRideId);
        await _liveLocationService.stopLocationSharing();
        await _driverStatusService.setDriverOfflineById(testDriverId);
        await _firestore.collection('ride_offers').doc(testRideId).delete();
      } catch (cleanupError) {
        _logger.e('Cleanup error: $cleanupError');
      }

      return RideLocationTestResult(
        success: false,
        message: 'Test failed: $e',
        duration: stopwatch.elapsed,
        testSteps: testSteps,
        finalStatus: null,
        locations: locations,
        details: {'error': e.toString()},
      );
    }
  }

  /// Simulate a location update for the driver
  Future<void> _simulateLocationUpdate(String driverId, LatLng location) async {
    try {
      // Update driver location in the location service
      await _firestore.collection('live_locations').doc(driverId).set({
        'userId': driverId,
        'coordinates': {
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'speed': 0.0,
        'heading': 0.0,
      });

      // Also update in driver status
      await _driverStatusService.updateDriverLocationById(driverId, {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

    } catch (e) {
      _logger.e('Error simulating location update: $e');
    }
  }

  /// Offset a location by a certain distance in meters
  LatLng _offsetLocation(LatLng location, double meters) {
    // Rough conversion: 1 degree ≈ 111,000 meters
    final latOffset = meters / 111000;
    final lngOffset = meters / (111000 * cos(location.latitude * pi / 180));
    
    return LatLng(
      location.latitude + latOffset,
      location.longitude + lngOffset,
    );
  }

  /// Interpolate between two locations
  LatLng _interpolateLocation(LatLng start, LatLng end, double t) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * t,
      start.longitude + (end.longitude - start.longitude) * t,
    );
  }

}

class RideLocationTestResult {
  final bool success;
  final String message;
  final Duration duration;
  final List<String> testSteps;
  final PickupStatus? finalStatus;
  final Map<String, LatLng> locations;
  final Map<String, dynamic> details;

  RideLocationTestResult({
    required this.success,
    required this.message,
    required this.duration,
    required this.testSteps,
    required this.finalStatus,
    required this.locations,
    required this.details,
  });

  @override
  String toString() {
    final status = success ? '[PASS]' : '[FAIL]';
    return '$status Ride Location Test: $message (${duration.inMilliseconds}ms)';
  }
}