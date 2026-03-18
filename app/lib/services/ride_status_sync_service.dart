import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import '../models/ride_model.dart';
import 'live_location_service.dart';
import 'passenger_service.dart';
import 'ride_notification_service.dart';

class RideStatusSyncService {
  static final RideStatusSyncService _instance = RideStatusSyncService._internal();
  factory RideStatusSyncService() => _instance;
  RideStatusSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LiveLocationService _liveLocationService = LiveLocationService();
  final PassengerService _passengerService = PassengerService();
  final RideNotificationService _notificationService = RideNotificationService();
  final Logger _logger = Logger();

  // Thresholds for automatic status updates
  static const double _arrivalThreshold = 50.0; // meters
  static const double _pickupThreshold = 20.0; // meters
  static const Duration _arrivalDelay = Duration(seconds: 30);
  static const Duration _statusCheckInterval = Duration(seconds: 15);

  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, Timer> _arrivalTimers = {};
  final Map<String, DateTime> _lastStatusChecks = {};

  /// Start monitoring ride status for automatic updates
  Future<void> startRideStatusMonitoring(String rideId) async {
    try {
      _logger.i('Starting ride status monitoring for: $rideId');
      
      // Stop existing monitoring if any
      await stopRideStatusMonitoring(rideId);

      // Get ride data
      final rideDoc = await _firestore.collection('ride_offers').doc(rideId).get();
      if (!rideDoc.exists) {
        _logger.w('Ride not found: $rideId');
        return;
      }

      final ride = RideOffer.fromFirestore(rideDoc);
      
      // Only monitor active and in-progress rides
      if (ride.status != RideStatus.active && ride.status != RideStatus.inProgress) {
        _logger.i('Ride status monitoring not needed for status: ${ride.status}');
        return;
      }

      // Set up location monitoring
      _activeSubscriptions[rideId] = _liveLocationService
          .getRideParticipantsLocationStream(ride)
          .listen(
            (locationUpdates) => _handleLocationUpdates(ride, locationUpdates),
            onError: (error) => _logger.e('Location stream error for ride $rideId: $error'),
          );

      // Set up periodic status checks
      Timer.periodic(_statusCheckInterval, (timer) {
        if (!_activeSubscriptions.containsKey(rideId)) {
          timer.cancel();
          return;
        }
        _performPeriodicStatusCheck(rideId);
      });

      _logger.i('Ride status monitoring started for: $rideId');
    } catch (e) {
      _logger.e('Error starting ride status monitoring: $e');
      rethrow;
    }
  }

  /// Stop monitoring ride status
  Future<void> stopRideStatusMonitoring(String rideId) async {
    try {
      _activeSubscriptions[rideId]?.cancel();
      _activeSubscriptions.remove(rideId);
      
      _arrivalTimers[rideId]?.cancel();
      _arrivalTimers.remove(rideId);
      
      _lastStatusChecks.remove(rideId);
      
      _logger.i('Stopped ride status monitoring for: $rideId');
    } catch (e) {
      _logger.e('Error stopping ride status monitoring: $e');
    }
  }

  /// Handle real-time location updates and trigger status changes
  Future<void> _handleLocationUpdates(
    RideOffer ride,
    Map<String, LiveLocationUpdate> locationUpdates,
  ) async {
    try {
      final driverLocation = locationUpdates[ride.driverId];
      if (driverLocation == null) return;

      // Check each passenger for proximity-based status updates
      for (final passengerId in ride.passengerIds) {
        await _checkPassengerProximity(
          ride,
          passengerId,
          driverLocation,
        );
      }

      // Check if ride should be completed
      await _checkRideCompletion(ride, locationUpdates);
      
    } catch (e) {
      _logger.e('Error handling location updates: $e');
    }
  }

