import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/user_model.dart';
import '../../services/safety_service.dart';
import '../../services/location_service.dart';
import '../../providers/auth_provider.dart';

class EmergencyButton extends StatefulWidget {
  final String? rideId;
  final bool showConfirmDialog;
  final EdgeInsets? margin;
  final double? width;

  const EmergencyButton({
    super.key,
    this.rideId,
    this.showConfirmDialog = true,
    this.margin,
    this.width,
  });

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton>
    with TickerProviderStateMixin {
  final SafetyService _safetyService = SafetyService();
  final LocationService _locationService = LocationService();
  bool _isActivated = false;
  bool _isProcessing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _activateEmergency() async {
    if (_isProcessing) return;

    // Extract user before any async operations
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.userModel;

    // Provide haptic feedback
    HapticFeedback.heavyImpact();

    if (widget.showConfirmDialog && !_isActivated) {
      final confirmed = await _showConfirmationDialog();
      if (!confirmed) return;
    }

    setState(() {
      _isProcessing = true;
      _isActivated = true;
    });

    // Start pulsing animation
    _pulseController.repeat(reverse: true);

    try {
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current GPS location
      Position? currentPosition;
      String locationString = 'LOCATION_UNAVAILABLE';
      Map<String, dynamic> additionalContext = {
        'activatedAt': DateTime.now().toIso8601String(),
      };
      
      try {
        currentPosition = await _locationService.getCurrentLocation();
        if (currentPosition != null) {
          locationString = '${currentPosition.latitude},${currentPosition.longitude}';
          additionalContext.addAll({
            'userLocation': locationString,
            'locationAccuracy': currentPosition.accuracy.toString(),
            'locationTimestamp': DateTime.fromMillisecondsSinceEpoch(currentPosition.timestamp.millisecondsSinceEpoch).toIso8601String(),
          });
        } else {
          additionalContext['userLocation'] = locationString;
        }
      } catch (e) {
        debugPrint('Failed to get location for emergency: $e');
        additionalContext['userLocation'] = locationString;
        additionalContext['locationError'] = e.toString();
        // Continue with emergency activation even if location fails
      }

      // Log the emergency activation with GPS coordinates
      final eventId = await _safetyService.logEmergencyButtonActivation(
        userId: currentUser.uid,
        rideId: widget.rideId,
        additionalContext: additionalContext,
      );

      if (eventId != null) {
        // Show emergency actions dialog
        if (mounted) {
          await _showEmergencyActionsDialog(currentUser);
        }
      } else {
        throw Exception('Failed to log emergency event');
      }
    } catch (e) {
      debugPrint('Error activating emergency: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emergency activation failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        // Keep activated state and pulsing for visibility
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emergency, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency Activation'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will immediately:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Log your location and situation'),
            Text('• Notify your emergency contacts'),
            Text('• Alert our safety team'),
            Text('• Provide emergency action options'),
            SizedBox(height: 16),
            Text(
              'Are you sure you want to activate emergency mode?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Activate Emergency'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showEmergencyActionsDialog(UserModel user) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emergency, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency Activated'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                'Emergency mode is now active. Your location has been logged and safety team has been notified.',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose an action:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Emergency Actions
            _buildActionButton(
              icon: Icons.phone,
              text: 'Call 911',
              color: Colors.red,
              onPressed: () => _call('911'),
            ),
            const SizedBox(height: 8),
            
            if (user.emergencyContacts.isNotEmpty)
              _buildActionButton(
                icon: Icons.contact_phone,
                text: 'Call Emergency Contact',
                color: Colors.orange,
                onPressed: () => _showEmergencyContactsDialog(user.emergencyContacts),
              ),
            const SizedBox(height: 8),
            
            _buildActionButton(
              icon: Icons.report,
              text: 'File Safety Report',
              color: Colors.blue,
              onPressed: () => _navigateToSafetyReport(),
            ),
            const SizedBox(height: 8),
            
            _buildActionButton(
              icon: Icons.share_location,
              text: 'Share My Location',
              color: Colors.green,
              onPressed: () => _shareLocation(user),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Future<void> _call(String phoneNumber) async {
    try {
      final uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $phoneNumber';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to make call: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEmergencyContactsDialog(List<EmergencyContact> contacts) async {
    if (contacts.isEmpty) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Contacts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: contacts.map((contact) => ListTile(
            leading: const Icon(Icons.person),
            title: Text(contact.name),
            subtitle: Text('${contact.relationship} - ${contact.phoneNumber}'),
            trailing: IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () {
                Navigator.pop(context);
                _call(contact.phoneNumber);
              },
            ),
          )).toList(),
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

  void _navigateToSafetyReport() {
    Navigator.of(context).pop(); // Close emergency dialog
    Navigator.of(context).pushNamed(
      '/safety/report',
      arguments: {'rideId': widget.rideId},
    );
  }

  Future<void> _shareLocation(UserModel user) async {
    try {
      // Get current location
      final position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get current location. Please check location permissions.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Create Google Maps link
      final mapsUrl = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      final shareText = 'EMERGENCY: I need help! My current location is: $mapsUrl '
          'Shared by ${user.profile.displayName} at ${DateTime.now().toString()}';

      // Create shareable location data
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
        'user': user.profile.displayName,
        'emergency': true,
      };

      // For now, copy to clipboard and show options
      await _showLocationShareOptions(shareText, mapsUrl, locationData);
      
    } catch (e) {
      debugPrint('Error sharing location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showLocationShareOptions(String shareText, String mapsUrl, Map<String, dynamic> locationData) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.share_location, color: Colors.green),
            SizedBox(width: 8),
            Text('Share Your Location'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your location has been captured:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lat: ${locationData['latitude']?.toStringAsFixed(6)}'),
                  Text('Lng: ${locationData['longitude']?.toStringAsFixed(6)}'),
                  Text('Accuracy: ${locationData['accuracy']?.toStringAsFixed(1)}m'),
                  Text('Time: ${DateTime.now().toString().split('.')[0]}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Choose how to share:'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: shareText));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Location copied to clipboard'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy to Clipboard'),
          ),
          TextButton.icon(
            onPressed: () async {
              final uri = Uri.parse(mapsUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.map),
            label: const Text('Open in Maps'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      width: widget.width,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isActivated ? _pulseAnimation.value : 1.0,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _activateEmergency,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      _isActivated ? Icons.emergency : Icons.emergency_outlined,
                      size: 24,
                    ),
              label: Text(
                _isActivated ? 'EMERGENCY ACTIVE' : 'EMERGENCY',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isActivated ? Colors.red.shade900 : Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: _isActivated ? 8 : 2,
              ),
            ),
          );
        },
      ),
    );
  }
}