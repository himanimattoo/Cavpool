import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/ride_model.dart';
import '../services/directions_service.dart';

class RouteOptimizationService {
  final DirectionsService _directionsService = DirectionsService();

  /// Optimizes the order of passenger pickups and drop-offs to minimize route time
  /// Returns an optimized list of route stops with their types
  Future<List<OptimizedRouteStop>> optimizeRoute({
    required RideOffer ride,
    required LatLng driverStartLocation,
    required LatLng driverEndLocation,
    required List<PassengerRouteInfo> passengers,
  }) async {
    if (passengers.isEmpty) {
      return [
        OptimizedRouteStop(
          location: driverEndLocation,
          type: RouteStopType.driverDestination,
          address: ride.endLocation.address,
          sequenceNumber: 1,
        ),
      ];
    }

    // Create all possible stops
    List<RouteStop> allStops = _createAllStops(passengers, driverEndLocation, ride.endLocation.address);
    
    // Get distance matrix between all locations
    List<LatLng> allLocations = [driverStartLocation, ...allStops.map((s) => s.location)];
    Map<String, Map<String, double>> distanceMatrix = await _calculateDistanceMatrix(allLocations);
    
    // Use optimization algorithm to find best order
    List<RouteStop> optimizedStops = await _optimizeStopOrder(
      startLocation: driverStartLocation,
      stops: allStops,
      distanceMatrix: distanceMatrix,
    );

    // Convert to OptimizedRouteStop objects with sequence numbers
    return optimizedStops.asMap().entries.map((entry) {
      int index = entry.key;
      RouteStop stop = entry.value;
      return OptimizedRouteStop(
        location: stop.location,
        type: stop.type,
        address: stop.address,
        passengerId: stop.passengerId,
        sequenceNumber: index + 1,
      );
    }).toList();
  }

  /// Creates all pickup and drop-off stops for optimization
  List<RouteStop> _createAllStops(List<PassengerRouteInfo> passengers, LatLng driverEnd, String driverEndAddress) {
    List<RouteStop> stops = [];
    
    // Add passenger pickups and drop-offs
    for (final passenger in passengers) {
      stops.add(RouteStop(
        location: passenger.pickupLocation.coordinates,
        type: RouteStopType.pickup,
        address: passenger.pickupLocation.address,
        passengerId: passenger.passengerId,
      ));
      
      stops.add(RouteStop(
        location: passenger.dropoffLocation.coordinates,
        type: RouteStopType.dropoff,
        address: passenger.dropoffLocation.address,
        passengerId: passenger.passengerId,
      ));
    }
    
    // Add driver destination
    stops.add(RouteStop(
      location: driverEnd,
      type: RouteStopType.driverDestination,
      address: driverEndAddress,
    ));
    
    return stops;
  }

  /// Calculates distance matrix between all locations using real route data
  Future<Map<String, Map<String, double>>> _calculateDistanceMatrix(List<LatLng> locations) async {
    Map<String, Map<String, double>> matrix = {};
    
    for (int i = 0; i < locations.length; i++) {
      String fromKey = _locationKey(locations[i]);
      matrix[fromKey] = {};
      
      for (int j = 0; j < locations.length; j++) {
        if (i == j) {
          matrix[fromKey]![_locationKey(locations[j])] = 0.0;
          continue;
        }
        
        try {
          final route = await _directionsService.getDirections(
            origin: locations[i],
            destination: locations[j],
          );
          
          if (route != null) {
            // Parse duration string and convert to seconds for optimization metric
            double durationSeconds = _parseDurationToSeconds(route.totalDuration);
            matrix[fromKey]![_locationKey(locations[j])] = durationSeconds;
          } else {
            // Fallback to straight-line distance if route fails
            matrix[fromKey]![_locationKey(locations[j])] = _calculateStraightLineDistance(locations[i], locations[j]);
          }
        } catch (e) {
          // Fallback to straight-line distance
          matrix[fromKey]![_locationKey(locations[j])] = _calculateStraightLineDistance(locations[i], locations[j]);
        }
      }
    }
    
    return matrix;
  }

