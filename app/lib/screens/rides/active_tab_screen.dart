import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/passenger_provider.dart';
import '../../models/ride_model.dart';
import '../driver/driver_active_ride_screen.dart';
import '../rider/rider_tracking_screen.dart';
import 'ride_preview_screen.dart';

/// Smart Active tab that shows different screens based on user type and ride state
class ActiveTabScreen extends StatefulWidget {
  const ActiveTabScreen({super.key});

  @override
  State<ActiveTabScreen> createState() => _ActiveTabScreenState();
}

class _ActiveTabScreenState extends State<ActiveTabScreen> {
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    // Defer provider initialization until after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
  }

  void _initializeProviders() {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null && authProvider.isAuthenticated) {
      final userId = authProvider.user!.uid;
      final userEmail = authProvider.user!.email;
      
      // Debug: Log authentication state
      _logger.d('Initializing providers for user: $userId, email: $userEmail');
      _logger.d('Is authenticated: ${authProvider.isAuthenticated}');
      
      // Only initialize if user has UVA email (per Firestore rules)
      if (userEmail != null && userEmail.endsWith('@virginia.edu')) {
        // Initialize both providers - the appropriate one will activate based on user type
        final driverProvider = Provider.of<DriverProvider>(context, listen: false);
        final passengerProvider = Provider.of<PassengerProvider>(context, listen: false);
        
        driverProvider.initialize(userId);
        passengerProvider.initialize(userId);
      } else {
        _logger.w('User does not have UVA email: $userEmail');
      }
    } else {
      _logger.w('User not authenticated, skipping provider initialization');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, DriverProvider, PassengerProvider>(
      builder: (context, authProvider, driverProvider, passengerProvider, child) {
        // Check if user is authenticated
        if (authProvider.user == null) {
          return _buildNotAuthenticatedState();
        }

        // Determine user type and show appropriate content
        final userModel = authProvider.userModel;
        final isDriver = userModel?.accountType == 'driver';

        if (isDriver) {
          return _buildDriverActiveTab(driverProvider);
        } else {
          return _buildPassengerActiveTab(passengerProvider);
        }
      },
    );
  }

  /// Build driver's active tab based on ride state
  Widget _buildDriverActiveTab(DriverProvider driverProvider) {
    // If driver has an active ride
    if (driverProvider.activeRide != null) {
      final rideInfo = driverProvider.activeRide!;
      final rideStatus = rideInfo.ride.status;

      _logger.d('Building driver active tab - Ride Status: $rideStatus');

      switch (rideStatus) {
        case RideStatus.active:
          // Driver accepted ride but hasn't started yet - show preview
          return RidePreviewScreen(
            rideInfo: rideInfo,
            onStartRide: () => driverProvider.startRide(),
            onCancelRide: () => _showCancelConfirmation(context, driverProvider),
          );
          
        case RideStatus.inProgress:
        case RideStatus.completed:
          // Keep the active ride screen mounted through completion so drivers can finish reviews
          return DriverActiveRideScreen(
            ride: rideInfo.ride,
            onComplete: () => driverProvider.finalizeCompletedRide(rideInfo.ride.id),
          );
          
        case RideStatus.cancelled:
        case RideStatus.expired:
          // Ride is done - clear and show empty state
          WidgetsBinding.instance.addPostFrameCallback((_) {
            driverProvider.clearActiveRide();
          });
          return _buildNoActiveRideState(isDriver: true);
          
        default:
          return _buildNoActiveRideState(isDriver: true);
      }
    }

    // No active ride - show empty state
    return _buildNoActiveRideState(isDriver: true);
  }

  /// Build passenger's active tab based on ride state  
  Widget _buildPassengerActiveTab(PassengerProvider passengerProvider) {
    // If passenger has an active ride
    if (passengerProvider.hasActiveRide) {
      // Show passenger ride tracking screen
      return const RiderTrackingScreen();
    }

    // No active ride - show empty state
    return _buildNoActiveRideState(isDriver: false);
  }

  /// Build state when user is not authenticated
  Widget _buildNotAuthenticatedState() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Please Sign In',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to view your active rides',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build state when there's no active ride
  Widget _buildNoActiveRideState({required bool isDriver}) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDriver ? Icons.directions_car_outlined : Icons.schedule,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              isDriver ? 'No Active Rides' : 'No Active Requests',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isDriver 
                ? 'Accept a ride request to get started'
                : 'Create a ride request to get started',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),
            
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isDriver 
                        ? 'Go to the Driver tab to browse requests'
                        : 'Go to Find Rides to request a trip'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE57200),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                isDriver ? 'Find Requests' : 'Book a Ride',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show cancel confirmation dialog
  void _showCancelConfirmation(BuildContext context, DriverProvider driverProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text('Are you sure you want to cancel this accepted ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Ride'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Add cancel ride functionality to driver provider
              driverProvider.clearActiveRide();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );
  }
}
