import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import '../models/ride_model.dart';
import '../models/ride_search_result.dart';
import '../services/ride_service.dart';
import '../services/directions_service.dart';

class RideProvider with ChangeNotifier {
  final RideService _rideService = RideService();
  final DirectionsService _directionsService = DirectionsService();
  final Logger _logger = Logger();

  // Helper to get current user ID
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  
  // Public getter for backward compatibility
  String? get currentUserId => _currentUserId;

  // Ride offers state
  List<RideOffer> _rideOffers = [];
  List<RideOffer> _myRideOffers = [];
  bool _isLoadingOffers = false;
  String? _offersError;
  bool _isSearchingOffers = false;
  List<RideSearchResult> _rideSearchResults = [];
  String? _rideSearchError;
  bool _isArchivingExpired = false;

  // Ride requests state
  List<RideRequest> _rideRequests = [];
  List<RideRequest> _myRideRequests = [];
  List<RideRequest> _driverPendingRequests = [];
  bool _isLoadingRequests = false;
  String? _requestsError;

  // Selected ride state
  RideOffer? _selectedRideOffer;
  RideRequest? _selectedRideRequest;

  // Form state for creating rides
  bool _isCreatingOffer = false;
  bool _isCreatingRequest = false;
  String? _creationError;
  
  // Update state
  bool _isUpdatingRequest = false;
  String? _updateError;

  // Stream subscriptions for cleanup
  StreamSubscription<List<RideOffer>>? _rideOffersSubscription;
  StreamSubscription<List<RideRequest>>? _rideRequestsSubscription;

  // Getters
  List<RideOffer> get rideOffers => _rideOffers;
  List<RideOffer> get myRideOffers => _myRideOffers;
  bool get isLoadingOffers => _isLoadingOffers;
  String? get offersError => _offersError;
  bool get isSearchingOffers => _isSearchingOffers;
  List<RideSearchResult> get rideSearchResults => _rideSearchResults;
  String? get rideSearchError => _rideSearchError;

  List<RideRequest> get rideRequests => _rideRequests;
  List<RideRequest> get myRideRequests => _myRideRequests;
  List<RideRequest> get driverPendingRequests => _driverPendingRequests;
  bool get isLoadingRequests => _isLoadingRequests;
  String? get requestsError => _requestsError;

  RideOffer? get selectedRideOffer => _selectedRideOffer;
  RideRequest? get selectedRideRequest => _selectedRideRequest;

  bool get isCreatingOffer => _isCreatingOffer;
  bool get isCreatingRequest => _isCreatingRequest;
  String? get creationError => _creationError;
  
  bool get isUpdatingRequest => _isUpdatingRequest;
  String? get updateError => _updateError;

  Future<void> _archiveExpiredTrips() async {
    if (_isArchivingExpired) return;
    _isArchivingExpired = true;
    try {
      await _rideService.archiveExpiredTripsForUser();
    } catch (e) {
      _logger.w('Auto-archive expired rides failed: $e');
    } finally {
      _isArchivingExpired = false;
    }
  }

  // Load all active ride offers
  Future<void> loadRideOffers({
    RideStatus? status,
    DateTime? departureAfter,
    DateTime? departureBefore,
  }) async {
    try {
      await _archiveExpiredTrips();
      _isLoadingOffers = true;
      _offersError = null;
      notifyListeners();

      final offers = await _rideService.getRideOffers(
        status: status ?? RideStatus.active,
        departureAfter: departureAfter,
        departureBefore: departureBefore,
      );

      _rideOffers = offers;
      _logger.i('Loaded ${offers.length} ride offers');
    } catch (e) {
      _offersError = 'Failed to load ride offers: $e';
      _logger.e('Error loading ride offers: $e');
    } finally {
      _isLoadingOffers = false;
      notifyListeners();
    }
  }

