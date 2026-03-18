import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';
import 'ride_request_screen.dart';
import 'request_details_screen.dart';

class RequestsListScreen extends StatefulWidget {
  final bool showArchived;
  
  const RequestsListScreen({super.key, this.showArchived = false});

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      rideProvider.loadRideRequests();
      rideProvider.loadMyRideRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tabs
        Container(
          color: const Color(0xFF232F3E),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFE57200),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: widget.showArchived ? 'Archived Requests' : 'All Requests'),
              Tab(text: widget.showArchived ? 'My Archived' : 'My Requests'),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  _buildAllRequests(),
                  _buildMyRequests(),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: () => _navigateToRequestScreen(),
                  backgroundColor: const Color(0xFFE57200),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    'Request Ride',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllRequests() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, child) {
        if (rideProvider.isLoadingRequests) {
          return const Center(child: CircularProgressIndicator());
        }

        if (rideProvider.requestsError != null) {
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
                  'Error loading requests',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rideProvider.requestsError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => rideProvider.loadRideRequests(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Filter requests based on archive status  
        final requests = widget.showArchived 
            ? rideProvider.rideRequests.where((r) => r.isArchived).toList()
            : rideProvider.rideRequests.where((r) => !r.isArchived).toList();

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.showArchived ? Icons.archive : Icons.add_circle_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.showArchived ? 'No archived requests' : 'No ride requests',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.showArchived 
                      ? 'Archived requests will appear here'
                      : 'Be the first to request a ride',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => rideProvider.loadRideRequests(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildRequestCard(request, rideProvider);
            },
          ),
        );
      },
    );
  }

  Widget _buildMyRequests() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, child) {
        if (rideProvider.isLoadingRequests) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter requests based on archive status
        final requests = widget.showArchived 
            ? rideProvider.myRideRequests.where((r) => r.isArchived).toList()
            : rideProvider.myRideRequests.where((r) => !r.isArchived).toList();

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.showArchived ? Icons.archive : Icons.add_circle_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.showArchived ? 'No archived requests' : 'No requests posted',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.showArchived 
                      ? 'Archived requests will appear here'
                      : 'Request your first ride to get started',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade600,
                  ),
                ),
                if (!widget.showArchived) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToRequestScreen(),
                    icon: const Icon(Icons.add),
                    label: const Text('Request a Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE57200),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => rideProvider.loadMyRideRequests(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildMyRequestCard(request, rideProvider);
            },
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(RideRequest request, RideProvider rideProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                              request.startLocation.address,
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
                              request.endLocation.address,
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
                      'Max \$${request.maxPricePerSeat.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
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
                  _formatDateTime(request.preferredDepartureTime),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '±${request.flexibilityWindow.inMinutes}min',
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
                  '${request.seatsNeeded} seat${request.seatsNeeded != 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRequestStatusColor(request.status),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                request.status.name.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRequestCard(RideRequest request, RideProvider rideProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                              request.startLocation.address,
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
                              request.endLocation.address,
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
                    color: _getRequestStatusColor(request.status),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    request.status.name.toUpperCase(),
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
                  _formatDateTime(request.preferredDepartureTime),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Max \$${request.maxPricePerSeat.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRequestActions(request, rideProvider),
          ],
        ),
      ),
    );
  }

  void _navigateToRequestScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RideRequestScreen(),
      ),
    );
  }

  Widget _buildRequestActions(RideRequest request, RideProvider rideProvider) {
    // Check if request can be archived (completed or cancelled)
    final canArchive = request.status == RequestStatus.completed || 
                      request.status == RequestStatus.cancelled;
    
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _navigateToRequestDetails(request),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE57200)),
              foregroundColor: const Color(0xFFE57200),
            ),
            child: const Text('View Details'),
          ),
        ),
        const SizedBox(width: 8),
        // Show different actions based on status and archive state
        if (request.status == RequestStatus.pending) ...[
          Expanded(
            child: ElevatedButton(
              onPressed: () => _cancelRequest(request.id, rideProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel'),
            ),
          ),
        ] else if (canArchive) ...[
          Expanded(
            child: ElevatedButton(
              onPressed: () => _toggleArchiveRequest(request.id, request.isArchived, rideProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: request.isArchived ? const Color(0xFFE57200) : Colors.grey[600],
                foregroundColor: Colors.white,
              ),
              child: Text(request.isArchived ? 'Unarchive' : 'Archive'),
            ),
          ),
        ],
      ],
    );
  }

  void _navigateToRequestDetails(RideRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RequestDetailsScreen(
          request: request,
          isEditable: true,
        ),
      ),
    );
  }

  Future<void> _toggleArchiveRequest(String requestId, bool isCurrentlyArchived, RideProvider rideProvider) async {
    bool success;
    if (isCurrentlyArchived) {
      success = await rideProvider.unarchiveRideRequest(requestId);
    } else {
      success = await rideProvider.archiveRideRequest(requestId);
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
    }
  }

  Future<void> _cancelRequest(String requestId, RideProvider rideProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel this ride request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await rideProvider.cancelRideRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Request cancelled successfully' : 'Failed to cancel request'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
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
        return Colors.purple;
      case RequestStatus.cancelled:
        return Colors.grey;
    }
  }
}