  /// Optimizes the order of stops using a nearest neighbor algorithm with constraints
  Future<List<RouteStop>> _optimizeStopOrder({
    required LatLng startLocation,
    required List<RouteStop> stops,
    required Map<String, Map<String, double>> distanceMatrix,
  }) async {
    if (stops.isEmpty) return [];
    
    List<RouteStop> optimized = [];
    List<RouteStop> remaining = List.from(stops);
    Set<String> pickedUpPassengers = {};
    LatLng currentLocation = startLocation;
    
    while (remaining.isNotEmpty) {
      RouteStop? nextStop = _findBestNextStop(
        currentLocation: currentLocation,
        remainingStops: remaining,
        pickedUpPassengers: pickedUpPassengers,
        distanceMatrix: distanceMatrix,
      );
      
      if (nextStop == null) break;
      
      optimized.add(nextStop);
      remaining.remove(nextStop);
      currentLocation = nextStop.location;
      
      // Update passenger status
      if (nextStop.type == RouteStopType.pickup) {
        pickedUpPassengers.add(nextStop.passengerId!);
      } else if (nextStop.type == RouteStopType.dropoff) {
        pickedUpPassengers.remove(nextStop.passengerId!);
      }
    }
    
    return optimized;
  }

  /// Finds the best next stop based on distance and constraints
  RouteStop? _findBestNextStop({
    required LatLng currentLocation,
    required List<RouteStop> remainingStops,
    required Set<String> pickedUpPassengers,
    required Map<String, Map<String, double>> distanceMatrix,
  }) {
    String currentKey = _locationKey(currentLocation);
    RouteStop? bestStop;
    double bestScore = double.infinity;
    
    for (final stop in remainingStops) {
      // Check constraints
      if (!_isValidNextStop(stop, pickedUpPassengers)) {
        continue;
      }
      
      // Calculate score (lower is better)
      double distance = distanceMatrix[currentKey]?[_locationKey(stop.location)] ?? double.infinity;
      double score = _calculateStopScore(stop, distance, pickedUpPassengers);
      
      if (score < bestScore) {
        bestScore = score;
        bestStop = stop;
      }
    }
    
    return bestStop;
  }

  /// Validates if a stop can be the next stop based on pickup/dropoff constraints
  bool _isValidNextStop(RouteStop stop, Set<String> pickedUpPassengers) {
    switch (stop.type) {
      case RouteStopType.pickup:
        // Can always pick up passengers
        return true;
      case RouteStopType.dropoff:
        // Can only drop off if passenger was picked up
        return stop.passengerId != null && pickedUpPassengers.contains(stop.passengerId!);
      case RouteStopType.driverDestination:
        // Driver destination should be last (when all passengers are dropped off)
        return pickedUpPassengers.isEmpty;
    }
  }

  /// Calculates a score for a stop (lower is better)
  double _calculateStopScore(RouteStop stop, double distance, Set<String> pickedUpPassengers) {
    double score = distance;
    
    // Prioritize pickups when no one is in the car to minimize empty driving
    if (pickedUpPassengers.isEmpty && stop.type == RouteStopType.pickup) {
      score *= 0.8;
    }
    
    // Prioritize drop-offs for passengers already picked up
    if (stop.type == RouteStopType.dropoff && 
        stop.passengerId != null && 
        pickedUpPassengers.contains(stop.passengerId!)) {
      score *= 0.9;
    }
    
    // Driver destination should have lowest priority (go last)
    if (stop.type == RouteStopType.driverDestination) {
      score *= 2.0;
    }
    
    return score;
  }

  /// Creates a unique key for a location
  String _locationKey(LatLng location) {
    return '${location.latitude.toStringAsFixed(6)},${location.longitude.toStringAsFixed(6)}';
  }