  Future<List<RideSearchResult>> searchRideOffers({
    required RideLocation pickup,
    required RideLocation dropoff,
    required DateTime departureTime,
    Duration flexibility = const Duration(minutes: 45),
    int seatsNeeded = 1,
    double? maxPricePerSeat,
    int limit = 5,
  }) async {
    try {
      await _archiveExpiredTrips();
      _isSearchingOffers = true;
      _rideSearchError = null;
      notifyListeners();

      final offers = await _rideService.getRideOffers(
        status: RideStatus.active,
      );
      final now = DateTime.now();

      final matches = <RideSearchResult>[];
      for (final ride in offers) {
        if (ride.isArchived) continue;
        if (ride.departureTime.isBefore(now)) continue;
        if (ride.availableSeats < seatsNeeded) continue;
        if (maxPricePerSeat != null && ride.pricePerSeat > maxPricePerSeat) continue;

        // Calculate route-based matching instead of exact destination matching
        final routeMatch = await _calculateRouteBasedMatch(
          pickup,
          dropoff,
          ride,
        );

        if (routeMatch == null) continue; // Skip if route calculation fails

        final timeDeltaMinutes =
            ride.departureTime.difference(departureTime).inMinutes.abs();

        final score = _calculateRouteBasedScore(
          routeMatch.pickupDetourKm,
          routeMatch.dropoffDetourKm,
          routeMatch.totalDetourKm,
          timeDeltaMinutes,
          ride.pricePerSeat,
          maxPricePerSeat,
        );

        final quality = _calculateRouteBasedQuality(
          routeMatch.pickupDetourKm,
          routeMatch.dropoffDetourKm,
          routeMatch.totalDetourKm,
          timeDeltaMinutes,
        );

        matches.add(RideSearchResult(
          offer: ride,
          pickupDistanceKm: routeMatch.pickupDetourKm,
          dropoffDistanceKm: routeMatch.dropoffDetourKm,
          departureDeltaMinutes: timeDeltaMinutes,
          score: score,
          qualityScore: quality,
        ));
      }

      matches.sort((a, b) => a.score.compareTo(b.score));

      _rideSearchResults = matches.take(limit).toList();
      return _rideSearchResults;
    } catch (e) {
      _rideSearchError = 'Failed to search ride offers: $e';
      _logger.e('Error searching ride offers: $e');
      return [];
    } finally {
      _isSearchingOffers = false;
      notifyListeners();
    }
  }

  Future<RideOffer?> getRideOfferById(String rideId) async {
    try {
      return await _rideService.getRideOffer(rideId);
    } catch (e) {
      _logger.e('Error fetching ride offer $rideId: $e');
      return null;
    }
  }

  Future<List<RideRequest>> getAcceptedRequestsForRide(String rideId) async {
    try {
      return await _rideService.getRideRequestsForOffer(
        rideId,
        status: RequestStatus.accepted,
      );
    } catch (e) {
      _logger.e('Error loading accepted requests for ride $rideId: $e');
      return [];
    }
  }

  // Load user's own ride offers
  Future<void> loadMyRideOffers() async {
    if (_currentUserId == null) return;

    try {
      await _archiveExpiredTrips();
      _isLoadingOffers = true;
      _offersError = null;
      notifyListeners();

      final offers = await _rideService.getRideOffers(
        driverId: _currentUserId!,
      );

      _myRideOffers = offers.where((ride) =>
          ride.status == RideStatus.active ||
          ride.status == RideStatus.full ||
          ride.status == RideStatus.inProgress).toList();

      _logger.i('Loaded ${_myRideOffers.length} active driver ride offers');
    } catch (e) {
      _offersError = 'Failed to load your ride offers: $e';
      _logger.e('Error loading user ride offers: $e');
    } finally {
      _isLoadingOffers = false;
      notifyListeners();
    }
  }

  void removeRideFromMyOffers(String rideId) {
    final initialLength = _myRideOffers.length;
    _myRideOffers = _myRideOffers.where((ride) => ride.id != rideId).toList();
    if (_myRideOffers.length != initialLength) {
      notifyListeners();
    }
  }

