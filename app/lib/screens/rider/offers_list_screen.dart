import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';
import '../../utils/security_utils.dart';
import '../../widgets/request_style_card.dart';
import '../rides/ride_details_screen.dart';
import 'find_ride_screen.dart';

class OffersListScreen extends StatefulWidget {
  const OffersListScreen({super.key});

  @override
  State<OffersListScreen> createState() => _OffersListScreenState();
}

class _OffersListScreenState extends State<OffersListScreen> {
  static const Color _uvaOrange = Color(0xFFE57200);
  static const Color _background = Color(0xFFFEF8F4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyRequests());
  }

  Future<void> _loadMyRequests() async {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    await rideProvider.loadMyRideRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _uvaOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        icon: const Icon(Icons.search),
        label: Text(
          'Find a ride',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FindRideScreen()),
          );
        },
      ),
      body: Container(
        color: _background,
        child: RefreshIndicator(
          onRefresh: _loadMyRequests,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: Consumer<RideProvider>(
              builder: (context, rideProvider, child) {
                if (rideProvider.isLoadingRequests) {
                  return const Center(child: CircularProgressIndicator());
                }

              final requests = rideProvider.myRideRequests;
              if (requests.isEmpty) {
                return const _EmptyState();
              }

              final upcoming = requests
                  .where((r) => r.status == RequestStatus.accepted)
                  .toList()
                ..sort((a, b) =>
                    a.preferredDepartureTime.compareTo(b.preferredDepartureTime));

              final pending = requests
                  .where((r) =>
                      r.status == RequestStatus.pending ||
                      r.status == RequestStatus.matched ||
                      r.status == RequestStatus.declined)
                  .toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    _sectionTitle('Upcoming Rides'),
                    if (upcoming.isEmpty)
                      _sectionEmpty(
                        'No upcoming rides',
                        'Accepted requests will appear here.',
                      )
                    else
                      ...upcoming.map(
                        (req) => _requestCard(
                          request: req,
                          statusLabel: 'upcoming',
                          statusColor: Colors.green,
                          allowCancel: true,
                        ),
                      ),
                    const SizedBox(height: 24),
                    _sectionTitle('Pending Requests'),
                    if (pending.isEmpty)
                      _sectionEmpty(
                        'No pending requests',
                        'Use “Find a ride” to send a request.',
                      )
                    else
                      ...pending.map(
                        (req) {
                          final isDeclined =
                              req.status == RequestStatus.declined;
                          return _requestCard(
                            request: req,
                            statusLabel: isDeclined ? 'declined' : 'pending',
                            statusColor:
                                isDeclined ? Colors.red : Colors.orange,
                            allowCancel: true,
                            isPending: !isDeclined,
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      );

  Widget _sectionEmpty(String title, String subtitle) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ],
        ),
      );

  Widget _requestCard({
    required RideRequest request,
    required String statusLabel,
    required Color statusColor,
    bool allowCancel = false,
    bool isPending = false,
  }) {
    final departure = request.preferredDepartureTime;
    final dateText =
        '${departure.month}/${departure.day} at ${TimeOfDay.fromDateTime(departure).format(context)}';

    final priceText = request.maxPricePerSeat > 0
        ? request.maxPricePerSeat.toStringAsFixed(0)
        : null;

    final isDeclined = statusLabel.toLowerCase() == 'declined';

    return RequestStyleCard(
      startAddress: SecurityUtils.maskAddress(request.startLocation.address),
      endAddress: SecurityUtils.maskAddress(request.endLocation.address),
      statusLabel: statusLabel,
      statusColor: statusColor,
      dateText: dateText,
      rightMoneyText: priceText,
      trailingMetaText: priceText != null ? 'per seat' : null,
      distanceInMeters: request.estimatedDistance > 0 
          ? request.estimatedDistance
          : null,
      leftLabel: 'Details',
      rightLabel: allowCancel
          ? (isPending ? 'Cancel' : (isDeclined ? 'Remove' : 'Leave Ride'))
          : 'Close',
      rightButtonColor: allowCancel
          ? (isPending
              ? Colors.red
              : (isDeclined ? Colors.red.shade300 : Colors.orange))
          : Colors.grey.shade400,
      onLeftPressed: () => _showRequestDetails(request),
      onRightPressed: allowCancel ? () => _cancelRequest(request) : null,
    );
  }

  void _showRequestDetails(RideRequest request) {
    // If request has a matched offer, navigate to the full ride details screen
    if (request.matchedOfferId?.isNotEmpty == true) {
      _navigateToRideDetails(request.matchedOfferId!);
      return;
    }
    
    // Otherwise, show the basic request details modal
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Ride Request',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _detailRow('Pickup', request.startLocation.address),
            _detailRow('Drop-off', request.endLocation.address),
            _detailRow(
              'Requested Departure',
              '${request.preferredDepartureTime.month}/${request.preferredDepartureTime.day} '
                  'at ${TimeOfDay.fromDateTime(request.preferredDepartureTime).format(context)}',
            ),
            _detailRow('Seats Requested', '${request.seatsNeeded}'),
            _detailRow('Maximum Fare (per seat)', 
                request.maxPricePerSeat > 0 
                    ? '\$${request.maxPricePerSeat.toStringAsFixed(0)}'
                    : 'No limit'
            ),
            if (request.notes?.isNotEmpty == true)
              _detailRow('Notes', request.notes!),
            _detailRow('Status', _getStatusText(request.status)),
            if (request.status == RequestStatus.declined)
              _detailRow('Info', 'This request was declined. You can create a new request.'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                if (request.status == RequestStatus.pending) ...[
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FindRideScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _uvaOrange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Find More Rides'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _navigateToRideDetails(String offerId) async {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    
    // Show loading indicator while fetching ride details
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      final offer = await rideProvider.getRideOfferById(offerId);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      if (offer != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RideDetailsScreen(ride: offer),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride details not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading ride details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  String _getStatusText(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return 'Waiting for driver acceptance';
      case RequestStatus.matched:
        return 'Matched with a ride';
      case RequestStatus.accepted:
        return 'Accepted';
      case RequestStatus.declined:
        return 'Declined by driver';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(fontSize: 15),
            ),
          ],
        ),
      );

  Future<void> _cancelRequest(RideRequest request) async {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;
    final ok = await rideProvider.cancelRideRequest(request.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Request cancelled' : 'Failed to cancel request'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car, color: Colors.grey, size: 80),
            const SizedBox(height: 16),
            Text(
              'No rides yet',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Use “Find a ride” to request your next trip.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
