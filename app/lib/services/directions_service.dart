import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import '../config/app_config.dart';

class DirectionStep {
  final String instruction;
  final String distance;
  final String duration;
  final LatLng startLocation;
  final LatLng endLocation;
  final String maneuver;

  DirectionStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.maneuver,
  });

  factory DirectionStep.fromJson(Map<String, dynamic> json) {
    final startLoc = json['start_location'];
    final endLoc = json['end_location'];
    
    return DirectionStep(
      instruction: json['html_instructions'] ?? '',
      distance: json['distance']?['text'] ?? '',
      duration: json['duration']?['text'] ?? '',
      startLocation: LatLng(
        startLoc['lat']?.toDouble() ?? 0.0,
        startLoc['lng']?.toDouble() ?? 0.0,
      ),
      endLocation: LatLng(
        endLoc['lat']?.toDouble() ?? 0.0,
        endLoc['lng']?.toDouble() ?? 0.0,
      ),
      maneuver: json['maneuver'] ?? '',
    );
  }
}

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final List<DirectionStep> steps;
  final String totalDistance;
  final String totalDuration;
  final LatLng startLocation;
  final LatLng endLocation;
  final String startAddress;
  final String endAddress;

  DirectionsResult({
    required this.polylinePoints,
    required this.steps,
    required this.totalDistance,
    required this.totalDuration,
    required this.startLocation,
    required this.endLocation,
    required this.startAddress,
    required this.endAddress,
  });
}

class DirectionsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  
  final Logger _logger = Logger();
  
  String get _googleApiKey => AppConfig.googleMapsApiKey;

  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String? originAddress,
    String? destinationAddress,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$_googleApiKey'
        '&mode=driving'
        '&alternatives=false'
        '&avoid=tolls'
      );

      _logger.i('Fetching directions from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}');

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Decode the polyline
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
          
          // Parse steps
          final steps = (leg['steps'] as List)
              .map((step) => DirectionStep.fromJson(step))
              .toList();

          return DirectionsResult(
            polylinePoints: polylinePoints,
            steps: steps,
            totalDistance: leg['distance']['text'] ?? '',
            totalDuration: leg['duration']['text'] ?? '',
            startLocation: origin,
            endLocation: destination,
            startAddress: originAddress ?? leg['start_address'] ?? '',
            endAddress: destinationAddress ?? leg['end_address'] ?? '',
          );
        } else {
          _logger.w('Google Directions API error: ${data['status']}');
          if (data['error_message'] != null) {
            _logger.w('Error message: ${data['error_message']}');
          }
          return null;
        }
      } else {
        _logger.e('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Error getting directions: $e');
      return null;
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  // Get alternative routes
  Future<List<DirectionsResult>> getAlternativeRoutes({
    required LatLng origin,
    required LatLng destination,
    String? originAddress,
    String? destinationAddress,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$_googleApiKey'
        '&mode=driving'
        '&alternatives=true'
        '&avoid=tolls'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          List<DirectionsResult> results = [];
          
          for (var route in data['routes']) {
            final leg = route['legs'][0];
            final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
            
            final steps = (leg['steps'] as List)
                .map((step) => DirectionStep.fromJson(step))
                .toList();

            results.add(DirectionsResult(
              polylinePoints: polylinePoints,
              steps: steps,
              totalDistance: leg['distance']['text'] ?? '',
              totalDuration: leg['duration']['text'] ?? '',
              startLocation: origin,
              endLocation: destination,
              startAddress: originAddress ?? leg['start_address'] ?? '',
              endAddress: destinationAddress ?? leg['end_address'] ?? '',
            ));
          }
          
          return results;
        }
      }
      return [];
    } catch (e) {
      _logger.e('Error getting alternative routes: $e');
      return [];
    }
  }

  // Calculate distance between two points using Haversine formula
  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c * 1000; // Return distance in meters
  }

  // Format duration from seconds to readable string
  String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Format distance from meters to readable string (US units)
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

  // Clean HTML instructions for display
  String cleanInstructions(String htmlInstructions) {
    // Remove HTML tags and decode common entities
    return htmlInstructions
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }
}