  // Load all ride requests
  Future<void> loadRideRequests({
    RequestStatus? status,
    DateTime? departureAfter,
    DateTime? departureBefore,
  }) async {
    try {
      await _archiveExpiredTrips();
      _isLoadingRequests = true;
      _requestsError = null;
      notifyListeners();

      final requests = await _rideService.getRideRequests(
        status: status ?? RequestStatus.pending,
        departureAfter: departureAfter,
        departureBefore: departureBefore,
      );

      _rideRequests = requests;
      _logger.i('Loaded ${requests.length} ride requests');
    } catch (e) {
      _requestsError = 'Failed to load ride requests: $e';
      _logger.e('Error loading ride requests: $e');
    } finally {
      _isLoadingRequests = false;
      notifyListeners();
    }
  }

  // Load user's own ride requests
  Future<void> loadMyRideRequests() async {
    if (_currentUserId == null) return;

    try {
      await _archiveExpiredTrips();
      _isLoadingRequests = true;
      _requestsError = null;
      notifyListeners();

      final requests = await _rideService.getRideRequests(
        requesterId: _currentUserId!,
      );

      _myRideRequests = requests;
      _logger.i('Loaded ${requests.length} user ride requests');
    } catch (e) {
      _requestsError = 'Failed to load your ride requests: $e';
      _logger.e('Error loading user ride requests: $e');
    } finally {
      _isLoadingRequests = false;
      notifyListeners();
    }
  }

  // Create a new ride offer
  Future<bool> createRideOffer(RideOffer rideOffer) async {
    if (_currentUserId == null) {
      _creationError = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      _isCreatingOffer = true;
      _creationError = null;
      notifyListeners();

      final rideId = await _rideService.createRideOffer(rideOffer);
      
      if (rideId != null) {
        _logger.i('Created ride offer with ID: $rideId');
        
        // Refresh user's ride offers
        await loadMyRideOffers();
        
        return true;
      } else {
        _creationError = 'Failed to create ride offer';
        return false;
      }
    } catch (e) {
      _creationError = 'Error creating ride offer: $e';
      _logger.e('Error creating ride offer: $e');
      return false;
    } finally {
      _isCreatingOffer = false;
      notifyListeners();
    }
  }

  // Create a new ride request
  Future<bool> createRideRequest(RideRequest rideRequest) async {
    if (_currentUserId == null) {
      _creationError = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      _isCreatingRequest = true;
      _creationError = null;
      notifyListeners();

      final requestId = await _rideService.createRideRequest(rideRequest);
      
      if (requestId != null) {
        _logger.i('Created ride request with ID: $requestId');
        
        // Refresh user's ride requests
        await loadMyRideRequests();
        
        return true;
      } else {
        _creationError = 'Failed to create ride request';
        return false;
      }
    } catch (e) {
      _creationError = 'Error creating ride request: $e';
      _logger.e('Error creating ride request: $e');
      return false;
    } finally {
      _isCreatingRequest = false;
      notifyListeners();
    }
  }

  // Update a ride request
  Future<bool> updateRideRequest(RideRequest rideRequest) async {
    if (_currentUserId == null) {
      _updateError = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      _isUpdatingRequest = true;
      _updateError = null;
      notifyListeners();

      await _rideService.updateRideRequest(rideRequest.id, rideRequest.toMap());
      
      _logger.i('Updated ride request with ID: ${rideRequest.id}');
      
      // Refresh user's ride requests
      await loadMyRideRequests();
      
      return true;
    } catch (e) {
      _updateError = 'Error updating ride request: $e';
      _logger.e('Error updating ride request: $e');
      return false;
    } finally {
      _isUpdatingRequest = false;
      notifyListeners();
    }
  }

  // Join a ride offer
  Future<bool> joinRide(
    String rideId, {
    double? seatPrice,
    RideLocation? pickupLocation,
    RideLocation? dropoffLocation,
    int seatsRequested = 1,
  }) async {
    if (_currentUserId == null) {
      _creationError = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      await _rideService.joinRide(
        rideId,
        _currentUserId!,
        seatPrice: seatPrice,
        pickupLocation: pickupLocation,
        dropoffLocation: dropoffLocation,
        seatsRequested: seatsRequested,
      );
      
      // Refresh ride offers to show updated availability
      await loadRideOffers();
      
      _logger.i('Successfully joined ride: $rideId');
      return true;
    } catch (e) {
      _creationError = 'Failed to join ride: $e';
      _logger.e('Error joining ride: $e');
      notifyListeners();
      return false;
    }
  }

