import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import '../models/ride_model.dart';
import 'location_service.dart';

class LiveLocationUpdate {
  final String userId;
  final LatLng coordinates;
  final DateTime timestamp;
  final double? speed;
  final double? heading;
  final String? rideId;

  LiveLocationUpdate({
    required this.userId,
    required this.coordinates,
    required this.timestamp,
    this.speed,
    this.heading,
    this.rideId,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'coordinates': {
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude,
      },
      'timestamp': Timestamp.fromDate(timestamp),
      'speed': speed,
      'heading': heading,
      'rideId': rideId,
    };
  }

  factory LiveLocationUpdate.fromMap(Map<String, dynamic> map) {
    return LiveLocationUpdate(
      userId: map['userId'] ?? '',
      coordinates: LatLng(
        (map['coordinates']['latitude'] ?? 0.0).toDouble(),
        (map['coordinates']['longitude'] ?? 0.0).toDouble(),
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      speed: map['speed']?.toDouble(),
      heading: map['heading']?.toDouble(),
      rideId: map['rideId'],
    );
  }
}

class LiveLocationService {
  static final LiveLocationService _instance = LiveLocationService._internal();
  factory LiveLocationService() => _instance;
  LiveLocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  final Logger _logger = Logger();

  StreamSubscription<Position>? _locationStreamSubscription;
  Timer? _locationUpdateTimer;
  Timer? _emergencyContactUpdateTimer;
  String? _currentRideId;
  String? _currentUserId;
  bool _isSharing = false;
  bool _isEmergencyMode = false;
  List<String> _emergencyContactIds = [];

  CollectionReference get _liveLocationsCollection => 
      _firestore.collection('live_locations');

  Future<void> startLocationSharing({
    required String userId,
    String? rideId,
    Duration updateInterval = const Duration(seconds: 10),
    List<String>? emergencyContactIds,
    bool isEmergencyMode = false,
  }) async {
    try {
      _logger.i('Starting location sharing for user: $userId');
      
      if (_isSharing) {
        await stopLocationSharing();
      }

      _currentRideId = rideId;
      _currentUserId = userId;
      _isSharing = true;
      _isEmergencyMode = isEmergencyMode;
      _emergencyContactIds = emergencyContactIds ?? [];

      // Use emergency location stream if in emergency mode
      final locationStream = _isEmergencyMode 
          ? _locationService.getLocationStream(
              accuracy: LocationAccuracy.best,
              distanceFilter: 5,
              isEmergency: true,
            )
          : _locationService.getLocationStream();

      _locationStreamSubscription = locationStream.listen(
        (position) async {
          if (_isSharing) {
            await _updateLocation(
              userId: userId,
              position: position,
              rideId: _currentRideId,
            );
          }
        },
        onError: (error) {
          _logger.e('Location stream error: $error');
        },
      );

      _locationUpdateTimer = Timer.periodic(updateInterval, (timer) {
        if (!_isSharing) {
          timer.cancel();
        }
      });

      // Start emergency contact updates if we have contacts
      if (_emergencyContactIds.isNotEmpty) {
        await _startEmergencyContactUpdates();
      }

      _logger.i('Location sharing started successfully');
    } catch (e) {
      _logger.e('Error starting location sharing: $e');
      _isSharing = false;
      rethrow;
    }
  }

  Future<void> stopLocationSharing() async {
    try {
      _logger.i('Stopping location sharing');
      
      _isSharing = false;
      _currentRideId = null;
      _currentUserId = null;
      _isEmergencyMode = false;
      _emergencyContactIds.clear();
      
      await _locationStreamSubscription?.cancel();
      _locationStreamSubscription = null;
      
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = null;
      
      _emergencyContactUpdateTimer?.cancel();
      _emergencyContactUpdateTimer = null;
      
      _logger.i('Location sharing stopped');
    } catch (e) {
      _logger.e('Error stopping location sharing: $e');
    }
  }

