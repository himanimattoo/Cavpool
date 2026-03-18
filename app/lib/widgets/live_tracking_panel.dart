import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/ride_model.dart';
import '../services/ride_service.dart';
import '../services/live_location_service.dart';
import '../services/eta_service.dart';

class LiveTrackingPanel extends StatefulWidget {
  final RideOffer ride;
  final bool isDriver;
  final LatLng? userLocation;

  const LiveTrackingPanel({
    super.key,
    required this.ride,
    required this.isDriver,
    this.userLocation,
  });

  @override
  State<LiveTrackingPanel> createState() => _LiveTrackingPanelState();
}

class _LiveTrackingPanelState extends State<LiveTrackingPanel> {
  final RideService _rideService = RideService();
  StreamSubscription<LiveLocationUpdate?>? _driverLocationSubscription;
  StreamSubscription<ETAUpdate>? _etaSubscription;
  StreamSubscription<Map<String, LiveLocationUpdate>>? _allLocationsSubscription;
  
  LiveLocationUpdate? _driverLocation;
  ETAUpdate? _currentETA;
  Map<String, LiveLocationUpdate> _allParticipantLocations = {};
  
  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    _etaSubscription?.cancel();
    _allLocationsSubscription?.cancel();
    super.dispose();
  }

  void _initializeTracking() {
    if (!widget.isDriver) {
      _subscribeToDriverLocation();
      _subscribeToPickupETA();
    }
    _subscribeToAllParticipantLocations();
  }

  void _subscribeToDriverLocation() {
    _driverLocationSubscription = _rideService
        .getDriverLiveLocation(widget.ride.driverId)
        .listen(
      (location) {
        if (mounted) {
          setState(() {
            _driverLocation = location;
          });
        }
      },
      onError: (error) {
        debugPrint('Error getting driver location: $error');
      },
    );
  }

  void _subscribeToPickupETA() {
    final userLocation = widget.userLocation;
    if (userLocation != null) {
      _etaSubscription = _rideService
          .getPickupETA(widget.ride.driverId, userLocation)
          .listen(
        (eta) {
          if (mounted) {
            setState(() {
              _currentETA = eta;
            });
          }
        },
        onError: (error) {
          debugPrint('Error getting ETA: $error');
        },
      );
    }
  }

  void _subscribeToAllParticipantLocations() {
    _allLocationsSubscription = _rideService
        .getRideLiveLocations(widget.ride)
        .listen(
      (locations) {
        if (mounted) {
          setState(() {
            _allParticipantLocations = locations;
          });
        }
      },
      onError: (error) {
        debugPrint('Error getting participant locations: $error');
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()}m';
    } else {
      return '${distanceKm.toStringAsFixed(1)}km';
    }
  }

  Color _getTrafficColor(String? trafficCondition) {
    switch (trafficCondition) {
      case 'light':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'heavy':
        return Colors.red;
      case 'severe':
        return Colors.red.shade800;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Tracking',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _driverLocation != null ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _driverLocation != null ? 'Live' : 'Offline',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (!widget.isDriver) ...[
              _buildDriverLocationInfo(),
              const SizedBox(height: 12),
              _buildETAInfo(),
            ] else ...[
              _buildDriverDashboard(),
            ],
            
            const SizedBox(height: 12),
            _buildParticipantsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverLocationInfo() {
    if (_driverLocation == null) {
      return const Row(
        children: [
          Icon(Icons.location_off, color: Colors.grey),
          SizedBox(width: 8),
          Text('Driver location unavailable'),
        ],
      );
    }

    final timeDiff = DateTime.now().difference(_driverLocation!.timestamp);
    final isRecent = timeDiff.inMinutes < 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.directions_car,
              color: isRecent ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text('Driver Location'),
            const Spacer(),
            Text(
              isRecent ? 'Updated ${timeDiff.inSeconds}s ago' : 'Last seen ${timeDiff.inMinutes}m ago',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isRecent ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        if (_driverLocation!.speed != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.speed, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${(_driverLocation!.speed! * 3.6).toStringAsFixed(0)} km/h',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildETAInfo() {
    if (_currentETA == null) {
      return const Row(
        children: [
          Icon(Icons.access_time, color: Colors.grey),
          SizedBox(width: 8),
          Text('Calculating ETA...'),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getTrafficColor(_currentETA!.trafficCondition).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getTrafficColor(_currentETA!.trafficCondition).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: _getTrafficColor(_currentETA!.trafficCondition),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ETA: ${_formatDuration(_currentETA!.estimatedDuration)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_formatDistance(_currentETA!.distanceRemaining)} away',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (_currentETA!.trafficCondition != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getTrafficColor(_currentETA!.trafficCondition),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentETA!.trafficCondition!.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverDashboard() {
    final participantCount = widget.ride.passengerIds.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.dashboard, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'Driver Dashboard',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                'Passengers',
                '$participantCount/${widget.ride.totalSeats}',
                Icons.people,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatusCard(
                'Sharing',
                'Location',
                Icons.location_on,
                Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList() {
    if (_allParticipantLocations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participants (${_allParticipantLocations.length})',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...(_allParticipantLocations.entries.map((entry) {
          final userId = entry.key;
          final location = entry.value;
          final isDriver = userId == widget.ride.driverId;
          final timeDiff = DateTime.now().difference(location.timestamp);
          final isOnline = timeDiff.inMinutes < 5;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  isDriver ? Icons.directions_car : Icons.person,
                  size: 16,
                  color: isOnline ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  isDriver ? 'Driver' : 'Passenger',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }).toList()),
      ],
    );
  }
}