  // Leave a ride offer
  Future<bool> leaveRide(String rideId) async {
    if (_currentUserId == null) {
      _creationError = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      await _rideService.leaveRide(rideId, _currentUserId!);
      
      // Refresh ride offers to show updated availability
      await loadRideOffers();
      
      _logger.i('Successfully left ride: $rideId');
      return true;
    } catch (e) {
      _creationError = 'Failed to leave ride: $e';
      _logger.e('Error leaving ride: $e');
      notifyListeners();
      return false;
    }
  }

  // Cancel ride offer
  Future<bool> cancelRideOffer(String rideId) async {
    try {
      await _rideService.cancelRideOffer(rideId);
      
      // Refresh user's ride offers
      await loadMyRideOffers();
      
      _logger.i('Successfully cancelled ride offer: $rideId');
      return true;
    } catch (e) {
      _creationError = 'Failed to cancel ride offer: $e';
      _logger.e('Error cancelling ride offer: $e');
      notifyListeners();
      return false;
    }
  }

  // Cancel ride request
  Future<bool> cancelRideRequest(String requestId) async {
    try {
      await _rideService.cancelRideRequest(requestId);
      
      // Refresh user's ride requests
      await loadMyRideRequests();
      
      _logger.i('Successfully cancelled ride request: $requestId');
      return true;
    } catch (e) {
      _creationError = 'Failed to cancel ride request: $e';
      _logger.e('Error cancelling ride request: $e');
      notifyListeners();
      return false;
    }
  }

  // Set selected ride offer
  void setSelectedRideOffer(RideOffer? rideOffer) {
    _selectedRideOffer = rideOffer;
    notifyListeners();
  }

  // Set selected ride request
  void setSelectedRideRequest(RideRequest? rideRequest) {
    _selectedRideRequest = rideRequest;
    notifyListeners();
  }

  // Archive a ride offer
  Future<bool> archiveRideOffer(String rideId) async {
    try {
      await _rideService.archiveRideOffer(rideId);
      
      // Refresh user's ride offers
      await loadMyRideOffers();
      
      _logger.i('Successfully archived ride offer: $rideId');
      return true;
    } catch (e) {
      _creationError = 'Failed to archive ride offer: $e';
      _logger.e('Error archiving ride offer: $e');
      notifyListeners();
      return false;
    }
  }

  // Unarchive a ride offer
  Future<bool> unarchiveRideOffer(String rideId) async {
    try {
      await _rideService.unarchiveRideOffer(rideId);
      
      // Refresh user's ride offers
      await loadMyRideOffers();
      
      _logger.i('Successfully unarchived ride offer: $rideId');
      return true;
    } catch (e) {
      _creationError = 'Failed to unarchive ride offer: $e';
      _logger.e('Error unarchiving ride offer: $e');
      notifyListeners();
      return false;
    }
  }

  // Archive a ride request
  Future<bool> archiveRideRequest(String requestId) async {
    try {
      await _rideService.archiveRideRequest(requestId);
      
      // Refresh user's ride requests
      await loadMyRideRequests();
      
      _logger.i('Successfully archived ride request: $requestId');
      return true;
    } catch (e) {
      _updateError = 'Failed to archive ride request: $e';
      _logger.e('Error archiving ride request: $e');
      notifyListeners();
      return false;
    }
  }

  // Unarchive a ride request
  Future<bool> unarchiveRideRequest(String requestId) async {
    try {
      await _rideService.unarchiveRideRequest(requestId);
      
      // Refresh user's ride requests
      await loadMyRideRequests();
      
      _logger.i('Successfully unarchived ride request: $requestId');
      return true;
    } catch (e) {
      _updateError = 'Failed to unarchive ride request: $e';
      _logger.e('Error unarchiving ride request: $e');
      notifyListeners();
      return false;
    }
  }

  // Get history ride offers (completed/cancelled, non-archived)
  Future<List<RideOffer>> getHistoryRideOffers({bool includeArchived = false}) async {
    if (_currentUserId == null) return [];
    
    try {
      return await _rideService.getHistoryRideOffers(_currentUserId!, includeArchived: includeArchived);
    } catch (e) {
      _logger.e('Error getting history ride offers: $e');
      return [];
    }
  }

