import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final Logger _logger = Logger();
  
  // Privacy and permission management
  bool _hasUserConsentForSharing = false;
  bool _isBackgroundTrackingEnabled = false;
  Timer? _backgroundLocationTimer;
  StreamSubscription<Position>? _backgroundLocationSubscription;

  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.w('Location services are disabled.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _logger.w('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.e('Location permissions are permanently denied, we cannot request permissions.');
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _logger.i('Current location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      _logger.e('Error getting location: $e');
      return null;
    }
  }

  /// Request enhanced permissions for background location tracking
  Future<bool> requestBackgroundLocationPermission() async {
    try {
      // First get basic location permission
      final hasBasicPermission = await requestLocationPermission();
      if (!hasBasicPermission) {
        return false;
      }

      // Check for always location permission (background)
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) {
        _logger.w('Background location permission not granted. User will need to enable "Always" in settings.');
        return false;
      }

      _logger.i('Background location permission granted');
      return true;
    } catch (e) {
      _logger.e('Error requesting background location permission: $e');
      return false;
    }
  }

  /// Set user consent for location sharing
  Future<void> setLocationSharingConsent(bool consent) async {
    _hasUserConsentForSharing = consent;
    _logger.i('Location sharing consent set to: $consent');
    
    if (!consent && _isBackgroundTrackingEnabled) {
      await stopBackgroundLocationTracking();
    }
  }

  /// Start background location tracking with battery optimization
  Future<bool> startBackgroundLocationTracking({
    Duration updateInterval = const Duration(minutes: 2),
    LocationAccuracy accuracy = LocationAccuracy.medium,
    int distanceFilter = 50, // meters
  }) async {
    try {
      if (!_hasUserConsentForSharing) {
        _logger.w('Cannot start background tracking: user consent not granted');
        return false;
      }

      final hasPermission = await requestBackgroundLocationPermission();
      if (!hasPermission) {
        return false;
      }

      if (_isBackgroundTrackingEnabled) {
        await stopBackgroundLocationTracking();
      }

      _logger.i('Starting background location tracking');
      
      final locationSettings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );

      _backgroundLocationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) {
          _logger.d('Background location update: ${position.latitude}, ${position.longitude}');
        },
        onError: (error) {
          _logger.e('Background location stream error: $error');
        },
      );

      // Additional timer for periodic updates even when not moving much
      _backgroundLocationTimer = Timer.periodic(updateInterval, (timer) async {
        if (_isBackgroundTrackingEnabled) {
          try {
            final position = await getCurrentLocation();
            if (position != null) {
              _logger.d('Periodic background location: ${position.latitude}, ${position.longitude}');
            }
          } catch (e) {
            _logger.e('Error in periodic background location: $e');
          }
        } else {
          timer.cancel();
        }
      });

      _isBackgroundTrackingEnabled = true;
      _logger.i('Background location tracking started successfully');
      return true;

    } catch (e) {
      _logger.e('Error starting background location tracking: $e');
      return false;
    }
  }

  /// Stop background location tracking
  Future<void> stopBackgroundLocationTracking() async {
    try {
      _logger.i('Stopping background location tracking');
      
      _isBackgroundTrackingEnabled = false;
      
      await _backgroundLocationSubscription?.cancel();
      _backgroundLocationSubscription = null;
      
      _backgroundLocationTimer?.cancel();
      _backgroundLocationTimer = null;
      
      _logger.i('Background location tracking stopped');
    } catch (e) {
      _logger.e('Error stopping background location tracking: $e');
    }
  }

  /// Get optimized location stream based on context
  Stream<Position> getLocationStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
    bool isEmergency = false,
  }) {
    // Use higher accuracy and more frequent updates for emergencies
    if (isEmergency) {
      return Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5, // 5 meters for emergency
        ),
      );
    }

    // Normal tracking with battery optimization
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Get battery-optimized location for routine updates
  Future<Position?> getBatteryOptimizedLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      Position position = await Geolocator.getLastKnownPosition() ?? 
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      
      return position;
    } catch (e) {
      _logger.e('Error getting battery optimized location: $e');
      return null;
    }
  }

  /// Check if background location is available and enabled
  bool get isBackgroundTrackingEnabled => _isBackgroundTrackingEnabled;
  bool get hasLocationSharingConsent => _hasUserConsentForSharing;

  /// Get location sharing privacy status
  Map<String, dynamic> getPrivacyStatus() {
    return {
      'hasUserConsent': _hasUserConsentForSharing,
      'backgroundTrackingEnabled': _isBackgroundTrackingEnabled,
      'permissionStatus': Geolocator.checkPermission().toString(),
      'serviceEnabled': Geolocator.isLocationServiceEnabled(),
    };
  }

  /// Clean up resources
  void dispose() {
    stopBackgroundLocationTracking();
  }
}