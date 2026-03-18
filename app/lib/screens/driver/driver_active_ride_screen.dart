import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ride_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/ride_service.dart';
import '../../services/passenger_service.dart';
import '../../services/rating_service.dart';
import '../../services/route_optimization_service.dart';
import '../../services/directions_service.dart';
import '../../services/driver_status_service.dart';
import '../../providers/user_profile_provider.dart';
import '../../utils/units_formatter.dart';
import '../../widgets/passenger_details_overlay.dart';
import '../rides/ride_review_screen.dart';

class DriverActiveRideScreen extends StatefulWidget {
  final RideOffer ride;
  final VoidCallback? onComplete;

  const DriverActiveRideScreen({
    super.key,
    required this.ride,
    this.onComplete,
  });

  @override
  State<DriverActiveRideScreen> createState() => _DriverActiveRideScreenState();
}

class _DriverActiveRideScreenState extends State<DriverActiveRideScreen> {
  // Map controllers and display
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  BitmapDescriptor? _carIcon;
  bool _is3DEnabled = false;
  
  // Services
  final RideService _rideService = RideService();
  final PassengerService _passengerService = PassengerService();
  final RatingService _ratingService = RatingService();
  final RouteOptimizationService _routeOptimizationService = RouteOptimizationService();
  final DirectionsService _directionsService = DirectionsService();
  final DriverStatusService _driverStatusService = DriverStatusService();
  
  // Passenger management
  StreamSubscription<List<PassengerInfo>>? _passengerInfoSubscription;
  List<PassengerInfo> _passengers = [];
  final Set<String> _ratedPassengerIds = {};
  
  // Route optimization
  List<OptimizedRouteStop> _optimizedRoute = [];
  List<LatLng> _completeRoutePoints = [];
  int _currentStepIndex = 0;
  bool _routeOptimizationInProgress = false;
  bool _hasInitializedOptimization = false;
  bool _hasCompletedRide = false;
  bool _isCompletingRide = false;
  
  // UI state
  bool _showPassengerDetails = false;
  bool _isRideOperationLoading = false;
  String? _verificationCode;
  bool _isVerificationLoading = false;
  