  Future<void> _updateLocation({
    required String userId,
    required Position position,
    String? rideId,
  }) async {
    try {
      final locationUpdate = LiveLocationUpdate(
        userId: userId,
        coordinates: LatLng(position.latitude, position.longitude),
        timestamp: DateTime.now(),
        speed: position.speed,
        heading: position.heading,
        rideId: rideId,
      );

      await _liveLocationsCollection.doc(userId).set(
        locationUpdate.toMap(),
        SetOptions(merge: true),
      );

      _logger.d('Location updated for user: $userId');
    } catch (e) {
      _logger.e('Error updating location: $e');
    }
  }

  Stream<LiveLocationUpdate?> getDriverLocationStream(String driverId) {
    try {
      return _liveLocationsCollection
          .doc(driverId)
          .snapshots()
          .map((doc) {
        if (doc.exists && doc.data() != null) {
          return LiveLocationUpdate.fromMap(doc.data() as Map<String, dynamic>);
        }
        return null;
      });
    } catch (e) {
      _logger.e('Error getting driver location stream: $e');
      return Stream.value(null);
    }
  }

  Stream<Map<String, LiveLocationUpdate>> getRideParticipantsLocationStream(
      RideOffer ride) {
    try {
      final participantIds = [ride.driverId, ...ride.passengerIds];
      
      return _liveLocationsCollection
          .where('userId', whereIn: participantIds)
          .where('rideId', isEqualTo: ride.id)
          .snapshots()
          .map((snapshot) {
        final locationMap = <String, LiveLocationUpdate>{};
        
        for (final doc in snapshot.docs) {
          if (doc.exists && doc.data() != null) {
            final location = LiveLocationUpdate.fromMap(
              doc.data() as Map<String, dynamic>
            );
            locationMap[location.userId] = location;
          }
        }
        
        return locationMap;
      });
    } catch (e) {
      _logger.e('Error getting ride participants location stream: $e');
      return Stream.value({});
    }
  }

  Future<LiveLocationUpdate?> getLastKnownLocation(String userId) async {
    try {
      final doc = await _liveLocationsCollection.doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        return LiveLocationUpdate.fromMap(doc.data() as Map<String, dynamic>);
      }
      
      return null;
    } catch (e) {
      _logger.e('Error getting last known location: $e');
      return null;
    }
  }

  Future<void> clearLocationData(String userId) async {
    try {
      await _liveLocationsCollection.doc(userId).delete();
      _logger.i('Location data cleared for user: $userId');
    } catch (e) {
      _logger.e('Error clearing location data: $e');
    }
  }

  /// Start emergency contact location updates
  Future<void> _startEmergencyContactUpdates() async {
    try {
      _logger.i('Starting emergency contact updates for ${_emergencyContactIds.length} contacts');
      
      // Send initial location to emergency contacts
      await _notifyEmergencyContacts(isInitial: true);
      
      // Set up periodic updates for emergency contacts (more frequent)
      final emergencyUpdateInterval = _isEmergencyMode 
          ? const Duration(seconds: 30) 
          : const Duration(minutes: 2);
          
      _emergencyContactUpdateTimer = Timer.periodic(emergencyUpdateInterval, (timer) async {
        if (_isSharing && _emergencyContactIds.isNotEmpty) {
          await _notifyEmergencyContacts();
        } else {
          timer.cancel();
        }
      });
      
    } catch (e) {
      _logger.e('Error starting emergency contact updates: $e');
    }
  }