  // Get history ride requests (completed/cancelled, non-archived)
  Future<List<RideRequest>> getHistoryRideRequests({bool includeArchived = false}) async {
    if (_currentUserId == null) return [];
    
    try {
      return await _rideService.getHistoryRideRequests(_currentUserId!, includeArchived: includeArchived);
    } catch (e) {
      _logger.e('Error getting history ride requests: $e');
      return [];
    }
  }

  // Get archived ride offers
  Future<List<RideOffer>> getArchivedRideOffers() async {
    if (_currentUserId == null) return [];
    
    try {
      return await _rideService.getArchivedRideOffers(_currentUserId!);
    } catch (e) {
      _logger.e('Error getting archived ride offers: $e');
      return [];
    }
  }

  // Get archived ride requests
  Future<List<RideRequest>> getArchivedRideRequests() async {
    if (_currentUserId == null) return [];
    
    try {
      return await _rideService.getArchivedRideRequests(_currentUserId!);
    } catch (e) {
      _logger.e('Error getting archived ride requests: $e');
      return [];
    }
  }

  // Clear errors
  void clearErrors() {
    _offersError = null;
    _requestsError = null;
    _creationError = null;
    _updateError = null;
    notifyListeners();
  }

  // Filter rides by departure time
  List<RideOffer> filterRidesByTime(List<RideOffer> rides, DateTime startTime, DateTime endTime) {
    return rides.where((ride) {
      return ride.departureTime.isAfter(startTime) && 
             ride.departureTime.isBefore(endTime);
    }).toList();
  }

  // Filter rides by available seats
  List<RideOffer> filterRidesBySeats(List<RideOffer> rides, int minSeats) {
    return rides.where((ride) => ride.availableSeats >= minSeats).toList();
  }

  // Filter rides by price range
  List<RideOffer> filterRidesByPrice(List<RideOffer> rides, double maxPrice) {
    return rides.where((ride) => ride.pricePerSeat <= maxPrice).toList();
  }

  // Get user's role in a specific ride
  String getUserRoleInRide(RideOffer ride) {
    if (_currentUserId == null) return 'none';
    
    if (ride.driverId == _currentUserId) {
      return 'driver';
    } else if (ride.passengerIds.contains(_currentUserId)) {
      return 'passenger';
    } else {
      return 'none';
    }
  }

  // Check if user can join a ride
  bool canJoinRide(RideOffer ride) {
    if (_currentUserId == null) return false;
    
    // Can't join own ride
    if (ride.driverId == _currentUserId) return false;
    
    // Can't join if already a passenger
    if (ride.passengerIds.contains(_currentUserId)) return false;
    
    // Can't join if no available seats
    if (ride.availableSeats <= 0) return false;
    
    // Can't join if ride is not active
    if (ride.status != RideStatus.active) return false;
    
    return true;
  }

  // Refresh all data
  Future<void> refreshAll() async {
    await Future.wait([
      loadRideOffers(),
      loadMyRideOffers(),
      loadRideRequests(),
      loadMyRideRequests(),
    ]);
  }

  // Load pending requests for driver's rides
  Future<void> loadDriverPendingRequests(String driverId) async {
    try {
      await _archiveExpiredTrips();
      _isLoadingRequests = true;
      _requestsError = null;
      notifyListeners();

      final requests = await _rideService.getDriverPendingRequests(driverId);
      _driverPendingRequests = requests;
      _logger.i('Loaded ${requests.length} pending requests for driver');
    } catch (e) {
      _requestsError = 'Failed to load pending requests: $e';
      _logger.e('Error loading driver pending requests: $e');
    } finally {
      _isLoadingRequests = false;
      notifyListeners();
    }
  }

  // Accept a ride request
  Future<bool> acceptRideRequest(String requestId) async {
    try {
      await _rideService.acceptRideRequest(requestId);
      _logger.i('Successfully accepted ride request: $requestId');
      
      // Reload driver requests to update the list
      if (_currentUserId != null) {
        await loadDriverPendingRequests(_currentUserId!);
      }
      
      return true;
    } catch (e) {
      _requestsError = 'Failed to accept ride request: $e';
      _logger.e('Error accepting ride request: $e');
      notifyListeners();
      return false;
    }
  }