  /// Check proximity between driver and passenger for status updates
  Future<void> _checkPassengerProximity(
    RideOffer ride,
    String passengerId,
    LiveLocationUpdate driverLocation,
  ) async {
    try {
      // Get passenger info to access pickup/dropoff locations
      final passengerInfoList = await _passengerService.getPassengerInfoForRide(ride);
      final passenger = passengerInfoList.firstWhere(
        (p) => p.user.uid == passengerId,
        orElse: () => throw StateError('Passenger not found'),
      );

      final currentStatus = ride.passengerPickupStatus[passengerId] ?? PickupStatus.pending;
      
      // Calculate distances
      final pickupDistance = _calculateDistance(
        driverLocation.coordinates,
        passenger.pickupLocation.coordinates,
      );

      final dropoffDistance = _calculateDistance(
        driverLocation.coordinates,
        passenger.dropoffLocation.coordinates,
      );

      // Handle status transitions based on proximity
      switch (currentStatus) {
        case PickupStatus.pending:
          if (pickupDistance <= _arrivalThreshold) {
            await _scheduleArrivalUpdate(ride.id, passengerId);
          }
          break;

        case PickupStatus.driverArrived:
          if (pickupDistance <= _pickupThreshold) {
            await _triggerPickupConfirmation(ride.id, passengerId);
          }
          break;

        case PickupStatus.passengerPickedUp:
          if (dropoffDistance <= _pickupThreshold) {
            await _triggerDropoffConfirmation(ride.id, passengerId);
          }
          break;

        case PickupStatus.completed:
          // Passenger journey complete
          break;
      }
    } catch (e) {
      _logger.e('Error checking passenger proximity: $e');
    }
  }

  /// Schedule arrival status update with delay to avoid false positives
  Future<void> _scheduleArrivalUpdate(String rideId, String passengerId) async {
    final timerKey = '${rideId}_${passengerId}_arrival';
    
    // Cancel existing timer if any
    _arrivalTimers[timerKey]?.cancel();
    
    // Schedule new arrival update
    _arrivalTimers[timerKey] = Timer(_arrivalDelay, () async {
      try {
        await _passengerService.updatePassengerPickupStatus(
          rideId,
          passengerId,
          PickupStatus.driverArrived,
        );
        
        // Get passenger info for notification
        final rideDoc = await _firestore.collection('ride_offers').doc(rideId).get();
        final ride = RideOffer.fromFirestore(rideDoc);
        final passengerInfoList = await _passengerService.getPassengerInfoForRide(ride);
        final passenger = passengerInfoList.firstWhere((p) => p.user.uid == passengerId);
        
        // Send notification to passenger
        await _notificationService.notifyDriverArrival(
          rideId: rideId,
          passengerId: passengerId,
          driverName: 'Your driver', // Could be enhanced with actual driver name
          pickupAddress: passenger.pickupLocation.address,
        );
        
        await _broadcastStatusChange(
          rideId,
          'Driver has arrived for pickup',
          {'passengerId': passengerId, 'status': 'driverArrived'},
        );
        
        _logger.i('Auto-updated status to driverArrived for passenger: $passengerId');
      } catch (e) {
        _logger.e('Error auto-updating arrival status: $e');
      } finally {
        _arrivalTimers.remove(timerKey);
      }
    });
  }

  /// Trigger pickup confirmation (requires manual confirmation)
  Future<void> _triggerPickupConfirmation(String rideId, String passengerId) async {
    try {
      // Get ride and passenger info
      final rideDoc = await _firestore.collection('ride_offers').doc(rideId).get();
      final ride = RideOffer.fromFirestore(rideDoc);
      final passengerInfoList = await _passengerService.getPassengerInfoForRide(ride);
      final passenger = passengerInfoList.firstWhere((p) => p.user.uid == passengerId);
      
      // Send notification to driver
      await _notificationService.notifyPickupReady(
        rideId: rideId,
        driverId: ride.driverId,
        passengerName: passenger.user.profile.displayName,
      );
      
      await _broadcastStatusChange(
        rideId,
        'Passenger is ready for pickup - please confirm',
        {
          'passengerId': passengerId,
          'action': 'confirmPickup',
          'requiresConfirmation': true,
        },
      );
      
      _logger.i('Triggered pickup confirmation for passenger: $passengerId');
    } catch (e) {
      _logger.e('Error triggering pickup confirmation: $e');
    }
  }

