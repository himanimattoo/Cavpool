import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showArchived = false;
  List<RideRequest> _riderHistory = [];
  List<RideOffer> _driverHistory = [];
  List<RideRequest> _archivedRiderHistory = [];
  List<RideOffer> _archivedDriverHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistoryData();
    });
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);
    
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    
    final riderHistory = await rideProvider.getHistoryRideRequests();
    final driverHistory = await rideProvider.getHistoryRideOffers();
    final archivedRiderHistory = await rideProvider.getArchivedRideRequests();
    final archivedDriverHistory = await rideProvider.getArchivedRideOffers();
    
    setState(() {
      _riderHistory = riderHistory;
      _driverHistory = driverHistory;
      _archivedRiderHistory = archivedRiderHistory;
      _archivedDriverHistory = archivedDriverHistory;
      _isLoading = false;
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
      appBar: AppBar(
        title: const Text('Ride History'),
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.unarchive : Icons.archive),
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
              });
            },
            tooltip: _showArchived ? 'Show Active' : 'Show Archived',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE57200),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: _showArchived ? 'Archived Rides' : 'As Rider'),
            Tab(text: _showArchived ? 'Archived Offers' : 'As Driver'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRiderHistory(),
          _buildDriverHistory(),
        ],
      ),
    );
  }

  Widget _buildRiderHistory() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _showArchived ? _archivedRiderHistory : _riderHistory;
    
    if (data.isEmpty) {
      return _buildEmptyState(
        _showArchived ? 'No archived rides' : 'No ride history yet',
        _showArchived ? 'Archived rides will appear here' : 'Your completed rides will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistoryData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: data.length,
        itemBuilder: (context, index) {
          final request = data[index];
          return _buildRideRequestCard(request);
        },
      ),
    );
  }

  Widget _buildDriverHistory() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _showArchived ? _archivedDriverHistory : _driverHistory;
    
    if (data.isEmpty) {
      return _buildEmptyState(
        _showArchived ? 'No archived offers' : 'No offer history yet',
        _showArchived ? 'Archived offers will appear here' : 'Your completed offers will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistoryData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: data.length,
        itemBuilder: (context, index) {
          final offer = data[index];
          return _buildRideOfferCard(offer);
        },
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showArchived ? Icons.archive : Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideRequestCard(RideRequest request) {
    final statusColor = _getRequestStatusColor(request.status);
    final statusIcon = _getRequestStatusIcon(request.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.startLocation.address} → ${request.endLocation.address}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      request.status.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _formatDate(request.preferredDepartureTime),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.seatsNeeded} seat${request.seatsNeeded != 1 ? 's' : ''} needed',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Text(
                request.status == RequestStatus.cancelled 
                    ? 'Cancelled' 
                    : 'Max \$${request.maxPricePerSeat.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: request.status == RequestStatus.cancelled 
                      ? Colors.grey[600] 
                      : const Color(0xFF232F3E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActionButtons(
            isRequest: true,
            rideId: request.id,
            isArchived: request.isArchived,
            status: request.status.name,
            route: '${request.startLocation.address} → ${request.endLocation.address}',
          ),
        ],
      ),
    );
  }

  Widget _buildRideOfferCard(RideOffer offer) {
    final statusColor = _getRideStatusColor(offer.status);
    final statusIcon = _getRideStatusIcon(offer.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${offer.startLocation.address} → ${offer.endLocation.address}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      offer.status.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _formatDate(offer.departureTime),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${offer.totalSeats - offer.availableSeats}/${offer.totalSeats} passengers',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Text(
                offer.status == RideStatus.cancelled 
                    ? 'Cancelled' 
                    : 'Earned \$${(offer.pricePerSeat * (offer.totalSeats - offer.availableSeats)).toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: offer.status == RideStatus.cancelled 
                      ? Colors.grey[600] 
                      : const Color(0xFF232F3E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActionButtons(
            isRequest: false,
            rideId: offer.id,
            isArchived: offer.isArchived,
            status: offer.status.name,
            route: '${offer.startLocation.address} → ${offer.endLocation.address}',
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required bool isRequest,
    required String rideId,
    required bool isArchived,
    required String status,
    required String route,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              _showRideDetails(context, route, rideId, status, isRequest);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[400]!),
            ),
            child: Text(
              'View Details',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _toggleArchiveStatus(rideId, isArchived, isRequest),
            style: ElevatedButton.styleFrom(
              backgroundColor: isArchived ? const Color(0xFFE57200) : Colors.grey[600],
              foregroundColor: Colors.white,
            ),
            child: Text(
              isArchived ? 'Unarchive' : 'Archive',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
        ),
        if (status == 'completed' && !isArchived) ...[
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _showRatingDialog(context, route);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE57200),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Rate Ride',
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _toggleArchiveStatus(String rideId, bool isCurrentlyArchived, bool isRequest) async {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    
    bool success;
    if (isCurrentlyArchived) {
      // Unarchive
      success = isRequest 
          ? await rideProvider.unarchiveRideRequest(rideId)
          : await rideProvider.unarchiveRideOffer(rideId);
    } else {
      // Archive
      success = isRequest 
          ? await rideProvider.archiveRideRequest(rideId)
          : await rideProvider.archiveRideOffer(rideId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? '${isCurrentlyArchived ? 'Unarchived' : 'Archived'} successfully!'
                : 'Failed to ${isCurrentlyArchived ? 'unarchive' : 'archive'}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      
      if (success) {
        await _loadHistoryData();
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    }
  }

  Color _getRequestStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Colors.orange;
      case RequestStatus.matched:
        return Colors.blue;
      case RequestStatus.accepted:
        return Colors.green;
      case RequestStatus.declined:
        return Colors.red;
      case RequestStatus.completed:
        return Colors.green;
      case RequestStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getRequestStatusIcon(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Icons.schedule;
      case RequestStatus.matched:
        return Icons.link;
      case RequestStatus.accepted:
        return Icons.check_circle;
      case RequestStatus.declined:
        return Icons.cancel;
      case RequestStatus.completed:
        return Icons.done_all;
      case RequestStatus.cancelled:
        return Icons.block;
    }
  }

  Color _getRideStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return Colors.blue;
      case RideStatus.full:
        return Colors.orange;
      case RideStatus.inProgress:
        return Colors.purple;
      case RideStatus.completed:
        return Colors.green;
      case RideStatus.cancelled:
        return Colors.grey;
      case RideStatus.expired:
        return Colors.red;
    }
  }

  IconData _getRideStatusIcon(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return Icons.directions_car;
      case RideStatus.full:
        return Icons.group;
      case RideStatus.inProgress:
        return Icons.play_arrow;
      case RideStatus.completed:
        return Icons.done_all;
      case RideStatus.cancelled:
        return Icons.block;
      case RideStatus.expired:
        return Icons.schedule;
    }
  }

  void _showRideDetails(BuildContext context, String route, String rideId, String status, bool isRequest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Ride Details',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Route', route),
            _buildDetailRow('ID', rideId),
            _buildDetailRow('Status', status.toUpperCase()),
            _buildDetailRow('Type', isRequest ? 'Ride Request' : 'Ride Offer'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(),
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, String route) {
    int rating = 0;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Rate Your Ride',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                route,
                style: GoogleFonts.inter(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        rating = index + 1;
                      });
                    },
                    icon: Icon(
                      Icons.star,
                      color: index < rating ? Colors.amber : Colors.grey[400],
                      size: 32,
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: rating > 0 ? () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for your rating!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE57200),
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}