  // Decline a ride request
  Future<bool> declineRideRequest(String requestId) async {
    try {
      await _rideService.declineRideRequest(requestId);
      _logger.i('Successfully declined ride request: $requestId');
      
      // Reload driver requests to update the list
      if (_currentUserId != null) {
        await loadDriverPendingRequests(_currentUserId!);
      }
      
      return true;
    } catch (e) {
      _requestsError = 'Failed to decline ride request: $e';
      _logger.e('Error declining ride request: $e');
      notifyListeners();
      return false;
    }
  }

  // Setup real-time listeners for user's rides
  void setupUserRideListeners() {
    if (_currentUserId == null) return;

    // Cancel existing subscriptions before creating new ones
    _rideOffersSubscription?.cancel();
    _rideRequestsSubscription?.cancel();

    // Listen to user's ride offers
    _rideOffersSubscription = _rideService.getRideOffersStream(driverId: _currentUserId!).listen(
      (offers) {
        _myRideOffers = offers;
        notifyListeners();
      },
      onError: (error) {
        _offersError = 'Real-time update failed: $error';
        notifyListeners();
      },
    );

    // Listen to user's ride requests
    _rideRequestsSubscription = _rideService.getRideRequestsStream(requesterId: _currentUserId!).listen(
      (requests) {
        _myRideRequests = requests;
        notifyListeners();
      },
      onError: (error) {
        _requestsError = 'Real-time update failed: $error';
        notifyListeners();
      },
    );
  }

  // Cleanup method to cancel all stream subscriptions
  void cancelAllSubscriptions() {
    _logger.d('Cancelling all ride stream subscriptions');
    _rideOffersSubscription?.cancel();
    _rideRequestsSubscription?.cancel();
    _rideOffersSubscription = null;
    _rideRequestsSubscription = null;

    _rideOffers = [];
    _myRideOffers = [];
    _rideRequests = [];
    _myRideRequests = [];
    _driverPendingRequests = [];
    _selectedRideOffer = null;
    _selectedRideRequest = null;
    _offersError = null;
    _requestsError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    cancelAllSubscriptions();
    super.dispose();
  }

