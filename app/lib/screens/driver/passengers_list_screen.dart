import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ride_model.dart';
import '../../models/user_model.dart';
import '../../services/ride_service.dart';
import '../../services/auth_service.dart';

class PassengersListScreen extends StatefulWidget {
  final RideOffer ride;

  const PassengersListScreen({
    super.key,
    required this.ride,
  });

  @override
  State<PassengersListScreen> createState() => _PassengersListScreenState();
}

class _PassengersListScreenState extends State<PassengersListScreen> {
  final RideService _rideService = RideService();
  final AuthService _authService = AuthService();
  Map<String, UserModel> _passengerProfiles = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Defer loading until after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPassengerProfiles();
    });
  }

  Future<void> _loadPassengerProfiles() async {
    try {
      final profiles = <String, UserModel>{};
      
      for (final passengerId in widget.ride.passengerIds) {
        try {
          // Load user data directly using AuthService
          final userDoc = await _authService.getUserData(passengerId);
          if (userDoc != null && userDoc.exists) {
            final userModel = UserModel.fromFirestore(userDoc);
            profiles[passengerId] = userModel;
          }
        } catch (e) {
          debugPrint('Error loading profile for passenger $passengerId: $e');
          // Continue loading other passengers even if one fails
        }
      }
      
      if (mounted) {
        setState(() {
          _passengerProfiles = profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading passenger profiles: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Passengers (${widget.ride.passengerIds.length})',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF232F3E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.ride.passengerIds.isEmpty
              ? _buildEmptyState()
              : _buildPassengersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No passengers yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Passengers will appear here when they book your ride',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.ride.passengerIds.length,
      itemBuilder: (context, index) {
        final passengerId = widget.ride.passengerIds[index];
        final profile = _passengerProfiles[passengerId];
        final pickupLocation = widget.ride.passengerPickupLocations[passengerId];
        final dropoffLocation = widget.ride.passengerDropoffLocations[passengerId];
        final seatCount = widget.ride.passengerSeatCounts[passengerId] ?? 1;
        final seatPrice = widget.ride.passengerSeatPrices[passengerId] ?? widget.ride.pricePerSeat;
        final pickupStatus = widget.ride.passengerPickupStatus[passengerId] ?? PickupStatus.pending;
        
        return _buildPassengerCard(
          passengerId: passengerId,
          profile: profile,
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          seatCount: seatCount,
          seatPrice: seatPrice,
          pickupStatus: pickupStatus,
        );
      },
    );
  }

  Widget _buildPassengerCard({
    required String passengerId,
    required UserModel? profile,
    required RideLocation? pickupLocation,
    required RideLocation? dropoffLocation,
    required int seatCount,
    required double seatPrice,
    required PickupStatus pickupStatus,
  }) {
    final passengerName = profile?.profile.displayName ?? profile?.email ?? 'Unknown Passenger';
    final pickup = pickupLocation ?? widget.ride.startLocation;
    final dropoff = dropoffLocation ?? widget.ride.endLocation;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Passenger header
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: profile?.profile.photoURL.isNotEmpty == true
                      ? NetworkImage(profile!.profile.photoURL)
                      : null,
                  backgroundColor: const Color(0xFFE57200),
                  child: profile?.profile.photoURL.isEmpty != false
                      ? Text(
                          passengerName[0].toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passengerName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (profile?.email != null)
                        Text(
                          profile!.email,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(pickupStatus),
              ],
            ),
            const SizedBox(height: 16),
            
            // Ride details
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.event_seat,
                    label: 'Seats',
                    value: '$seatCount',
                    color: const Color(0xFFE57200),
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.attach_money,
                    label: 'Price',
                    value: '\$${seatPrice.toStringAsFixed(2)}',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.calculate,
                    label: 'Total',
                    value: '\$${(seatPrice * seatCount).toStringAsFixed(2)}',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Pickup location
            _buildLocationCard(
              icon: Icons.my_location,
              label: 'Pickup Location',
              address: pickup.address,
              color: Colors.green,
              onTap: () => _openMaps(pickup.coordinates.latitude, pickup.coordinates.longitude, 'Pickup: ${pickup.address}'),
            ),
            const SizedBox(height: 8),
            
            // Dropoff location
            _buildLocationCard(
              icon: Icons.location_on,
              label: 'Dropoff Location',
              address: dropoff.address,
              color: Colors.red,
              onTap: () => _openMaps(dropoff.coordinates.latitude, dropoff.coordinates.longitude, 'Dropoff: ${dropoff.address}'),
            ),
            
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              children: [
                if (profile?.profile.phoneNumber.isNotEmpty == true) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callPassenger(profile!.profile.phoneNumber),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updatePickupStatus(passengerId, pickupStatus),
                    icon: Icon(_getStatusIcon(pickupStatus), size: 18),
                    label: Text(_getStatusAction(pickupStatus)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getStatusColor(pickupStatus),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(PickupStatus status) {
    String text;
    Color color;
    
    switch (status) {
      case PickupStatus.pending:
        text = 'PENDING';
        color = Colors.orange;
        break;
      case PickupStatus.driverArrived:
        text = 'ARRIVED';
        color = Colors.blue;
        break;
      case PickupStatus.passengerPickedUp:
        text = 'PICKED UP';
        color = Colors.green;
        break;
      case PickupStatus.completed:
        text = 'COMPLETED';
        color = Colors.grey;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard({
    required IconData icon,
    required String label,
    required String address,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    address,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.navigation,
              color: Colors.grey.shade400,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(PickupStatus status) {
    switch (status) {
      case PickupStatus.pending:
        return Icons.directions_car;
      case PickupStatus.driverArrived:
        return Icons.person_add;
      case PickupStatus.passengerPickedUp:
        return Icons.check;
      case PickupStatus.completed:
        return Icons.flag;
    }
  }

  String _getStatusAction(PickupStatus status) {
    switch (status) {
      case PickupStatus.pending:
        return 'Mark Arrived';
      case PickupStatus.driverArrived:
        return 'Pick Up';
      case PickupStatus.passengerPickedUp:
        return 'Complete';
      case PickupStatus.completed:
        return 'Done';
    }
  }

  Color _getStatusColor(PickupStatus status) {
    switch (status) {
      case PickupStatus.pending:
        return Colors.orange;
      case PickupStatus.driverArrived:
        return Colors.blue;
      case PickupStatus.passengerPickedUp:
        return Colors.green;
      case PickupStatus.completed:
        return Colors.grey;
    }
  }

  Future<void> _updatePickupStatus(String passengerId, PickupStatus currentStatus) async {
    PickupStatus nextStatus;
    
    switch (currentStatus) {
      case PickupStatus.pending:
        nextStatus = PickupStatus.driverArrived;
        break;
      case PickupStatus.driverArrived:
        nextStatus = PickupStatus.passengerPickedUp;
        break;
      case PickupStatus.passengerPickedUp:
        nextStatus = PickupStatus.completed;
        break;
      case PickupStatus.completed:
        return; // Can't progress further
    }

    try {
      final newPickupStatus = Map<String, PickupStatus>.from(widget.ride.passengerPickupStatus);
      newPickupStatus[passengerId] = nextStatus;
      
      await _rideService.updateRideOffer(widget.ride.id, {
        'passengerPickupStatus': newPickupStatus.map((k, v) => MapEntry(k, v.name)),
      });

      // If passenger was just dropped off, mark their request as completed
      if (nextStatus == PickupStatus.completed) {
        try {
          await _rideService.markPassengerRideRequestCompleted(widget.ride.id, passengerId);
        } catch (e) {
          debugPrint('Error marking passenger request as completed: $e');
        }
      }

      // Refresh the UI
      setState(() {
        widget.ride.passengerPickupStatus[passengerId] = nextStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated passenger status to ${nextStatus.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _callPassenger(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not call $phoneNumber'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openMaps(double latitude, double longitude, String label) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}