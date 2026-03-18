import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/driver_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/driver_status_service.dart';
import '../../widgets/driver/driver_status_card.dart';
import '../../widgets/driver/incoming_request_modal.dart';
import '../../widgets/driver/active_ride_dashboard.dart';
import '../../widgets/driver/driver_earnings_summary.dart';
import '../rides/ride_history_screen.dart';
import 'driver_earnings_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeDriver();
  }

  void _initializeDriver() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final driverProvider = Provider.of<DriverProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      driverProvider.initialize(authProvider.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<DriverProvider>(
        builder: (context, driverProvider, child) {
          return Stack(
            children: [
              // Main content
              SafeArea(
                child: RefreshIndicator(
                  onRefresh: () async {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    if (authProvider.user != null) {
                      await driverProvider.initialize(authProvider.user!.uid);
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        _buildHeader(context, driverProvider),
                        const SizedBox(height: 24),
                        
                        // Status Card
                        DriverStatusCard(
                          status: driverProvider.currentStatus,
                          acceptingRequests: driverProvider.acceptingRequests,
                          onToggleOnline: () => _handleStatusToggle(driverProvider),
                          onToggleRequests: () => driverProvider.toggleAcceptingRequests(),
                          isLoading: driverProvider.isLoading,
                        ),
                        const SizedBox(height: 24),
                        
                        // Error Message Display
                        if (driverProvider.errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error, color: Colors.red[600], size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    driverProvider.errorMessage!,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.red[800],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => driverProvider.clearError(),
                                  icon: Icon(Icons.close, color: Colors.red[600], size: 18),
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        
                        // Active Ride or Earnings
                        if (driverProvider.activeRide != null)
                          ActiveRideDashboard(
                            rideInfo: driverProvider.activeRide!,
                            onPickupPassenger: driverProvider.pickupPassenger,
                            onDropoffPassenger: driverProvider.dropoffPassenger,
                            onCallPassenger: driverProvider.callPassenger,
                            onSendSMS: driverProvider.sendSMSToPassenger,
                            onStartRide: driverProvider.startRide,
                            onCompleteRide: driverProvider.completeRide,
                          )
                        else if (driverProvider.isOnline)
                          _buildWaitingForRides()
                        else
                          const DriverEarningsSummary(),
                        
                        const SizedBox(height: 24),
                        
                        // Quick Actions
                        _buildQuickActions(context, driverProvider),
                        
                        const SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ),
              
              // Incoming Request Modal
              if (driverProvider.hasIncomingRequests)
                IncomingRequestModal(
                  requests: driverProvider.incomingRequests,
                  onAccept: driverProvider.acceptRequest,
                  onDecline: driverProvider.declineRequest,
                ),
              
              // Loading Overlay
              if (driverProvider.isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DriverProvider driverProvider) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    
    return Row(
      children: [
        // Profile Avatar
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.blue[100],
          backgroundImage: user?.photoURL != null 
              ? NetworkImage(user!.photoURL!) 
              : null,
          child: user?.photoURL == null 
              ? Text(
                  user?.displayName?.substring(0, 1).toUpperCase() ?? 'D',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        
        // Welcome Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                user?.displayName?.split(' ').first ?? 'Driver',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
        ),
        
        // Status Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(driverProvider.currentStatus),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _getStatusText(driverProvider.currentStatus),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingForRides() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: Colors.blue[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Looking for rides...',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re online and ready to receive ride requests',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Loading indicator
          SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, DriverProvider driverProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.history,
                title: 'Ride History',
                subtitle: 'View past rides',
                onTap: () => _navigateToRideHistory(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.account_balance_wallet,
                title: 'Earnings',
                subtitle: 'Track income',
                onTap: () => _navigateToEarnings(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.settings,
                title: 'Settings',
                subtitle: 'Preferences',
                onTap: () => _navigateToSettings(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.help_outline,
                title: 'Support',
                subtitle: 'Get help',
                onTap: () => _navigateToSupport(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 24,
              color: Colors.blue[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[900],
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.online:
        return Colors.green;
      case DriverStatus.busy:
        return Colors.orange;
      case DriverStatus.inRide:
        return Colors.blue;
      case DriverStatus.offline:
        return Colors.grey;
    }
  }

  String _getStatusText(DriverStatus status) {
    switch (status) {
      case DriverStatus.online:
        return 'Online';
      case DriverStatus.busy:
        return 'Busy';
      case DriverStatus.inRide:
        return 'In Ride';
      case DriverStatus.offline:
        return 'Offline';
    }
  }

  void _handleStatusToggle(DriverProvider driverProvider) {
    if (driverProvider.isOffline) {
      driverProvider.goOnline();
    } else {
      driverProvider.goOffline();
    }
  }

  void _navigateToRideHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RideHistoryScreen(),
      ),
    );
  }

  void _navigateToEarnings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverEarningsScreen(),
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    // TODO: Navigate to settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings - Coming soon!')),
    );
  }

  void _navigateToSupport(BuildContext context) {
    // TODO: Navigate to support screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Support - Coming soon!')),
    );
  }
}