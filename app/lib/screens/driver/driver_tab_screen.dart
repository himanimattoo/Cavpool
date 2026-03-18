import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/ride_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/driver_provider.dart';
import '../../services/auth_service.dart';
import '../../services/message_service.dart';
import '../driver/driver_post_ride_screen.dart';
import 'drive_details_screen.dart';
import 'driver_verification_screen.dart';
import 'passengers_list_screen.dart';

class DriverTabScreen extends StatefulWidget {
  const DriverTabScreen({super.key});

  @override
  State<DriverTabScreen> createState() => _DriverTabScreenState();
}

class _DriverTabScreenState extends State<DriverTabScreen> {
  static const background = Color(0xFFFEF8F4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  Future<void> _refreshData() async {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await rideProvider.loadMyRideOffers();
    final uid = auth.user?.uid;
    if (uid != null) {
      await rideProvider.loadDriverPendingRequests(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = context.watch<RideProvider>();
    final rides = rideProvider.myRideOffers
        .where((ride) => !ride.isArchived)
        .toList()
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refreshData,
          child: Container(
            color: background,
            child: rides.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 120),
                    children: const [
                      _SectionHeader(label: 'Upcoming Drives'),
                      SizedBox(height: 16),
                      _EmptyState(
                        icon: Icons.directions_car,
                        title: 'No upcoming drives',
                        subtitle: 'Post a drive to get started!',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: rides.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const _SectionHeader(label: 'Upcoming Drives');
                      }
                      final ride = rides[index - 1];
                      final pending = rideProvider.driverPendingRequests
                          .where((req) => req.matchedOfferId == ride.id)
                          .toList();
                      return _DriveCard(
                        ride: ride,
                        pendingRequests: pending,
                        rideProvider: rideProvider,
                      );
                    },
                  ),
          ),
        ),
        const Positioned(
          right: 16,
          bottom: 24,
          child: _PostDriveFab(),
        ),
      ],
    );
  }
}

class _DriveCard extends StatelessWidget {
  const _DriveCard({
    required this.ride,
    required this.pendingRequests,
    required this.rideProvider,
  });

