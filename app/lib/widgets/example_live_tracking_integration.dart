// Example integration of LiveTrackingPanel in an existing ride screen
// This shows how to integrate live location tracking into your existing UI

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/ride_model.dart';
import '../widgets/live_tracking_panel.dart';

class ExampleRideScreenWithLiveTracking extends StatefulWidget {
  final RideOffer ride;
  final bool isDriver;

  const ExampleRideScreenWithLiveTracking({
    super.key,
    required this.ride,
    required this.isDriver,
  });

  @override
  State<ExampleRideScreenWithLiveTracking> createState() => 
      _ExampleRideScreenWithLiveTrackingState();
}

class _ExampleRideScreenWithLiveTrackingState 
    extends State<ExampleRideScreenWithLiveTracking> {
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    // Initialize user location
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    // Use your existing location service to get current location
    // For example:
    // final location = await LocationService().getCurrentLocation();
    // setState(() {
    //   _userLocation = LatLng(location.latitude, location.longitude);
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDriver ? 'Driving' : 'Your Ride'),
      ),
      body: Column(
        children: [
          // Your existing map or other content
          const Expanded(
            child: Center(
              child: Text('Your existing ride interface'),
            ),
          ),
          
          // Add the live tracking panel
          LiveTrackingPanel(
            ride: widget.ride,
            isDriver: widget.isDriver,
            userLocation: _userLocation,
          ),
        ],
      ),
    );
  }
}

/*
To use this in your app:

1. Import the necessary services:
   - RideService for ride management
   - LiveLocationService for location tracking
   - ETAService for ETA calculations

2. Start location sharing when a ride begins:
   await RideService().startRide(rideId, driverId);

3. Add the LiveTrackingPanel widget to your ride screens:
   LiveTrackingPanel(
     ride: currentRide,
     isDriver: user.isDriver,
     userLocation: userCurrentLocation,
   )

4. Stop location sharing when ride ends:
   await RideService().completeRide(rideId, driverId);

Features included:
- Real-time driver location for passengers
- Live ETA updates with traffic conditions
- Participant status (online/offline)
- Driver dashboard with passenger count
- Automatic location cleanup on ride completion
*/