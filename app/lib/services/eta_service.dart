import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'live_location_service.dart';

class ETAUpdate {
  final Duration estimatedDuration;
  final double distanceRemaining;
  final DateTime updatedAt;
  final String? trafficCondition;

  ETAUpdate({
    required this.estimatedDuration,
    required this.distanceRemaining,
    required this.updatedAt,
    this.trafficCondition,
  });

  Map<String, dynamic> toMap() {
    return {
      'estimatedDuration': estimatedDuration.inMinutes,
      'distanceRemaining': distanceRemaining,
      'updatedAt': updatedAt.toIso8601String(),
      'trafficCondition': trafficCondition,
    };
  }

  factory ETAUpdate.fromMap(Map<String, dynamic> map) {
    return ETAUpdate(
      estimatedDuration: Duration(minutes: map['estimatedDuration'] ?? 0),
      distanceRemaining: (map['distanceRemaining'] ?? 0.0).toDouble(),
      updatedAt: DateTime.parse(map['updatedAt']),
      trafficCondition: map['trafficCondition'],
    );
  }
}

class ETAService {
  static final ETAService _instance = ETAService._internal();
  factory ETAService() => _instance;
  ETAService._internal();

  final Logger _logger = Logger();
  final LiveLocationService _liveLocationService = LiveLocationService();
  
  static const String _googleApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const Duration _updateInterval = Duration(minutes: 2);
  
  final Map<String, Timer> _activeETATrackers = {};
  final Map<String, StreamController<ETAUpdate>> _etaControllers = {};

  Future<ETAUpdate?> calculateETA({
    required LatLng currentLocation,
    required LatLng destination,
    bool includeTraffic = true,
  }) async {
    try {
      if (_googleApiKey.isEmpty) {
        _logger.w('Google Maps API key not provided');
        return _calculateBasicETA(currentLocation, destination);
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${currentLocation.latitude},${currentLocation.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&departure_time=now'
        '${includeTraffic ? '&traffic_model=best_guess' : ''}'
        '&key=$_googleApiKey'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          final durationInTraffic = leg['duration_in_traffic'] ?? leg['duration'];
          final distance = leg['distance'];
          
          return ETAUpdate(
            estimatedDuration: Duration(seconds: durationInTraffic['value']),
            distanceRemaining: (distance['value'] / 1000.0), // Convert to km
            updatedAt: DateTime.now(),
            trafficCondition: _getTrafficCondition(
              leg['duration']['value'],
              durationInTraffic['value'],
            ),
          );
        }
      }
      
      _logger.w('Google Directions API error, falling back to basic calculation');
      return _calculateBasicETA(currentLocation, destination);
    } catch (e) {
      _logger.e('Error calculating ETA: $e');
      return _calculateBasicETA(currentLocation, destination);
    }
  }

  ETAUpdate _calculateBasicETA(LatLng from, LatLng to) {
    final distance = _calculateDistance(from, to);
    const averageSpeed = 50.0; // km/h
    final duration = Duration(
      minutes: ((distance / averageSpeed) * 60).round(),
    );
    
    return ETAUpdate(
      estimatedDuration: duration,
      distanceRemaining: distance,
      updatedAt: DateTime.now(),
      trafficCondition: 'unknown',
    );
  }

  String _getTrafficCondition(int normalDuration, int trafficDuration) {
    final ratio = trafficDuration / normalDuration;
    
    if (ratio <= 1.1) return 'light';
    if (ratio <= 1.3) return 'moderate';
    if (ratio <= 1.5) return 'heavy';
    return 'severe';
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371; // km
    
    final lat1Rad = from.latitude * (pi / 180);
    final lat2Rad = to.latitude * (pi / 180);
    final deltaLatRad = (to.latitude - from.latitude) * (pi / 180);
    final deltaLngRad = (to.longitude - from.longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  Stream<ETAUpdate> startETATracking({
    required String trackingId,
    required String driverId,
    required LatLng destination,
  }) {
    _logger.i('Starting ETA tracking for: $trackingId');
    
    if (_etaControllers.containsKey(trackingId)) {
      stopETATracking(trackingId);
    }

    final controller = StreamController<ETAUpdate>.broadcast();
    _etaControllers[trackingId] = controller;

    _activeETATrackers[trackingId] = Timer.periodic(_updateInterval, (timer) async {
      try {
        final driverLocation = await _liveLocationService.getLastKnownLocation(driverId);
        
        if (driverLocation != null) {
          final eta = await calculateETA(
            currentLocation: driverLocation.coordinates,
            destination: destination,
          );
          
          if (eta != null && !controller.isClosed) {
            controller.add(eta);
          }
        }
      } catch (e) {
        _logger.e('Error in ETA tracking timer: $e');
      }
    });

    return controller.stream;
  }

  void stopETATracking(String trackingId) {
    _logger.i('Stopping ETA tracking for: $trackingId');
    
    _activeETATrackers[trackingId]?.cancel();
    _activeETATrackers.remove(trackingId);
    
    _etaControllers[trackingId]?.close();
    _etaControllers.remove(trackingId);
  }

  void stopAllETATracking() {
    _logger.i('Stopping all ETA tracking');
    
    for (final timer in _activeETATrackers.values) {
      timer.cancel();
    }
    _activeETATrackers.clear();
    
    for (final controller in _etaControllers.values) {
      controller.close();
    }
    _etaControllers.clear();
  }

  Stream<ETAUpdate> getPickupETA({
    required String driverId,
    required LatLng pickupLocation,
  }) {
    return startETATracking(
      trackingId: 'pickup_$driverId',
      driverId: driverId,
      destination: pickupLocation,
    );
  }

  Stream<ETAUpdate> getDropoffETA({
    required String driverId,
    required LatLng dropoffLocation,
  }) {
    return startETATracking(
      trackingId: 'dropoff_$driverId',
      driverId: driverId,
      destination: dropoffLocation,
    );
  }

  void dispose() {
    stopAllETATracking();
  }
}