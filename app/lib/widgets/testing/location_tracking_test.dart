import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';
import '../../services/live_location_service.dart';
/// Test widget to verify location tracking functionality
/// Use this for testing the real-time location tracking features
class LocationTrackingTest extends StatefulWidget {
  const LocationTrackingTest({super.key});

  @override
  State<LocationTrackingTest> createState() => _LocationTrackingTestState();
}

class _LocationTrackingTestState extends State<LocationTrackingTest> {
  final LocationService _locationService = LocationService();
  final LiveLocationService _liveLocationService = LiveLocationService();
  
  Map<String, dynamic> _privacyStatus = {};
  Map<String, dynamic> _trackingStatus = {};
  String _locationStatus = 'Not started';
  LatLng? _currentLocation;
  final String _currentUserId = 'test_user_123';
  final List<String> _testEmergencyContacts = ['contact_1', 'contact_2'];

  @override
  void initState() {
    super.initState();
    _updateStatus();
  }

  void _updateStatus() {
    setState(() {
      _privacyStatus = _locationService.getPrivacyStatus();
      _trackingStatus = _liveLocationService.getTrackingStatus();
    });
  }

  Future<void> _requestPermissions() async {
    final granted = await _locationService.requestLocationPermission();
    setState(() {
      _locationStatus = granted ? 'Permission granted' : 'Permission denied';
    });
    _updateStatus();
  }

  Future<void> _requestBackgroundPermission() async {
    final granted = await _locationService.requestBackgroundLocationPermission();
    setState(() {
      _locationStatus = granted ? 'Background permission granted' : 'Background permission required';
    });
    _updateStatus();
  }

  Future<void> _setLocationConsent(bool consent) async {
    await _locationService.setLocationSharingConsent(consent);
    setState(() {
      _locationStatus = consent ? 'Location sharing consent granted' : 'Location sharing consent revoked';
    });
    _updateStatus();
  }

  Future<void> _startBackgroundTracking() async {
    final success = await _locationService.startBackgroundLocationTracking();
    setState(() {
      _locationStatus = success ? 'Background tracking started' : 'Failed to start background tracking';
    });
    _updateStatus();
  }

  Future<void> _stopBackgroundTracking() async {
    await _locationService.stopBackgroundLocationTracking();
    setState(() {
      _locationStatus = 'Background tracking stopped';
    });
    _updateStatus();
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _locationStatus = 'Location obtained: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });
    } else {
      setState(() {
        _locationStatus = 'Failed to get current location';
      });
    }
  }

  Future<void> _startLocationSharing() async {
    await _liveLocationService.startLocationSharing(
      userId: _currentUserId,
      rideId: 'test_ride_123',
      emergencyContactIds: _testEmergencyContacts,
      updateInterval: const Duration(seconds: 15),
    );
    
    setState(() {
      _locationStatus = 'Live location sharing started';
    });
    _updateStatus();
  }

  Future<void> _startEmergencySharing() async {
    await _liveLocationService.startLocationSharing(
      userId: _currentUserId,
      rideId: 'emergency_test_456',
      emergencyContactIds: _testEmergencyContacts,
      updateInterval: const Duration(seconds: 10),
      isEmergencyMode: true,
    );
    
    setState(() {
      _locationStatus = 'Emergency location sharing started';
    });
    _updateStatus();
  }

  Future<void> _activateEmergencyMode() async {
    await _liveLocationService.activateEmergencyMode();
    setState(() {
      _locationStatus = 'Emergency mode activated';
    });
    _updateStatus();
  }

  Future<void> _stopLocationSharing() async {
    await _liveLocationService.stopLocationSharing();
    setState(() {
      _locationStatus = 'Location sharing stopped';
    });
    _updateStatus();
  }

  Widget _buildStatusCard(String title, Map<String, dynamic> status) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...status.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text('${entry.key}: '),
                  Flexible(
                    child: Text(
                      entry.value.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(entry.value),
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(dynamic value) {
    if (value is bool) {
      return value ? Colors.green : Colors.red;
    } else if (value is String) {
      if (value.toLowerCase().contains('grant') || 
          value.toLowerCase().contains('true') ||
          value.toLowerCase().contains('active')) {
        return Colors.green;
      } else if (value.toLowerCase().contains('denied') || 
                 value.toLowerCase().contains('false')) {
        return Colors.red;
      }
    }
    return Colors.black87;
  }

  Widget _buildActionButton(String text, VoidCallback onPressed, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
          ),
          child: Text(text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracking Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'Status: $_locationStatus',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),

            // Current Location
            if (_currentLocation != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}'),
                      Text('Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Privacy Status
            _buildStatusCard('Privacy Status', _privacyStatus),
            const SizedBox(height: 16),

            // Tracking Status
            _buildStatusCard('Live Tracking Status', _trackingStatus),
            const SizedBox(height: 16),

            // Test Actions
            const Text(
              'Test Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildActionButton('Request Location Permission', _requestPermissions),
            _buildActionButton('Request Background Permission', _requestBackgroundPermission),
            _buildActionButton('Grant Location Consent', () => _setLocationConsent(true), color: Colors.green),
            _buildActionButton('Revoke Location Consent', () => _setLocationConsent(false), color: Colors.red),
            _buildActionButton('Start Background Tracking', _startBackgroundTracking),
            _buildActionButton('Stop Background Tracking', _stopBackgroundTracking),
            _buildActionButton('Get Current Location', _getCurrentLocation),

            const Divider(height: 32),
            
            const Text(
              'Live Location Sharing Tests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildActionButton('Start Normal Location Sharing', _startLocationSharing, color: Colors.blue),
            _buildActionButton('Start Emergency Location Sharing', _startEmergencySharing, color: Colors.orange),
            _buildActionButton('Activate Emergency Mode', _activateEmergencyMode, color: Colors.red),
            _buildActionButton('Stop Location Sharing', _stopLocationSharing),

            const SizedBox(height: 24),
            
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Test Configuration:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Test User ID: test_user_123'),
                    Text('Test Ride ID: test_ride_123'),
                    Text('Emergency Contacts: contact_1, contact_2'),
                    SizedBox(height: 8),
                    Text(
                      'Note: This is a test interface for verifying location tracking functionality. '
                      'Check Firestore collections for actual data updates.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}