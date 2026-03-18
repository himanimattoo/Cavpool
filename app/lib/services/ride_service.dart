import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import '../models/ride_model.dart';
import 'routes_service.dart';
import 'live_location_service.dart';
import 'eta_service.dart';
import 'ride_status_sync_service.dart';
import 'ride_notification_service.dart';
import '../utils/verification_code_utils.dart';

class RideService {
  static final RideService _instance = RideService._internal();
  factory RideService() => _instance;
  RideService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();
  final RoutesService _routesService = RoutesService();
  final LiveLocationService _liveLocationService = LiveLocationService();
  final ETAService _etaService = ETAService();
  final RideNotificationService _notificationService = RideNotificationService();
  
  // Lazy initialization to avoid circular dependency
  RideStatusSyncService? _statusSyncService;
  RideStatusSyncService get statusSyncService {
    _statusSyncService ??= RideStatusSyncService();
    return _statusSyncService!;
  }

  // Collections
  CollectionReference get _ridesCollection => _firestore.collection('ride_offers');
  CollectionReference get _requestsCollection => _firestore.collection('ride_requests');

  // Create a new ride offer
  Future<String?> createRideOffer(RideOffer rideOffer) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      _logger.i('Creating ride offer from ${rideOffer.startLocation.address} to ${rideOffer.endLocation.address}');
      
      // Calculate route information
      final routeInfo = await _routesService.calculateRoute(
        startLocation: rideOffer.startLocation.coordinates,
        endLocation: rideOffer.endLocation.coordinates,
        startName: rideOffer.startLocation.address,
        endName: rideOffer.endLocation.address,
      );

      // Create ride offer with route information or fallback calculation
      final distance = routeInfo?.totalDistance ?? _calculateStraightLineDistance(
        rideOffer.startLocation.coordinates,
        rideOffer.endLocation.coordinates,
      );
      
      final rideWithRoute = rideOffer.copyWith(
        driverId: currentUserId, // Auto-set to current user
        estimatedDistance: distance,
        estimatedDuration: routeInfo?.estimatedDuration ?? const Duration(minutes: 30),
        passengerPickupStatus: <String, PickupStatus>{}, // Initialize empty pickup status map
      );

