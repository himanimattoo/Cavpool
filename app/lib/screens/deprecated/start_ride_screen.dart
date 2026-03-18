import 'dart:async';
import 'package:flutter/material.dart';
//import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/directions_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import 'active_route_screen.dart'; // new screen

// Simple Ride model for navigation to the screen
class Ride {
  final String id;
  final LatLng origin;
  final LatLng destination;
  final String destinationAddress;
  // optional precomputed route data
  final List<LatLng>? routePoints;
  final double? totalDistanceMeters;
  final int? durationSeconds;
  Ride({
    required this.id,
    required this.origin,
    required this.destination,
    required this.destinationAddress,
    this.routePoints,
    this.totalDistanceMeters,
    this.durationSeconds,
  });
}

class ActiveRideScreen extends StatefulWidget {
  final Ride ride;
  final VoidCallback? onComplete; // hook for completing ride

  const ActiveRideScreen({super.key, required this.ride, this.onComplete});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _positionSub;
  double _distanceRemainingMeters = 0;
  bool _isLoadingRoute = true;

  @override
  void initState() {
    super.initState();
    _initMapData();
    _startLocationStream();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initMapData() async {
    // if the caller already provided route points, use them instead of requesting again
    if (widget.ride.routePoints != null && widget.ride.routePoints!.isNotEmpty) {
      setState(() {
        _routePoints = widget.ride.routePoints!;
        _distanceRemainingMeters = widget.ride.totalDistanceMeters ?? _distanceRemainingMeters;
        _polylines.add(Polyline(polylineId: const PolylineId('route'), color: Colors.blueAccent, width: 6, points: _routePoints));
        _markers.add(Marker(markerId: const MarkerId('origin'), position: widget.ride.origin, infoWindow: const InfoWindow(title: 'Pickup')));
        _markers.add(Marker(markerId: const MarkerId('destination'), position: widget.ride.destination, infoWindow: InfoWindow(title: widget.ride.destinationAddress)));
        _isLoadingRoute = false;
      });
      await Future.delayed(const Duration(milliseconds: 300));
      _fitMapToRoute();
      return;
    }

    // otherwise request directions now (fallback)
    final res = await DirectionsService().getDirections(origin: widget.ride.origin, destination: widget.ride.destination);
    if (res != null) {
      setState(() {
        _routePoints = res.polylinePoints;
        // prefer numeric field if available, else parse string
        _distanceRemainingMeters = (double.tryParse(res.totalDistance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0);
        _polylines.add(Polyline(polylineId: const PolylineId('route'), color: Colors.blueAccent, width: 6, points: _routePoints));
        _markers.add(Marker(markerId: const MarkerId('origin'), position: widget.ride.origin, infoWindow: const InfoWindow(title: 'Pickup')));
        _markers.add(Marker(markerId: const MarkerId('destination'), position: widget.ride.destination, infoWindow: InfoWindow(title: widget.ride.destinationAddress)));
        _isLoadingRoute = false;
      });
      // move camera to show entire route
      await Future.delayed(const Duration(milliseconds: 300));
      _fitMapToRoute();
    } else {
      setState(() { _isLoadingRoute = false; });
    }
  }

  void _startLocationStream() async {
    final hasPerm = await _ensureLocationPermission();
    if (!hasPerm) return;
    _positionSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5))
      .listen((pos) {
        final current = LatLng(pos.latitude, pos.longitude);
        // approximate distance remaining: current -> destination
        final meters = Geolocator.distanceBetween(current.latitude, current.longitude, widget.ride.destination.latitude, widget.ride.destination.longitude);
        setState(() { _distanceRemainingMeters = meters; });
        _updateCurrentMarker(current);
      });
  }

  Future<bool> _ensureLocationPermission() async {
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      final request = await Geolocator.requestPermission();
      return request == LocationPermission.always || request == LocationPermission.whileInUse;
    }
    return status == LocationPermission.always || status == LocationPermission.whileInUse;
  }

  void _updateCurrentMarker(LatLng pos) {
    final cur = Marker(markerId: const MarkerId('current'), position: pos, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), infoWindow: const InfoWindow(title: 'You'));
    setState(() {
      _markers.removeWhere((m) => m.markerId == const MarkerId('current'));
      _markers.add(cur);
    });
    // optionally animate camera to follow
    _mapController.animateCamera(CameraUpdate.newLatLng(pos));
  }

  Future<void> _fitMapToRoute() async {
    if (_routePoints.isEmpty) return;
    final latitudes = _routePoints.map((p) => p.latitude);
    final longitudes = _routePoints.map((p) => p.longitude);
    final sw = LatLng(latitudes.reduce((a,b) => a < b ? a : b), longitudes.reduce((a,b) => a < b ? a : b));
    final ne = LatLng(latitudes.reduce((a,b) => a > b ? a : b), longitudes.reduce((a,b) => a > b ? a : b));
    final bounds = LatLngBounds(southwest: sw, northeast: ne);
    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
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

  Future<void> _startRide() async {
    // Request a route from the Directions/Routes service, then open ActiveRideScreen
    if (!mounted) return;
    // show progress while fetching
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final res = await DirectionsService().getDirections(origin: widget.ride.origin, destination: widget.ride.destination);
      if (!mounted) return;
      Navigator.of(context).pop(); // remove progress dialog

      if (res == null || res.polylinePoints.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not calculate route')));
        return;
      }

      final rideWithRoute = Ride(
        id: widget.ride.id,
        origin: widget.ride.origin,
        destination: widget.ride.destination,
        destinationAddress: widget.ride.destinationAddress,
        routePoints: res.polylinePoints,
        totalDistanceMeters: (double.tryParse(res.totalDistance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0),
        durationSeconds: (int.tryParse(res.totalDuration.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0)
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ActiveRouteScreen(ride: rideWithRoute)),
      );
    } catch (e, st) {
      if (!mounted) return;
      Navigator.of(context).pop(); // remove progress dialog if present
      debugPrint('StartRide route fetch/navigation failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to start ride')));
    }
  }

  String _readableDistance(double meters) {
    if (meters >= 1000) return '${(meters/1000).toStringAsFixed(1)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraPosition(target: widget.ride.origin, zoom: 15);
    return Scaffold(
      appBar: AppBar(title: const Text('Active Ride')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: initialCamera,
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  onMapCreated: (controller) { _mapController = controller; },
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Card(
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _isLoadingRoute ? const Text('Loading route...') :
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Destination: ${widget.ride.destinationAddress}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Remaining: ${_readableDistance(_distanceRemainingMeters)}'),
                          ],
                        ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.call),
                      label: const Text('Call for help'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: _callForHelp,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Start ride'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: _startRide,
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
}