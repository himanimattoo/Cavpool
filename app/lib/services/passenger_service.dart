import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';

class PassengerInfo {
  final UserModel user;
  final PickupStatus pickupStatus;
  final RideLocation pickupLocation;
  final RideLocation dropoffLocation;
  final String? notes;

  PassengerInfo({
    required this.user,
    required this.pickupStatus,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.notes,
  });
}

class PassengerService {
  static final PassengerService _instance = PassengerService._internal();
  factory PassengerService() => _instance;
  PassengerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  Future<List<PassengerInfo>> getPassengerInfoForRide(RideOffer ride) async {
    try {
      final passengerInfoList = <PassengerInfo>[];
      
      for (final passengerId in ride.passengerIds) {
        final userDoc = await _firestore.collection('users').doc(passengerId).get();
        
        if (userDoc.exists) {
          final user = UserModel.fromFirestore(userDoc);
          final pickupStatus = ride.passengerPickupStatus[passengerId] ?? PickupStatus.pending;
          
          // Get passenger's specific pickup and dropoff locations
          final pickupLocation = ride.passengerPickupLocations[passengerId] ?? ride.startLocation;
          final dropoffLocation = ride.passengerDropoffLocations[passengerId] ?? ride.endLocation;
          
          final passengerInfo = PassengerInfo(
            user: user,
            pickupStatus: pickupStatus,
            pickupLocation: pickupLocation,
            dropoffLocation: dropoffLocation,
            notes: ride.notes,
          );
          
          passengerInfoList.add(passengerInfo);
        }
      }
      
      return passengerInfoList;
    } catch (e) {
      _logger.e('Error getting passenger info: $e');
      return [];
    }
  }

  Future<UserModel?> getPassengerById(String passengerId) async {
    try {
      final doc = await _firestore.collection('users').doc(passengerId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting passenger: $e');
      return null;
    }
  }

  Future<void> updatePassengerPickupStatus(
    String rideId,
    String passengerId,
    PickupStatus status,
  ) async {
    try {
      await _firestore.collection('ride_offers').doc(rideId).update({
        'passengerPickupStatus.$passengerId': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      _logger.i('Updated pickup status for passenger $passengerId to ${status.name}');
    } catch (e) {
      _logger.e('Error updating pickup status: $e');
      rethrow;
    }
  }

  Stream<List<PassengerInfo>> getPassengerInfoStream(RideOffer ride) {
    try {
      return _firestore
          .collection('ride_offers')
          .doc(ride.id)
          .snapshots()
          .asyncMap((rideDoc) async {
        if (!rideDoc.exists) return <PassengerInfo>[];
        
        final updatedRide = RideOffer.fromFirestore(rideDoc);
        return await getPassengerInfoForRide(updatedRide);
      });
    } catch (e) {
      _logger.e('Error getting passenger info stream: $e');
      return Stream.value([]);
    }
  }

  String getPickupStatusDisplayName(PickupStatus status) {
    switch (status) {
      case PickupStatus.pending:
        return 'Heading to pickup';
      case PickupStatus.driverArrived:
        return 'Driver arrived';
      case PickupStatus.passengerPickedUp:
        return 'Passenger on board';
      case PickupStatus.completed:
        return 'Dropped off';
    }
  }

  bool canMarkArrived(PickupStatus status) {
    return status == PickupStatus.pending;
  }

  bool canMarkPickedUp(PickupStatus status) {
    return status == PickupStatus.driverArrived;
  }

  bool canMarkDroppedOff(PickupStatus status) {
    return status == PickupStatus.passengerPickedUp;
  }
}