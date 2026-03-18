import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/ride_sharing_model.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../models/safety_event_model.dart';
import 'directions_service.dart';
import 'safety_service.dart';
import 'notification_delivery_service.dart';

class RideSharingService {
  static final RideSharingService _instance = RideSharingService._internal();
  factory RideSharingService() => _instance;
  RideSharingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _sharedRidesCollection = 'shared_rides';
  final String _emergencyContactsCollection = 'emergency_contacts';
  final String _notificationsCollection = 'ride_sharing_notifications';
  final DirectionsService _directionsService = DirectionsService();
  final SafetyService _safetyService = SafetyService();
  final NotificationDeliveryService _deliveryService = NotificationDeliveryService();

  // Emergency Contact Management

  /// Add or update an emergency contact with verification
  Future<String?> addEmergencyContact({
    required String userId,
    required String name,
    required String phoneNumber,
    String? email,
    required String relationship,
  }) async {
    try {
      final contact = EnhancedEmergencyContact(
        id: '',
        userId: userId,
        name: name.trim(),
        phoneNumber: phoneNumber.trim(),
        email: email?.trim(),
        relationship: relationship.trim(),
        isVerified: false,
        verificationToken: _generateVerificationToken(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection(_emergencyContactsCollection)
          .add(contact.toMap());

      // Send verification message
      await _sendVerificationMessage(contact.copyWith(id: docRef.id));

      debugPrint('Emergency contact added: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding emergency contact: $e');
      return null;
    }
  }

  /// Get all emergency contacts for a user
  Stream<List<EnhancedEmergencyContact>> getEmergencyContacts(String userId) {
    return _firestore
        .collection(_emergencyContactsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EnhancedEmergencyContact.fromFirestore(doc))
          .toList();
    });
  }

