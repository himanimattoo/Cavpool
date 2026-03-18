import 'dart:async';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class NavigationStep {
  final String instruction;
  final LatLng location;
  final double distanceMeters;
  
  NavigationStep({
    required this.instruction,
    required this.location, 
    required this.distanceMeters,
  });
}

class NavigationService {
  final List<LatLng> routePoints;
  final void Function(NavigationStep) onNextStep;
  final void Function(double) onDistanceUpdate;
  
  StreamSubscription<Position>? _locationSub;
  int _currentStepIndex = 0;
  
  NavigationService({
    required this.routePoints,
    required this.onNextStep,
    required this.onDistanceUpdate,
  });

  Future<void> startNavigation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final request = await Geolocator.requestPermission();
      if (request != LocationPermission.whileInUse && request != LocationPermission.always) {
        return;  // Add curly braces around return
      }
    }

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_onLocationUpdate);
  }

  void _onLocationUpdate(Position position) {
    final currentLocation = LatLng(position.latitude, position.longitude);
    
    // Find nearest point on route
    int nearestIdx = _findNearestPointIndex(currentLocation);
    
    // Calculate remaining distance along route
    double remainingDistance = _calculateRemainingDistance(nearestIdx, currentLocation);
    onDistanceUpdate(remainingDistance);

    // Check if we should advance to next navigation step
    if (nearestIdx > _currentStepIndex) {
      _currentStepIndex = nearestIdx;
      final nextStep = NavigationStep(
        instruction: _getNavigationInstruction(nearestIdx),
        location: routePoints[nearestIdx],
        distanceMeters: remainingDistance,
      );
      onNextStep(nextStep);
    }
  }

  int _findNearestPointIndex(LatLng current) {
    int nearest = _currentStepIndex;
    double minDist = double.infinity;
    
    // Look ahead up to 10 points to find closest
    for (int i = _currentStepIndex; 
         i < _currentStepIndex + 10 && i < routePoints.length; 
         i++) {
      final point = routePoints[i];
      final dist = Geolocator.distanceBetween(
        current.latitude, current.longitude,
        point.latitude, point.longitude,
      );
      if (dist < minDist) {
        minDist = dist;
        nearest = i;
      }
    }
    return nearest;
  }

  double _calculateRemainingDistance(int fromIndex, LatLng current) {
    double total = Geolocator.distanceBetween(
      current.latitude, current.longitude,
      routePoints[fromIndex].latitude, routePoints[fromIndex].longitude,
    );
    
    // Add remaining segments
    for (int i = fromIndex; i < routePoints.length - 1; i++) {
      total += Geolocator.distanceBetween(
        routePoints[i].latitude, routePoints[i].longitude,
        routePoints[i + 1].latitude, routePoints[i + 1].longitude,
      );
    }
    return total;
  }

  String _getNavigationInstruction(int pointIndex) {
    if (pointIndex >= routePoints.length - 1) return "Arrive at destination";
    
    final current = routePoints[pointIndex];
    final next = routePoints[pointIndex + 1];
    
    // Calculate bearing between points
    final bearing = _calculateBearing(current, next);
    
    // Convert bearing to cardinal direction
    return _bearingToInstruction(bearing);
  }

  double _calculateBearing(LatLng from, LatLng to) {
    // Calculate bearing between two points
    final dLon = to.longitude - from.longitude;
    final y = sin(dLon) * cos(to.latitude);
    final x = cos(from.latitude) * sin(to.latitude) -
              sin(from.latitude) * cos(to.latitude) * cos(dLon);
    final bearing = atan2(y, x);
    return (bearing * 180 / pi + 360) % 360; // Convert to degrees
  }

  String _bearingToInstruction(double bearing) {
    if (bearing < 22.5) return "Head north";
    if (bearing < 67.5) return "Turn northeast"; 
    if (bearing < 112.5) return "Turn east";
    if (bearing < 157.5) return "Turn southeast";
    if (bearing < 202.5) return "Turn south";
    if (bearing < 247.5) return "Turn southwest";
    if (bearing < 292.5) return "Turn west";
    if (bearing < 337.5) return "Turn northwest";
    return "Head north";
  }

  void dispose() {
    _locationSub?.cancel();
  }
}