  // Route-based matching methods
  Future<RouteBasedMatch?> _calculateRouteBasedMatch(
    RideLocation pickup,
    RideLocation dropoff,
    RideOffer ride,
  ) async {
    try {
      // Get original route distance and time
      final originalRoute = await _directionsService.getDirections(
        origin: ride.startLocation.coordinates,
        destination: ride.endLocation.coordinates,
      );
      
      if (originalRoute == null) {
        // Fallback to straight-line distance
        return RouteBasedMatch(
          pickupDetourKm: _distanceBetweenKm(pickup, ride.startLocation),
          dropoffDetourKm: _distanceBetweenKm(dropoff, ride.endLocation),
          totalDetourKm: _distanceBetweenKm(pickup, ride.startLocation) + _distanceBetweenKm(dropoff, ride.endLocation),
          originalRouteKm: _distanceBetweenKm(ride.startLocation, ride.endLocation),
        );
      }

      // Get route with detour (start -> pickup -> dropoff -> destination)
      final detourRoute1 = await _directionsService.getDirections(
        origin: ride.startLocation.coordinates,
        destination: pickup.coordinates,
      );
      
      final detourRoute2 = await _directionsService.getDirections(
        origin: pickup.coordinates,
        destination: dropoff.coordinates,
      );
      
      final detourRoute3 = await _directionsService.getDirections(
        origin: dropoff.coordinates,
        destination: ride.endLocation.coordinates,
      );

      if (detourRoute1 == null || detourRoute2 == null || detourRoute3 == null) {
        // Fallback to approximation
        return RouteBasedMatch(
          pickupDetourKm: _distanceBetweenKm(pickup, ride.startLocation),
          dropoffDetourKm: _distanceBetweenKm(dropoff, ride.endLocation),
          totalDetourKm: _distanceBetweenKm(pickup, ride.startLocation) + _distanceBetweenKm(dropoff, ride.endLocation),
          originalRouteKm: _distanceBetweenKm(ride.startLocation, ride.endLocation),
        );
      }

      final originalKm = _parseDistanceToKm(originalRoute.totalDistance);
      final detourTotalKm = _parseDistanceToKm(detourRoute1.totalDistance) + 
                           _parseDistanceToKm(detourRoute2.totalDistance) + 
                           _parseDistanceToKm(detourRoute3.totalDistance);
      
      final totalDetourKm = detourTotalKm - originalKm;
      
      // Calculate how far pickup is from original route
      final pickupDetourKm = _calculatePointToRouteDistance(pickup.coordinates, originalRoute);
      
      // Calculate how far dropoff is from original route
      final dropoffDetourKm = _calculatePointToRouteDistance(dropoff.coordinates, originalRoute);

      return RouteBasedMatch(
        pickupDetourKm: pickupDetourKm,
        dropoffDetourKm: dropoffDetourKm,
        totalDetourKm: totalDetourKm.abs(),
        originalRouteKm: originalKm,
      );
    } catch (e) {
      _logger.w('Route calculation failed, using fallback: $e');
      // Fallback to straight-line distance
      return RouteBasedMatch(
        pickupDetourKm: _distanceBetweenKm(pickup, ride.startLocation),
        dropoffDetourKm: _distanceBetweenKm(dropoff, ride.endLocation),
        totalDetourKm: _distanceBetweenKm(pickup, ride.startLocation) + _distanceBetweenKm(dropoff, ride.endLocation),
        originalRouteKm: _distanceBetweenKm(ride.startLocation, ride.endLocation),
      );
    }
  }

  double _parseDistanceToKm(String distanceString) {
    final normalized = distanceString.toLowerCase().trim();
    final numberRegex = RegExp(r'(\d+\.?\d*)');
    final match = numberRegex.firstMatch(normalized);
    
    if (match == null) return 0;
    
    final value = double.parse(match.group(1)!);
    
    if (normalized.contains('mi')) {
      return value * 1.60934; // miles to km
    } else if (normalized.contains('km')) {
      return value;
    } else {
      return value / 1000; // assume meters, convert to km
    }
  }

  double _calculatePointToRouteDistance(LatLng point, DirectionsResult route) {
    double minDistance = double.infinity;
    
    // Find the closest point on the route polyline
    for (int i = 0; i < route.polylinePoints.length - 1; i++) {
      final start = route.polylinePoints[i];
      final end = route.polylinePoints[i + 1];
      final distance = _distanceToLineSegment(point, start, end);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance;
  }

  double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final A = point.latitude - lineStart.latitude;
    final B = point.longitude - lineStart.longitude;
    final C = lineEnd.latitude - lineStart.latitude;
    final D = lineEnd.longitude - lineStart.longitude;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    
    if (lenSq == 0) {
      // Line segment is actually a point
      return _distanceBetweenKm(
        RideLocation(coordinates: point, address: ''),
        RideLocation(coordinates: lineStart, address: ''),
      );
    }

    double param = dot / lenSq;
    param = math.max(0, math.min(1, param)); // Clamp to [0, 1]

    final xx = lineStart.latitude + param * C;
    final yy = lineStart.longitude + param * D;

    return _distanceBetweenKm(
      RideLocation(coordinates: point, address: ''),
      RideLocation(coordinates: LatLng(xx, yy), address: ''),
    );
  }

