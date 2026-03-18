import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';
import '../../utils/security_utils.dart';
import 'ride_details_screen.dart';
import '../rider/ride_booking_screen.dart';

class RidesListScreen extends StatefulWidget {
  const RidesListScreen({super.key});

  @override
  State<RidesListScreen> createState() => _RidesListScreenState();
}

class _RidesListScreenState extends State<RidesListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      rideProvider.loadRideOffers();
      rideProvider.loadMyRideOffers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: const Color(0xFF232F3E),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFE57200),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Available Rides'),
                Tab(text: 'My Rides'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAvailableRides(),
                _buildMyRides(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPostRideDialog(),
        backgroundColor: const Color(0xFFE57200),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Post Ride',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableRides() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, child) {
        if (rideProvider.isLoadingOffers) {
          return const Center(child: CircularProgressIndicator());
        }

        if (rideProvider.offersError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading rides',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rideProvider.offersError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => rideProvider.loadRideOffers(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (rideProvider.rideOffers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No available rides',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for new ride offers',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => rideProvider.loadRideOffers(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rideProvider.rideOffers.length,
            itemBuilder: (context, index) {
              final ride = rideProvider.rideOffers[index];
              return _buildRideCard(ride, rideProvider);
            },
          ),
        );
      },
    );
  }

  Widget _buildMyRides() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, child) {
        if (rideProvider.isLoadingOffers) {
          return const Center(child: CircularProgressIndicator());
        }

        if (rideProvider.myRideOffers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.car_rental_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No rides posted',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Post your first ride to help fellow Hoos',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showPostRideDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Post a Ride'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57200),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => rideProvider.loadMyRideOffers(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rideProvider.myRideOffers.length,
            itemBuilder: (context, index) {
              final ride = rideProvider.myRideOffers[index];
              return _buildMyRideCard(ride, rideProvider);
            },
          ),
        );
      },
    );
  }

  Widget _buildRideCard(RideOffer ride, RideProvider rideProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToRideDetails(ride),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.my_location,
                              color: Color(0xFFE57200),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                SecurityUtils.maskAddress(ride.startLocation.address),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                SecurityUtils.maskAddress(ride.endLocation.address),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${ride.pricePerSeat.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE57200),
                        ),
                      ),
                      Text(
                        'per seat',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(ride.departureTime),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.route,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(ride.estimatedDistance * 0.621371).toStringAsFixed(1)} mi', // Direct km to miles conversion
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${ride.availableSeats} seat${ride.availableSeats != 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _navigateToRideDetails(ride),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE57200)),
                        foregroundColor: const Color(0xFFE57200),
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: rideProvider.canJoinRide(ride)
                          ? () => _navigateToBookingScreen(ride)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE57200),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        rideProvider.getUserRoleInRide(ride) == 'passenger'
                            ? 'Joined'
                            : 'Book Ride',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyRideCard(RideOffer ride, RideProvider rideProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToRideDetails(ride),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.my_location,
                              color: Color(0xFFE57200),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                SecurityUtils.maskAddress(ride.startLocation.address),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                SecurityUtils.maskAddress(ride.endLocation.address),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(ride.status),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      ride.status.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(ride.departureTime),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${ride.passengerIds.length}/${ride.totalSeats} passengers',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _navigateToRideDetails(ride),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE57200)),
                        foregroundColor: const Color(0xFFE57200),
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: ride.status == RideStatus.active
                          ? () => _cancelRide(ride.id, rideProvider)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToRideDetails(RideOffer ride) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RideDetailsScreen(ride: ride),
      ),
    );
  }

  void _navigateToBookingScreen(RideOffer ride) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RideBookingScreen(rideOffer: ride),
      ),
    );
  }


  Future<void> _cancelRide(String rideId, RideProvider rideProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Ride'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await rideProvider.cancelRideOffer(rideId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Ride cancelled successfully' : 'Failed to cancel ride'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showPostRideDialog() {
    // TODO: Navigate to ride posting screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ride posting feature coming soon!'),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return 'Today at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    } else {
      return '${dateTime.day}/${dateTime.month} at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    }
  }

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return Colors.green;
      case RideStatus.full:
        return Colors.orange;
      case RideStatus.inProgress:
        return Colors.purple;
      case RideStatus.completed:
        return Colors.blue;
      case RideStatus.cancelled:
        return Colors.red;
      case RideStatus.expired:
        return Colors.red[300]!;
    }
  }
}