  /// Notify emergency contacts with current location
  Future<void> _notifyEmergencyContacts({bool isInitial = false}) async {
    try {
      if (_currentUserId == null) return;
      
      final lastLocation = await getLastKnownLocation(_currentUserId!);
      if (lastLocation == null) return;
      
      final locationString = 'https://maps.google.com/?q=${lastLocation.coordinates.latitude},${lastLocation.coordinates.longitude}';
      final timeString = DateTime.now().toString().split('.')[0];
      
      String message;
      if (isInitial) {
        if (_isEmergencyMode) {
          message = '''🚨 EMERGENCY ALERT 🚨

Your emergency contact has activated emergency mode and is sharing their location with you.

Current Location: $locationString
Time: $timeString
${_currentRideId != null ? 'During ride: $_currentRideId' : 'Not during active ride'}

You will receive regular location updates until the emergency is resolved.

This is an automated safety notification from CavPool.''';
        } else {
          message = '''📍 Ride Location Sharing Started

Your contact has started sharing their location during a ride.

Current Location: $locationString  
Time: $timeString
Ride ID: $_currentRideId

You will receive periodic location updates for safety.

CavPool Safety Team''';
        }
      } else {
        message = '''📍 Location Update

Time: $timeString
Location: $locationString
${_currentRideId != null ? 'Ride: $_currentRideId' : ''}

${_isEmergencyMode ? '🚨 Emergency mode active' : 'Regular location update'}''';
      }
      
      // Send notifications to all emergency contacts
      for (final contactId in _emergencyContactIds) {
        try {
          // Create a direct notification record for emergency contacts
          await _firestore.collection('emergency_contact_notifications').add({
            'sharedRideId': _currentRideId ?? 'location_sharing',
            'contactId': contactId,
            'notificationType': _isEmergencyMode ? 'emergency_location' : 'location_update',
            'message': message,
            'data': {
              'location': {
                'latitude': lastLocation.coordinates.latitude,
                'longitude': lastLocation.coordinates.longitude,
              },
              'timestamp': lastLocation.timestamp.toIso8601String(),
              'isEmergency': _isEmergencyMode,
              'isInitialUpdate': isInitial,
            },
            'createdAt': Timestamp.fromDate(DateTime.now()),
            'status': 'pending',
          });
        } catch (contactError) {
          _logger.e('Error notifying contact $contactId: $contactError');
        }
      }
      
      _logger.d('Emergency contacts notified: ${_emergencyContactIds.length}');
      
    } catch (e) {
      _logger.e('Error notifying emergency contacts: $e');
    }
  }

  /// Activate emergency mode for enhanced tracking
  Future<void> activateEmergencyMode() async {
    if (!_isSharing || _isEmergencyMode) return;
    
    try {
      _logger.i('Activating emergency mode for location sharing');
      _isEmergencyMode = true;
      
      // Restart with emergency settings
      await stopLocationSharing();
      await startLocationSharing(
        userId: _currentUserId!,
        rideId: _currentRideId,
        updateInterval: const Duration(seconds: 10), // More frequent updates
        emergencyContactIds: _emergencyContactIds,
        isEmergencyMode: true,
      );
      
    } catch (e) {
      _logger.e('Error activating emergency mode: $e');
    }
  }

  /// Add emergency contacts to active sharing session
  Future<void> addEmergencyContacts(List<String> contactIds) async {
    try {
      _emergencyContactIds.addAll(contactIds);
      _emergencyContactIds = _emergencyContactIds.toSet().toList(); // Remove duplicates
      
      if (_isSharing) {
        await _startEmergencyContactUpdates();
      }
      
      _logger.i('Added ${contactIds.length} emergency contacts. Total: ${_emergencyContactIds.length}');
    } catch (e) {
      _logger.e('Error adding emergency contacts: $e');
    }
  }

  /// Remove emergency contacts from active sharing session
  Future<void> removeEmergencyContacts(List<String> contactIds) async {
    try {
      _emergencyContactIds.removeWhere((id) => contactIds.contains(id));
      _logger.i('Removed ${contactIds.length} emergency contacts. Remaining: ${_emergencyContactIds.length}');
    } catch (e) {
      _logger.e('Error removing emergency contacts: $e');
    }
  }

  /// Get current tracking status
  Map<String, dynamic> getTrackingStatus() {
    return {
      'isSharing': _isSharing,
      'isEmergencyMode': _isEmergencyMode,
      'currentUserId': _currentUserId,
      'currentRideId': _currentRideId,
      'emergencyContactsCount': _emergencyContactIds.length,
      'hasLocationConsent': _locationService.hasLocationSharingConsent,
      'backgroundTrackingEnabled': _locationService.isBackgroundTrackingEnabled,
    };
  }

  bool get isSharing => _isSharing;
  bool get isEmergencyMode => _isEmergencyMode;
  String? get currentRideId => _currentRideId;
  String? get currentUserId => _currentUserId;
  List<String> get emergencyContactIds => List.unmodifiable(_emergencyContactIds);
}