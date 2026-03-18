import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/directions_panel.dart';

// Simple Ride model for navigation to the screen
class Ride {
  final String id;
  final LatLng origin;
  final LatLng destination;
  final String destinationAddress;
  Ride({required this.id, required this.origin, required this.destination, required this.destinationAddress});
}

class ActiveRideScreen extends StatefulWidget {
  final Ride ride;
  final VoidCallback? onComplete; // hook for completing ride

  const ActiveRideScreen({super.key, required this.ride, this.onComplete});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  bool _isNavigationStarted = false;
  bool _showDirectionsPanel = false;

  @override
  void initState() {
    super.initState();
    // Defer navigation initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNavigation();
    });
  }

  @override
  void dispose() {
    // Stop navigation synchronously to prevent callbacks after disposal
    try {
      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.stopNavigation();
    } catch (e) {
      // Ignore errors during disposal
    }
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    
    // Start navigation
    final success = await navigationProvider.startNavigation(
      widget.ride.origin,
      widget.ride.destination,
    );
    
    if (success && mounted) {
      setState(() {
        _isNavigationStarted = true;
      });
      _updateMapWithRoute();
    }
  }

  void _updateMapWithRoute() {
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    final route = navigationProvider.route;
    
    if (route != null) {
      setState(() {
        // Add route polyline
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          color: const Color(0xFF232F3E),
          width: 6,
          points: route.polylinePoints,
        ));
        
        // Add markers
        _markers.clear();
        _markers.add(Marker(
          markerId: const MarkerId('origin'),
          position: widget.ride.origin,
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ));
        _markers.add(Marker(
          markerId: const MarkerId('destination'),
          position: widget.ride.destination,
          infoWindow: InfoWindow(title: widget.ride.destinationAddress),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ));
      });
      
      // Fit map to show route
      Future.delayed(const Duration(milliseconds: 500), _fitMapToRoute);
    }
  }

  void _updateCurrentLocationMarker(LatLng? location) {
    if (location == null || !mounted) return;
    
    try {
      setState(() {
        _markers.removeWhere((m) => m.markerId == const MarkerId('current'));
        _markers.add(Marker(
          markerId: const MarkerId('current'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ));
      });
      
      // Follow user location
      _mapController?.animateCamera(CameraUpdate.newLatLng(location));
    } catch (e) {
      // Ignore errors if widget is disposed
    }
  }

  Future<void> _fitMapToRoute() async {
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    final route = navigationProvider.route;
    
    if (route == null || route.polylinePoints.isEmpty) return;
    
    final points = route.polylinePoints;
    final latitudes = points.map((p) => p.latitude);
    final longitudes = points.map((p) => p.longitude);
    
    final sw = LatLng(
      latitudes.reduce((a, b) => a < b ? a : b),
      longitudes.reduce((a, b) => a < b ? a : b),
    );
    final ne = LatLng(
      latitudes.reduce((a, b) => a > b ? a : b),
      longitudes.reduce((a, b) => a > b ? a : b),
    );
    
    final bounds = LatLngBounds(southwest: sw, northeast: ne);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  Future<void> _callForHelp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = authProvider.userModel;
    
    final emergencyContacts = userModel?.emergencyContacts ?? [];
    
    if (emergencyContacts.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No Emergency Contacts'),
          content: const Text('Please add emergency contacts in your profile settings before using this feature.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Emergency Help'),
        content: const Text('Who would you like to contact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final uri = Uri.parse('tel:911');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            child: const Text('Call 911'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEmergencyContactsList(emergencyContacts);
            },
            child: const Text('Emergency Contacts'),
          ),
        ],
      ),
    );
  }
  
  void _showEmergencyContactsList(List<EmergencyContact> contacts) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Emergency Contacts'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(contact.name),
                subtitle: Text('${contact.relationship} • ${contact.phoneNumber}'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final uri = Uri.parse('tel:${contact.phoneNumber}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeRide() async {
    // Show a dialog on the root navigator and surface any error as a SnackBar.
    if (!mounted) return;
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (context) => AlertDialog(
          title: const Text('Start Ride'),
          content: const Text('Start Ride feature coming soon'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e, st) {
      debugPrint('CompleteRide dialog error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start Ride feature coming soon')),
      );
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraPosition(target: widget.ride.origin, zoom: 15);
    
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, child) {
        // Update current location marker when location changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _updateCurrentLocationMarker(navigationProvider.currentLocation);
          }
        });
        
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Active Ride',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF232F3E),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(
                  navigationProvider.voiceEnabled ? Icons.volume_up : Icons.volume_off,
                ),
                onPressed: () {
                  navigationProvider.setVoiceEnabled(!navigationProvider.voiceEnabled);
                },
              ),
              IconButton(
                icon: Icon(
                  _showDirectionsPanel ? Icons.map : Icons.list,
                ),
                onPressed: () {
                  setState(() {
                    _showDirectionsPanel = !_showDirectionsPanel;
                  });
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Navigation info bar
              if (_isNavigationStarted) _buildNavigationInfoBar(navigationProvider),
              
              // Map and directions
              Expanded(
                child: Stack(
                  children: [
                    // Google Map
                    GoogleMap(
                      initialCameraPosition: initialCamera,
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    ),
                    
                    // Current step info overlay
                    if (navigationProvider.currentStep != null)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: _buildCurrentStepCard(navigationProvider),
                      ),
                    
                    // Directions panel overlay
                    if (_showDirectionsPanel && navigationProvider.steps.isNotEmpty)
                      Positioned(
                        top: 100,
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: DirectionsPanel(
                          steps: navigationProvider.steps,
                          onClose: () {
                            setState(() {
                              _showDirectionsPanel = false;
                            });
                          },
                        ),
                      ),
                    
                    // My location button
                    Positioned(
                      bottom: 100,
                      right: 16,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.white,
                        onPressed: () {
                          if (navigationProvider.currentLocation != null) {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLng(navigationProvider.currentLocation!),
                            );
                          }
                        },
                        child: const Icon(Icons.my_location, color: Color(0xFF232F3E)),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action buttons
              SafeArea(
                child: _buildActionButtons(navigationProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavigationInfoBar(NavigationProvider navigationProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF232F3E),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distance: ${_formatDistance(navigationProvider.remainingDistanceMeters)}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'ETA: ${_formatDuration(navigationProvider.remainingDuration)}',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE57200),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${(navigationProvider.progressPercentage * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepCard(NavigationProvider navigationProvider) {
    final currentStep = navigationProvider.currentStep!;
    final cleanInstruction = currentStep.instruction
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
    
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getManeuverIcon(currentStep.maneuver),
                  color: const Color(0xFF232F3E),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cleanInstruction,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'In ${_formatDistance(navigationProvider.distanceToNextStep)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFFE57200),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  'Step ${navigationProvider.currentStepIndex + 1}/${navigationProvider.steps.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(NavigationProvider navigationProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.call),
              label: const Text('Emergency'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _callForHelp,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(
                navigationProvider.state == NavigationState.completed
                    ? Icons.check
                    : Icons.stop,
              ),
              label: Text(
                navigationProvider.state == NavigationState.completed
                    ? 'Complete'
                    : 'End Navigation',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: navigationProvider.state == NavigationState.completed
                    ? Colors.green
                    : const Color(0xFFE57200),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _handleNavigationAction(navigationProvider),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getManeuverIcon(String maneuver) {
    switch (maneuver.toLowerCase()) {
      case 'turn-left':
      case 'turn-slight-left':
        return Icons.turn_left;
      case 'turn-right':
      case 'turn-slight-right':
        return Icons.turn_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'uturn-left':
      case 'uturn-right':
        return Icons.u_turn_left;
      case 'straight':
        return Icons.straight;
      case 'ramp-left':
      case 'merge':
        return Icons.merge;
      case 'ramp-right':
        return Icons.ramp_right;
      case 'roundabout-left':
      case 'roundabout-right':
        return Icons.roundabout_right;
      default:
        return Icons.navigation;
    }
  }

  Future<void> _handleNavigationAction(NavigationProvider navigationProvider) async {
    if (!mounted) return;
    
    if (navigationProvider.state == NavigationState.completed) {
      await _completeRide();
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End Navigation'),
          content: const Text('Are you sure you want to end navigation?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('End'),
            ),
          ],
        ),
      );
      
      if (confirmed == true && mounted) {
        await navigationProvider.stopNavigation();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }
}