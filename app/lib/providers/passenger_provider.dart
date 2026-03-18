import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../services/ride_service.dart';
import '../services/rating_service.dart';
import '../services/live_location_service.dart';
import '../services/eta_service.dart';
import '../services/message_service.dart';
import '../models/message_model.dart';
import '../services/passenger_service.dart';

enum PassengerRideState {
  noRide,
  requestPending,
  matched,
  driverEnRoute,
  driverArrived,
  inRide,
  completed,
  cancelled,
}

class PassengerRideInfo {
  final RideRequest request;
  final RideOffer? ride;
  final UserModel? driver;
  final PassengerRideState state;
  final PickupStatus pickupStatus;
  final LatLng? driverLocation;
  final ETAUpdate? pickupETA;
  final ETAUpdate? dropoffETA;
  final String? statusMessage;
  final DateTime lastUpdate;

  PassengerRideInfo({
    required this.request,
    this.ride,
    this.driver,
    required this.state,
    required this.pickupStatus,
    this.driverLocation,
    this.pickupETA,
    this.dropoffETA,
    this.statusMessage,
    required this.lastUpdate,
  });
}

class PassengerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RideService _rideService = RideService();
  final RatingService _ratingService = RatingService();
  final LiveLocationService _liveLocationService = LiveLocationService();
  final ETAService _etaService = ETAService();
  final MessageService _messageService = MessageService();
  final PassengerService _passengerService = PassengerService();
  final Logger _logger = Logger();

  // State
  String? _currentPassengerId;
  PassengerRideInfo? _currentRideInfo;
  bool _isLoading = false;
  String? _errorMessage;
  List<RideOffer> _availableRides = [];

  // Real-time subscriptions
  StreamSubscription? _rideSubscription;
  StreamSubscription? _driverLocationSubscription;
  StreamSubscription? _rideOffersSubscription;
  Timer? _etaUpdateTimer;
  
  // Stream management state
  String? _monitoredRideId;
  bool _isMonitoringAvailableRides = false;

  // Getters
  PassengerRideInfo? get currentRideInfo => _currentRideInfo;
  bool get hasActiveRide => _currentRideInfo != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<RideOffer> get availableRides => _availableRides;
  PassengerRideState get currentState => _currentRideInfo?.state ?? PassengerRideState.noRide;
  bool get canContactDriver => _currentRideInfo?.driver != null && 
      (_currentRideInfo!.state == PassengerRideState.driverEnRoute ||
       _currentRideInfo!.state == PassengerRideState.driverArrived ||
       _currentRideInfo!.state == PassengerRideState.inRide);

  /// Initialize passenger provider
  Future<void> initialize(String passengerId) async {
    try {
      _isLoading = true;
      _currentPassengerId = passengerId;
      // Defer notification to prevent setState during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });

      // Check for existing active rides
      await _checkExistingRides();

      // Start monitoring available rides if no active ride
      if (!hasActiveRide) {
        await _startAvailableRidesMonitoring();
      }

      _isLoading = false;
      _errorMessage = null;
      
      // Defer final notification to prevent setState during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });

      _logger.i('Passenger provider initialized for: $passengerId');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to initialize: $e';
      
      // Defer error notification to prevent setState during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      _logger.e('Error initializing passenger provider: $e');
    }
  }

  /// Request a ride
  Future<void> requestRide(RideRequest request) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Create the ride request
      await _rideService.createRideRequest(request);

      // Update current ride info
      _currentRideInfo = PassengerRideInfo(
        request: request,
        state: PassengerRideState.requestPending,
        pickupStatus: PickupStatus.pending,
        lastUpdate: DateTime.now(),
      );

      // Start monitoring for matches
      await _startRideMonitoring(request.id);

      _isLoading = false;
      notifyListeners();

      _logger.i('Ride requested: ${request.id}');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to request ride: $e';
      notifyListeners();
      _logger.e('Error requesting ride: $e');
    }
  }

  /// Cancel ride request
  Future<void> cancelRideRequest() async {
    if (_currentRideInfo == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      await _rideService.cancelRideRequest(_currentRideInfo!.request.id);
      await _stopAllMonitoring();

      _currentRideInfo = null;
      await _startAvailableRidesMonitoring();

      _isLoading = false;
      notifyListeners();

      _logger.i('Ride request cancelled');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to cancel ride: $e';
      notifyListeners();
      _logger.e('Error cancelling ride: $e');
    }
  }

  /// Rate the driver
  /// Check if the current passenger has already rated the current ride
  Future<bool> hasRatedCurrentRide() async {
    if (_currentRideInfo?.ride == null || _currentPassengerId == null) return false;
    
    return await _ratingService.hasUserRatedRide(
      rideId: _currentRideInfo!.ride!.id,
      reviewerId: _currentPassengerId!,
    );
  }

  /// Get the existing rating for the current ride if it exists
  Future<Map<String, dynamic>?> getCurrentRideRating() async {
    if (_currentRideInfo?.ride == null || _currentPassengerId == null) return null;
    
    return await _ratingService.getUserRatingForRide(
      rideId: _currentRideInfo!.ride!.id,
      reviewerId: _currentPassengerId!,
    );
  }

  Future<void> rateDriver(double rating, String? comment) async {
    if (_currentRideInfo?.driver == null || _currentRideInfo?.ride == null) return;

    try {
      // Double-check for duplicate ratings before submission
      final hasAlreadyRated = await hasRatedCurrentRide();
      if (hasAlreadyRated) {
        final existingRating = await getCurrentRideRating();
        final existingStars = existingRating?['rating'] ?? 0;
        throw Exception('You have already rated this ride with $existingStars star${existingStars != 1 ? 's' : ''}');
      }

      await _ratingService.submitRating(
        rideId: _currentRideInfo!.ride!.id,
        reviewerId: _currentPassengerId!,
        revieweeId: _currentRideInfo!.driver!.uid,
        rating: rating,
        comment: comment,
        reviewerIsDriver: false,
      );
      _logger.i('Successfully submitted driver rating: $rating stars');

      // Ensure the linked ride request is marked completed before archiving
      try {
        await _rideService.markPassengerRideRequestCompleted(
          _currentRideInfo!.ride!.id,
          _currentPassengerId!,
        );
      } catch (e) {
        _logger.w('Unable to mark request completed after rating: $e');
      }

      // Archive the ride request so it falls out of upcoming lists
      final requestId = _currentRideInfo!.request.id;
      if (requestId.isNotEmpty) {
        try {
          await _rideService.archiveRideRequest(requestId);
        } catch (e) {
          _logger.w('Unable to archive ride request $requestId after rating: $e');
        }
      }
      
      // Clear active ride state so ride no longer appears in Active tab/upcoming list
      await _stopAllMonitoring();
      _currentRideInfo = null;
      await _startAvailableRidesMonitoring();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to rate driver: $e';
      notifyListeners();
      _logger.e('Error rating driver: $e');
      rethrow; // Re-throw so the UI can handle the specific error
    }
  }

  /// Contact driver via phone call
  Future<bool> callDriver() async {
    if (_currentRideInfo?.driver?.profile.phoneNumber == null) {
      _errorMessage = 'Driver phone number not available';
      notifyListeners();
      return false;
    }

    try {
      final phoneNumber = _currentRideInfo!.driver!.profile.phoneNumber;
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        _logger.i('Initiated call to driver: $phoneNumber');
        return true;
      } else {
        _errorMessage = 'Cannot launch phone app';
        notifyListeners();
        _logger.e('Cannot launch phone app for: $phoneNumber');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to call driver: $e';
      notifyListeners();
      _logger.e('Error calling driver: $e');
      return false;
    }
  }

  /// Send message to driver via in-app messaging
  Future<bool> messageDriver(String message) async {
    if (_currentRideInfo?.ride == null || _currentPassengerId == null) {
      _errorMessage = 'No active ride to send message';
      notifyListeners();
      return false;
    }

    try {
      final rideId = _currentRideInfo!.ride!.id;
      await _messageService.sendMessage(
        rideId: rideId,
        senderId: _currentPassengerId!,
        content: message,
      );
      
      _logger.i('Message sent to driver: $message');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send message: $e';
      notifyListeners();
      _logger.e('Error sending message: $e');
      return false;
    }
  }

  /// Get messages stream for the current ride
  Stream<List<Message>> getMessagesStream() {
    if (_currentRideInfo?.ride == null) {
      return Stream.value([]);
    }
    
    try {
      return _messageService.getMessagesStream(_currentRideInfo!.ride!.id);
    } catch (e) {
      _logger.e('Error getting messages stream: $e');
      return Stream.value([]);
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead() async {
    if (_currentRideInfo?.ride == null || _currentPassengerId == null) return;
    
    try {
      await _messageService.markMessagesAsRead(
        _currentRideInfo!.ride!.id,
        _currentPassengerId!,
      );
    } catch (e) {
      _logger.e('Error marking messages as read: $e');
    }
  }

  /// Confirm that passenger has boarded the vehicle
  Future<void> confirmBoarded() async {
    if (_currentRideInfo?.ride == null || _currentPassengerId == null) {
      _errorMessage = 'No active ride to confirm boarding';
      notifyListeners();
      return;
    }

    if (_currentRideInfo!.pickupStatus != PickupStatus.driverArrived) {
      _errorMessage = 'Wait for your driver to arrive before confirming';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      await _passengerService.updatePassengerPickupStatus(
        _currentRideInfo!.ride!.id,
        _currentPassengerId!,
        PickupStatus.passengerPickedUp,
      );

      _currentRideInfo = PassengerRideInfo(
        request: _currentRideInfo!.request,
        ride: _currentRideInfo!.ride,
        driver: _currentRideInfo!.driver,
        state: PassengerRideState.inRide,
        pickupStatus: PickupStatus.passengerPickedUp,
        driverLocation: _currentRideInfo!.driverLocation,
        pickupETA: _currentRideInfo!.pickupETA,
        dropoffETA: _currentRideInfo!.dropoffETA,
        statusMessage: 'Enjoying your ride to destination',
        lastUpdate: DateTime.now(),
      );

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();

      _logger.i('Passenger confirmed boarding');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to confirm boarding: $e';
      notifyListeners();
      _logger.e('Error confirming boarding: $e');
      rethrow;
    }
  }

  /// Confirm that passenger has been successfully dropped off
  Future<void> confirmDroppedOff() async {
    if (_currentRideInfo?.ride == null || _currentPassengerId == null) {
      _errorMessage = 'No active ride to confirm dropoff';
      notifyListeners();
      return;
    }

    if (_currentRideInfo!.pickupStatus != PickupStatus.passengerPickedUp) {
      _errorMessage = 'You must be picked up before confirming dropoff';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      await _passengerService.updatePassengerPickupStatus(
        _currentRideInfo!.ride!.id,
        _currentPassengerId!,
        PickupStatus.completed,
      );

      // Ensure request status is updated to completed
      await _rideService.markPassengerRideRequestCompleted(
        _currentRideInfo!.ride!.id,
        _currentPassengerId!,
      );

      // Update local state
      _currentRideInfo = PassengerRideInfo(
        request: _currentRideInfo!.request,
        ride: _currentRideInfo!.ride,
        driver: _currentRideInfo!.driver,
        state: PassengerRideState.completed,
        pickupStatus: PickupStatus.completed,
        driverLocation: _currentRideInfo!.driverLocation,
        pickupETA: _currentRideInfo!.pickupETA,
        dropoffETA: _currentRideInfo!.dropoffETA,
        statusMessage: 'Ride completed successfully',
        lastUpdate: DateTime.now(),
      );

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();

      _logger.i('Passenger confirmed dropoff');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to confirm dropoff: $e';
      notifyListeners();
      _logger.e('Error confirming dropoff: $e');
      rethrow;
    }
  }

  /// Check for existing active rides
  Future<void> _checkExistingRides() async {
    if (_currentPassengerId == null) return;

    try {
      // First, check for active ride requests
      final requests = await _getActiveRideRequestsForPassenger(_currentPassengerId!);
      
      if (requests.isNotEmpty) {
        final request = requests.first;
        await _startRideMonitoring(request.id);
        return;
      }

      // Also check for active rides where passenger is already matched
      final activeRide = await _getActiveRideForPassenger(_currentPassengerId!);
      if (activeRide != null) {
        // Find the corresponding request or create ride info from the ride offer
        await _loadRideInfoFromOffer(activeRide);
      }
    } catch (e) {
      _logger.e('Error checking existing rides: $e');
    }
  }

  /// Get active or recently completed ride where passenger is already matched
  Future<RideOffer?> _getActiveRideForPassenger(String passengerId) async {
    try {
      // Query for active, in-progress, and recently completed rides
      final activeRides = await _rideService.getRideOffers(
        status: RideStatus.active,
      );
      final inProgressRides = await _rideService.getRideOffers(
        status: RideStatus.inProgress,
      );
      final completedRides = await _rideService.getRideOffers(
        status: RideStatus.completed,
      );

      final now = DateTime.now();
      final recentCompletedCutoff = now.subtract(const Duration(hours: 12));

      // Combine and filter for rides where passenger is matched
      final allRides = [
        ...activeRides,
        ...inProgressRides,
        ...completedRides.where((ride) {
          final completionTime = ride.completedAt ?? ride.updatedAt;
          return completionTime.isAfter(recentCompletedCutoff);
        }),
      ];

      final matchingRides = allRides.where((ride) {
        if (!ride.passengerIds.contains(passengerId)) return false;
        if (ride.status == RideStatus.completed) {
          // Allow completed rides even if archived so passengers can review
          return true;
        }
        return !ride.isArchived;
      }).toList();

      if (matchingRides.isNotEmpty) {
        // Return the most recent one (by departure time)
        matchingRides.sort((a, b) => b.departureTime.compareTo(a.departureTime));
        return matchingRides.first;
      }
      return null;
    } catch (e) {
      _logger.e('Error getting active ride for passenger: $e');
      return null;
    }
  }

  /// Load ride info from a ride offer (when passenger is already matched)
  Future<void> _loadRideInfoFromOffer(RideOffer ride) async {
    try {
      // Get driver info
      final driver = await _getUserInfo(ride.driverId);
      
      // Get passenger's pickup/dropoff locations from the ride
      final pickupLocation = ride.passengerPickupLocations[_currentPassengerId] ?? ride.startLocation;
      final dropoffLocation = ride.passengerDropoffLocations[_currentPassengerId] ?? ride.endLocation;
      final pickupStatus = ride.passengerPickupStatus[_currentPassengerId] ?? PickupStatus.pending;

      // Create a ride request from the ride offer data
      final seatCount = ride.passengerSeatCounts[_currentPassengerId] ?? 1;
      final seatPrice = ride.passengerSeatPrices[_currentPassengerId] ?? ride.pricePerSeat;
      
      final request = RideRequest(
        id: ride.id, // Use ride ID as request ID
        requesterId: _currentPassengerId!,
        startLocation: pickupLocation,
        endLocation: dropoffLocation,
        preferredDepartureTime: ride.departureTime,
        flexibilityWindow: const Duration(minutes: 30),
        seatsNeeded: seatCount,
        maxPricePerSeat: seatPrice,
        status: RequestStatus.accepted,
        matchedOfferId: ride.id,
        declinedOfferIds: [],
        preferences: ride.preferences,
        notes: null,
        createdAt: ride.createdAt,
        updatedAt: ride.updatedAt,
      );

      final state = _derivePassengerStateFromRide(ride, pickupStatus);

      _currentRideInfo = PassengerRideInfo(
        request: request,
        ride: ride,
        driver: driver,
        state: state,
        pickupStatus: pickupStatus,
        driverLocation: null,
        pickupETA: null,
        dropoffETA: null,
        statusMessage: _getStatusMessage(state, pickupStatus),
        lastUpdate: DateTime.now(),
      );

      if (state == PassengerRideState.completed) {
        await _finalizeCompletedRideIfRated();
        if (_currentRideInfo == null) {
          return;
        }
      }

      // Start driver location tracking if in progress
      if (ride.status == RideStatus.inProgress) {
        await _startDriverLocationTracking(ride.driverId);
      }

      // Start monitoring the ride offer for updates
      _startRideOfferMonitoring(ride.id);

      notifyListeners();
    } catch (e) {
      _logger.e('Error loading ride info from offer: $e');
    }
  }

  /// Start monitoring a ride offer for updates
  void _startRideOfferMonitoring(String rideId) {
    _monitoredRideId = rideId;
    _isMonitoringAvailableRides = false;
    _startUnifiedRideOffersStream();
  }

  /// Start monitoring a specific ride request
  Future<void> _startRideMonitoring(String requestId) async {
    await _stopAllMonitoring();

    _rideSubscription = _rideService.getRideRequestsStream().listen(
      (requests) async {
        final request = requests.where((r) => r.id == requestId).firstOrNull;
        if (request != null) {
          await _updateRideInfo(request);
        }
      },
      onError: (error) {
        _logger.e('Error in ride requests stream: $error');
        if (error.toString().contains('permission-denied')) {
          _errorMessage = 'Authentication required. Please sign in with a UVA email.';
          notifyListeners();
        }
      },
    );
  }

  /// Update ride information based on request status
  Future<void> _updateRideInfo(RideRequest request) async {
    try {
      RideOffer? ride;
      UserModel? driver;
      PassengerRideState state;
      PickupStatus pickupStatus = PickupStatus.pending;

      // Determine state based on request status
      switch (request.status) {
        case RequestStatus.pending:
          state = PassengerRideState.requestPending;
          break;
        case RequestStatus.matched:
          state = PassengerRideState.matched;
          break;
        case RequestStatus.accepted:
          // Get ride and driver info
          if (request.matchedOfferId != null) {
            ride = await _rideService.getRideOffer(request.matchedOfferId!);
            if (ride != null) {
              driver = await _getUserInfo(ride.driverId);
              pickupStatus = ride.passengerPickupStatus[_currentPassengerId] ?? PickupStatus.pending;
              state = _derivePassengerStateFromRide(ride, pickupStatus);
              
              // Start driver location tracking
              await _startDriverLocationTracking(ride.driverId);
            } else {
              state = PassengerRideState.matched;
            }
          } else {
            state = PassengerRideState.matched;
          }
          break;
        case RequestStatus.completed:
          state = PassengerRideState.completed;
          pickupStatus = PickupStatus.completed;
          if (request.matchedOfferId != null) {
            ride = await _rideService.getRideOffer(request.matchedOfferId!);
            if (ride != null) {
              driver = await _getUserInfo(ride.driverId);
            }
          }
          ride ??= _currentRideInfo?.ride;
          driver ??= _currentRideInfo?.driver;
          break;
        case RequestStatus.cancelled:
          await _handleCompletedOrCancelledRide();
          return;
        case RequestStatus.declined:
          state = PassengerRideState.requestPending;
          break;
      }

      // Update ride info
      _currentRideInfo = PassengerRideInfo(
        request: request,
        ride: ride,
        driver: driver,
        state: state,
        pickupStatus: pickupStatus,
        driverLocation: _currentRideInfo?.driverLocation,
        pickupETA: _currentRideInfo?.pickupETA,
        dropoffETA: _currentRideInfo?.dropoffETA,
        statusMessage: _getStatusMessage(state, pickupStatus),
        lastUpdate: DateTime.now(),
      );

      // Start ETA updates if we have driver location
      if (state == PassengerRideState.driverEnRoute || state == PassengerRideState.driverArrived) {
        _startETAUpdates();
      }

      notifyListeners();

      if (state == PassengerRideState.completed) {
        await _finalizeCompletedRideIfRated();
      }
    } catch (e) {
      _logger.e('Error updating ride info: $e');
    }
  }

  /// Start tracking driver location
  Future<void> _startDriverLocationTracking(String driverId) async {
    _driverLocationSubscription?.cancel();
    
    _driverLocationSubscription = _liveLocationService
        .getDriverLocationStream(driverId)
        .listen((locationUpdate) {
      if (locationUpdate != null && _currentRideInfo != null) {
        _currentRideInfo = PassengerRideInfo(
          request: _currentRideInfo!.request,
          ride: _currentRideInfo!.ride,
          driver: _currentRideInfo!.driver,
          state: _currentRideInfo!.state,
          pickupStatus: _currentRideInfo!.pickupStatus,
          driverLocation: locationUpdate.coordinates,
          pickupETA: _currentRideInfo!.pickupETA,
          dropoffETA: _currentRideInfo!.dropoffETA,
          statusMessage: _currentRideInfo!.statusMessage,
          lastUpdate: DateTime.now(),
        );
        notifyListeners();
      }
    });
  }

  /// Start ETA updates
  void _startETAUpdates() {
    _etaUpdateTimer?.cancel();
    
    _etaUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_currentRideInfo?.driverLocation == null) return;

      try {
        ETAUpdate? pickupETA;
        ETAUpdate? dropoffETA;

        if (_currentRideInfo!.state == PassengerRideState.driverEnRoute ||
            _currentRideInfo!.state == PassengerRideState.driverArrived) {
          // Calculate ETA to pickup
          pickupETA = await _etaService.calculateETA(
            currentLocation: _currentRideInfo!.driverLocation!,
            destination: _currentRideInfo!.request.startLocation.coordinates,
          );
        }

        if (_currentRideInfo!.state == PassengerRideState.inRide) {
          // Calculate ETA to dropoff
          dropoffETA = await _etaService.calculateETA(
            currentLocation: _currentRideInfo!.driverLocation!,
            destination: _currentRideInfo!.request.endLocation.coordinates,
          );
        }

        if (pickupETA != null || dropoffETA != null) {
          _currentRideInfo = PassengerRideInfo(
            request: _currentRideInfo!.request,
            ride: _currentRideInfo!.ride,
            driver: _currentRideInfo!.driver,
            state: _currentRideInfo!.state,
            pickupStatus: _currentRideInfo!.pickupStatus,
            driverLocation: _currentRideInfo!.driverLocation,
            pickupETA: pickupETA ?? _currentRideInfo!.pickupETA,
            dropoffETA: dropoffETA ?? _currentRideInfo!.dropoffETA,
            statusMessage: _currentRideInfo!.statusMessage,
            lastUpdate: DateTime.now(),
          );
          notifyListeners();
        }
      } catch (e) {
        _logger.e('Error updating ETA: $e');
      }
    });
  }

  /// Start monitoring available rides
  Future<void> _startAvailableRidesMonitoring() async {
    _monitoredRideId = null;
    _isMonitoringAvailableRides = true;
    _startUnifiedRideOffersStream();
  }
  
  /// Unified stream for ride offers to eliminate duplicates
  void _startUnifiedRideOffersStream() {
    _rideOffersSubscription?.cancel();
    
    _rideOffersSubscription = _rideService.getRideOffersStream().listen(
      (rides) async {
        // Handle specific ride monitoring
        if (_monitoredRideId != null) {
          final ride = rides.where((r) => r.id == _monitoredRideId).firstOrNull;
          if (ride != null && _currentPassengerId != null) {
            // Check if passenger is still in this ride
            if (ride.passengerIds.contains(_currentPassengerId!)) {
              await _loadRideInfoFromOffer(ride);
            } else {
              // Passenger was removed from ride
              _currentRideInfo = null;
              await _startAvailableRidesMonitoring();
              notifyListeners();
            }
          }
        }
        
        // Handle available rides monitoring
        if (_isMonitoringAvailableRides) {
          _availableRides = rides.where((ride) => 
              ride.status == RideStatus.active && 
              ride.availableSeats > 0
          ).toList();
          notifyListeners();
        }
      },
      onError: (error) {
        _logger.e('Error in unified ride offers stream: $error');
        if (error.toString().contains('permission-denied')) {
          _errorMessage = 'Authentication required. Please sign in with a UVA email.';
          notifyListeners();
        }
      },
    );
  }

  /// Stop all monitoring
  Future<void> _stopAllMonitoring() async {
    _rideSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _rideOffersSubscription?.cancel();
    _etaUpdateTimer?.cancel();
    
    // Reset monitoring state
    _monitoredRideId = null;
    _isMonitoringAvailableRides = false;
  }

  /// Cancel all subscriptions (for logout cleanup)
  void cancelAllSubscriptions() {
    _stopAllMonitoring();
    _currentRideInfo = null;
    _availableRides = [];
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _handleCompletedOrCancelledRide() async {
    await _stopAllMonitoring();
    _currentRideInfo = null;
    await _startAvailableRidesMonitoring();
    notifyListeners();
  }

  Future<void> _finalizeCompletedRideIfRated() async {
    if (_currentRideInfo?.ride == null || _currentPassengerId == null) {
      return;
    }

    try {
      final hasRated = await hasRatedCurrentRide();
      if (hasRated) {
        final requestId = _currentRideInfo!.request.id;
        if (requestId.isNotEmpty) {
          try {
            await _rideService.archiveRideRequest(requestId);
          } catch (e) {
            _logger.w('Unable to archive ride request $requestId while finalizing: $e');
          }
        }
        await _handleCompletedOrCancelledRide();
      }
    } catch (e) {
      _logger.w('Error checking rating status before cleanup: $e');
    }
  }

  PassengerRideState _derivePassengerStateFromRide(RideOffer ride, PickupStatus pickupStatus) {
    switch (ride.status) {
      case RideStatus.inProgress:
        switch (pickupStatus) {
          case PickupStatus.pending:
            return PassengerRideState.driverEnRoute;
          case PickupStatus.driverArrived:
            return PassengerRideState.driverArrived;
          case PickupStatus.passengerPickedUp:
            return PassengerRideState.inRide;
          case PickupStatus.completed:
            return PassengerRideState.completed;
        }
      case RideStatus.completed:
        return PassengerRideState.completed;
      case RideStatus.cancelled:
      case RideStatus.expired:
        return PassengerRideState.cancelled;
      default:
        if (pickupStatus == PickupStatus.driverArrived) {
          return PassengerRideState.driverArrived;
        }
        if (pickupStatus == PickupStatus.passengerPickedUp) {
          return PassengerRideState.inRide;
        }
        if (pickupStatus == PickupStatus.completed) {
          return PassengerRideState.completed;
        }
        // Ride hasn't started yet, so keep passenger in matched state
        if (ride.status == RideStatus.active || ride.status == RideStatus.full) {
          return PassengerRideState.matched;
        }
        return PassengerRideState.driverEnRoute;
    }
  }

  /// Get status message based on state
  String _getStatusMessage(PassengerRideState state, PickupStatus pickupStatus) {
    switch (state) {
      case PassengerRideState.noRide:
        return 'No active ride';
      case PassengerRideState.requestPending:
        return 'Looking for a driver...';
      case PassengerRideState.matched:
        return 'Driver found! Waiting for confirmation';
      case PassengerRideState.driverEnRoute:
        return 'Driver is on the way to pick you up';
      case PassengerRideState.driverArrived:
        return 'Driver has arrived at pickup location';
      case PassengerRideState.inRide:
        return 'Enjoying your ride to destination';
      case PassengerRideState.completed:
        return 'Ride completed successfully';
      case PassengerRideState.cancelled:
        return 'Ride was cancelled';
    }
  }

  /// Get active ride requests for passenger
  Future<List<RideRequest>> _getActiveRideRequestsForPassenger(String passengerId) async {
    try {
      // Use the getRideRequests method with requesterId filter
      final requests = await _rideService.getRideRequests(
        requesterId: passengerId,
      );

      // Filter for active requests (not completed, cancelled, or declined)
      final activeRequests = requests.where((request) => 
        request.status != RequestStatus.completed &&
        request.status != RequestStatus.cancelled &&
        request.status != RequestStatus.declined
      ).toList();

      return activeRequests;
    } catch (e) {
      _logger.e('Error getting active ride requests: $e');
      return [];
    }
  }

  /// Get user info by ID
  Future<UserModel?> _getUserInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting user info: $e');
      return null;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopAllMonitoring();
    super.dispose();
  }
}
