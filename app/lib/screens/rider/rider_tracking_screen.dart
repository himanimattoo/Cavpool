import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/passenger_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/passenger/ride_status_card.dart';
import '../../widgets/passenger/driver_contact_panel.dart';
import '../../widgets/passenger/ride_progress_indicator.dart';
import '../../services/directions_service.dart';
import '../../services/ride_service.dart';
import '../../models/ride_model.dart';
import '../../widgets/verification_code_card.dart';

class RiderTrackingScreen extends StatefulWidget {
  const RiderTrackingScreen({super.key});

  @override
  State<RiderTrackingScreen> createState() => _RiderTrackingScreenState();
}

class _RiderTrackingScreenState extends State<RiderTrackingScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _mapReady = false;
  final DirectionsService _directionsService = DirectionsService();
  final RideService _rideService = RideService();
  bool _routeLoaded = false;
  LatLng? _lastDriverLocation;
  String? _currentRideId;
  bool _isRefreshingVerification = false;
  bool _isVerificationExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializePassenger();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _initializePassenger() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final passengerProvider = Provider.of<PassengerProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      passengerProvider.initialize(authProvider.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<PassengerProvider>(
        builder: (context, passengerProvider, child) {
          if (!passengerProvider.hasActiveRide) {
            return _buildNoActiveRide();
          }

          // Update map when ride info or driver location changes
          final currentDriverLocation = passengerProvider.currentRideInfo?.driverLocation;
          if (_mapReady) {
            // Update map if driver location changed or if route not loaded yet
            if (currentDriverLocation != _lastDriverLocation || !_routeLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && passengerProvider.currentRideInfo != null) {
                  _lastDriverLocation = currentDriverLocation;
                  _updateMapView(passengerProvider);
                }
              });
            }
          }

          return Stack(
            children: [
              // Map
              _buildMap(passengerProvider),
              
              // Top Status Bar
              _buildTopStatusBar(passengerProvider),
              
              // Bottom Sheet
              _buildBottomSheet(passengerProvider),
              
              // Loading Overlay
              if (passengerProvider.isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(PassengerProvider provider) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(38.0336, -78.5076), // Default to UVA
        zoom: 15,
      ),
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _mapReady = true;
        // Update map view after a short delay to ensure provider state is ready
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && provider.currentRideInfo != null) {
            _updateMapView(provider);
          }
        });
      },
      onCameraMove: (CameraPosition position) {
        // Optional: Handle camera movement if needed
      },
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      style: _getMapStyle(),
    );
  }

  Widget _buildTopStatusBar(PassengerProvider provider) {
    final rideInfo = provider.currentRideInfo!;
    
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rideInfo.statusMessage ?? 'Active Ride',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                  if (rideInfo.driver != null)
                    Text(
                      'with ${rideInfo.driver!.profile.displayName}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            
            // ETA Chip
            if (rideInfo.pickupETA != null || rideInfo.dropoffETA != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _getETAText(rideInfo),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(PassengerProvider provider) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.2,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ride Progress
                      RideProgressIndicator(
                        currentState: provider.currentState,
                        pickupStatus: provider.currentRideInfo!.pickupStatus,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Driver Contact Panel
                      if (provider.canContactDriver)
                        DriverContactPanel(
                          driver: provider.currentRideInfo!.driver!,
                          onCall: () => provider.callDriver(),
                          onMessage: () => _showMessageOptions(context, provider),
                        ),
                      
                      const SizedBox(height: 20),
                      
                      // Verification code display
                      if (provider.currentRideInfo!.ride != null &&
                          _shouldShowVerificationCard(provider))
                        _buildVerificationSection(provider),
                      
                      const SizedBox(height: 20),
                      
                      if (provider.currentRideInfo!.pickupStatus == PickupStatus.driverArrived) ...[
                        _buildBoardedButton(context, provider),
                        const SizedBox(height: 20),
                      ],
                      
                      // Ride Status Card
                      RideStatusCard(
                        rideInfo: provider.currentRideInfo!,
                        onCancel: () => _showCancelConfirmation(context, provider),
                        onRate: (rating, comment) => provider.rateDriver(rating, comment),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // "I've Arrived" Button - only after passenger has been picked up
                      if (provider.currentRideInfo!.pickupStatus == PickupStatus.passengerPickedUp &&
                          provider.currentRideInfo!.state != PassengerRideState.completed &&
                          provider.currentRideInfo!.state != PassengerRideState.cancelled)
                        _buildDroppedOffButton(context, provider),
                      
                      const SizedBox(height: 40), // Bottom padding
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _shouldShowVerificationCard(PassengerProvider provider) {
    final status = provider.currentRideInfo!.pickupStatus;
    return status == PickupStatus.pending || status == PickupStatus.driverArrived;
  }

  Widget _buildVerificationSection(PassengerProvider provider) {
    final ride = provider.currentRideInfo?.ride;
    if (ride == null) {
      return const SizedBox.shrink();
    }

    final driverName = provider.currentRideInfo?.driver?.profile.displayName ?? 'your driver';
    final code = ride.verificationCode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isVerificationExpanded = !_isVerificationExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify Your Driver',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share a code with $driverName before you hop in.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isVerificationExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF1A73E8),
                ),
              ],
            ),
          ),
          if (_isVerificationExpanded) ...[
            const SizedBox(height: 12),
            VerificationCodeCard(
              title: 'Verification Code',
              subtitle: 'Give this code to $driverName before entering the car.',
              emptyStateMessage: 'We\'ll generate a code as soon as your driver confirms your request.',
              code: code,
              expiresAt: ride.codeExpiresAt,
              isLoading: _isRefreshingVerification,
              onCopy: code == null ? null : () => _copyVerificationCode(code),
              onRefresh: () => _refreshVerificationCode(ride.id),
              accentColor: const Color(0xFF1A73E8),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _refreshVerificationCode(String rideId) async {
    if (_isRefreshingVerification) return;
    setState(() => _isRefreshingVerification = true);

    try {
      final code = await _rideService.getVerificationCode(rideId);
      if (!mounted) return;
      setState(() => _isRefreshingVerification = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            code != null
                ? 'Verification code updated. Share it with your driver.'
                : 'Still waiting for a verification code from your driver.',
          ),
          backgroundColor: code != null ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshingVerification = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to refresh verification code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyVerificationCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification code copied'),
      ),
    );
  }

  Widget _buildNoActiveRide() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'No Active Ride',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Request a ride to start tracking',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'Find a Ride',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateMapView(PassengerProvider provider) {
    if (!_mapReady || provider.currentRideInfo == null) return;

    final rideInfo = provider.currentRideInfo!;
    final rideId = rideInfo.ride?.id ?? rideInfo.request.id;
    
    // Reset route if this is a different ride
    if (_currentRideId != null && _currentRideId != rideId) {
      _routeLoaded = false;
      _polylines.clear();
    }
    _currentRideId = rideId;
    
    final markers = <Marker>{};
    
    // Add pickup marker
    markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: rideInfo.request.startLocation.coordinates,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: 'Pickup Location',
        snippet: rideInfo.request.startLocation.address,
      ),
    ));
    
    // Add dropoff marker
    markers.add(Marker(
      markerId: const MarkerId('dropoff'),
      position: rideInfo.request.endLocation.coordinates,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: 'Dropoff Location',
        snippet: rideInfo.request.endLocation.address,
      ),
    ));
    
    // Add driver marker if available
    if (rideInfo.driverLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: rideInfo.driverLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: 'Driver',
          snippet: rideInfo.driver?.profile.displayName ?? 'Your Driver',
        ),
      ));
    }
    
    setState(() {
      _markers = markers;
    });
    
    // Load route polyline if not already loaded
    if (!_routeLoaded) {
      _loadRoutePolyline(rideInfo);
    }
    
    // Fit map to show all markers
    _fitMarkersInView();
  }

  Future<void> _loadRoutePolyline(PassengerRideInfo rideInfo) async {
    try {
      final directionsResult = await _directionsService.getDirections(
        origin: rideInfo.request.startLocation.coordinates,
        destination: rideInfo.request.endLocation.coordinates,
        originAddress: rideInfo.request.startLocation.address,
        destinationAddress: rideInfo.request.endLocation.address,
      );

      if (directionsResult != null && directionsResult.polylinePoints.isNotEmpty) {
        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: directionsResult.polylinePoints,
            color: Colors.blue,
            width: 5,
            patterns: [],
          ));
          _routeLoaded = true;
        });
      } else {
        // Fallback to straight line
        _createStraightLinePolyline(rideInfo);
      }
    } catch (e) {
      // Fallback to straight line on error
      _createStraightLinePolyline(rideInfo);
    }
  }

  void _createStraightLinePolyline(PassengerRideInfo rideInfo) {
    setState(() {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [
          rideInfo.request.startLocation.coordinates,
          rideInfo.request.endLocation.coordinates,
        ],
        color: Colors.blue,
        width: 5,
      ));
      _routeLoaded = true;
    });
  }

  void _fitMarkersInView() {
    if (_mapController == null || _markers.isEmpty) return;

    final latLngs = _markers.map((marker) => marker.position).toList();
    
    if (latLngs.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(latLngs.first, 16),
      );
    } else {
      final bounds = _getBounds(latLngs);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }

  LatLngBounds _getBounds(List<LatLng> positions) {
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final pos in positions) {
      minLat = minLat < pos.latitude ? minLat : pos.latitude;
      maxLat = maxLat > pos.latitude ? maxLat : pos.latitude;
      minLng = minLng < pos.longitude ? minLng : pos.longitude;
      maxLng = maxLng > pos.longitude ? maxLng : pos.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  String _getETAText(PassengerRideInfo rideInfo) {
    if (rideInfo.pickupETA != null) {
      return '${rideInfo.pickupETA!.estimatedDuration.inMinutes} min';
    } else if (rideInfo.dropoffETA != null) {
      return '${rideInfo.dropoffETA!.estimatedDuration.inMinutes} min';
    }
    return '';
  }

  String? _getMapStyle() {
    // You can customize the map style here
    return null;
  }

  void _showMessageOptions(BuildContext context, PassengerProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PassengerMessageSheet(provider: provider),
    );
  }

  void _showCancelConfirmation(BuildContext context, PassengerProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text('Are you sure you want to cancel this ride request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Ride'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.cancelRideRequest();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );
  }

  Widget _buildDroppedOffButton(BuildContext context, PassengerProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Text(
            'Have you arrived at your destination?',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _confirmDroppedOff(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'I\'ve Arrived',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardedButton(BuildContext context, PassengerProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Has your driver arrived?',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _confirmBoarded(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'I\'m in the car',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBoarded(PassengerProvider provider) async {
    try {
      await provider.confirmBoarded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enjoy the ride!'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm boarding: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDroppedOff(PassengerProvider provider) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Arrival'),
        content: const Text('Have you successfully arrived at your destination? This will complete your ride.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, I\'ve Arrived'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      try {
        await provider.confirmDroppedOff();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arrival confirmed! Your ride is complete.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm dropoff: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _PassengerMessageSheet extends StatefulWidget {
  final PassengerProvider provider;

  const _PassengerMessageSheet({required this.provider});

  @override
  State<_PassengerMessageSheet> createState() => _PassengerMessageSheetState();
}

class _PassengerMessageSheetState extends State<_PassengerMessageSheet> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final success = await widget.provider.messageDriver(message.trim());
      
      if (success) {
        _messageController.clear();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.provider.errorMessage ?? 'Failed to send message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quickMessages = [
      "I'm waiting at the pickup location",
      "I'm running 5 minutes late",
      "I'm here, where are you?",
      "Thank you for the ride!",
    ];

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Send Message to Driver',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom message input
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _messageController,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                hintStyle: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                ),
              ),
              style: GoogleFonts.inter(),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                setState(() {}); // Update button state
              },
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _sendMessage(value);
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Send button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending || _messageController.text.trim().isEmpty
                  ? null
                  : () => _sendMessage(_messageController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Send Message',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Quick Messages',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 12),

          // Quick messages
          ...quickMessages.map((message) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                onTap: () => _sendMessage(message),
              )),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
