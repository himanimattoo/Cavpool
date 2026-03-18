import 'package:flutter/material.dart';
import '../../services/location_service.dart';

class LocationPrivacySettings extends StatefulWidget {
  const LocationPrivacySettings({super.key});

  @override
  State<LocationPrivacySettings> createState() => _LocationPrivacySettingsState();
}

class _LocationPrivacySettingsState extends State<LocationPrivacySettings> {
  final LocationService _locationService = LocationService();
  bool _isLocationSharingEnabled = false;
  bool _isBackgroundTrackingEnabled = false;
  bool _isEmergencyTrackingEnabled = true;
  bool _shareWithEmergencyContacts = true;
  String _permissionStatus = 'Unknown';

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final permissionStatus = await _locationService.requestLocationPermission();
    
    setState(() {
      _isLocationSharingEnabled = _locationService.hasLocationSharingConsent;
      _isBackgroundTrackingEnabled = _locationService.isBackgroundTrackingEnabled;
      _permissionStatus = permissionStatus ? 'Granted' : 'Denied';
    });
  }

  Future<void> _toggleLocationSharing(bool value) async {
    await _locationService.setLocationSharingConsent(value);
    setState(() {
      _isLocationSharingEnabled = value;
    });

    if (!value) {
      _showLocationSharingDisabledDialog();
    }
  }

  Future<void> _toggleBackgroundTracking(bool value) async {
    if (value && !_isLocationSharingEnabled) {
      _showEnableLocationSharingFirst();
      return;
    }

    if (value) {
      final success = await _locationService.startBackgroundLocationTracking();
      if (success) {
        setState(() {
          _isBackgroundTrackingEnabled = true;
        });
      } else {
        _showBackgroundPermissionRequired();
      }
    } else {
      await _locationService.stopBackgroundLocationTracking();
      setState(() {
        _isBackgroundTrackingEnabled = false;
      });
    }
  }

  void _showLocationSharingDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Sharing Disabled'),
        content: const Text(
          'Location sharing has been disabled. This will affect:\n\n'
          '• Emergency response capabilities\n'
          '• Real-time ride tracking\n'
          '• Route deviation detection\n\n'
          'You can re-enable it anytime in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEnableLocationSharingFirst() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Location Sharing'),
        content: const Text(
          'Please enable location sharing first before enabling background tracking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBackgroundPermissionRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Background Location Required'),
        content: const Text(
          'To enable background location tracking, please:\n\n'
          '1. Go to Settings > Apps > CavPool\n'
          '2. Select Permissions > Location\n'
          '3. Choose "Allow all the time"\n\n'
          'This allows us to track your location during rides for safety.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Open app settings
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Privacy Matters',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'CavPool takes your privacy seriously. Your location data is:\n\n'
              '• Only shared during active rides\n'
              '• Encrypted and secured\n'
              '• Deleted after ride completion\n'
              '• Never sold to third parties\n'
              '• Used only for safety and ride management',
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged, {
    Color? iconColor,
    bool enabled = true,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? (value ? Colors.green : Colors.grey),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: enabled ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: enabled ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildPermissionStatus() {
    final isGranted = _permissionStatus == 'Granted';
    
    return Card(
      color: isGranted ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(
          isGranted ? Icons.check_circle : Icons.warning,
          color: isGranted ? Colors.green : Colors.orange,
        ),
        title: Text(
          'Location Permission: $_permissionStatus',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isGranted 
              ? 'App can access your location for rides and emergencies'
              : 'Location access is required for ride sharing and safety features',
        ),
        trailing: !isGranted ? TextButton(
          onPressed: () async {
            await _locationService.requestLocationPermission();
            _loadCurrentSettings();
          },
          child: const Text('Grant'),
        ) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Privacy'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrivacyInfoCard(),
            const SizedBox(height: 16),
            
            _buildPermissionStatus(),
            const SizedBox(height: 16),
            
            Text(
              'Location Sharing Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildSettingCard(
              'Share Location During Rides',
              'Allow emergency contacts to track your location during rides',
              Icons.share_location,
              _isLocationSharingEnabled,
              _toggleLocationSharing,
              enabled: _permissionStatus == 'Granted',
            ),
            
            _buildSettingCard(
              'Background Location Tracking',
              'Continue tracking location even when app is in background',
              Icons.my_location,
              _isBackgroundTrackingEnabled,
              _toggleBackgroundTracking,
              enabled: _isLocationSharingEnabled && _permissionStatus == 'Granted',
            ),
            
            _buildSettingCard(
              'Emergency Location Sharing',
              'Automatically share precise location during emergencies',
              Icons.emergency,
              _isEmergencyTrackingEnabled,
              (value) {
                setState(() {
                  _isEmergencyTrackingEnabled = value;
                });
              },
              iconColor: Colors.red,
              enabled: _isLocationSharingEnabled,
            ),
            
            _buildSettingCard(
              'Share with Emergency Contacts',
              'Allow your emergency contacts to receive location updates',
              Icons.contact_emergency,
              _shareWithEmergencyContacts,
              (value) {
                setState(() {
                  _shareWithEmergencyContacts = value;
                });
              },
              enabled: _isLocationSharingEnabled,
            ),
            
            const SizedBox(height: 24),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.battery_saver, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Battery Optimization',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Our location tracking is optimized to minimize battery usage:\n\n'
                      '• Reduced accuracy when not in emergency\n'
                      '• Smart interval adjustments\n'
                      '• Automatic pausing when stationary\n'
                      '• Location caching to reduce GPS usage',
                      style: TextStyle(height: 1.4),
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