  /// Trigger dropoff confirmation (requires manual confirmation)
  Future<void> _triggerDropoffConfirmation(String rideId, String passengerId) async {
    try {
      // Get ride and passenger info
      final rideDoc = await _firestore.collection('ride_offers').doc(rideId).get();
      final ride = RideOffer.fromFirestore(rideDoc);
      final passengerInfoList = await _passengerService.getPassengerInfoForRide(ride);
      final passenger = passengerInfoList.firstWhere((p) => p.user.uid == passengerId);
      
      // Send notification to driver
      await _notificationService.notifyDropoffReady(
        rideId: rideId,
        driverId: ride.driverId,
        passengerName: passenger.user.profile.displayName,
        dropoffAddress: passenger.dropoffLocation.address,
      );
      
      await _broadcastStatusChange(
        rideId,
        'Arrived at destination - please confirm dropoff',
        {
          'passengerId': passengerId,
          'action': 'confirmDropoff',
          'requiresConfirmation': true,
        },
      );
      
      _logger.i('Triggered dropoff confirmation for passenger: $passengerId');
    } catch (e) {
      _logger.e('Error triggering dropoff confirmation: $e');
    }
  }

  /// Check if ride should be automatically completed
  Future<void> _checkRideCompletion(
    RideOffer ride,
    Map<String, LiveLocationUpdate> locationUpdates,
  ) async {
    try {
      if (ride.status != RideStatus.inProgress) return;

      // Check if all passengers are completed
      final allCompleted = ride.passengerPickupStatus.values
          .every((status) => status == PickupStatus.completed);

      if (allCompleted && ride.passengerIds.isNotEmpty) {
        _logger.d('All passengers dropped off for ${ride.id}, waiting for driver to complete manually');
        return;
      }
    } catch (e) {
      _logger.e('Error checking ride completion: $e');
    }
  }

  /// Perform periodic status checks for edge cases
  Future<void> _performPeriodicStatusCheck(String rideId) async {
    try {
      final now = DateTime.now();
      final lastCheck = _lastStatusChecks[rideId];
      
      if (lastCheck != null && 
          now.difference(lastCheck) < _statusCheckInterval) {
        return;
      }
      
      _lastStatusChecks[rideId] = now;

      // Get updated ride data
      final rideDoc = await _firestore.collection('ride_offers').doc(rideId).get();
      if (!rideDoc.exists) {
        await stopRideStatusMonitoring(rideId);
        return;
      }

      final ride = RideOffer.fromFirestore(rideDoc);
      
      // Stop monitoring if ride is no longer active
      if (ride.status == RideStatus.completed || ride.status == RideStatus.cancelled) {
        await stopRideStatusMonitoring(rideId);
        return;
      }

      // Additional periodic checks can be added here
      _logger.d('Periodic status check completed for ride: $rideId');
      
    } catch (e) {
      _logger.e('Error in periodic status check: $e');
    }
  }

  /// Broadcast status change to all ride participants
  Future<void> _broadcastStatusChange(
    String rideId,
    String message,
    Map<String, dynamic> data,
  ) async {
    try {
      final notification = {
        'rideId': rideId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'statusChange',
        'data': data,
      };

      await _firestore
          .collection('ride_notifications')
          .doc('${rideId}_${DateTime.now().millisecondsSinceEpoch}')
          .set(notification);
          
    } catch (e) {
      _logger.e('Error broadcasting status change: $e');
    }
  }

  /// Calculate distance between two coordinates
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Dispose all resources
  Future<void> dispose() async {
    try {
      for (final subscription in _activeSubscriptions.values) {
        await subscription.cancel();
      }
      _activeSubscriptions.clear();

      for (final timer in _arrivalTimers.values) {
        timer.cancel();
      }
      _arrivalTimers.clear();

      _lastStatusChecks.clear();
      
      _logger.i('RideStatusSyncService disposed');
    } catch (e) {
      _logger.e('Error disposing RideStatusSyncService: $e');
    }
  }
}