  // Simulation state
  bool _showTestControls = false;
  bool _isSimulating = false;
  bool _isSimulationPaused = false;
  Timer? _simulationTimer;
  int _currentRouteIndex = 0;
  LatLng? _pausedLocation;
  final Set<String> _simulationNotifications = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDriverMode();
      _loadCarIcon();
    });
  }

  @override
  void dispose() {
    _passengerInfoSubscription?.cancel();
    _simulationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> _initializeDriverMode() async {
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        await _rideService.startRide(widget.ride.id, user.uid);
      }
      
      _subscribeToPassengerUpdates();
      await _initializeNavigation();
      await _fetchVerificationCode();
    } catch (e) {
      debugPrint('Error initializing driver mode: $e');
      if (mounted) {
        _showSnackBar('Failed to initialize driver mode: $e', Colors.red);
      }
    }
  }

  void _subscribeToPassengerUpdates() {
    _passengerInfoSubscription = _passengerService
        .getPassengerInfoStream(widget.ride)
        .listen(
      (passengers) async {
        if (!mounted) return;
        setState(() => _passengers = passengers);
        _updateMapMarkers();
        await _optimizeRouteAndUpdateNavigation();
      },
      onError: (error) => debugPrint('Error getting passenger updates: $error'),
    );
  }

  Future<void> _initializeNavigation() async {
    if (!mounted) return;
    
    try {
      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
      
      // Set user preferences for voice announcements
      try {
        final userProvider = Provider.of<UserProfileProvider>(context, listen: false);
        navigationProvider.setUserPreferences(userProvider.userProfile?.preferences);
      } catch (e) {
        debugPrint('Could not set user preferences for navigation: $e');
      }
      
      await navigationProvider.startNavigation(
        widget.ride.startLocation.coordinates,
        widget.ride.endLocation.coordinates,
      );

      _setupMapListeners();
      
      if (_passengers.isNotEmpty && _optimizedRoute.isEmpty) {
        await _optimizeRouteAndUpdateNavigation();
      }
    } catch (e) {
      debugPrint('Navigation initialization error: $e');
    }
  }

  void _setupMapListeners() {
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    navigationProvider.addListener(() {
      if (mounted) _updateMapDisplay();
    });
  }

  Future<void> _loadCarIcon() async {
    try {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/car_icon.png',
      );
    } catch (e) {
      _carIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  // ============================================================================
  // MAP DISPLAY
  // ============================================================================

  void _updateMapDisplay() {
    if (!mounted) return;
    
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    
    setState(() {
      _polylines.clear();
      _markers.clear();

      // Add route polyline
      if (_completeRoutePoints.isNotEmpty) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('optimized_route'),
          points: _completeRoutePoints,
          color: Colors.blue,
          width: 5,
        ));
      } else {
        final route = navigationProvider.route;
        if (route != null && route.polylinePoints.isNotEmpty) {
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: route.polylinePoints,
            color: Colors.blue,
            width: 5,
          ));
        }
      }

      // Add destination marker
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: widget.ride.endLocation.coordinates,
        infoWindow: InfoWindow(title: widget.ride.endLocation.address),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));

      // Add current location marker
      if (navigationProvider.currentLocation != null) {
        _markers.add(Marker(
          markerId: const MarkerId('current'),
          position: navigationProvider.currentLocation!,
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
          rotation: _calculateBearing(),
        ));
      }

      _updateMapMarkers();
    });
  }

  void _updateMapMarkers() {
    if (_optimizedRoute.isNotEmpty) {
      _updateMapMarkersWithSequence();
    } else {
      _updateMapMarkersDefault();
    }
  }

  void _updateMapMarkersDefault() {
    _markers.removeWhere((m) => m.markerId.value.startsWith('passenger_') || 
                                 m.markerId.value.startsWith('stop_'));

    for (int i = 0; i < _passengers.length; i++) {
      final passenger = _passengers[i];
      final markerColor = _getPickupStatusColor(passenger.pickupStatus);

      _markers.add(Marker(
        markerId: MarkerId('passenger_${passenger.user.uid}'),
        position: passenger.pickupLocation.coordinates,
        icon: BitmapDescriptor.defaultMarkerWithHue(_getHueFromColor(markerColor)),
        infoWindow: InfoWindow(
          title: passenger.user.profile.displayName,
          snippet: _passengerService.getPickupStatusDisplayName(passenger.pickupStatus),
        ),
        onTap: () => _showPassengerDetailBottomSheet(i),
      ));
    }
  }

  void _updateMapMarkersWithSequence() {
    _markers.removeWhere((m) => m.markerId.value.startsWith('passenger_') || 
                                 m.markerId.value.startsWith('stop_'));

    for (final stop in _optimizedRoute) {
      Color markerColor;
      String title;
      
      switch (stop.type) {
        case RouteStopType.pickup:
          final passenger = _passengers.firstWhere((p) => p.user.uid == stop.passengerId);
          markerColor = _getPickupStatusColor(passenger.pickupStatus);
          title = 'Pickup: ${passenger.user.profile.displayName}';
          break;
        case RouteStopType.dropoff:
          markerColor = Colors.blue;
          title = 'Dropoff: ${_getPassengerName(stop.passengerId!)}';
          break;
        case RouteStopType.driverDestination:
          markerColor = Colors.red;
          title = 'Destination';
          break;
      }

      _markers.add(Marker(
        markerId: MarkerId('stop_${stop.sequenceNumber}'),
        position: stop.location,
        icon: BitmapDescriptor.defaultMarkerWithHue(_getHueFromColor(markerColor)),
        infoWindow: InfoWindow(
          title: '${stop.sequenceNumber}. $title',
          snippet: stop.address,
        ),
      ));
    }
  }

  // ============================================================================
  // PASSENGER ACTIONS
  // ============================================================================

  Future<void> _markDriverArrived(int passengerIndex) async {
    if (!mounted) return;
    
    final passenger = _passengers[passengerIndex];
    if (!_passengerService.canMarkArrived(passenger.pickupStatus)) return;
    
    setState(() => _isRideOperationLoading = true);
    
    try {
      _showSnackBar('Marking arrival for ${passenger.user.profile.displayName}...', Colors.orange);
      
      await _passengerService.updatePassengerPickupStatus(
        widget.ride.id,
        passenger.user.uid,
        PickupStatus.driverArrived,
      );
      
      if (!mounted) return;
      
      _closeModal();
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (!mounted) return;
      
      _showSnackBar('Marked as arrived for ${passenger.user.profile.displayName}', Colors.blue);
      setState(() => _isRideOperationLoading = false);
    } catch (e) {
      debugPrint('Error marking driver arrived: $e');
      if (!mounted) return;
      
      _closeModal();
      _showSnackBar('Failed to mark as arrived: $e', Colors.red);
      setState(() => _isRideOperationLoading = false);
    }
  }

  Future<void> _markPassengerPickedUp(int passengerIndex) async {
    if (!mounted) return;
    
    final passenger = _passengers[passengerIndex];
    if (!_passengerService.canMarkPickedUp(passenger.pickupStatus)) return;
    
    setState(() => _isRideOperationLoading = true);
    
    try {
      _showSnackBar('Picking up ${passenger.user.profile.displayName}...', Colors.orange);
      
      await _passengerService.updatePassengerPickupStatus(
        widget.ride.id,
        passenger.user.uid,
        PickupStatus.passengerPickedUp,
      );
      
      if (!mounted) return;
      
      _closeModal();
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (!mounted) return;
      
      _showSnackBar('${passenger.user.profile.displayName} picked up', Colors.green);
      
      // Clear loading BEFORE navigation attempt
      setState(() => _isRideOperationLoading = false);
      
      // Advance to next step (errors handled silently)
      if (_optimizedRoute.isNotEmpty && mounted) {
        _advanceToNextStep().catchError((e) {
          debugPrint('Error advancing to next step: $e');
        });
      }
    } catch (e) {
      debugPrint('Error marking passenger picked up: $e');
      if (!mounted) return;
      
      _closeModal();
      _showSnackBar('Failed to mark as picked up: $e', Colors.red);
      setState(() => _isRideOperationLoading = false);
    }
  }

  Future<void> _markPassengerDroppedOff(int passengerIndex) async {
    if (!mounted) return;
    
    final passenger = _passengers[passengerIndex];
    if (!_passengerService.canMarkDroppedOff(passenger.pickupStatus)) return;
    
    setState(() => _isRideOperationLoading = true);
    
    try {
      _showSnackBar('Marking ${passenger.user.profile.displayName} as dropped off...', Colors.orange);
      
      await _passengerService.updatePassengerPickupStatus(
        widget.ride.id,
        passenger.user.uid,
        PickupStatus.completed,
      );

      // Ensure the passenger's ride request moves to completed for the rider UI
      await _rideService.markPassengerRideRequestCompleted(
        widget.ride.id,
        passenger.user.uid,
      );
      
      if (!mounted) return;
      
      _closeModal();
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (!mounted) return;
      
      _showSnackBar('${passenger.user.profile.displayName} dropped off', Colors.green);
      
      // Clear loading BEFORE navigation attempt
      setState(() => _isRideOperationLoading = false);
      
      // Advance to next step (errors handled silently)
      if (_optimizedRoute.isNotEmpty && mounted) {
        _advanceToNextStep().catchError((e) {
          debugPrint('Error advancing to next step: $e');
        });
      }
    } catch (e) {
      debugPrint('Error marking passenger dropped off: $e');
      if (!mounted) return;
      
      _closeModal();
      _showSnackBar('Failed to mark as dropped off: $e', Colors.red);
      setState(() => _isRideOperationLoading = false);
    }
  }

  Future<void> _navigateToPassengerReview(PassengerInfo passenger) async {
    if (!mounted) return;
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideReviewScreen(
          revieweeName: passenger.user.profile.displayName,
          title: 'Rate ${passenger.user.profile.displayName}',
          subtitle: 'Share how this rider behaved during the trip.',
          onSubmit: (rating, comment) => _submitPassengerRating(passenger, rating, comment),
        ),
      ),
    );
  }

  Future<void> _submitPassengerRating(PassengerInfo passenger, double rating, String? comment) async {
    try {
      await _ratingService.submitRating(
        rideId: widget.ride.id,
        reviewerId: widget.ride.driverId,
        revieweeId: passenger.user.uid,
        rating: rating,
        comment: comment,
        reviewerIsDriver: true,
      );
      
      if (!mounted) return;
      
      setState(() => _ratedPassengerIds.add(passenger.user.uid));
      _showSnackBar('Rated ${passenger.user.profile.displayName}', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to rate passenger: $e', Colors.red);
    }
  }

  // ============================================================================
  // ROUTE OPTIMIZATION
  // ============================================================================

  Future<void> _optimizeRouteAndUpdateNavigation() async {
    if (_passengers.isEmpty || _routeOptimizationInProgress) return;
    
    if (_hasInitializedOptimization && _optimizedRoute.isNotEmpty) {
      _currentStepIndex = _calculateCurrentStepFromPickupStatus();
      return;
    }
    
    await _optimizeRoute();
    
    if (_optimizedRoute.isNotEmpty && mounted) {
      _currentStepIndex = _calculateCurrentStepFromPickupStatus();
      await _updateNavigationWithOptimizedRoute();
      _hasInitializedOptimization = true;
      await _buildCompleteRouteForSimulation();
    }
  }

  Future<void> _optimizeRoute() async {
    if (_passengers.isEmpty || _routeOptimizationInProgress) return;
    
    setState(() => _routeOptimizationInProgress = true);

    try {
      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
      final currentLocation = navigationProvider.currentLocation ?? widget.ride.startLocation.coordinates;
      
      final passengerRouteInfos = _passengers.map((p) => 
        PassengerRouteInfo(
          passengerId: p.user.uid,
          pickupLocation: p.pickupLocation,
          dropoffLocation: p.dropoffLocation,
        )
      ).toList();

      final optimizedStops = await _routeOptimizationService.optimizeRoute(
        ride: widget.ride,
        driverStartLocation: currentLocation,
        driverEndLocation: widget.ride.endLocation.coordinates,
        passengers: passengerRouteInfos,
      );

      if (mounted) {
        setState(() {
          _optimizedRoute = optimizedStops;
          _routeOptimizationInProgress = false;
        });
        await _updateNavigationWithOptimizedRoute();
        await _buildCompleteRouteForSimulation();
      }
    } catch (e) {
      debugPrint('Route optimization failed: $e');
      if (mounted) {
        setState(() => _routeOptimizationInProgress = false);
      }
    }
  }

  Future<void> _updateNavigationWithOptimizedRoute() async {
    if (!mounted || _optimizedRoute.isEmpty) return;
    
    _updateMapMarkersWithSequence();
    
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    if (_currentStepIndex < _optimizedRoute.length) {
      final currentStop = _optimizedRoute[_currentStepIndex];
      
      try {
        final success = await navigationProvider.updateDestination(currentStop.location);
        if (!success) {
          final currentLocation = navigationProvider.currentLocation ?? widget.ride.startLocation.coordinates;
          await navigationProvider.startNavigation(currentLocation, currentStop.location);
        }
      } catch (e) {
        debugPrint('Error updating navigation: $e');
      }
    }
    
    if (mounted && _optimizedRoute.isNotEmpty) {
      _showSnackBar('Route optimized: ${_optimizedRoute.length} stops planned', Colors.green);
    }
  }

  Future<void> _buildCompleteRouteForSimulation() async {
    if (!mounted || _optimizedRoute.isEmpty) {
      if (mounted) setState(() => _completeRoutePoints = []);
      return;
    }

    try {
      List<LatLng> allRoutePoints = [];
      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
      LatLng currentLocation = navigationProvider.currentLocation ?? widget.ride.startLocation.coordinates;

      allRoutePoints.add(currentLocation);

      for (final stop in _optimizedRoute) {
        if (!mounted) return;
        
        final directions = await _directionsService.getDirections(
          origin: currentLocation,
          destination: stop.location,
        );

        if (directions != null && directions.polylinePoints.isNotEmpty) {
          allRoutePoints.addAll(directions.polylinePoints.skip(1));
        } else {
          allRoutePoints.add(stop.location);
        }
        
        currentLocation = stop.location;
      }

      if (mounted) {
        setState(() => _completeRoutePoints = allRoutePoints);
        _updateMapDisplay();
      }
    } catch (e) {
      debugPrint('Error building complete route: $e');
      if (mounted) setState(() => _completeRoutePoints = []);
    }
  }

  Future<void> _advanceToNextStep() async {
    if (!mounted || _currentStepIndex >= _optimizedRoute.length - 1) return;
    
    setState(() => _currentStepIndex++);
    
    final currentStep = _optimizedRoute[_currentStepIndex];
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    
    try {
      final success = await navigationProvider.updateDestination(currentStep.location);
      if (!success) {
        final currentLocation = navigationProvider.currentLocation ?? widget.ride.startLocation.coordinates;
        await navigationProvider.startNavigation(currentLocation, currentStep.location);
      }
      
      if (mounted) {
        _showSnackBar('Next: ${_getStepDescription(currentStep)}', Colors.blue);
      }
    } catch (e) {
      debugPrint('Error advancing to next step: $e');
    }
  }

  int _calculateCurrentStepFromPickupStatus() {
    if (_optimizedRoute.isEmpty) return 0;
    
    for (int i = 0; i < _optimizedRoute.length; i++) {
      final step = _optimizedRoute[i];
      
      if (step.type == RouteStopType.driverDestination) {
        final allCompleted = _passengers.every((p) => 
          widget.ride.passengerPickupStatus[p.user.uid] == PickupStatus.completed
        );
        return allCompleted ? i : i - 1;
      }
      
      if (step.passengerId != null) {
        final status = widget.ride.passengerPickupStatus[step.passengerId!];
        
        if (step.type == RouteStopType.pickup) {
          if (status == null || status == PickupStatus.pending || status == PickupStatus.driverArrived) {
            return i;
          }
        } else if (step.type == RouteStopType.dropoff) {
          if (status == PickupStatus.passengerPickedUp) {
            return i;
          }
        }
      }
    }
    
    return _optimizedRoute.length - 1;
  }

  // ============================================================================
  // RIDE MANAGEMENT
  // ============================================================================

  Future<void> _completeRide() async {
    if (!mounted) return;
    
    if (_hasCompletedRide || _isCompletingRide) return;
    
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    if (user != null) {
      try {
        setState(() => _isCompletingRide = true);
        await _rideService.completeRide(widget.ride.id, user.uid);
        try {
          await _driverStatusService.setDriverAvailable();
        } catch (e) {
          debugPrint('Failed to reset driver status after ride completion: $e');
        }
        if (!mounted) return;

        List<PassengerInfo> passengersToRate = List<PassengerInfo>.from(_passengers);
        if (passengersToRate.isEmpty) {
          // Ensure we still prompt for reviews even if the live stream cleared early
          final refreshedRide = await _rideService.getRideOffer(widget.ride.id) ?? widget.ride;
          passengersToRate = await _passengerService.getPassengerInfoForRide(refreshedRide);
        }
        passengersToRate = passengersToRate
            .where((p) => !_ratedPassengerIds.contains(p.user.uid))
            .toList();

        for (final passenger in passengersToRate) {
          if (!mounted) break;
          await _navigateToPassengerReview(passenger);
        }

        try {
          await _rideService.archiveRideOffer(widget.ride.id);
        } catch (archiveError) {
          debugPrint('Failed to archive completed ride: $archiveError');
        }

        if (mounted) {
          setState(() {
            _hasCompletedRide = true;
            _isCompletingRide = false;
          });
        }

        widget.onComplete?.call();

        rideProvider.removeRideFromMyOffers(widget.ride.id);
        // Kick off a refresh so any other tabs pick up the archived state
        unawaited(rideProvider.loadMyRideOffers());

      } catch (e) {
        if (!mounted) return;
        setState(() => _isCompletingRide = false);
        _showSnackBar('Failed to complete ride: $e', Colors.red);
      }
    }
  }

  Future<void> _fetchVerificationCode({bool showFeedback = false}) async {
    if (_isVerificationLoading || !mounted) return;
    
    setState(() => _isVerificationLoading = true);
    
    try {
      final ride = await _rideService.getRideOffer(widget.ride.id);
      if (!mounted) return;
      
      setState(() {
        _verificationCode = ride?.verificationCode;
        _isVerificationLoading = false;
      });
      
      if (showFeedback && mounted) {
        final message = _verificationCode != null 
            ? 'Verification code refreshed.' 
            : 'No verification code yet.';
        _showSnackBar(message, _verificationCode != null ? Colors.green : Colors.orange);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerificationLoading = false);
      if (showFeedback) {
        _showSnackBar('Failed to refresh verification code: $e', Colors.red);
      }
    }
  }

  Future<void> _copyDriverVerificationCode() async {
    if (_verificationCode == null) return;
    await Clipboard.setData(ClipboardData(text: _verificationCode!));
    if (!mounted) return;
    _showSnackBar('Verification code copied', Colors.grey);
  }

  // ============================================================================
  // SIMULATION (for testing)
  // ============================================================================

  void _toggleRouteSimulation() {
    if (_isSimulating) {
      _pauseRouteSimulation();
    } else {
      _resumeRouteSimulation();
    }
  }

  Future<void> _startRouteSimulation() async {
    if (!mounted) return;
    
    if (_optimizedRoute.isNotEmpty && _completeRoutePoints.isEmpty) {
      await _buildCompleteRouteForSimulation();
    }
    
    if (!mounted) return;
    
    final routePoints = _completeRoutePoints.isNotEmpty 
        ? _completeRoutePoints 
        : Provider.of<NavigationProvider>(context, listen: false).route?.polylinePoints ?? [];
    
    if (routePoints.isEmpty) {
      _showSnackBar('No route available for simulation', Colors.orange);
      return;
    }

    final isResuming = _isSimulationPaused;
    
    setState(() {
      _isSimulating = true;
      if (!isResuming) _currentRouteIndex = 0;
      _isSimulationPaused = false;
    });
    
    if (isResuming && _pausedLocation != null) {
      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.updateCurrentLocation(_pausedLocation!);
      _mapController?.animateCamera(CameraUpdate.newLatLng(_pausedLocation!));
    }
    
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_currentRouteIndex < routePoints.length - 1) {
        _currentRouteIndex++;
        final newLocation = routePoints[_currentRouteIndex];
        
        final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
        navigationProvider.updateCurrentLocation(newLocation);
        _mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));
        
        _checkSimulationProgress(newLocation);
      } else {
        _stopRouteSimulation();
        _showSnackBar('Simulation completed!', Colors.green);
      }
    });
  }

  void _pauseRouteSimulation() {
    if (mounted) {
      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
      _pausedLocation = navigationProvider.currentLocation;
      navigationProvider.pauseNavigation();
    }
    
    setState(() {
      _isSimulating = false;
      _isSimulationPaused = true;
    });
    
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  Future<void> _resumeRouteSimulation() async {
    await _startRouteSimulation();
  }
  
  void _stopRouteSimulation() {
    setState(() {
      _isSimulating = false;
      _isSimulationPaused = false;
      _pausedLocation = null;
    });
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void _checkSimulationProgress(LatLng currentLocation) {
    if (_optimizedRoute.isEmpty) return;
    
    for (final stop in _optimizedRoute) {
      final distance = _calculateDistance(currentLocation, stop.location);
      
      if (distance <= 50.0) {
        final stopKey = 'simulation_${stop.sequenceNumber}';
        if (!_simulationNotifications.contains(stopKey)) {
          _simulationNotifications.add(stopKey);
          
          final (message, color) = switch (stop.type) {
            RouteStopType.pickup => ('Arrived at pickup for ${_getPassengerName(stop.passengerId!)}', Colors.green),
            RouteStopType.dropoff => ('Arrived at dropoff for ${_getPassengerName(stop.passengerId!)}', Colors.blue),
            RouteStopType.driverDestination => ('Arrived at final destination', Colors.red),
          };
          
          _showSnackBar('Simulation: $message', color);
        }
        break;
      }
    }
  }

  void _resetSimulation() {
    _stopRouteSimulation();
    setState(() {
      _currentRouteIndex = 0;
      _simulationNotifications.clear();
    });
    
    if (_optimizedRoute.isNotEmpty) {
      _buildCompleteRouteForSimulation();
    }
    
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    final startLocation = _completeRoutePoints.isNotEmpty 
        ? _completeRoutePoints.first 
        : widget.ride.startLocation.coordinates;
    
    navigationProvider.updateCurrentLocation(startLocation);
    _mapController?.animateCamera(CameraUpdate.newLatLng(startLocation));
    _showSnackBar('Simulation reset', Colors.grey);
  }

  // ============================================================================
  // 3D MAP
  // ============================================================================

  void _toggle3DView() async {
    if (_is3DEnabled) {
      await _disable3DView();
    } else {
      await _enable3DView();
    }
    setState(() => _is3DEnabled = !_is3DEnabled);
  }

  Future<void> _enable3DView() async {
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    final currentLocation = navigationProvider.currentLocation ?? widget.ride.startLocation.coordinates;
    
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentLocation,
          zoom: 19.0,
          tilt: 60.0,
          bearing: _calculateBearing(),
        ),
      ),
    );
  }

  Future<void> _disable3DView() async {
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    final currentLocation = navigationProvider.currentLocation ?? widget.ride.startLocation.coordinates;
    
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentLocation,
          zoom: 15.0,
          tilt: 0.0,
          bearing: 0.0,
        ),
      ),
    );
  }

  void _onCameraMove(CameraPosition position) {
    setState(() => _is3DEnabled = position.tilt > 10.0);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  void _showPassengerDetailBottomSheet(int passengerIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final passenger = _passengers[passengerIndex];
        final canRate = passenger.pickupStatus == PickupStatus.completed &&
            !_ratedPassengerIds.contains(passenger.user.uid);

        return PassengerDetailsOverlay(
          passenger: passenger,
          onMarkArrived: () => _markDriverArrived(passengerIndex),
          onMarkPickedUp: () => _markPassengerPickedUp(passengerIndex),
          onMarkDroppedOff: () => _markPassengerDroppedOff(passengerIndex),
          onCall: () => _launchUrl('tel:${passenger.user.profile.phoneNumber}'),
          onMessage: () => _launchUrl('sms:${passenger.user.profile.phoneNumber}'),
          onRatePassenger: canRate
              ? () {
                  Navigator.pop(context);
                  _navigateToPassengerReview(passenger);
                }
              : null,
        );
      },
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _centerOnCurrentLocation() async {
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    if (navigationProvider.currentLocation != null && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLng(navigationProvider.currentLocation!),
      );
    }
  }

  void _showRideInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ride Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${widget.ride.startLocation.address}'),
            Text('To: ${widget.ride.endLocation.address}'),
            Text('Price per seat: \$${widget.ride.pricePerSeat.toStringAsFixed(2)}'),
            if (widget.ride.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(widget.ride.notes!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _closeModal() {
    try {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error closing modal: $e');
    }
  }

  Color _getPickupStatusColor(PickupStatus status) => switch (status) {
    PickupStatus.pending => Colors.orange,
    PickupStatus.driverArrived => Colors.blue,
    PickupStatus.passengerPickedUp => Colors.green,
    PickupStatus.completed => Colors.grey,
  };

  double _getHueFromColor(Color color) {
    if (color == Colors.orange) return BitmapDescriptor.hueOrange;
    if (color == Colors.blue) return BitmapDescriptor.hueBlue;
    if (color == Colors.green) return BitmapDescriptor.hueGreen;
    return BitmapDescriptor.hueRed;
  }

  String _getPassengerName(String passengerId) {
    final passenger = _passengers.firstWhere((p) => p.user.uid == passengerId);
    return passenger.user.profile.displayName;
  }

  String _getStepDescription(OptimizedRouteStop stop) => switch (stop.type) {
    RouteStopType.pickup => 'Pickup ${_getPassengerName(stop.passengerId!)}',
    RouteStopType.dropoff => 'Drop off ${_getPassengerName(stop.passengerId!)}',
    RouteStopType.driverDestination => 'Arrive at destination',
  };

  double _calculateBearing() {
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    if (navigationProvider.currentLocation == null || navigationProvider.route == null) {
      return 0.0;
    }
    
    final route = navigationProvider.route!;
    if (route.polylinePoints.isEmpty) return 0.0;
    
    final currentLocation = navigationProvider.currentLocation!;
    double minDistance = double.infinity;
    int closestIndex = 0;
    
    for (int i = 0; i < route.polylinePoints.length; i++) {
      final distance = _calculateDistance(currentLocation, route.polylinePoints[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    
    if (closestIndex < route.polylinePoints.length - 1) {
      return _calculateBearing2Points(currentLocation, route.polylinePoints[closestIndex + 1]);
    }
    
    return 0.0;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;
    
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _calculateBearing2Points(LatLng start, LatLng end) {
    final lat1 = start.latitude * (pi / 180);
    final lat2 = end.latitude * (pi / 180);
    final deltaLng = (end.longitude - start.longitude) * (pi / 180);

    final y = sin(deltaLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLng);

    final bearing = atan2(y, x) * (180 / pi);
    return (bearing + 360) % 360;
  }

  String _cleanInstruction(String instruction) {
    return instruction
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

  String _formatDistance(double meters) {
    try {
      final userProvider = Provider.of<UserProfileProvider>(context, listen: false);
      final unit = UnitsFormatter.getUnitFromPreferences(userProvider.userProfile?.preferences);
      return UnitsFormatter.formatDistance(meters, unit: unit);
    } catch (e) {
      if (meters < 100) return '${meters.round()} m';
      if (meters < 1000) return '${(meters / 100).round() * 100} m';
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  String _formatVerificationCode(String code) {
    if (code.length == 4) {
      return code.split('').join(' ');
    }
    return code;
  }

  bool _shouldShowVerificationSection() {
    if (_passengers.isEmpty) return false;
    return _passengers.any((p) =>
        p.pickupStatus == PickupStatus.pending ||
        p.pickupStatus == PickupStatus.driverArrived);
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            mapType: MapType.normal,
            buildingsEnabled: true,
            initialCameraPosition: CameraPosition(
              target: widget.ride.startLocation.coordinates,
              zoom: 15,
              tilt: 0.0,
              bearing: 0.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: _onCameraMove,
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            trafficEnabled: true,
          ),
          
          // Driver status panel
          _buildDriverTopPanel(),
          
          // Test controls (when enabled)
          if (_showTestControls)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: _buildTestControls(),
            ),

          // Toolbar
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: _buildCompactToolbar(),
          ),
          
          // Loading overlay
          if (_isRideOperationLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFE57200)),
                          SizedBox(height: 16),
                          Text('Processing...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // UI COMPONENTS
  // ============================================================================

  Widget _buildDriverTopPanel() {
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, child) {
        final currentStepInstruction = navigationProvider.currentStep != null
            ? _cleanInstruction(navigationProvider.currentStep!.instruction)
            : (_currentStepIndex < _optimizedRoute.length 
                ? _getStepDescription(_optimizedRoute[_currentStepIndex])
                : 'Waiting for navigation');
        
        final currentStepDistance = navigationProvider.currentStep != null
            ? 'In ${_formatDistance(navigationProvider.distanceToNextStep)}'
            : null;
        
        final nextInstruction = navigationProvider.nextStep != null
            ? _cleanInstruction(navigationProvider.nextStep!.instruction)
            : null;

        return Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Card(
            color: Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.navigation, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStepInstruction,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            if (currentStepDistance != null)
                              Text(
                                currentStepDistance,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'DRIVING',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (nextInstruction != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.arrow_forward, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Then $nextInstruction',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_shouldShowVerificationSection()) ...[
                    const SizedBox(height: 12),
                    _buildVerificationSummaryRow(),
                  ],
                  if (_passengers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => setState(() => _showPassengerDetails = !_showPassengerDetails),
                      child: Row(
                        children: [
                          Text(
                            'Passengers (${_passengers.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          Text(
                            _showPassengerDetails ? 'Hide details' : 'Show details',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Icon(
                            _showPassengerDetails ? Icons.expand_less : Icons.expand_more,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_showPassengerDetails)
                      Column(
                        children: _passengers
                            .asMap()
                            .entries
                            .map((entry) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: entry.key == _passengers.length - 1 ? 0 : 12,
                                  ),
                                  child: _buildExpandedPassengerRow(entry.value, entry.key),
                                ))
                            .toList(),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _passengers.map(_buildPassengerSummaryChip).toList(),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerificationSummaryRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.green[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification Code',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                Text(
                  _verificationCode != null ? _formatVerificationCode(_verificationCode!) : '----',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh code',
            onPressed: _isVerificationLoading ? null : () => _fetchVerificationCode(showFeedback: true),
            icon: _isVerificationLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
          if (_verificationCode != null)
            IconButton(
              tooltip: 'Copy code',
              onPressed: _copyDriverVerificationCode,
              icon: const Icon(Icons.copy),
            ),
        ],
      ),
    );
  }

  Widget _buildPassengerSummaryChip(PassengerInfo passenger) {
    final color = _getPickupStatusColor(passenger.pickupStatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: passenger.user.profile.photoURL.isNotEmpty
                ? NetworkImage(passenger.user.profile.photoURL)
                : null,
            child: passenger.user.profile.photoURL.isEmpty
                ? Text(
                    passenger.user.profile.displayName.isNotEmpty
                        ? passenger.user.profile.displayName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            passenger.user.profile.displayName,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedPassengerRow(PassengerInfo passenger, int index) {
    final canArrive = _passengerService.canMarkArrived(passenger.pickupStatus);
    final canPickUp = _passengerService.canMarkPickedUp(passenger.pickupStatus);
    final canDrop = _passengerService.canMarkDroppedOff(passenger.pickupStatus);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: passenger.user.profile.photoURL.isNotEmpty
                    ? NetworkImage(passenger.user.profile.photoURL)
                    : null,
                child: passenger.user.profile.photoURL.isEmpty
                    ? Text(
                        passenger.user.profile.displayName.isNotEmpty
                            ? passenger.user.profile.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passenger.user.profile.displayName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      passenger.pickupLocation.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPickupStatusColor(passenger.pickupStatus).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _passengerService.getPickupStatusDisplayName(passenger.pickupStatus),
                  style: TextStyle(
                    color: _getPickupStatusColor(passenger.pickupStatus),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton('Arrived', Icons.location_on, canArrive, Colors.blue, () => _markDriverArrived(index)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton('Onboard', Icons.person, canPickUp, Colors.green, () => _markPassengerPickedUp(index)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton('Drop', Icons.flag, canDrop, Colors.grey[700]!, () => _markPassengerDroppedOff(index)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, bool enabled, Color color, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        foregroundColor: enabled ? color : Colors.grey,
        side: BorderSide(color: enabled ? color.withValues(alpha: 0.4) : Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCompactToolbar() {
    final allPassengersReady = _passengers.every(
      (p) => p.pickupStatus == PickupStatus.completed,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolbarButton(
              icon: _showTestControls ? Icons.visibility : Icons.visibility_off,
              onPressed: () => setState(() => _showTestControls = !_showTestControls),
              color: _showTestControls ? Colors.orange : Colors.grey[600]!,
            ),
            const SizedBox(width: 4),
            _buildToolbarButton(
              icon: Icons.my_location,
              onPressed: _centerOnCurrentLocation,
              color: Colors.blue,
            ),
            const SizedBox(width: 4),
            _buildToolbarButton(
              icon: _is3DEnabled ? Icons.threed_rotation : Icons.map,
              onPressed: _toggle3DView,
              color: _is3DEnabled ? Colors.purple : Colors.grey[600]!,
            ),
            const SizedBox(width: 4),
            Consumer<NavigationProvider>(
              builder: (context, nav, _) => _buildToolbarButton(
                icon: nav.voiceEnabled ? Icons.volume_up : Icons.volume_off,
                onPressed: () => nav.setVoiceEnabled(!nav.voiceEnabled),
                color: nav.voiceEnabled ? Colors.green : Colors.grey[600]!,
              ),
            ),
            const SizedBox(width: 4),
            _buildToolbarButton(
              icon: Icons.info_outline,
              onPressed: _showRideInfo,
              color: Colors.black,
            ),
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (allPassengersReady && !_hasCompletedRide && !_isCompletingRide) ? _completeRide : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (allPassengersReady && !_hasCompletedRide && !_isCompletingRide) ? Colors.red : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Complete',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildTestControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Simulation Controls',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleRouteSimulation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSimulating ? Colors.orange : (_isSimulationPaused ? Colors.green : Colors.blue),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: Icon(_isSimulating ? Icons.pause : Icons.play_arrow, size: 16),
                    label: Text(
                      _isSimulating ? 'Pause' : (_isSimulationPaused ? 'Resume' : 'Start'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resetSimulation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

