import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import 'passenger_service.dart';

class PassengerContactInfo {
  final String passengerId;
  final UserModel passenger;
  final PickupStatus pickupStatus;
  final RideLocation pickupLocation;
  final RideLocation dropoffLocation;
  final String? phoneNumber;
  final DateTime? eta;
  final double? distanceToPickup;
  final String? notes;

  PassengerContactInfo({
    required this.passengerId,
    required this.passenger,
    required this.pickupStatus,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.phoneNumber,
    this.eta,
    this.distanceToPickup,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'passengerId': passengerId,
      'passenger': passenger.toMap(),
      'pickupStatus': pickupStatus.name,
      'pickupLocation': pickupLocation.toMap(),
      'dropoffLocation': dropoffLocation.toMap(),
      'phoneNumber': phoneNumber,
      'eta': eta?.toIso8601String(),
      'distanceToPickup': distanceToPickup,
      'notes': notes,
    };
  }
}

class ActiveRideInfo {
  final RideOffer ride;
  final List<PassengerContactInfo> passengers;
  final DateTime? estimatedCompletion;
  final double totalDistance;
  final Duration estimatedDuration;
  final Map<String, dynamic> driverInfo;

  ActiveRideInfo({
    required this.ride,
    required this.passengers,
    this.estimatedCompletion,
    required this.totalDistance,
    required this.estimatedDuration,
    required this.driverInfo,
  });
}

class ActiveRideManagementService {
  static final ActiveRideManagementService _instance = ActiveRideManagementService._internal();
  factory ActiveRideManagementService() => _instance;
  ActiveRideManagementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PassengerService _passengerService = PassengerService();
  final Logger _logger = Logger();

  /// Get comprehensive active ride information for driver
  Future<ActiveRideInfo?> getActiveRideInfo(String driverId) async {
    try {
      // Find active ride for driver
      final activeRideQuery = await _firestore
          .collection('ride_offers')
          .where('driverId', isEqualTo: driverId)
          .where('isArchived', isEqualTo: false)
          .where('status', whereIn: [
            RideStatus.inProgress.name,
            RideStatus.active.name,
            RideStatus.completed.name,
          ])
          .limit(1)
          .get();

      if (activeRideQuery.docs.isEmpty) {
        return null;
      }

      final rideDoc = activeRideQuery.docs.first;
      final ride = RideOffer.fromFirestore(rideDoc);

      // Get passenger contact information
      final passengers = await _getPassengerContactInfo(ride);

      // Get driver information
      final driverDoc = await _firestore.collection('users').doc(driverId).get();
      final driverInfo = driverDoc.exists ? driverDoc.data()! : <String, dynamic>{};

      // Calculate estimated completion
      final estimatedCompletion = await _calculateEstimatedCompletion(ride);

      return ActiveRideInfo(
        ride: ride,
        passengers: passengers,
        estimatedCompletion: estimatedCompletion,
        totalDistance: ride.estimatedDistance,
        estimatedDuration: ride.estimatedDuration,
        driverInfo: driverInfo,
      );
    } catch (e) {
      _logger.e('Error getting active ride info: $e');
      return null;
    }
  }