  double _calculateRouteBasedScore(
    double pickupDetourKm,
    double dropoffDetourKm,
    double totalDetourKm,
    int timeDeltaMinutes,
    double pricePerSeat,
    double? maxPricePerSeat,
  ) {
    // Weights for route-based scoring (lower scores are better)
    const double pickupDetourWeight = 1.5;   // Important but more lenient
    const double dropoffDetourWeight = 1.0;  // Moderate - dropoff can be further
    const double totalDetourWeight = 2.0;    // Important but more reasonable
    const double timeWeight = 0.5;           // Time less critical for long trips
    const double priceWeight = 0.3;          // Price is least important

    // More reasonable exponential penalty thresholds
    double pickupScore = pickupDetourKm <= 5.0 
        ? pickupDetourKm * pickupDetourWeight
        : (pickupDetourKm * 1.2) * pickupDetourWeight; // Gentler penalty

    double dropoffScore = dropoffDetourKm <= 8.0
        ? dropoffDetourKm * dropoffDetourWeight
        : (dropoffDetourKm * 1.3) * dropoffDetourWeight; // Gentler penalty

    double totalDetourScore = totalDetourKm <= 10.0
        ? totalDetourKm * totalDetourWeight
        : (totalDetourKm * 1.5) * totalDetourWeight; // Much gentler penalty

    // More reasonable time scoring - especially for long trips
    double timeScore = timeDeltaMinutes <= 60
        ? (timeDeltaMinutes / 60) * timeWeight
        : (math.sqrt(timeDeltaMinutes / 60)) * timeWeight; // Square root instead of exponential

    // Price scoring
    double priceScore = 0;
    if (maxPricePerSeat != null) {
      double priceRatio = pricePerSeat / maxPricePerSeat;
      priceScore = priceRatio <= 0.8 
          ? -0.3  // Smaller bonus for good value
          : (priceRatio - 0.8) * priceWeight;
    } else {
      priceScore = pricePerSeat / 150 * priceWeight; // More lenient price normalization
    }

    return pickupScore + dropoffScore + totalDetourScore + timeScore + priceScore;
  }

  int _calculateRouteBasedQuality(
    double pickupDetourKm,
    double dropoffDetourKm,
    double totalDetourKm,
    int timeDeltaMinutes,
  ) {
    int score = 100;

    // More reasonable pickup detour thresholds
    if (pickupDetourKm > 8.0) {
      score -= 30;
    } else if (pickupDetourKm > 5.0) {
      score -= 20;
    } else if (pickupDetourKm > 3.0) {
      score -= 10;
    }

    // More reasonable dropoff detour thresholds
    if (dropoffDetourKm > 12.0) {
      score -= 25;
    } else if (dropoffDetourKm > 8.0) {
      score -= 15;
    } else if (dropoffDetourKm > 5.0) {
      score -= 8;
    }

    // Total detour penalty - much more lenient for longer trips
    if (totalDetourKm > 20.0) {
      score -= 40;
    } else if (totalDetourKm > 15.0) {
      score -= 25;
    } else if (totalDetourKm > 10.0) {
      score -= 15;
    } else if (totalDetourKm > 5.0) {
      score -= 8;
    }

    // More reasonable time penalty - 8 minutes on 2 hour drive should be fine
    if (timeDeltaMinutes > 180) { // 3 hours
      score -= 15;
    } else if (timeDeltaMinutes > 120) { // 2 hours
      score -= 8;
    } else if (timeDeltaMinutes > 60) { // 1 hour
      score -= 5;
    }

    return math.max(0, score);
  }

  double _distanceBetweenKm(RideLocation a, RideLocation b) {
    const double earthRadius = 6371;
    final lat1 = _toRadians(a.coordinates.latitude);
    final lat2 = _toRadians(b.coordinates.latitude);
    final deltaLat = _toRadians(b.coordinates.latitude - a.coordinates.latitude);
    final deltaLng = _toRadians(b.coordinates.longitude - a.coordinates.longitude);

    final sinHalfLat = math.sin(deltaLat / 2);
    final sinHalfLng = math.sin(deltaLng / 2);

    final haversine = sinHalfLat * sinHalfLat +
        math.cos(lat1) * math.cos(lat2) * sinHalfLng * sinHalfLng;
    final c = 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
    return earthRadius * c;
  }



  double _toRadians(double degrees) => degrees * (math.pi / 180);
}

class RouteBasedMatch {
  final double pickupDetourKm;
  final double dropoffDetourKm;
  final double totalDetourKm;
  final double originalRouteKm;

  const RouteBasedMatch({
    required this.pickupDetourKm,
    required this.dropoffDetourKm,
    required this.totalDetourKm,
    required this.originalRouteKm,
  });
}
