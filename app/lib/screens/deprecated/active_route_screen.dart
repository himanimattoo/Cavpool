import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import 'start_ride_screen.dart'; // for Ride type (both files now in deprecated)

class ActiveRouteScreen extends StatefulWidget {
  final Ride ride;
  const ActiveRouteScreen({super.key, required this.ride});

  @override
  State<ActiveRouteScreen> createState() => _ActiveRouteScreenState();
}

class _ActiveRouteScreenState extends State<ActiveRouteScreen> {
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _positionSub;
  double _distanceRemainingMeters = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _routePoints = widget.ride.routePoints ?? [];
    _distanceRemainingMeters = widget.ride.totalDistanceMeters ?? 0;
    _setupMapData();
    _startLocationStream();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _setupMapData() {
    if (_routePoints.isNotEmpty) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.blueAccent,
        width: 6,
        points: _routePoints,
      ));
      _markers.add(Marker(markerId: const MarkerId('origin'), position: widget.ride.origin, infoWindow: const InfoWindow(title: 'Pickup')));
      _markers.add(Marker(markerId: const MarkerId('destination'), position: widget.ride.destination, infoWindow: InfoWindow(title: 'Destination')));
    }
    setState(() { _isLoading = false; });
    Future.microtask(() => _fitMapToRoute());
  }

  Future<void> _startLocationStream() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final req = await Geolocator.requestPermission();
      if (req == LocationPermission.denied || req == LocationPermission.deniedForever) return;
    }
    _positionSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5))
      .listen((pos) {
        final cur = LatLng(pos.latitude, pos.longitude);
        final dest = widget.ride.destination;
        final meters = Geolocator.distanceBetween(cur.latitude, cur.longitude, dest.latitude, dest.longitude);
        setState(() {
          _distanceRemainingMeters = meters;
          _markers.removeWhere((m) => m.markerId == const MarkerId('current'));
          _markers.add(Marker(markerId: const MarkerId('current'), position: cur, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), infoWindow: const InfoWindow(title: 'You')));
        });
        _mapController?.animateCamera(CameraUpdate.newLatLng(cur));
      });
  }

  Future<void> _fitMapToRoute() async {
    if (_routePoints.isEmpty || _mapController == null) return;
    final lats = _routePoints.map((p) => p.latitude);
    final lngs = _routePoints.map((p) => p.longitude);
    final sw = LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b));
    final ne = LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b));
    final bounds = LatLngBounds(southwest: sw, northeast: ne);
    try {
      await _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } catch (_) { /* ignore if camera not ready */ }
  }

  Future<void> _callForHelp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;
    final contacts = user?.emergencyContacts ?? [];
    if (contacts.isEmpty) {
      await showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('No Emergency Contacts'),
        content: const Text('Add emergency contacts in profile settings.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ));
      return;
    }

    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Emergency Help'),
      content: const Text('Contact emergency services or a saved contact.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () async {
          Navigator.of(context).pop();
          final uri = Uri.parse('tel:911');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        }, child: const Text('Call 911')),
        TextButton(onPressed: () {
          Navigator.of(context).pop();
          _showContacts(contacts);
        }, child: const Text('Contacts')),
      ],
    ));
  }

  void _showContacts(List contacts) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Emergency Contacts'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: contacts.length,
          itemBuilder: (c, i) {
            final item = contacts[i];
            return ListTile(
              title: Text(item.name ?? item.phoneNumber ?? 'Contact'),
              subtitle: Text(item.phoneNumber ?? ''),
              onTap: () async {
                Navigator.of(context).pop();
                final uri = Uri.parse('tel:${item.phoneNumber}');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    ));
  }

  Future<void> _completeRide() async {
    if (!mounted) return;
    await showDialog<void>(context: context, useRootNavigator: true, builder: (_) => AlertDialog(
      title: const Text('Complete Ride'),
      content: const Text('Complete Ride feature coming soon'),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final initial = CameraPosition(target: widget.ride.origin, zoom: 14);
    return Scaffold(
      appBar: AppBar(title: const Text('Active Ride')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: initial,
                  polylines: _polylines,
                  markers: _markers,
                  myLocationEnabled: true,
                  onMapCreated: (c) {
                    _mapController = c;
                    Future.microtask(() => _fitMapToRoute());
                  },
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Card(
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _isLoading
                        ? const Text('Loading route...')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Destination: ${widget.ride.destinationAddress}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Remaining: ${_formatDistance(_distanceRemainingMeters)}'),
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
                      label: const Text('Complete ride'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: _completeRide,
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

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters/1000).toStringAsFixed(1)} km';
    return '${meters.toStringAsFixed(0)} m';
  }
}