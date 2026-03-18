import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../../providers/routes_provider.dart';
import '../../services/routes_service.dart';
import '../../services/address_search_service.dart';
import '../../widgets/address_search_widget.dart';
import '../../widgets/directions_panel.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  bool _showSearchPanel = false;
  bool _showDirectionsPanel = false;
  String? _fromAddress;
  String? _toAddress;
  LatLng? _fromLocation;
  LatLng? _toLocation;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routesProvider = Provider.of<RoutesProvider>(context, listen: false);
      routesProvider.getCurrentLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_showSearchPanel ? Icons.map : Icons.search),
            onPressed: () {
              setState(() {
                _showSearchPanel = !_showSearchPanel;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              final routesProvider = Provider.of<RoutesProvider>(context, listen: false);
              routesProvider.getCurrentLocation();
            },
          ),
        ],
      ),
      body: Consumer<RoutesProvider>(
        builder: (context, routesProvider, child) {
          
          return Stack(
            children: [
              GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  routesProvider.setMapController(controller);
                },
                initialCameraPosition: CameraPosition(
                  target: routesProvider.currentLocation,
                  zoom: 15.0,
                ),
                markers: routesProvider.markers,
                polylines: routesProvider.polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                onTap: _showSearchPanel ? null : (LatLng location) {
                  _showLocationDialog(context, location);
                },
              ),
              
              // Search Panel (Uber-style)
              if (_showSearchPanel)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SearchPanel(
                    fromAddress: _fromAddress,
                    toAddress: _toAddress,
                    onFromAddressSelected: (result) {
                      setState(() {
                        _fromAddress = result.formattedAddress;
                        _fromLocation = result.location;
                      });
                      _calculateRouteFromAddresses(routesProvider);
                    },
                    onToAddressSelected: (result) {
                      setState(() {
                        _toAddress = result.formattedAddress;
                        _toLocation = result.location;
                      });
                      _calculateRouteFromAddresses(routesProvider);
                      setState(() {
                        _showSearchPanel = false;
                      });
                    },
                    onCurrentLocationSelected: () {
                      routesProvider.getCurrentLocation();
                      setState(() {
                        _fromAddress = 'Current Location';
                        _fromLocation = null; // Will use current location
                      });
                    },
                  ),
                ),
              
              // Route info card
              if (routesProvider.currentRoute != null && !_showDirectionsPanel)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: RouteInfoCard(
                    route: routesProvider.currentRoute!,
                    onShowDirections: routesProvider.currentRoute!.steps != null
                        ? () {
                            setState(() {
                              _showDirectionsPanel = true;
                            });
                          }
                        : null,
                  ),
                ),

              // Directions panel
              if (_showDirectionsPanel && routesProvider.currentRoute?.steps != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: DirectionsPanel(
                    steps: routesProvider.currentRoute!.steps!,
                    onClose: () {
                      setState(() {
                        _showDirectionsPanel = false;
                      });
                    },
                  ),
                ),
              
              // Loading indicator
              if (routesProvider.isLoadingRoute)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              
              // Error message
              if (routesProvider.error != null)
                Positioned(
                  bottom: 100,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.red.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              routesProvider.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: routesProvider.clearError,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<RoutesProvider>(
        builder: (context, routesProvider, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (routesProvider.currentRoute != null)
                FloatingActionButton(
                  heroTag: "clear_route",
                  onPressed: () {
                    routesProvider.clearRoute();
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.clear, color: Colors.white),
                ),
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: "my_location",
                onPressed: () {
                  routesProvider.getCurrentLocation();
                },
                child: const Icon(Icons.my_location),
              ),
            ],
          );
        },
      ),
    );
  }

  void _calculateRouteFromAddresses(RoutesProvider routesProvider) {
    // Only calculate route if we have a destination
    if (_toLocation == null) return;

    LatLng startLocation;
    String startName;

    // Use selected "From" location or current location
    if (_fromLocation != null) {
      startLocation = _fromLocation!;
      startName = _fromAddress ?? 'Selected Location';
    } else {
      // Use current location
      if (routesProvider.currentPosition != null) {
        startLocation = LatLng(
          routesProvider.currentPosition!.latitude,
          routesProvider.currentPosition!.longitude,
        );
        startName = 'Current Location';
      } else {
        // If no current location, get it first
        routesProvider.getCurrentLocation();
        return;
      }
    }

    // Calculate route with custom start location
    _calculateCustomRoute(
      routesProvider,
      startLocation: startLocation,
      endLocation: _toLocation!,
      startName: startName,
      endName: _toAddress ?? 'Destination',
    );
  }

  void _calculateCustomRoute(
    RoutesProvider routesProvider, {
    required LatLng startLocation,
    required LatLng endLocation,
    required String startName,
    required String endName,
  }) async {
    // Use the routes service directly for custom start/end points
    final routesService = RoutesService();
    
    try {
      final route = await routesService.calculateRoute(
        startLocation: startLocation,
        endLocation: endLocation,
        startName: startName,
        endName: endName,
      );

      if (route != null) {
        // Update the provider with the new route
        routesProvider.setCustomRoute(route, startLocation, endLocation);
        
        // Fit map to show the route
        if (routesProvider.mapController != null) {
          await _fitMapToCustomRoute(routesProvider, route);
        }
      }
    } catch (e) {
      // Handle error
      _logger.e('Error calculating custom route: $e');
    }
  }

  Future<void> _fitMapToCustomRoute(RoutesProvider routesProvider, RouteInfo route) async {
    if (routesProvider.mapController == null) return;

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

    await routesProvider.mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  void _showLocationDialog(BuildContext context, LatLng location) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Navigate to this location?'),
          content: Text(
            'Latitude: ${location.latitude.toStringAsFixed(6)}\n'
            'Longitude: ${location.longitude.toStringAsFixed(6)}',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Navigate'),
              onPressed: () {
                Navigator.of(context).pop();
                final routesProvider = Provider.of<RoutesProvider>(context, listen: false);
                routesProvider.calculateRoute(
                  destination: location,
                  destinationName: 'Selected Location',
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class RouteInfoCard extends StatelessWidget {
  final RouteInfo route;
  final VoidCallback? onShowDirections;

  const RouteInfoCard({
    super.key,
    required this.route,
    this.onShowDirections,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Route Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: RoutesService().formatDistance(route.totalDistance),
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.access_time,
                    label: 'Duration',
                    value: RoutesService().formatDuration(route.estimatedDuration),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoItem(
              icon: Icons.location_on,
              label: 'From',
              value: route.startPoint.name ?? 'Start Location',
            ),
            const SizedBox(height: 4),
            _InfoItem(
              icon: Icons.flag,
              label: 'To',
              value: route.endPoint.name ?? 'End Location',
            ),
            
            // Show directions button if we have turn-by-turn directions
            if (onShowDirections != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onShowDirections,
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Show Directions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57200),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class SearchPanel extends StatelessWidget {
  final String? fromAddress;
  final String? toAddress;
  final Function(AddressSearchResult) onFromAddressSelected;
  final Function(AddressSearchResult) onToAddressSelected;
  final VoidCallback onCurrentLocationSelected;

  const SearchPanel({
    super.key,
    this.fromAddress,
    this.toAddress,
    required this.onFromAddressSelected,
    required this.onToAddressSelected,
    required this.onCurrentLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.route, color: Color(0xFFE57200)),
              const SizedBox(width: 8),
              const Text(
                'Plan Your Route',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // From Address Search
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AddressSearchWidget(
                  initialAddress: fromAddress,
                  hintText: 'From (Current Location)',
                  onAddressSelected: onFromAddressSelected,
                  onCurrentLocationTap: onCurrentLocationSelected,
                  showCurrentLocationOption: true,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // To Address Search
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AddressSearchWidget(
                  initialAddress: toAddress,
                  hintText: 'Where to?',
                  onAddressSelected: onToAddressSelected,
                  showCurrentLocationOption: false,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Quick Actions
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    // Add home address functionality later
                  },
                  icon: const Icon(Icons.home, size: 20),
                  label: const Text('Home'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    // Add work address functionality later
                  },
                  icon: const Icon(Icons.work, size: 20),
                  label: const Text('Work'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    // Add recent searches functionality later
                  },
                  icon: const Icon(Icons.history, size: 20),
                  label: const Text('Recent'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}