  final RideOffer ride;
  final List<RideRequest> pendingRequests;
  final RideProvider rideProvider;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingRequests.isNotEmpty;
    final passengers = ride.passengerIds;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.my_location,
                              color: Color(0xFFE57200), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ride.startLocation.address,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ride.endLocation.address,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasPending)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${pendingRequests.length} request${pendingRequests.length == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${ride.departureTime.month}/${ride.departureTime.day} at ${TimeOfDay.fromDateTime(ride.departureTime).format(context)}',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event_seat, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${ride.availableSeats}/${ride.totalSeats} seats available',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '\$${ride.pricePerSeat.toStringAsFixed(0)} / seat',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DriveDetailsScreen(
                            offer: ride,
                            isEditable: true,
                          ),
                        ),
                      );
                    },
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
                    onPressed: () async {
                      final ok = await rideProvider.cancelRideOffer(ride.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              ok ? 'Drive cancelled' : 'Failed to cancel'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cancel drive'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasPending) ...[
              Text(
                'Pending requests',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...pendingRequests.map(
                (req) => _PendingRequestTile(
                  request: req,
                  rideProvider: rideProvider,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Passengers (${passengers.length})',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (passengers.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PassengersListScreen(ride: ride),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE57200),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (passengers.isEmpty)
              Text(
                'No passengers yet.',
                style: GoogleFonts.inter(color: Colors.grey.shade600),
              )
            else
              Column(
                children: passengers
                    .map((passengerId) => _buildPassengerListTile(passengerId))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerListTile(String passengerId) {
    return FutureBuilder<UserModel?>(
      future: _getPassengerData(passengerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey,
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading...',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        final passenger = snapshot.data;
        String displayName = passenger?.profile.displayName.trim() ?? '';
        if (displayName.isEmpty) {
          final firstName = passenger?.profile.firstName.trim() ?? '';
          final lastName = passenger?.profile.lastName.trim() ?? '';
          if (firstName.isNotEmpty && lastName.isNotEmpty) {
            displayName = '$firstName $lastName';
          } else if (firstName.isNotEmpty) {
            displayName = firstName;
          } else {
            displayName = 'Unknown Passenger';
          }
        }

        final seatCount = ride.passengerSeatCounts[passengerId] ?? 1;
        final displayWithGuests = seatCount > 1
            ? '$displayName + ${seatCount - 1} other${seatCount - 1 == 1 ? '' : 's'}'
            : displayName;

        final seatPrice = ride.passengerSeatPrices[passengerId] ?? ride.pricePerSeat;

        return InkWell(
          onTap: () => _showPassengerProfile(context, passenger, passengerId, ride),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: passenger?.profile.photoURL.isNotEmpty == true
                      ? NetworkImage(passenger!.profile.photoURL)
                      : null,
                  child: passenger?.profile.photoURL.isEmpty != false
                      ? Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
                        displayWithGuests,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${seatPrice.toStringAsFixed(2)} / seat',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (passenger != null && passenger.ratings.averageRating > 0)
                        Row(
                          children: [
                            Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                            const SizedBox(width: 2),
                            Text(
                              passenger.ratings.averageRating.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        )
                      else if (passenger != null)
                        Text(
                          'New rider',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPassengerProfile(
    BuildContext context,
    UserModel? passenger,
    String passengerId,
    RideOffer ride,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PassengerProfileBottomSheet(
        passenger: passenger,
        passengerId: passengerId,
        ride: ride,
      ),
    );
  }

  Future<UserModel?> _getPassengerData(String passengerId) async {
    try {
      final authService = AuthService();
      final userDoc = await authService.getUserData(passengerId);
      if (userDoc != null && userDoc.exists) {
        return UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      // Handle error silently
    }
    return null;
  }
}

class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({
    required this.request,
    required this.rideProvider,
  });

  final RideRequest request;
  final RideProvider rideProvider;

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final departure = request.preferredDepartureTime;
    final dateText =
        '${departure.month}/${departure.day} ${TimeOfDay.fromDateTime(departure).format(context)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      Row(children: [
                        const Icon(Icons.my_location, color: Color(0xFFE57200), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.startLocation.address,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.endLocation.address,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'PENDING',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(dateText, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                if (request.maxPricePerSeat > 0) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.attach_money, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(request.maxPricePerSeat.toStringAsFixed(0), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(width: 4),
                  Text('per seat', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRequestDetails(context, request, rideProvider),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      foregroundColor: Colors.blue,
                    ),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    onPressed: () async {
                      final ok = await rideProvider.declineRideRequest(request.id);
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Request declined' : 'Failed to decline'),
                          backgroundColor: ok ? Colors.orange : Colors.red,
                        ),
                      );
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    onPressed: () async {
                      final ok = await rideProvider.acceptRideRequest(request.id);
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Request accepted' : 'Failed to accept'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.green.shade300),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showRequestDetails(BuildContext context, RideRequest request, RideProvider rideProvider) {
  showDialog(
    context: context,
    builder: (context) => _RequestDetailsDialog(
      request: request,
      rideProvider: rideProvider,
    ),
  );
}

class _RequestDetailsDialog extends StatefulWidget {
  final RideRequest request;
  final RideProvider rideProvider;

  const _RequestDetailsDialog({
    required this.request,
    required this.rideProvider,
  });

  @override
  State<_RequestDetailsDialog> createState() => _RequestDetailsDialogState();
}

class _RequestDetailsDialogState extends State<_RequestDetailsDialog> {
  final AuthService _authService = AuthService();
  UserModel? _passengerData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPassengerData();
  }

  Future<void> _fetchPassengerData() async {
    try {
      final userDoc = await _authService.getUserData(widget.request.requesterId);
      if (userDoc != null && userDoc.exists) {
        setState(() {
          _passengerData = UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Request Details',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Passenger Info
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_passengerData != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: _passengerData!.profile.photoURL.isNotEmpty
                          ? NetworkImage(_passengerData!.profile.photoURL)
                          : null,
                      child: _passengerData!.profile.photoURL.isEmpty
                          ? Text(
                              _passengerData!.profile.displayName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _passengerData!.profile.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_passengerData!.ratings.averageRating > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber.shade600, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  _passengerData!.ratings.averageRating.toStringAsFixed(1),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Trip Details
            Text(
              'Trip Details',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.my_location, color: Color(0xFFE57200), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.request.startLocation.address,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.request.endLocation.address,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.grey, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        '${widget.request.preferredDepartureTime.month}/${widget.request.preferredDepartureTime.day} at ${TimeOfDay.fromDateTime(widget.request.preferredDepartureTime).format(context)}',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ],
                  ),
                  if (widget.request.seatsNeeded > 1) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.people, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          '${widget.request.seatsNeeded} passengers',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                  if (widget.request.maxPricePerSeat > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.attach_money, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Max ${widget.request.maxPricePerSeat.toStringAsFixed(0)} per seat',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final ok = await widget.rideProvider.declineRideRequest(widget.request.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Request declined' : 'Failed to decline'),
                          backgroundColor: ok ? Colors.orange : Colors.red,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final ok = await widget.rideProvider.acceptRideRequest(widget.request.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Request accepted' : 'Failed to accept'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostDriveFab extends StatelessWidget {
  const _PostDriveFab();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final acct = auth.userModel == null
        ? 'rider'
        : auth.userModel!.accountType.toLowerCase();
    final isVerifiedDriver = acct == 'driver';

    return FloatingActionButton.extended(
      heroTag: 'post-drive-fab',
      backgroundColor: const Color(0xFFE57200),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      icon: const Icon(Icons.add),
      label: Text(
        'Post Drive',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      onPressed: () => _handleTap(context, isVerifiedDriver),
    );
  }

  void _handleTap(BuildContext context, bool isVerifiedDriver) {
    if (!isVerifiedDriver) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Get Verified'),
          content: const Text(
            'Only verified drivers can post a drive.\nStart verification now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DriverVerificationScreen(),
                  ),
                );
              },
              child: const Text('Start Verification'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DriverPostRideScreen(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _PassengerProfileBottomSheet extends StatelessWidget {
  final UserModel? passenger;
  final String passengerId;
  final RideOffer ride;

  const _PassengerProfileBottomSheet({
    required this.passenger,
    required this.passengerId,
    required this.ride,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Passenger Profile',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (passenger != null) ...[
            // Profile Info
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: passenger!.profile.photoURL.isNotEmpty
                      ? NetworkImage(passenger!.profile.photoURL)
                      : null,
                  child: passenger!.profile.photoURL.isEmpty
                      ? Text(
                          passenger!.profile.displayName.isNotEmpty
                              ? passenger!.profile.displayName[0].toUpperCase()
                              : 'P',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passenger!.profile.displayName.isNotEmpty
                            ? passenger!.profile.displayName
                            : 'Passenger',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (passenger!.ratings.averageRating > 0) ...[
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber.shade600, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              passenger!.ratings.averageRating.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${passenger!.ratings.totalRatings} rating${passenger!.ratings.totalRatings != 1 ? 's' : ''})',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          'New rider - No ratings yet',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildPassengerRideInfo(context),
            const SizedBox(height: 24),

            // Contact Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleCall(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                    ),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleMessage(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      foregroundColor: Colors.blue,
                    ),
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text('Message'),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Error state
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load passenger information',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Passenger ID: $passengerId',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPassengerRideInfo(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomPadding = viewInsets.bottom + 24;

    final seatPrice = ride.passengerSeatPrices[passengerId];
    final pickup = ride.passengerPickupLocations[passengerId];
    final dropoff = ride.passengerDropoffLocations[passengerId];

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ride Details',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _infoRow(
                    icon: Icons.attach_money,
                    label: 'Accepted price',
                    value: seatPrice != null
                        ? '\$${seatPrice.toStringAsFixed(2)} per seat'
                        : '\$${ride.pricePerSeat.toStringAsFixed(2)} per seat',
                  ),
                  const SizedBox(height: 12),
                  _infoRow(
                    icon: Icons.my_location,
                    label: 'Pickup',
                    value: (pickup ?? ride.startLocation).address,
                  ),
                  const SizedBox(height: 12),
                  _infoRow(
                    icon: Icons.location_on,
                    label: 'Drop-off',
                    value: (dropoff ?? ride.endLocation).address,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleCall(BuildContext context) async {
    if (passenger?.profile.phoneNumber == null || passenger!.profile.phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available for this passenger'),
        ),
      );
      return;
    }

    final phoneNumber = passenger!.profile.phoneNumber;
    final driverProvider = Provider.of<DriverProvider>(context, listen: false);
    
    try {
      final success = await driverProvider.callPassenger(phoneNumber);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initiate call'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making call: $e'),
          ),
        );
      }
    }
  }

  void _handleMessage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildMessageSheet(context),
    );
  }

  Widget _buildMessageSheet(BuildContext context) {
    return _MessageSheetWidget(
      passenger: passenger,
      passengerId: passengerId,
      rideId: ride.id,
    );
  }
}

class _MessageSheetWidget extends StatefulWidget {
  final UserModel? passenger;
  final String passengerId;
  final String rideId;

  const _MessageSheetWidget({
    required this.passenger,
    required this.passengerId,
    required this.rideId,
  });

  @override
  State<_MessageSheetWidget> createState() => _MessageSheetWidgetState();
}

class _MessageSheetWidgetState extends State<_MessageSheetWidget> {
  final TextEditingController _messageController = TextEditingController();
  final MessageService _messageService = MessageService();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || _isSending) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid;

    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to send messages'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _messageService.sendMessage(
        rideId: widget.rideId,
        senderId: currentUserId,
        recipientId: widget.passengerId,
        content: message.trim(),
      );

      _messageController.clear();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quickMessages = [
      "I'm on my way to pick you up!",
      "I'm running about 5 minutes late",
      "I've arrived at your pickup location",
      "Please come outside, I'm here",
      "Thank you for riding with me!",
    ];

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Send Message to ${widget.passenger?.profile.displayName ?? "Passenger"}',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom message input
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _messageController,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                hintStyle: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                ),
              ),
              style: GoogleFonts.inter(),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                setState(() {}); // Update button state
              },
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _sendMessage(value);
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Send button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending || _messageController.text.trim().isEmpty
                  ? null
                  : () => _sendMessage(_messageController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Send Message',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Quick Messages',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 12),

          // Quick messages
          ...quickMessages.map((message) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                onTap: () => _sendMessage(message),
              )),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