  /// Parses duration string (e.g., "5 mins", "1 hour 20 mins") to seconds
  double _parseDurationToSeconds(String durationString) {
    double totalSeconds = 0;
    
    // Remove extra spaces and convert to lowercase
    String normalized = durationString.toLowerCase().trim();
    
    // Match hours
    RegExp hourRegex = RegExp(r'(\d+)\s*h');
    Match? hourMatch = hourRegex.firstMatch(normalized);
    if (hourMatch != null) {
      totalSeconds += int.parse(hourMatch.group(1)!) * 3600;
    }
    
    // Match minutes
    RegExp minuteRegex = RegExp(r'(\d+)\s*m');
    Match? minuteMatch = minuteRegex.firstMatch(normalized);
    if (minuteMatch != null) {
      totalSeconds += int.parse(minuteMatch.group(1)!) * 60;
    }
    
    // If no matches found, try to parse as plain number (assume minutes)
    if (totalSeconds == 0) {
      RegExp numberRegex = RegExp(r'(\d+)');
      Match? numberMatch = numberRegex.firstMatch(normalized);
      if (numberMatch != null) {
        totalSeconds = int.parse(numberMatch.group(1)!) * 60; // Assume minutes
      }
    }
    
    return totalSeconds;
  }

  /// Parses distance string (e.g., "5.2 km", "3.1 mi") to meters
  double _parseDistanceToMeters(String distanceString) {
    String normalized = distanceString.toLowerCase().trim();
    
    // Extract number
    RegExp numberRegex = RegExp(r'(\d+\.?\d*)');
    Match? numberMatch = numberRegex.firstMatch(normalized);
    if (numberMatch == null) return 0;
    
    double value = double.parse(numberMatch.group(1)!);
    
    // Check unit
    if (normalized.contains('km')) {
      return value * 1000; // km to meters
    } else if (normalized.contains('mi')) {
      return value * 1609.34; // miles to meters
    } else if (normalized.contains('m') && !normalized.contains('mi')) {
      return value; // already in meters
    } else {
      return value; // assume meters if no unit
    }
  }

  /// Calculates straight-line distance between two points (fallback)
  double _calculateStraightLineDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // Distance in meters, converted to seconds for comparison
  }

  /// Calculates the total optimized route distance and duration
  Future<RouteOptimizationResult> calculateOptimizedRouteMetrics({
    required LatLng startLocation,
    required List<OptimizedRouteStop> optimizedStops,
  }) async {
    double totalDistance = 0;
    Duration totalDuration = Duration.zero;
    
    LatLng currentLocation = startLocation;
    
    for (final stop in optimizedStops) {
      try {
        final route = await _directionsService.getDirections(
          origin: currentLocation,
          destination: stop.location,
        );
        
        if (route != null) {
          totalDistance += _parseDistanceToMeters(route.totalDistance);
          totalDuration += Duration(seconds: _parseDurationToSeconds(route.totalDuration).round());
        }
      } catch (e) {
        // Use fallback calculations if route service fails
        final distance = _calculateStraightLineDistance(currentLocation, stop.location);
        totalDistance += distance;
        totalDuration += Duration(seconds: (distance / 13.89).round()); // Assume ~50 km/h average speed
      }
      
      currentLocation = stop.location;
    }
    
    return RouteOptimizationResult(
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      optimizedStops: optimizedStops,
    );
  }
}

/// Represents a stop in the route optimization
class RouteStop {
  final LatLng location;
  final RouteStopType type;
  final String address;
  final String? passengerId;
  
  RouteStop({
    required this.location,
    required this.type,
    required this.address,
    this.passengerId,
  });
}

/// Represents an optimized route stop with sequence information
class OptimizedRouteStop {
  final LatLng location;
  final RouteStopType type;
  final String address;
  final String? passengerId;
  final int sequenceNumber;
  
  OptimizedRouteStop({
    required this.location,
    required this.type,
    required this.address,
    this.passengerId,
    required this.sequenceNumber,
  });
}

/// Type of stop in the route
enum RouteStopType {
  pickup,
  dropoff,
  driverDestination,
}

/// Information about a passenger for route optimization
class PassengerRouteInfo {
  final String passengerId;
  final RideLocation pickupLocation;
  final RideLocation dropoffLocation;
  
  PassengerRouteInfo({
    required this.passengerId,
    required this.pickupLocation,
    required this.dropoffLocation,
  });
}

/// Result of route optimization
class RouteOptimizationResult {
  final double totalDistance;
  final Duration totalDuration;
  final List<OptimizedRouteStop> optimizedStops;
  
  RouteOptimizationResult({
    required this.totalDistance,
    required this.totalDuration,
    required this.optimizedStops,
  });
}