      final docRef = await _ridesCollection.add(rideWithRoute.toMap());
      _logger.i('Ride offer created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      _logger.e('Error creating ride offer: $e');
      rethrow;
    }
  }

  // Create a new ride request
  Future<String?> createRideRequest(RideRequest rideRequest) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    
    try {
      _logger.i('Creating ride request from ${rideRequest.startLocation.address} to ${rideRequest.endLocation.address}');
      
      // Calculate route information
      final routeInfo = await _routesService.calculateRoute(
        startLocation: rideRequest.startLocation.coordinates,
        endLocation: rideRequest.endLocation.coordinates,
        startName: rideRequest.startLocation.address,
        endName: rideRequest.endLocation.address,
      );

      // Create ride request with route information or fallback calculation
      final distance = routeInfo?.totalDistance ?? _calculateStraightLineDistance(
        rideRequest.startLocation.coordinates,
        rideRequest.endLocation.coordinates,
      );
      
      final requestWithRoute = rideRequest.copyWith(
        requesterId: currentUserId, // Auto-set to current user
        estimatedDistance: distance,
      );
      
      final docRef = await _requestsCollection.add(requestWithRoute.toMap());
      _logger.i('Ride request created with ID: ${docRef.id}');

      final savedRequest = requestWithRoute.copyWith(id: docRef.id);
      final matchedOfferId = requestWithRoute.matchedOfferId;

      if (matchedOfferId != null && matchedOfferId.isNotEmpty) {
        final matchedRide = await getRideOffer(matchedOfferId);
        if (matchedRide != null) {
          await _processMatch(savedRequest, matchedRide);
        } else {
          _logger.w('Matched ride $matchedOfferId not found, falling back to automatic matching');
          await _findMatchingRides(savedRequest);
        }
      } else {
        // Find potential matches automatically
        await _findMatchingRides(savedRequest);
      }
      
      return docRef.id;
    } catch (e) {
      _logger.e('Error creating ride request: $e');
      rethrow;
    }
  }

  // Get ride offers with optional filters
  Future<List<RideOffer>> getRideOffers({
    String? driverId,
    RideStatus? status,
    DateTime? departureAfter,
    DateTime? departureBefore,
    LatLng? nearLocation,
    double? radiusKm,
  }) async {
    try {
      Query query = _ridesCollection;

      // Apply filters
      if (driverId != null) {
        query = query.where('driverId', isEqualTo: driverId);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }
      if (departureAfter != null) {
        query = query.where('departureTime', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(departureAfter));
      }
      if (departureBefore != null) {
        query = query.where('departureTime', 
            isLessThanOrEqualTo: Timestamp.fromDate(departureBefore));
      }

      // Order by departure time
      query = query.orderBy('departureTime');

      final querySnapshot = await query.get();
      List<RideOffer> rides = querySnapshot.docs
          .map((doc) => RideOffer.fromFirestore(doc))
          .toList();

      // Apply location-based filtering if specified
      if (nearLocation != null && radiusKm != null) {
        rides = _filterRidesByLocation(rides, nearLocation, radiusKm);
      }

      return rides;
    } catch (e) {
      _logger.e('Error getting ride offers: $e');
      return [];
    }
  }

  // Get ride requests with optional filters
  Future<List<RideRequest>> getRideRequests({
    String? requesterId,
    RequestStatus? status,
    DateTime? departureAfter,
    DateTime? departureBefore,
  }) async {
    try {
      Query query = _requestsCollection;

      // Apply filters
      if (requesterId != null) {
        query = query.where('requesterId', isEqualTo: requesterId);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }
      if (departureAfter != null) {
        query = query.where('preferredDepartureTime', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(departureAfter));
      }
      if (departureBefore != null) {
        query = query.where('preferredDepartureTime', 
            isLessThanOrEqualTo: Timestamp.fromDate(departureBefore));
      }

      // Order by preferred departure time
      query = query.orderBy('preferredDepartureTime');

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => RideRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Error getting ride requests: $e');
      return [];
    }
  }

  // Get a specific ride offer
  Future<RideOffer?> getRideOffer(String rideId) async {
    try {
      final doc = await _ridesCollection.doc(rideId).get();
      if (doc.exists) {
        return RideOffer.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting ride offer: $e');
      return null;
    }
  }

  // Get a specific ride request
  Future<RideRequest?> getRideRequest(String requestId) async {
    try {
      final doc = await _requestsCollection.doc(requestId).get();
      if (doc.exists) {
        return RideRequest.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting ride request: $e');
      return null;
    }
  }

  Future<List<RideRequest>> getRideRequestsForOffer(
    String offerId, {
    RequestStatus? status,
  }) async {
    try {
      Query query = _requestsCollection.where('matchedOfferId', isEqualTo: offerId);
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => RideRequest.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error getting ride requests for offer $offerId: $e');
      return [];
    }
  }

  // Update ride offer
  Future<void> updateRideOffer(String rideId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _ridesCollection.doc(rideId).update(updates);
      _logger.i('Ride offer updated: $rideId');
    } catch (e) {
      _logger.e('Error updating ride offer: $e');
      rethrow;
    }
  }

  // Update ride request
  Future<void> updateRideRequest(String requestId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _requestsCollection.doc(requestId).update(updates);
      _logger.i('Ride request updated: $requestId');
    } catch (e) {
      _logger.e('Error updating ride request: $e');
      rethrow;
    }
  }

  // Join a ride (passenger joins driver's ride)
  Future<bool> joinRide(
    String rideId,
    String passengerId, {
    double? seatPrice,
    RideLocation? pickupLocation,
    RideLocation? dropoffLocation,
    int seatsRequested = 1,
  }) async {
    try {
      final rideOffer = await getRideOffer(rideId);
      if (rideOffer == null) {
        throw Exception('Ride not found');
      }

      if (seatsRequested <= 0) seatsRequested = 1;

      if (rideOffer.availableSeats < seatsRequested) {
        throw Exception('Not enough available seats');
      }

      if (rideOffer.passengerIds.contains(passengerId)) {
        throw Exception('Already joined this ride');
      }

      final newPassengerIds = [...rideOffer.passengerIds, passengerId];
      final newAvailableSeats = rideOffer.availableSeats - seatsRequested;
      final newStatus = newAvailableSeats == 0 ? RideStatus.full : rideOffer.status;
      
      // Initialize pickup status for new passenger
      final newPickupStatus = Map<String, PickupStatus>.from(rideOffer.passengerPickupStatus);
      newPickupStatus[passengerId] = PickupStatus.pending;
      final newSeatPrices = Map<String, double>.from(rideOffer.passengerSeatPrices);
      newSeatPrices[passengerId] = seatPrice ?? rideOffer.pricePerSeat;
      final newSeatCounts = Map<String, int>.from(rideOffer.passengerSeatCounts);
      newSeatCounts[passengerId] = seatsRequested;
      final newPickupLocations = Map<String, RideLocation>.from(rideOffer.passengerPickupLocations);
      newPickupLocations[passengerId] = pickupLocation ?? rideOffer.startLocation;
      final newDropoffLocations = Map<String, RideLocation>.from(rideOffer.passengerDropoffLocations);
      newDropoffLocations[passengerId] = dropoffLocation ?? rideOffer.endLocation;

      await updateRideOffer(rideId, {
        'passengerIds': newPassengerIds,
        'availableSeats': newAvailableSeats,
        'status': newStatus.name,
        'passengerPickupStatus': newPickupStatus.map((k, v) => MapEntry(k, v.name)),
        'passengerSeatPrices': newSeatPrices,
        'passengerSeatCounts': newSeatCounts,
        'passengerPickupLocations':
            newPickupLocations.map((k, v) => MapEntry(k, v.toMap())),
        'passengerDropoffLocations':
            newDropoffLocations.map((k, v) => MapEntry(k, v.toMap())),
      });

      _logger.i('Passenger $passengerId joined ride $rideId');
      return true;
    } catch (e) {
      _logger.e('Error joining ride: $e');
      rethrow;
    }
  }

  // Leave a ride (passenger leaves driver's ride)
  Future<bool> leaveRide(String rideId, String passengerId) async {
    try {
      final rideOffer = await getRideOffer(rideId);
      if (rideOffer == null) {
        throw Exception('Ride not found');
      }

      if (!rideOffer.passengerIds.contains(passengerId)) {
        throw Exception('Not a member of this ride');
      }

      final newPassengerIds = rideOffer.passengerIds
          .where((id) => id != passengerId)
          .toList();
      final seatCount = rideOffer.passengerSeatCounts[passengerId] ?? 1;
      final newAvailableSeats = rideOffer.availableSeats + seatCount;
      final newStatus = rideOffer.status == RideStatus.full 
          ? RideStatus.active 
          : rideOffer.status;
      
      // Remove pickup status for leaving passenger
      final newPickupStatus = Map<String, PickupStatus>.from(rideOffer.passengerPickupStatus);
      newPickupStatus.remove(passengerId);
      final newSeatPrices = Map<String, double>.from(rideOffer.passengerSeatPrices);
      newSeatPrices.remove(passengerId);
      final newSeatCounts = Map<String, int>.from(rideOffer.passengerSeatCounts);
      newSeatCounts.remove(passengerId);
      final newPickupLocations = Map<String, RideLocation>.from(rideOffer.passengerPickupLocations);
      newPickupLocations.remove(passengerId);
      final newDropoffLocations = Map<String, RideLocation>.from(rideOffer.passengerDropoffLocations);
      newDropoffLocations.remove(passengerId);

      await updateRideOffer(rideId, {
        'passengerIds': newPassengerIds,
        'availableSeats': newAvailableSeats,
        'status': newStatus.name,
        'passengerPickupStatus': newPickupStatus.map((k, v) => MapEntry(k, v.name)),
        'passengerSeatPrices': newSeatPrices,
        'passengerSeatCounts': newSeatCounts,
        'passengerPickupLocations':
            newPickupLocations.map((k, v) => MapEntry(k, v.toMap())),
        'passengerDropoffLocations':
            newDropoffLocations.map((k, v) => MapEntry(k, v.toMap())),
      });

      _logger.i('Passenger $passengerId left ride $rideId');
      return true;
    } catch (e) {
      _logger.e('Error leaving ride: $e');
      rethrow;
    }
  }

  // Cancel ride offer
  Future<void> cancelRideOffer(String rideId) async {
    try {
      await updateRideOffer(rideId, {
        'status': RideStatus.cancelled.name,
        'isArchived': true,
      });
      
      // Clear verification code
      await clearVerificationCode(rideId);
      

      final acceptedRequests = await _requestsCollection
          .where('matchedOfferId', isEqualTo: rideId)
          .where('status', isEqualTo: RequestStatus.accepted.name)
          .get();

      if (acceptedRequests.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in acceptedRequests.docs) {
          batch.update(doc.reference, {
            'status': RequestStatus.cancelled.name,
            'isArchived': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        _logger.i('Archived ${acceptedRequests.docs.length} accepted requests for cancelled ride $rideId');
      }

      _logger.i('Ride offer cancelled: $rideId');
    } catch (e) {
      _logger.e('Error cancelling ride offer: $e');
      rethrow;
    }
  }

  // Cancel ride request
  Future<void> cancelRideRequest(String requestId) async {
    try {
      await updateRideRequest(requestId, {
        'status': RequestStatus.cancelled.name,
      });
      _logger.i('Ride request cancelled: $requestId');
    } catch (e) {
      _logger.e('Error cancelling ride request: $e');
      rethrow;
    }
  }

  // Find matching rides for a request and process matches
  Future<void> _findMatchingRides(RideRequest request) async {
    try {
      _logger.i('Finding matches for request ${request.id}');
      
      // Get active rides within time window
      final startTime = request.preferredDepartureTime.subtract(request.flexibilityWindow);
      final endTime = request.preferredDepartureTime.add(request.flexibilityWindow);

      final potentialRides = await getRideOffers(
        status: RideStatus.active,
        departureAfter: startTime,
        departureBefore: endTime,
      );

      // Filter by location proximity and preferences
      final matchingRides = <RideOffer>[];
      for (final ride in potentialRides) {
        // Don't match with the requester's own rides
        if (ride.driverId == request.requesterId) {
          continue;
        }
        
        // Check if request was already declined for this ride
        if (request.declinedOfferIds.contains(ride.id)) {
          continue;
        }
        
        if (_isRideMatch(request, ride)) {
          matchingRides.add(ride);
        }
      }

      _logger.i('Found ${matchingRides.length} matching rides for request ${request.id}');

      if (matchingRides.isNotEmpty) {
        // Process matches - for now, match with the first compatible ride
        // In the future, this could be enhanced with ranking/scoring
        final bestMatch = matchingRides.first;
        await _processMatch(request, bestMatch);
      }
    } catch (e) {
      _logger.e('Error finding matching rides: $e');
    }
  }

  // Process a match between a request and a ride
  Future<void> _processMatch(RideRequest request, RideOffer ride) async {
    try {
      _logger.i('Processing match: Request ${request.id} <-> Ride ${ride.id}');

      // Update request status to matched and set the matched offer ID
      await updateRideRequest(request.id, {
        'status': RequestStatus.matched.name,
        'matchedOfferId': ride.id,
        'driverId': ride.driverId,
      });

      // Create a pending match document instead of directly updating the ride offer
      // This allows both parties to see the match without permission issues
      await _firestore.collection('pendingMatches').add({
        'requestId': request.id,
        'rideOfferId': ride.id,
        'requesterId': request.requesterId,
        'driverId': ride.driverId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      _logger.i('Successfully matched request ${request.id} with ride ${ride.id}');
      
      // TODO: Send notification to driver about new request
      // This will be implemented in the next step
      
    } catch (e) {
      _logger.e('Error processing match: $e');
      rethrow;
    }
  }

  // Check if a ride matches a request
  bool _isRideMatch(RideRequest request, RideOffer ride) {
    // Check available seats
    if (ride.availableSeats < request.seatsNeeded) {
      return false;
    }

    // Check price
    if (ride.pricePerSeat > request.maxPricePerSeat) {
      return false;
    }

    // Check location proximity (simple distance check)
    const double proximityThresholdKm = 2.0; // 2km radius
    
    final startDistance = _calculateDistance(
      request.startLocation.coordinates,
      ride.startLocation.coordinates,
    );
    final endDistance = _calculateDistance(
      request.endLocation.coordinates,
      ride.endLocation.coordinates,
    );

    if (startDistance > proximityThresholdKm || endDistance > proximityThresholdKm) {
      return false;
    }

    // Check basic preferences compatibility
    if (!_arePreferencesCompatible(request.preferences, ride.preferences)) {
      return false;
    }

    return true;
  }

  // Check if preferences are compatible
  bool _arePreferencesCompatible(RidePreferences requestPrefs, RidePreferences ridePrefs) {
    // If requester doesn't allow smoking but ride allows it, not compatible
    if (!requestPrefs.allowSmoking && ridePrefs.allowSmoking) {
      return false;
    }

    // If requester doesn't allow pets but ride allows it, not compatible
    if (!requestPrefs.allowPets && ridePrefs.allowPets) {
      return false;
    }

    return true;
  }

  // Filter rides by location proximity
  List<RideOffer> _filterRidesByLocation(
    List<RideOffer> rides, 
    LatLng centerLocation, 
    double radiusKm
  ) {
    return rides.where((ride) {
      final distance = _calculateDistance(
        centerLocation,
        ride.startLocation.coordinates,
      );
      return distance <= radiusKm;
    }).toList();
  }

  // Calculate distance between two coordinates in kilometers
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final lat1Rad = point1.latitude * (3.14159265359 / 180);
    final lat2Rad = point2.latitude * (3.14159265359 / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (3.14159265359 / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Get live ride offers stream
  Stream<List<RideOffer>> getRideOffersStream({
    String? driverId,
    RideStatus? status,
  }) {
    try {
      // Check if user is authenticated
      if (_auth.currentUser == null) {
        _logger.w('User not authenticated for ride offers stream');
        return const Stream<List<RideOffer>>.empty();
      }

      // Start stream without forcing token refresh
      Query query = _ridesCollection;

      if (driverId != null) {
        query = query.where('driverId', isEqualTo: driverId);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      query = query.orderBy('departureTime');

      return query.snapshots().handleError((error) {
        _logger.e('Firestore stream error: $error');
        if (error.toString().contains('permission-denied')) {
          _logger.e('Permission denied - check Firestore rules and authentication');
        }
      }).map((snapshot) {
        return snapshot.docs
            .map((doc) => RideOffer.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      _logger.e('Error getting ride offers stream: $e');
      return const Stream<List<RideOffer>>.empty();
    }
  }


  // Get live ride requests stream
  Stream<List<RideRequest>> getRideRequestsStream({
    String? requesterId,
    RequestStatus? status,
  }) {
    try {
      // Check if user is authenticated
      if (_auth.currentUser == null) {
        _logger.w('User not authenticated for ride requests stream');
        return const Stream<List<RideRequest>>.empty();
      }

      Query query = _requestsCollection;

      if (requesterId != null) {
        query = query.where('requesterId', isEqualTo: requesterId);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      query = query.orderBy('preferredDepartureTime');

      return query.snapshots().handleError((error) {
        _logger.e('Firestore stream error: $error');
        if (error.toString().contains('permission-denied')) {
          _logger.e('Permission denied - check Firestore rules and authentication');
        }
      }).map((snapshot) {
        return snapshot.docs
            .map((doc) => RideRequest.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      _logger.e('Error getting ride requests stream: $e');
      return const Stream<List<RideRequest>>.empty();
    }
  }

  Future<void> archiveExpiredTripsForUser([String? userId]) async {
    try {
      // Get current user if userId not provided
      final targetUserId = userId ?? _auth.currentUser?.uid;
      if (targetUserId == null) {
        _logger.w('No user ID provided and no authenticated user for archiving expired trips');
        return;
      }

      final now = DateTime.now();
      final archiveCutoff = Timestamp.fromDate(now.subtract(const Duration(minutes: 30)));
      final futureCutoff = Timestamp.fromDate(now);
      final batch = _firestore.batch();
      var hasUpdates = false;

      // First, correct any trips that were archived while still in the future.
      final futureArchivedOffers = await _ridesCollection
          .where('driverId', isEqualTo: targetUserId)
          .where('isArchived', isEqualTo: true)
          .where('departureTime', isGreaterThanOrEqualTo: futureCutoff)
          .get();

      for (final doc in futureArchivedOffers.docs) {
        final ride = RideOffer.fromFirestore(doc);
        final data = doc.data() as Map<String, dynamic>;
        final bool hasCompletedTimestamp = data['completedAt'] != null;
        
        // If this ride was legitimately completed, keep it archived
        if (hasCompletedTimestamp ||
            ride.status == RideStatus.completed ||
            ride.status == RideStatus.cancelled ||
            ride.status == RideStatus.expired) {
          continue;
        }

        final updates = {
          'isArchived': false,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (ride.status == RideStatus.full) {
          updates['status'] = RideStatus.active.name;
        }

        batch.update(doc.reference, updates);
        hasUpdates = true;
      }

      final futureArchivedRequests = await _requestsCollection
          .where('requesterId', isEqualTo: targetUserId)
          .where('isArchived', isEqualTo: true)
          .where('preferredDepartureTime', isGreaterThanOrEqualTo: futureCutoff)
          .get();

      for (final doc in futureArchivedRequests.docs) {
        final request = RideRequest.fromFirestore(doc);
        final updates = {
          'isArchived': false,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (request.status == RequestStatus.completed &&
            request.matchedOfferId != null) {
          updates['status'] = RequestStatus.accepted.name;
        }
        batch.update(doc.reference, updates);
        hasUpdates = true;
      }

      // Archive expired offers for this user
      final expiredOffers = await _ridesCollection
          .where('driverId', isEqualTo: targetUserId)
          .where('isArchived', isEqualTo: false)
          .where('departureTime', isLessThan: archiveCutoff)
          .get();

      for (final doc in expiredOffers.docs) {
        final ride = RideOffer.fromFirestore(doc);
        var targetStatus = RideStatus.completed;
        if (ride.status == RideStatus.cancelled ||
            ride.status == RideStatus.expired) {
          targetStatus = ride.status;
        }
        batch.update(doc.reference, {
          'status': targetStatus.name,
          'isArchived': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        hasUpdates = true;
      }

      // Archive expired requests for this user
      final expiredRequests = await _requestsCollection
          .where('requesterId', isEqualTo: targetUserId)
          .where('isArchived', isEqualTo: false)
          .where('preferredDepartureTime', isLessThan: archiveCutoff)
          .get();

      for (final doc in expiredRequests.docs) {
        final request = RideRequest.fromFirestore(doc);

        var targetStatus = RequestStatus.declined;
        if (request.status == RequestStatus.accepted ||
            request.status == RequestStatus.completed) {
          targetStatus = RequestStatus.completed;
        } else if (request.status == RequestStatus.cancelled) {
          targetStatus = RequestStatus.cancelled;
        }

        batch.update(doc.reference, {
          'status': targetStatus.name,
          'isArchived': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        hasUpdates = true;
      }

      if (hasUpdates) {
        await batch.commit();
        _logger.i(
          'Synced archived trips for user $targetUserId. Restored ${futureArchivedOffers.docs.length} future offers and ${futureArchivedRequests.docs.length} requests. Archived ${expiredOffers.docs.length} offers and ${expiredRequests.docs.length} requests.',
        );
      } else {
        _logger.d('No expired trips to archive for user $targetUserId');
      }
    } catch (e) {
      _logger.e('Error auto-archiving expired rides/requests: $e');
    }
  }

  /// Legacy method for backward compatibility - archives for current user
  @Deprecated('Use archiveExpiredTripsForUser() instead')
  Future<void> archiveExpiredTrips() async {
    await archiveExpiredTripsForUser();
  }

  // Archive a ride offer
  Future<void> archiveRideOffer(String rideId) async {
    try {
      await _ridesCollection.doc(rideId).update({
        'isArchived': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logger.i('Ride offer archived: $rideId');
    } catch (e) {
      _logger.e('Error archiving ride offer: $e');
      rethrow;
    }
  }

  // Unarchive a ride offer
  Future<void> unarchiveRideOffer(String rideId) async {
    try {
      await _ridesCollection.doc(rideId).update({
        'isArchived': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logger.i('Ride offer unarchived: $rideId');
    } catch (e) {
      _logger.e('Error unarchiving ride offer: $e');
      rethrow;
    }
  }

  // Archive a ride request
  Future<void> archiveRideRequest(String requestId) async {
    try {
      final docRef = _requestsCollection.doc(requestId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        _logger.w('Ride request $requestId does not exist, cannot archive');
        return;
      }
      
      final data = doc.data() as Map<String, dynamic>?;
      if (data?['isArchived'] == true) {
        _logger.i('Ride request $requestId already archived');
        return;
      }
      
      await docRef.update({
        'isArchived': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logger.i('Ride request archived: $requestId');
    } catch (e) {
      _logger.e('Error archiving ride request: $e');
      rethrow;
    }
  }

  // Unarchive a ride request
  Future<void> unarchiveRideRequest(String requestId) async {
    try {
      await _requestsCollection.doc(requestId).update({
        'isArchived': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logger.i('Ride request unarchived: $requestId');
    } catch (e) {
      _logger.e('Error unarchiving ride request: $e');
      rethrow;
    }
  }

  // Get archived ride offers for a user
  Future<List<RideOffer>> getArchivedRideOffers(String userId) async {
    try {
      final querySnapshot = await _ridesCollection
          .where('driverId', isEqualTo: userId)
          .where('isArchived', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => RideOffer.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Error getting archived ride offers: $e');
      return [];
    }
  }

  // Get archived ride requests for a user
  Future<List<RideRequest>> getArchivedRideRequests(String userId) async {
    try {
      final querySnapshot = await _requestsCollection
          .where('requesterId', isEqualTo: userId)
          .where('isArchived', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => RideRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Error getting archived ride requests: $e');
      return [];
    }
  }

  // Get completed/cancelled rides for history (excluding archived)
  Future<List<RideOffer>> getHistoryRideOffers(String userId, {bool includeArchived = false}) async {
    try {
      Query query = _ridesCollection
          .where('driverId', isEqualTo: userId)
          .where('status', whereIn: [RideStatus.completed.name, RideStatus.cancelled.name]);
      
      if (!includeArchived) {
        query = query.where('isArchived', isEqualTo: false);
      }
      
      final querySnapshot = await query
          .orderBy('departureTime', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => RideOffer.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Error getting history ride offers: $e');
      return [];
    }
  }

  // Get completed/cancelled requests for history (excluding archived)
  Future<List<RideRequest>> getHistoryRideRequests(String userId, {bool includeArchived = false}) async {
    try {
      Query query = _requestsCollection
          .where('requesterId', isEqualTo: userId)
          .where('status', whereIn: [RequestStatus.completed.name, RequestStatus.cancelled.name]);
      
      if (!includeArchived) {
        query = query.where('isArchived', isEqualTo: false);
      }
      
      final querySnapshot = await query
          .orderBy('preferredDepartureTime', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => RideRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Error getting history ride requests: $e');
      return [];
    }
  }

  // Get pending requests for a driver's rides
  Future<List<RideRequest>> getDriverPendingRequests(String driverId) async {
    try {
      // Get pending matches for this driver
      final matchesSnapshot = await _firestore
          .collection('pendingMatches')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (matchesSnapshot.docs.isEmpty) {
        return [];
      }

      // Get the request IDs from the matches
      final requestIds = matchesSnapshot.docs
          .map((doc) => doc.data()['requestId'] as String)
          .toList();

      // Fetch the actual ride requests
      final List<RideRequest> pendingRequests = [];
      
      // Firestore 'in' queries are limited to 10 items, so we need to batch them
      for (int i = 0; i < requestIds.length; i += 10) {
        final batch = requestIds.skip(i).take(10).toList();
        
        final querySnapshot = await _requestsCollection
            .where(FieldPath.documentId, whereIn: batch)
            .where('status', isEqualTo: RequestStatus.matched.name)
            .get();

        final batchRequests = querySnapshot.docs
            .map((doc) => RideRequest.fromFirestore(doc))
            .toList();
        
        pendingRequests.addAll(batchRequests);
      }

      // Sort by creation time (newest first)
      pendingRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _logger.i('Found ${pendingRequests.length} pending requests for driver $driverId');
      return pendingRequests;
    } catch (e) {
      _logger.e('Error getting driver pending requests: $e');
      return [];
    }
  }

  // Accept a ride request
    Future<void> acceptRideRequest(String requestId) async {
      try {
        _logger.i('Accepting ride request: $requestId');
        
        // Get the request details
        final request = await getRideRequest(requestId);
        if (request == null) {
          throw Exception('Request not found');
        }
  
        // Update request status to accepted
        await updateRideRequest(requestId, {
          'status': RequestStatus.accepted.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  
        // If there's a matched offer, add the requester as a passenger and update the match
        if (request.matchedOfferId != null) {
          await joinRide(
            request.matchedOfferId!,
            request.requesterId,
            seatPrice: request.maxPricePerSeat,
            pickupLocation: request.startLocation,
            dropoffLocation: request.endLocation,
            seatsRequested: request.seatsNeeded,
          );
          
          // Update the pending match status to accepted (best-effort; don't fail the acceptance)
          await _markPendingMatchesAccepted(requestId);

          // Generate verification code when ride is confirmed (has passengers)
          await _generateVerificationCodeIfNeeded(request.matchedOfferId!);
        }
  
        _logger.i('Successfully accepted ride request: $requestId');
      } catch (e) {
        _logger.e('Error accepting ride request: $e');
        rethrow;
      }
    }

    Future<void> _markPendingMatchesAccepted(String requestId) async {
      try {
        final matchesSnapshot = await _firestore
            .collection('pendingMatches')
            .where('requestId', isEqualTo: requestId)
            .where('status', isEqualTo: 'pending')
            .get();

        for (final matchDoc in matchesSnapshot.docs) {
          await matchDoc.reference.update({
            'status': 'accepted',
            'acceptedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        // Keep the acceptance successful even if match cleanup fails
        _logger.w('Accepted request $requestId but failed to update pendingMatches: $e');
      }
    }

  // Decline a ride request
  Future<void> declineRideRequest(String requestId) async {
    try {
      _logger.i('Declining ride request: $requestId');
      
      // Get the request details
      final request = await getRideRequest(requestId);
      if (request == null) {
        throw Exception('Request not found');
      }

      // Add the declined offer to the request's declined list and mark as declined
      final updatedDeclinedIds = request.matchedOfferId != null 
          ? [...request.declinedOfferIds, request.matchedOfferId!]
          : request.declinedOfferIds;

      await updateRideRequest(requestId, {
        'status': RequestStatus.declined.name,
        'matchedOfferId': null,
        'driverId': null,
        'declinedOfferIds': updatedDeclinedIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove the request from the ride offer's pending list
      if (request.matchedOfferId != null) {
        final ride = await getRideOffer(request.matchedOfferId!);
        if (ride != null) {
          final updatedPendingIds = ride.pendingRequestIds.where((id) => id != requestId).toList();
          await updateRideOffer(request.matchedOfferId!, {
            'pendingRequestIds': updatedPendingIds,
          });
        }
      }

      _logger.i('Successfully declined ride request: $requestId');
      
    } catch (e) {
      _logger.e('Error declining ride request: $e');
      rethrow;
    }
  }

  // Start ride and begin location sharing
  Future<void> startRide(String rideId, String driverId) async {
    try {
      _logger.i('Starting ride: $rideId');
      
      // Update ride status to in progress
      await updateRideOffer(rideId, {
        'status': RideStatus.inProgress.name,
        'startedAt': FieldValue.serverTimestamp(),
      });

      // Start location sharing for driver
      await _liveLocationService.startLocationSharing(
        userId: driverId,
        rideId: rideId,
      );

      // Start automatic status monitoring
      await statusSyncService.startRideStatusMonitoring(rideId);

      // Get ride data for notification
      final rideDoc = await _ridesCollection.doc(rideId).get();
      final ride = RideOffer.fromFirestore(rideDoc);
      
      // Send ride started notification to all participants
      await _notificationService.notifyRideStarted(ride: ride);

      _logger.i('Ride started, location sharing and status monitoring enabled: $rideId');
    } catch (e) {
      _logger.e('Error starting ride: $e');
      rethrow;
    }
  }

  // Complete ride and stop location sharing
  Future<void> completeRide(String rideId, String driverId) async {
    try {
      _logger.i('Completing ride: $rideId');
      
      // Update ride status to completed
      await updateRideOffer(rideId, {
        'status': RideStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Clear verification code
      await clearVerificationCode(rideId);

      // Stop location sharing
      await _liveLocationService.stopLocationSharing();
      
      // Stop ETA tracking
      _etaService.stopETATracking('pickup_$driverId');
      _etaService.stopETATracking('dropoff_$driverId');

      // Stop status monitoring
      await statusSyncService.stopRideStatusMonitoring(rideId);

      // Clear location data
      await _liveLocationService.clearLocationData(driverId);

      _logger.i('Ride completed, location sharing and status monitoring stopped: $rideId');
    } catch (e) {
      _logger.e('Error completing ride: $e');
      rethrow;
    }
  }

  /// Mark individual passenger's ride request as completed when they get dropped off
  Future<void> markPassengerRideRequestCompleted(String rideId, String passengerId) async {
    try {
      final passengerRequests = await _requestsCollection
          .where('matchedOfferId', isEqualTo: rideId)
          .where('requesterId', isEqualTo: passengerId)
          .where('status', isEqualTo: RequestStatus.accepted.name)
          .get();
      
      for (final requestDoc in passengerRequests.docs) {
        await updateRideRequest(requestDoc.id, {
          'status': RequestStatus.completed.name,
          'completedAt': FieldValue.serverTimestamp(),
        });
        _logger.i('Marked ride request ${requestDoc.id} as completed for passenger $passengerId');
      }
    } catch (e) {
      _logger.e('Error marking passenger ride request as completed: $e');
      rethrow;
    }
  }

  // Get live driver location for riders
  Stream<LiveLocationUpdate?> getDriverLiveLocation(String driverId) {
    return _liveLocationService.getDriverLocationStream(driverId);
  }

  // Get all participants' live locations for a ride
  Stream<Map<String, LiveLocationUpdate>> getRideLiveLocations(RideOffer ride) {
    return _liveLocationService.getRideParticipantsLocationStream(ride);
  }

  // Get pickup ETA for riders
  Stream<ETAUpdate> getPickupETA(String driverId, LatLng pickupLocation) {
    return _etaService.getPickupETA(
      driverId: driverId,
      pickupLocation: pickupLocation,
    );
  }

  // Get dropoff ETA during ride
  Stream<ETAUpdate> getDropoffETA(String driverId, LatLng dropoffLocation) {
    return _etaService.getDropoffETA(
      driverId: driverId,
      dropoffLocation: dropoffLocation,
    );
  }

  // Emergency method to force stop all location tracking
  Future<void> emergencyStopLocationTracking(String userId) async {
    try {
      await _liveLocationService.stopLocationSharing();
      await _liveLocationService.clearLocationData(userId);
      _etaService.stopAllETATracking();
      _logger.i('Emergency location tracking stop for user: $userId');
    } catch (e) {
      _logger.e('Error in emergency stop: $e');
    }
  }

  /// Calculate straight-line distance between two points as fallback
  double _calculateStraightLineDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  // Generate verification code for a ride if it doesn't already have one
  Future<void> _generateVerificationCodeIfNeeded(String rideId) async {
    try {
      final ride = await getRideOffer(rideId);
      if (ride == null) return;

      // Only generate code if ride has passengers and doesn't already have a valid code
      if (ride.passengerIds.isNotEmpty && 
          (ride.verificationCode == null || 
           VerificationCodeUtils.isCodeExpired(ride.codeExpiresAt))) {
        
        final newCode = VerificationCodeUtils.generateCode();
        final expiresAt = VerificationCodeUtils.getExpirationTime();
        
        await updateRideOffer(rideId, {
          'verificationCode': newCode,
          'codeExpiresAt': Timestamp.fromDate(expiresAt),
        });
        
        _logger.i('Generated verification code $newCode for ride $rideId');
      }
    } catch (e) {
      _logger.e('Error generating verification code: $e');
    }
  }

  // Get or generate verification code for a ride
  Future<String?> getVerificationCode(String rideId) async {
    try {
      final ride = await getRideOffer(rideId);
      if (ride == null) return null;

      // Check if existing code is valid
      if (ride.verificationCode != null && 
          !VerificationCodeUtils.isCodeExpired(ride.codeExpiresAt)) {
        return ride.verificationCode;
      }

      // Generate new code if needed and ride has passengers
      if (ride.passengerIds.isNotEmpty) {
        await _generateVerificationCodeIfNeeded(rideId);
        final updatedRide = await getRideOffer(rideId);
        return updatedRide?.verificationCode;
      }

      return null;
    } catch (e) {
      _logger.e('Error getting verification code: $e');
      return null;
    }
  }

  // Clear verification code when ride is completed or cancelled
  Future<void> clearVerificationCode(String rideId) async {
    try {
      await updateRideOffer(rideId, {
        'verificationCode': null,
        'codeExpiresAt': null,
      });
      _logger.i('Cleared verification code for ride $rideId');
    } catch (e) {
      _logger.e('Error clearing verification code: $e');
    }
  }
}
