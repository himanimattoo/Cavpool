import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/routes_service.dart';

class RoutesProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  final RoutesService _routesService = RoutesService();

  GoogleMapController? _mapController;
  Position? _currentPosition;
  RouteInfo? _currentRoute;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoadingRoute = false;
  String? _error;

  // Getters
  GoogleMapController? get mapController => _mapController;
  Position? get currentPosition => _currentPosition;
  RouteInfo? get currentRoute => _currentRoute;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  bool get isLoadingRoute => _isLoadingRoute;
  String? get error => _error;

  LatLng get currentLocation {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    // Default to a location (you can change this to your preferred default)
    return const LatLng(37.7749, -122.4194); // San Francisco
  }

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    notifyListeners();
  }

  Future<void> getCurrentLocation() async {
    try {
      _error = null;
      Position? position = await _locationService.getCurrentLocation();
      if (position != null) {
        _currentPosition = position;
        
        // Add current location marker
        _updateCurrentLocationMarker();
        
        // Move camera to current location
        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(currentLocation, 15.0),
          );
        }
        
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to get current location: $e';
      notifyListeners();
    }
  }

  void _updateCurrentLocationMarker() {
    if (_currentPosition != null) {
      _markers.removeWhere((marker) => marker.markerId.value == 'current_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLocation,
          infoWindow: const InfoWindow(
            title: 'Current Location',
            snippet: 'You are here',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
  }

  Future<void> calculateRoute({
    required LatLng destination,
    String? destinationName,
  }) async {
    if (_currentPosition == null) {
      _error = 'Current location not available';
      notifyListeners();
      return;
    }

    try {
      _isLoadingRoute = true;
      _error = null;
      notifyListeners();

      RouteInfo? route = await _routesService.calculateRoute(
        startLocation: currentLocation,
        endLocation: destination,
        startName: 'Current Location',
        endName: destinationName,
      );

      if (route != null) {
        _currentRoute = route;
        _updateMapWithRoute(route);
        
        // Fit the map to show the entire route
        if (_mapController != null) {
          await _fitMapToRoute(route);
        }
      } else {
        _error = 'Failed to calculate route';
      }
    } catch (e) {
      _error = 'Error calculating route: $e';
    } finally {
      _isLoadingRoute = false;
      notifyListeners();
    }
  }

  void _updateMapWithRoute(RouteInfo route) {
    // Clear previous route data
    _markers.removeWhere((marker) => 
      marker.markerId.value == 'start' || marker.markerId.value == 'end'
    );
    _polylines.clear();

    // Add route markers and polylines
    _markers.addAll(_routesService.createMarkersFromRoute(route));
    _polylines.addAll(_routesService.createPolylinesFromRoute(route));
    
    // Keep current location marker
    _updateCurrentLocationMarker();
  }

  Future<void> _fitMapToRoute(RouteInfo route) async {
    if (_mapController == null) return;

    // Calculate bounds that include all route points
    double minLat = route.polylinePoints.first.latitude;
    double maxLat = route.polylinePoints.first.latitude;
    double minLng = route.polylinePoints.first.longitude;
    double maxLng = route.polylinePoints.first.longitude;

    for (LatLng point in route.polylinePoints) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  void clearRoute() {
    _currentRoute = null;
    _markers.removeWhere((marker) => 
      marker.markerId.value == 'start' || marker.markerId.value == 'end'
    );
    _polylines.clear();
    _updateCurrentLocationMarker();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void addDestinationMarker(LatLng location, {String? name}) {
    _markers.add(
      Marker(
        markerId: MarkerId('destination_${location.latitude}_${location.longitude}'),
        position: location,
        infoWindow: InfoWindow(
          title: name ?? 'Destination',
          snippet: 'Tap to navigate here',
        ),
        onTap: () => calculateRoute(
          destination: location,
          destinationName: name,
        ),
      ),
    );
    notifyListeners();
  }

  void setCustomRoute(RouteInfo route, LatLng startLocation, LatLng endLocation) {
    _currentRoute = route;
    _updateMapWithCustomRoute(route, startLocation, endLocation);
    notifyListeners();
  }

  void _updateMapWithCustomRoute(RouteInfo route, LatLng startLocation, LatLng endLocation) {
    // Clear previous route data
    _markers.removeWhere((marker) => 
      marker.markerId.value == 'start' || 
      marker.markerId.value == 'end' ||
      marker.markerId.value == 'current_location'
    );
    _polylines.clear();

    // Add custom start and end markers
    _markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: startLocation,
        infoWindow: InfoWindow(
          title: route.startPoint.name ?? 'Start',
          snippet: route.startPoint.description,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('end'),
        position: endLocation,
        infoWindow: InfoWindow(
          title: route.endPoint.name ?? 'End',
          snippet: route.endPoint.description,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // Add polylines
    _polylines.addAll(_routesService.createPolylinesFromRoute(route));
  }
}