  /// Update emergency contact preferences
  Future<bool> updateEmergencyContact(EnhancedEmergencyContact contact) async {
    try {
      await _firestore
          .collection(_emergencyContactsCollection)
          .doc(contact.id)
          .update(contact.copyWith(updatedAt: DateTime.now()).toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating emergency contact: $e');
      return false;
    }
  }

  /// Remove an emergency contact
  Future<bool> removeEmergencyContact(String contactId) async {
    try {
      await _firestore
          .collection(_emergencyContactsCollection)
          .doc(contactId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error removing emergency contact: $e');
      return false;
    }
  }

  /// Verify emergency contact with token
  Future<bool> verifyEmergencyContact(String contactId, String token) async {
    try {
      final doc = await _firestore
          .collection(_emergencyContactsCollection)
          .doc(contactId)
          .get();

      if (doc.exists) {
        final contact = EnhancedEmergencyContact.fromFirestore(doc);
        if (contact.verificationToken == token) {
          await _firestore
              .collection(_emergencyContactsCollection)
              .doc(contactId)
              .update({
            'isVerified': true,
            'verifiedAt': Timestamp.fromDate(DateTime.now()),
            'verificationToken': null,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error verifying emergency contact: $e');
      return false;
    }
  }

  // Ride Sharing Management

  /// Start sharing a ride with emergency contacts
  Future<String?> startRideSharing({
    required String rideId,
    required String userId,
    required List<String> contactIds,
    required RideOffer rideOffer,
    required UserModel driver,
  }) async {
    try {
      final secureToken = _generateSecureTrackingToken();
      
      final sharedRide = SharedRideModel(
        id: '',
        rideId: rideId,
        shareOwnerId: userId,
        sharedWithContactIds: contactIds,
        status: SharedRideStatus.preparing,
        secureTrackingToken: secureToken,
        startTime: rideOffer.departureTime,
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        rideDetails: {
          'pickupLocation': rideOffer.startLocation.toMap(),
          'dropoffLocation': rideOffer.endLocation.toMap(),
          'estimatedDuration': rideOffer.estimatedDuration.inMinutes,
          'estimatedDistance': rideOffer.estimatedDistance,
        },
        driverDetails: {
          'name': driver.profile.displayName,
          'photoURL': driver.profile.photoURL,
          'rating': driver.ratings.averageRating,
          'vehicleInfo': driver.vehicleInfo?.toMap() ?? {},
        },
        currentLocation: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection(_sharedRidesCollection)
          .add(sharedRide.toMap());

      // Send initial notifications to contacts
      await _sendRideStartNotifications(
        sharedRide.copyWith(id: docRef.id),
        contactIds,
      );

      debugPrint('Ride sharing started: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error starting ride sharing: $e');
      return null;
    }
  }

  /// Update ride sharing status
  Future<bool> updateRideStatus(
    String sharedRideId,
    SharedRideStatus status, {
    Map<String, dynamic>? locationUpdate,
    bool? isEmergency,
  }) async {
    try {
      final updateData = {
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (locationUpdate != null) {
        updateData['currentLocation'] = locationUpdate;
      }

      if (isEmergency != null) {
        updateData['isEmergencyActive'] = isEmergency;
      }

      if (status == SharedRideStatus.completed) {
        updateData['endTime'] = Timestamp.fromDate(DateTime.now());
        updateData['expiresAt'] = Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24))
        );
      }

      await _firestore
          .collection(_sharedRidesCollection)
          .doc(sharedRideId)
          .update(updateData);

      // Send status update notifications
      final sharedRide = await getSharedRide(sharedRideId);
      if (sharedRide != null) {
        await _sendStatusUpdateNotifications(sharedRide, status);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating ride status: $e');
      return false;
    }
  }

  /// Get shared ride by ID
  Future<SharedRideModel?> getSharedRide(String sharedRideId) async {
    try {
      final doc = await _firestore
          .collection(_sharedRidesCollection)
          .doc(sharedRideId)
          .get();

      if (doc.exists) {
        return SharedRideModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting shared ride: $e');
      return null;
    }
  }

  /// Get shared ride by tracking token (public access)
  Future<SharedRideModel?> getSharedRideByToken(String trackingToken) async {
    try {
      final query = await _firestore
          .collection(_sharedRidesCollection)
          .where('secureTrackingToken', isEqualTo: trackingToken)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return SharedRideModel.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting shared ride by token: $e');
      return null;
    }
  }

  /// Stream real-time updates for a shared ride
  Stream<SharedRideModel?> streamSharedRide(String sharedRideId) {
    return _firestore
        .collection(_sharedRidesCollection)
        .doc(sharedRideId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return SharedRideModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Stream real-time updates by tracking token (public)
  Stream<SharedRideModel?> streamSharedRideByToken(String trackingToken) {
    return _firestore
        .collection(_sharedRidesCollection)
        .where('secureTrackingToken', isEqualTo: trackingToken)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return SharedRideModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    });
  }

  /// Stop sharing a ride
  Future<bool> stopRideSharing(String sharedRideId) async {
    try {
      await _firestore
          .collection(_sharedRidesCollection)
          .doc(sharedRideId)
          .update({
        'status': SharedRideStatus.completed.name,
        'endTime': Timestamp.fromDate(DateTime.now()),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24))
        ),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Send completion notifications
      final sharedRide = await getSharedRide(sharedRideId);
      if (sharedRide != null) {
        await _sendRideCompletionNotifications(sharedRide);
      }

      return true;
    } catch (e) {
      debugPrint('Error stopping ride sharing: $e');
      return false;
    }
  }

  // Real-time Location Updates

  /// Update current location for shared ride
  Future<bool> updateSharedRideLocation(
    String sharedRideId,
    LatLng location,
    double? speed,
    double? bearing,
  ) async {
    try {
      final locationData = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'speed': speed,
        'bearing': bearing,
      };

      await _firestore
          .collection(_sharedRidesCollection)
          .doc(sharedRideId)
          .update({
        'currentLocation': locationData,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Check for route deviations or extended stops
      await _checkForAnomalousEvents(sharedRideId, location);

      return true;
    } catch (e) {
      debugPrint('Error updating shared ride location: $e');
      return false;
    }
  }

  // Notification Management

  /// Send verification message to emergency contact
  Future<bool> _sendVerificationMessage(EnhancedEmergencyContact contact) async {
    try {
      final message = '''Hello! You have been added as an emergency contact for ${contact.name} on CavPool.

To verify this contact, please reply with: ${contact.verificationToken}

If you did not expect this message or do not know this person, please ignore.

CavPool Safety Team''';

      bool success = false;

      // Send SMS if phone number is available
      if (contact.phoneNumber.isNotEmpty) {
        success = await _deliveryService.sendSMS(
          phoneNumber: contact.phoneNumber,
          message: message,
          emergencyType: 'verification',
        );
      }

      // Send email if email is available (fallback or additional)
      if (contact.email != null && contact.email!.isNotEmpty) {
        final emailSuccess = await _deliveryService.sendEmail(
          email: contact.email!,
          subject: 'CavPool Emergency Contact Verification',
          message: message,
          emergencyType: 'verification',
        );
        
        // If SMS failed but email succeeded, consider it success
        success = success || emailSuccess;
      }

      if (success) {
        debugPrint('Verification message sent successfully to ${contact.name}');
      } else {
        debugPrint('Failed to send verification message to ${contact.name}');
      }

      return success;
    } catch (e) {
      debugPrint('Error sending verification message: $e');
      return false;
    }
  }

  /// Send ride start notifications to emergency contacts
  Future<void> _sendRideStartNotifications(
    SharedRideModel sharedRide,
    List<String> contactIds,
  ) async {
    try {
      for (final contactId in contactIds) {
        final contact = await _getEmergencyContact(contactId);
        if (contact != null && contact.isVerified) {
          final trackingUrl = _generateTrackingUrl(sharedRide.secureTrackingToken);
          
          final message = '${contact.name}\'s ride has started. '
              'Driver: ${sharedRide.driverDetails['name']}. '
              'Track ride: $trackingUrl';

          await _scheduleNotification(
            sharedRideId: sharedRide.id,
            contactId: contactId,
            notificationType: 'started',
            message: message,
            data: {
              'trackingUrl': trackingUrl,
              'driverName': sharedRide.driverDetails['name'],
              'pickupLocation': sharedRide.rideDetails['pickupLocation'],
              'dropoffLocation': sharedRide.rideDetails['dropoffLocation'],
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending ride start notifications: $e');
    }
  }

  /// Send status update notifications
  Future<void> _sendStatusUpdateNotifications(
    SharedRideModel sharedRide,
    SharedRideStatus status,
  ) async {
    try {
      String message = '';
      String notificationType = status.name;

      switch (status) {
        case SharedRideStatus.active:
          message = 'Ride is now active and in progress.';
          break;
        case SharedRideStatus.completed:
          message = 'Ride has been completed safely.';
          break;
        case SharedRideStatus.cancelled:
          message = 'Ride was cancelled.';
          break;
        case SharedRideStatus.emergency:
          message = 'EMERGENCY: Emergency button was activated during ride!';
          notificationType = 'emergency';
          break;
        default:
          return;
      }

      for (final contactId in sharedRide.sharedWithContactIds) {
        await _scheduleNotification(
          sharedRideId: sharedRide.id,
          contactId: contactId,
          notificationType: notificationType,
          message: message,
          data: {
            'status': status.name,
            'isEmergency': status == SharedRideStatus.emergency,
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending status update notifications: $e');
    }
  }

  /// Send ride completion notifications
  Future<void> _sendRideCompletionNotifications(SharedRideModel sharedRide) async {
    try {
      for (final contactId in sharedRide.sharedWithContactIds) {
        final message = 'Ride completed safely. Tracking will be available for 24 more hours.';

        await _scheduleNotification(
          sharedRideId: sharedRide.id,
          contactId: contactId,
          notificationType: 'completed',
          message: message,
          data: {
            'completedAt': DateTime.now().toIso8601String(),
            'expiresAt': sharedRide.expiresAt.toIso8601String(),
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending completion notifications: $e');
    }
  }

  /// Schedule a notification for delivery
  Future<void> _scheduleNotification({
    required String sharedRideId,
    required String contactId,
    required String notificationType,
    required String message,
    required Map<String, dynamic> data,
  }) async {
    try {
      final notification = RideSharingNotification(
        id: '',
        sharedRideId: sharedRideId,
        contactId: contactId,
        notificationType: notificationType,
        message: message,
        data: data,
        scheduledAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(_notificationsCollection)
          .add(notification.toMap());

      // Get emergency contact information for actual delivery
      final contact = await _getEmergencyContact(contactId);
      if (contact != null && contact.isVerified) {
        await _deliverEmergencyNotification(contact, message, notificationType);
      }
      
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  /// Deliver emergency notification to contact
  Future<void> _deliverEmergencyNotification(
    EnhancedEmergencyContact contact,
    String message,
    String notificationType,
  ) async {
    try {
      // Determine emergency type from notification type
      String emergencyType = 'general';
      if (notificationType.contains('emergency') || notificationType.contains('deviation')) {
        emergencyType = 'emergency';
      } else if (notificationType.contains('alert')) {
        emergencyType = 'alert';
      }

      // Send emergency notification (both SMS and email for redundancy)
      final results = await _deliveryService.sendEmergencyNotification(
        phoneNumber: contact.phoneNumber,
        email: contact.email ?? '',
        message: message,
        emergencyType: emergencyType,
      );

      // Log delivery results
      if (results[NotificationDeliveryMethod.sms] == true || 
          results[NotificationDeliveryMethod.email] == true) {
        debugPrint('Emergency notification delivered successfully to ${contact.name}');
      } else {
        debugPrint('Failed to deliver emergency notification to ${contact.name}');
      }

    } catch (e) {
      debugPrint('Error delivering emergency notification: $e');
    }
  }

  // Utility Functions

  /// Generate secure tracking token for public URLs
  String _generateSecureTrackingToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final token = List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return '$token-$timestamp';
  }

  /// Generate verification token for emergency contacts
  String _generateVerificationToken() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString(); // 6-digit code
  }

  /// Generate public tracking URL
  String _generateTrackingUrl(String token) {
    // TODO: Replace with actual domain
    return 'https://cavpool.app/track/$token';
  }

  /// Get emergency contact by ID
  Future<EnhancedEmergencyContact?> _getEmergencyContact(String contactId) async {
    try {
      final doc = await _firestore
          .collection(_emergencyContactsCollection)
          .doc(contactId)
          .get();

      if (doc.exists) {
        return EnhancedEmergencyContact.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting emergency contact: $e');
      return null;
    }
  }

  /// Check for anomalous events (route deviations, extended stops)
  Future<void> _checkForAnomalousEvents(String sharedRideId, LatLng location) async {
    try {
      // Get shared ride data with route information
      final sharedRide = await getSharedRide(sharedRideId);
      if (sharedRide == null) return;

      // Get expected route from ride details
      final pickupLocation = sharedRide.rideDetails['pickupLocation'];
      final dropoffLocation = sharedRide.rideDetails['dropoffLocation'];
      
      if (pickupLocation == null || dropoffLocation == null) {
        debugPrint('Missing route data for anomaly detection');
        return;
      }

      final pickup = LatLng(
        pickupLocation['latitude']?.toDouble() ?? 0.0,
        pickupLocation['longitude']?.toDouble() ?? 0.0,
      );
      final dropoff = LatLng(
        dropoffLocation['latitude']?.toDouble() ?? 0.0,
        dropoffLocation['longitude']?.toDouble() ?? 0.0,
      );

      // Check for route deviation
      await _checkRouteDeviation(sharedRideId, location, pickup, dropoff);
      
      // Check for extended stops
      await _checkExtendedStop(sharedRideId, location);
      
    } catch (e) {
      debugPrint('Error checking for anomalous events: $e');
    }
  }

  /// Check if current location deviates significantly from expected route
  Future<void> _checkRouteDeviation(
    String sharedRideId, 
    LatLng currentLocation, 
    LatLng pickup, 
    LatLng dropoff
  ) async {
    try {
      // Get expected route if not cached
      final cacheKey = 'route_$sharedRideId';
      List<LatLng>? expectedRoute = await _getCachedRoute(cacheKey);
      
      if (expectedRoute == null) {
        // Calculate expected route using directions service
        final directions = await _directionsService.getDirections(
          origin: pickup,
          destination: dropoff,
        );
        
        if (directions != null) {
          expectedRoute = directions.polylinePoints;
          await _cacheRoute(cacheKey, expectedRoute);
        } else {
          debugPrint('Unable to get expected route for deviation detection');
          return;
        }
      }

      // Find closest point on expected route
      double minDistance = double.infinity;
      
      for (int i = 0; i < expectedRoute.length; i++) {
        final distance = _directionsService.calculateDistance(
          currentLocation, 
          expectedRoute[i]
        );
        if (distance < minDistance) {
          minDistance = distance;
        }
      }

      // Define deviation thresholds
      const double warningThreshold = 500; // 500 meters
      const double alertThreshold = 1000; // 1 kilometer
      const double emergencyThreshold = 2000; // 2 kilometers

      // Check deviation severity and take action
      if (minDistance > emergencyThreshold) {
        await _handleSevereDeviation(sharedRideId, currentLocation, minDistance, 'emergency');
      } else if (minDistance > alertThreshold) {
        await _handleSevereDeviation(sharedRideId, currentLocation, minDistance, 'alert');
      } else if (minDistance > warningThreshold) {
        await _handleSevereDeviation(sharedRideId, currentLocation, minDistance, 'warning');
      }

    } catch (e) {
      debugPrint('Error checking route deviation: $e');
    }
  }

  /// Check for extended stops (vehicle not moving for too long)
  Future<void> _checkExtendedStop(String sharedRideId, LatLng location) async {
    try {
      // Get location history for this ride
      final historyDoc = await _firestore
          .collection('ride_location_history')
          .doc(sharedRideId)
          .get();

      List<Map<String, dynamic>> locationHistory = [];
      if (historyDoc.exists) {
        locationHistory = List<Map<String, dynamic>>.from(
          historyDoc.data()?['locations'] ?? []
        );
      }

      // Add current location to history
      final currentLocationData = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      };
      locationHistory.add(currentLocationData);

      // Keep only last 30 location updates (about 5 minutes if updated every 10 seconds)
      if (locationHistory.length > 30) {
        locationHistory = locationHistory.sublist(locationHistory.length - 30);
      }

      // Save updated history
      await _firestore
          .collection('ride_location_history')
          .doc(sharedRideId)
          .set({'locations': locationHistory});

      // Check for extended stop (no movement for extended period)
      if (locationHistory.length >= 10) { // At least 10 data points
        await _analyzeMovementPattern(sharedRideId, locationHistory);
      }

    } catch (e) {
      debugPrint('Error checking extended stop: $e');
    }
  }

  /// Analyze movement pattern to detect extended stops
  Future<void> _analyzeMovementPattern(String sharedRideId, List<Map<String, dynamic>> locationHistory) async {
    try {
      const double stopThreshold = 50; // 50 meters radius considered "stopped"
      const int stopTimeThreshold = 300; // 5 minutes in seconds
      const int emergencyStopThreshold = 600; // 10 minutes for emergency alert

      // Get the most recent 10 locations
      final recentLocations = locationHistory.sublist(
        max(0, locationHistory.length - 10)
      );

      // Check if all recent locations are within stop threshold of each other
      bool isStationary = true;
      double maxDistance = 0;
      
      for (int i = 0; i < recentLocations.length - 1; i++) {
        final loc1 = LatLng(
          recentLocations[i]['latitude']?.toDouble() ?? 0.0,
          recentLocations[i]['longitude']?.toDouble() ?? 0.0,
        );
        final loc2 = LatLng(
          recentLocations[i + 1]['latitude']?.toDouble() ?? 0.0,
          recentLocations[i + 1]['longitude']?.toDouble() ?? 0.0,
        );
        
        final distance = _directionsService.calculateDistance(loc1, loc2);
        maxDistance = max(maxDistance, distance);
        
        if (distance > stopThreshold) {
          isStationary = false;
          break;
        }
      }

      if (isStationary) {
        // Calculate time stopped
        final firstTimestamp = recentLocations.first['timestamp'] as Timestamp;
        final lastTimestamp = recentLocations.last['timestamp'] as Timestamp;
        final stoppedDuration = lastTimestamp.seconds - firstTimestamp.seconds;

        if (stoppedDuration >= emergencyStopThreshold) {
          await _handleExtendedStop(sharedRideId, stoppedDuration, 'emergency');
        } else if (stoppedDuration >= stopTimeThreshold) {
          await _handleExtendedStop(sharedRideId, stoppedDuration, 'warning');
        }
      }

    } catch (e) {
      debugPrint('Error analyzing movement pattern: $e');
    }
  }

  /// Handle severe route deviation
  Future<void> _handleSevereDeviation(
    String sharedRideId, 
    LatLng location, 
    double deviationDistance, 
    String severity
  ) async {
    try {
      final sharedRide = await getSharedRide(sharedRideId);
      if (sharedRide == null) return;

      // Create deviation event record
      await _firestore.collection('route_deviations').add({
        'sharedRideId': sharedRideId,
        'rideId': sharedRide.rideId,
        'userId': sharedRide.shareOwnerId,
        'deviationType': 'route_deviation',
        'severity': severity,
        'deviationDistance': deviationDistance,
        'currentLocation': {
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'status': 'detected',
      });

      // Send notifications based on severity
      if (severity == 'emergency' || severity == 'alert') {
        await _sendDeviationNotifications(sharedRide, deviationDistance, severity);
      }

      // Log safety event for emergency deviations
      if (severity == 'emergency') {
        await _safetyService.createSafetyEvent(
          SafetyEventModel(
            id: '',
            eventType: SafetyEventType.automaticDetection,
            incidentType: SafetyIncidentType.other,
            reporterId: 'system',
            reportedUserId: null,
            rideId: sharedRide.rideId,
            title: 'Severe Route Deviation Detected',
            description: 'Vehicle has deviated ${deviationDistance.toStringAsFixed(0)}m from expected route',
            severity: SafetyEventSeverity.high,
            status: SafetyEventStatus.pending,
            location: SafetyEventLocation(coordinates: location),
            evidence: [],
            metadata: {
              'deviationDistance': deviationDistance,
              'detectionType': 'automated_route_monitoring',
              'sharedRideId': sharedRideId,
            },
            timestamp: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            tags: ['route_deviation', 'automated_detection', severity],
            isAnonymous: false,
            systemData: {
              'autoGenerated': true,
              'sourceService': 'route_monitoring',
            },
          ),
        );
      }

      debugPrint('Route deviation detected: ${deviationDistance.toStringAsFixed(0)}m ($severity)');
      
    } catch (e) {
      debugPrint('Error handling severe deviation: $e');
    }
  }

  /// Handle extended stop detection
  Future<void> _handleExtendedStop(String sharedRideId, int stoppedDuration, String severity) async {
    try {
      final sharedRide = await getSharedRide(sharedRideId);
      if (sharedRide == null) return;

      // Create extended stop event record
      await _firestore.collection('route_deviations').add({
        'sharedRideId': sharedRideId,
        'rideId': sharedRide.rideId,
        'userId': sharedRide.shareOwnerId,
        'deviationType': 'extended_stop',
        'severity': severity,
        'stoppedDuration': stoppedDuration,
        'currentLocation': sharedRide.currentLocation,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'status': 'detected',
      });

      // Send notifications for emergency stops
      if (severity == 'emergency') {
        await _sendExtendedStopNotifications(sharedRide, stoppedDuration);
        
        // Log safety event for emergency stops
        await _safetyService.createSafetyEvent(
          SafetyEventModel(
            id: '',
            eventType: SafetyEventType.automaticDetection,
            incidentType: SafetyIncidentType.other,
            reporterId: 'system',
            reportedUserId: null,
            rideId: sharedRide.rideId,
            title: 'Extended Stop Detected',
            description: 'Vehicle has been stopped for ${(stoppedDuration / 60).toStringAsFixed(1)} minutes',
            severity: SafetyEventSeverity.medium,
            status: SafetyEventStatus.pending,
            location: sharedRide.currentLocation.isNotEmpty 
                ? SafetyEventLocation(
                    coordinates: LatLng(
                      sharedRide.currentLocation['latitude']?.toDouble() ?? 0.0,
                      sharedRide.currentLocation['longitude']?.toDouble() ?? 0.0,
                    )
                  )
                : null,
            evidence: [],
            metadata: {
              'stoppedDuration': stoppedDuration,
              'detectionType': 'automated_stop_monitoring',
              'sharedRideId': sharedRideId,
            },
            timestamp: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            tags: ['extended_stop', 'automated_detection', severity],
            isAnonymous: false,
            systemData: {
              'autoGenerated': true,
              'sourceService': 'route_monitoring',
            },
          ),
        );
      }

      debugPrint('Extended stop detected: ${(stoppedDuration / 60).toStringAsFixed(1)} minutes ($severity)');
      
    } catch (e) {
      debugPrint('Error handling extended stop: $e');
    }
  }

  /// Send deviation notifications to emergency contacts
  Future<void> _sendDeviationNotifications(
    SharedRideModel sharedRide, 
    double deviationDistance, 
    String severity
  ) async {
    try {
      for (final contactId in sharedRide.sharedWithContactIds) {
        final message = severity == 'emergency' 
            ? 'URGENT: ${sharedRide.driverDetails['name']} has deviated significantly from the planned route (${deviationDistance.toStringAsFixed(0)}m off course). Please check on them.'
            : 'ALERT: Route deviation detected for ${sharedRide.driverDetails['name']} (${deviationDistance.toStringAsFixed(0)}m off course).';

        await _scheduleNotification(
          sharedRideId: sharedRide.id,
          contactId: contactId,
          notificationType: 'route_deviation_$severity',
          message: message,
          data: {
            'deviationType': 'route_deviation',
            'severity': severity,
            'deviationDistance': deviationDistance,
            'currentLocation': sharedRide.currentLocation,
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending deviation notifications: $e');
    }
  }

  /// Send extended stop notifications to emergency contacts  
  Future<void> _sendExtendedStopNotifications(
    SharedRideModel sharedRide, 
    int stoppedDuration
  ) async {
    try {
      for (final contactId in sharedRide.sharedWithContactIds) {
        final message = 'ALERT: ${sharedRide.driverDetails['name']} has been stopped for ${(stoppedDuration / 60).toStringAsFixed(1)} minutes during their ride. They may need assistance.';

        await _scheduleNotification(
          sharedRideId: sharedRide.id,
          contactId: contactId,
          notificationType: 'extended_stop_emergency',
          message: message,
          data: {
            'deviationType': 'extended_stop',
            'severity': 'emergency',
            'stoppedDuration': stoppedDuration,
            'currentLocation': sharedRide.currentLocation,
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending extended stop notifications: $e');
    }
  }

  /// Cache route for deviation detection
  Future<void> _cacheRoute(String cacheKey, List<LatLng> route) async {
    try {
      final routeData = route.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
      }).toList();

      await _firestore.collection('cached_routes').doc(cacheKey).set({
        'route': routeData,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      });
    } catch (e) {
      debugPrint('Error caching route: $e');
    }
  }

  /// Get cached route for deviation detection
  Future<List<LatLng>?> _getCachedRoute(String cacheKey) async {
    try {
      final doc = await _firestore.collection('cached_routes').doc(cacheKey).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final expiresAt = data['expiresAt'] as Timestamp;
        
        // Check if cache is still valid
        if (expiresAt.toDate().isAfter(DateTime.now())) {
          final routeData = data['route'] as List<dynamic>;
          return routeData.map((point) => LatLng(
            point['latitude']?.toDouble() ?? 0.0,
            point['longitude']?.toDouble() ?? 0.0,
          )).toList();
        } else {
          // Delete expired cache
          await _firestore.collection('cached_routes').doc(cacheKey).delete();
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting cached route: $e');
      return null;
    }
  }
}