  /// Get detailed passenger contact information
  Future<List<PassengerContactInfo>> _getPassengerContactInfo(RideOffer ride) async {
    try {
      final passengers = <PassengerContactInfo>[];
      final passengerInfoList = await _passengerService.getPassengerInfoForRide(ride);

      for (final passengerInfo in passengerInfoList) {
        final passenger = passengerInfo.user;
        final pickupStatus = ride.passengerPickupStatus[passenger.uid] ?? PickupStatus.pending;

        // Get phone number from profile
        final phoneNumber = passenger.profile.phoneNumber;

        // Calculate ETA to pickup if not picked up yet
        DateTime? eta;
        double? distanceToPickup;
        
        if (pickupStatus == PickupStatus.pending || pickupStatus == PickupStatus.driverArrived) {
          try {
            // Get current driver location - for now, we'll skip ETA calculation
            // This would need driver's current location to work properly
            _logger.d('ETA calculation skipped - requires current driver location');
          } catch (e) {
            _logger.w('Could not calculate ETA for passenger ${passenger.uid}: $e');
          }
        }

        passengers.add(PassengerContactInfo(
          passengerId: passenger.uid,
          passenger: passenger,
          pickupStatus: pickupStatus,
          pickupLocation: passengerInfo.pickupLocation,
          dropoffLocation: passengerInfo.dropoffLocation,
          phoneNumber: phoneNumber,
          eta: eta,
          distanceToPickup: distanceToPickup,
          notes: passengerInfo.notes,
        ));
      }

      // Sort passengers by pickup status and ETA
      passengers.sort((a, b) {
        // Pending passengers first, then by ETA
        if (a.pickupStatus != b.pickupStatus) {
          return a.pickupStatus.index.compareTo(b.pickupStatus.index);
        }
        
        if (a.eta != null && b.eta != null) {
          return a.eta!.compareTo(b.eta!);
        }
        
        return 0;
      });

      return passengers;
    } catch (e) {
      _logger.e('Error getting passenger contact info: $e');
      return [];
    }
  }

