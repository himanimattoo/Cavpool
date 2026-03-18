import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'directions_service.dart';

class RoutePoint {
  final LatLng location;
  final String? name;
  final String? description;

  RoutePoint({
    required this.location,
    this.name,
    this.description,
  });
}

class RouteInfo {
  final List<LatLng> polylinePoints;
  final double totalDistance;
  final Duration estimatedDuration;
  final RoutePoint startPoint;
  final RoutePoint endPoint;
  final List<DirectionStep>? steps;
  final String? totalDistanceText;
  final String? totalDurationText;

  RouteInfo({
    required this.polylinePoints,
    required this.totalDistance,
    required this.estimatedDuration,
    required this.startPoint,
    required this.endPoint,
    this.steps,
    this.totalDistanceText,
    this.totalDurationText,
  });
}

class RoutesService {
  static final RoutesService _instance = RoutesService._internal();
  factory RoutesService() => _instance;
  RoutesService._internal();

  final Logger _logger = Logger();
  final DirectionsService _directionsService = DirectionsService();

  Future<RouteInfo?> calculateRoute({
    required LatLng startLocation,
    required LatLng endLocation,
    String? startName,
    String? endName,
  }) async {
    try {
      _logger.i('🗺️ Calculating route from $startLocation to $endLocation using Google Directions API');

      // Use Google Directions API to get actual route
      final directionsResult = await _directionsService.getDirections(
        origin: startLocation,
        destination: endLocation,
        originAddress: startName,
        destinationAddress: endName,
      );

      if (directionsResult == null) {
        _logger.w('⚠️ Failed to get directions from Google API, falling back to straight line distance calculation');
        return _createFallbackRoute(startLocation, endLocation, startName, endName);
      }

      // Parse the duration text to get a Duration object
      Duration estimatedDuration = _parseDuration(directionsResult.totalDuration);
      
      // Parse distance text to get meters
      double totalDistanceMeters = _parseDistance(directionsResult.totalDistance);

      RoutePoint startPoint = RoutePoint(
        location: startLocation,
        name: startName ?? directionsResult.startAddress,
      );

      RoutePoint endPoint = RoutePoint(
        location: endLocation,
        name: endName ?? directionsResult.endAddress,
      );

      _logger.i('✅ Successfully calculated route: ${totalDistanceMeters}m (${directionsResult.totalDistance}), duration: ${estimatedDuration.inMinutes}min');
      
      return RouteInfo(
        polylinePoints: directionsResult.polylinePoints,
        totalDistance: totalDistanceMeters,
        estimatedDuration: estimatedDuration,
        startPoint: startPoint,
        endPoint: endPoint,
        steps: directionsResult.steps,
        totalDistanceText: directionsResult.totalDistance,
        totalDurationText: directionsResult.totalDuration,
      );
    } catch (e) {
      _logger.e('Error calculating route: $e');
      return _createFallbackRoute(startLocation, endLocation, startName, endName);
    }
  }

  RouteInfo _createFallbackRoute(LatLng start, LatLng end, String? startName, String? endName) {
    // Fallback to straight line if Directions API fails
    List<LatLng> points = [start, end];
    double distance = Geolocator.distanceBetween(
      start.latitude, start.longitude, end.latitude, end.longitude);
    
    Duration duration = Duration(minutes: (distance / 1000 * 60 / 50).round());

    _logger.i('🔄 Using fallback straight-line calculation: ${distance.round()}m, estimated ${duration.inMinutes}min (assuming 50km/h)');

    return RouteInfo(
      polylinePoints: points,
      totalDistance: distance,
      estimatedDuration: duration,
      startPoint: RoutePoint(location: start, name: startName ?? 'Start'),
      endPoint: RoutePoint(location: end, name: endName ?? 'End'),
    );
  }

  Duration _parseDuration(String durationText) {
    // Parse duration text like "15 mins", "1 hour 30 mins", etc.
    try {
      final hourMatch = RegExp(r'(\d+)\s*hour?s?').firstMatch(durationText);
      final minMatch = RegExp(r'(\d+)\s*min?s?').firstMatch(durationText);
      
      int hours = hourMatch != null ? int.parse(hourMatch.group(1)!) : 0;
      int minutes = minMatch != null ? int.parse(minMatch.group(1)!) : 0;
      
      return Duration(hours: hours, minutes: minutes);
    } catch (e) {
      _logger.w('Failed to parse duration: $durationText');
      return const Duration(minutes: 10); // Default fallback
    }
  }

  double _parseDistance(String distanceText) {
    // Parse distance text like "5.2 km", "800 m", "3.1 mi", "1,500 ft", etc.
    try {
      // Remove commas from numbers
      String cleanText = distanceText.replaceAll(',', '');
      
      if (cleanText.contains('km')) {
        final kmMatch = RegExp(r'([\d.]+)\s*km').firstMatch(cleanText);
        if (kmMatch != null) {
          return double.parse(kmMatch.group(1)!) * 1000; // Convert to meters
        }
      } else if (cleanText.contains('mi')) {
        final miMatch = RegExp(r'([\d.]+)\s*mi').firstMatch(cleanText);
        if (miMatch != null) {
          return double.parse(miMatch.group(1)!) * 1609.344; // Convert miles to meters
        }
      } else if (cleanText.contains('ft')) {
        final ftMatch = RegExp(r'([\d.]+)\s*ft').firstMatch(cleanText);
        if (ftMatch != null) {
          return double.parse(ftMatch.group(1)!) * 0.3048; // Convert feet to meters
        }
      } else if (cleanText.contains('m')) {
        final mMatch = RegExp(r'([\d.]+)\s*m').firstMatch(cleanText);
        if (mMatch != null) {
          return double.parse(mMatch.group(1)!);
        }
      }
      return 0;
    } catch (e) {
      _logger.w('Failed to parse distance: $distanceText');
      return 0;
    }
  }

  Set<Marker> createMarkersFromRoute(RouteInfo route) {
    return {
      Marker(
        markerId: const MarkerId('start'),
        position: route.startPoint.location,
        infoWindow: InfoWindow(
          title: route.startPoint.name ?? 'Start',
          snippet: route.startPoint.description,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: route.endPoint.location,
        infoWindow: InfoWindow(
          title: route.endPoint.name ?? 'End',
          snippet: route.endPoint.description,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  Set<Polyline> createPolylinesFromRoute(RouteInfo route) {
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: route.polylinePoints,
        color: const Color(0xFF2196F3),
        width: 5,
        patterns: [],
      ),
    };
  }

  String formatDistance(double meters) {
    // Convert meters to miles (1 meter = 0.000621371 miles)
    double miles = meters * 0.000621371;
    
    if (miles < 0.1) {
      // Show feet for very short distances (1 mile = 5280 feet)
      double feet = meters * 3.28084;
      return '${feet.round()} ft';
    } else if (miles < 1.0) {
      // Show as decimal miles for distances under 1 mile
      return '${miles.toStringAsFixed(2)} mi';
    } else {
      // Show miles with 1 decimal place for longer distances
      return '${miles.toStringAsFixed(1)} mi';
    }
  }

  String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}