  /// Call passenger
  Future<bool> callPassenger(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        _logger.i('Initiated call to: $phoneNumber');
        return true;
      } else {
        _logger.e('Cannot launch phone app for: $phoneNumber');
        return false;
      }
    } catch (e) {
      _logger.e('Error calling passenger: $e');
      return false;
    }
  }

  /// Send SMS to passenger (fallback to system SMS app)
  /// Note: This is kept for backward compatibility, but in-app messaging is preferred
  Future<bool> sendSMSToPassenger(String phoneNumber, String message) async {
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        _logger.i('Initiated SMS to: $phoneNumber');
        return true;
      } else {
        _logger.e('Cannot launch SMS app for: $phoneNumber');
        return false;
      }
    } catch (e) {
      _logger.e('Error sending SMS: $e');
      return false;
    }
  }

  /// Get quick message templates for passengers
  List<String> getQuickMessageTemplates() {
    return [
      "I'm on my way to pick you up!",
      "I'm running about 5 minutes late",
      "I've arrived at your pickup location",
      "Please come outside, I'm here",
      "Thank you for riding with me!",
      "Have a great day!",
    ];
  }

  /// Mark passenger as picked up
  Future<void> markPassengerPickedUp(String rideId, String passengerId) async {
    try {
      await _passengerService.updatePassengerPickupStatus(
        rideId,
        passengerId,
        PickupStatus.passengerPickedUp,
      );
      
      _logger.i('Marked passenger as picked up: $passengerId');
    } catch (e) {
      _logger.e('Error marking passenger as picked up: $e');
      rethrow;
    }
  }

  /// Mark passenger as dropped off
  Future<void> markPassengerDroppedOff(String rideId, String passengerId) async {
    try {
      await _passengerService.updatePassengerPickupStatus(
        rideId,
        passengerId,
        PickupStatus.completed,
      );
      
      _logger.i('Marked passenger as dropped off: $passengerId');
    } catch (e) {
      _logger.e('Error marking passenger as dropped off: $e');
      rethrow;
    }
  }

  /// Get real-time active ride stream for driver
  Stream<ActiveRideInfo?> getActiveRideStream(String driverId) {
    try {
      return _firestore
          .collection('ride_offers')
          .where('driverId', isEqualTo: driverId)
          .where('isArchived', isEqualTo: false)
          .where('status', whereIn: [
            RideStatus.inProgress.name,
            RideStatus.active.name,
            RideStatus.completed.name,
          ])
          .limit(1)
          .snapshots()
          .asyncMap((snapshot) async {
        if (snapshot.docs.isEmpty) {
          return null;
        }

        final rideDoc = snapshot.docs.first;
        final ride = RideOffer.fromFirestore(rideDoc);

        // Get updated passenger information
        final passengers = await _getPassengerContactInfo(ride);

        // Get driver information
        final driverDoc = await _firestore.collection('users').doc(driverId).get();
        final driverInfo = driverDoc.exists ? driverDoc.data()! : <String, dynamic>{};

        // Calculate estimated completion
        final estimatedCompletion = await _calculateEstimatedCompletion(ride);

        return ActiveRideInfo(
          ride: ride,
          passengers: passengers,
          estimatedCompletion: estimatedCompletion,
          totalDistance: ride.estimatedDistance,
          estimatedDuration: ride.estimatedDuration,
          driverInfo: driverInfo,
        );
      });
    } catch (e) {
      _logger.e('Error getting active ride stream: $e');
      return Stream.value(null);
    }
  }

  /// Calculate estimated completion time
  Future<DateTime?> _calculateEstimatedCompletion(RideOffer ride) async {
    try {
      if (ride.status != RideStatus.inProgress) {
        return null;
      }

      // Get remaining passengers to drop off
      final remainingPassengers = ride.passengerPickupStatus.entries
          .where((entry) => entry.value != PickupStatus.completed)
          .length;

      if (remainingPassengers == 0) {
        return DateTime.now(); // Should be completed now
      }

      // Estimate 10 minutes per remaining stop + current ETA
      final estimatedMinutes = remainingPassengers * 10;
      return DateTime.now().add(Duration(minutes: estimatedMinutes));
    } catch (e) {
      _logger.e('Error calculating estimated completion: $e');
      return null;
    }
  }

  /// Get emergency information for all passengers
  Future<List<Map<String, String>>> getEmergencyContacts(RideOffer ride) async {
    try {
      final emergencyContacts = <Map<String, String>>[];

      for (final passengerId in ride.passengerIds) {
        try {
          final snapshot = await _firestore
              .collection('emergency_contacts')
              .where('userId', isEqualTo: passengerId)
              .get();

          for (final doc in snapshot.docs) {
            final contact = doc.data();
            emergencyContacts.add({
              'passengerId': passengerId,
              'name': contact['name'] ?? 'Unknown',
              'phoneNumber': contact['phoneNumber'] ?? '',
              'relationship': contact['relationship'] ?? 'Emergency Contact',
            });
          }
        } catch (e) {
          _logger.w('Could not get emergency contacts for $passengerId: $e');
        }
      }

      return emergencyContacts;
    } catch (e) {
      _logger.e('Error getting emergency contacts: $e');
      return [];
    }
  }

  /// Report an issue with passenger
  Future<void> reportPassengerIssue({
    required String rideId,
    required String passengerId,
    required String issueType,
    required String description,
  }) async {
    try {
      final report = {
        'rideId': rideId,
        'passengerId': passengerId,
        'reportedBy': 'driver',
        'issueType': issueType,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      };

      await _firestore.collection('passenger_reports').add(report);
      
      _logger.i('Passenger issue reported: $issueType for $passengerId');
    } catch (e) {
      _logger.e('Error reporting passenger issue: $e');
      rethrow;
    }
  }

  /// Get available issue types for reporting
  List<String> getIssueTypes() {
    return [
      'No-show',
      'Late to pickup',
      'Inappropriate behavior',
      'Safety concern',
      'Damage to vehicle',
      'Incorrect pickup location',
      'Payment issue',
      'Other',
    ];
  }

  /// Update passenger notes
  Future<void> updatePassengerNotes(String rideId, String passengerId, String notes) async {
    try {
      await _firestore
          .collection('ride_offers')
          .doc(rideId)
          .update({'passengerNotes.$passengerId': notes});
      
      _logger.i('Updated passenger notes for: $passengerId');
    } catch (e) {
      _logger.e('Error updating passenger notes: $e');
      rethrow;
    }
  }
}
