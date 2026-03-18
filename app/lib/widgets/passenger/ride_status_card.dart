import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/passenger_provider.dart';
import '../../screens/rides/ride_review_screen.dart';
import 'package:provider/provider.dart';

class RideStatusCard extends StatefulWidget {
  final PassengerRideInfo rideInfo;
  final VoidCallback onCancel;
  final Future<void> Function(double rating, String? comment) onRate;

  const RideStatusCard({
    super.key,
    required this.rideInfo,
    required this.onCancel,
    required this.onRate,
  });

  @override
  State<RideStatusCard> createState() => _RideStatusCardState();
}

class _RideStatusCardState extends State<RideStatusCard> {
  bool? _hasRated;
  Map<String, dynamic>? _existingRating;

  @override
  void initState() {
    super.initState();
    if (widget.rideInfo.state == PassengerRideState.completed) {
      _checkRatingStatus();
    }
  }

  @override
  void didUpdateWidget(RideStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rideInfo.state != widget.rideInfo.state &&
        widget.rideInfo.state == PassengerRideState.completed) {
      _checkRatingStatus();
    }
  }

  Future<void> _checkRatingStatus() async {
    final passProvider = context.read<PassengerProvider>();
    try {
      final hasRated = await passProvider.hasRatedCurrentRide();
      final existingRating = hasRated ? await passProvider.getCurrentRideRating() : null;
      
      if (mounted) {
        setState(() {
          _hasRated = hasRated;
          _existingRating = existingRating;
        });
      }
    } catch (e) {
      // Silently handle error - default to showing rating button
      if (mounted) {
        setState(() {
          _hasRated = false;
          _existingRating = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                _getStatusIcon(),
                color: _getStatusColor(),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Ride Details',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Trip Info
          _buildTripInfo(context),
          
          const SizedBox(height: 16),
          
          // Actions
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildTripInfo(BuildContext context) {
    return Column(
      children: [
        // Pickup Location
        _buildLocationRow(
          icon: Icons.my_location,
          iconColor: Colors.green,
          label: 'Pickup',
          address: widget.rideInfo.request.startLocation.address,
          time: _formatTime(widget.rideInfo.request.preferredDepartureTime, context),
        ),
        
        const SizedBox(height: 12),
        
        // Dropoff Location
        _buildLocationRow(
          icon: Icons.location_on,
          iconColor: Colors.red,
          label: 'Dropoff',
          address: widget.rideInfo.request.endLocation.address,
        ),
        
        const SizedBox(height: 16),
        
        // Ride Info Row
        Row(
          children: [
            Expanded(
              child: _buildInfoChip(
                icon: Icons.people,
                label: '${widget.rideInfo.request.seatsNeeded} seat${widget.rideInfo.request.seatsNeeded > 1 ? 's' : ''}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoChip(
                icon: Icons.attach_money,
                label: '\$${widget.rideInfo.request.maxPricePerSeat.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoChip(
                icon: Icons.access_time,
                label: _getFlexibilityText(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    String? time,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (time != null) ...[
                    const Spacer(),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[900],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    switch (widget.rideInfo.state) {
      case PassengerRideState.requestPending:
      case PassengerRideState.matched:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[600],
              side: BorderSide(color: Colors.red[300]!),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              'Cancel Request',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
        
      case PassengerRideState.driverEnRoute:
      case PassengerRideState.driverArrived:
      case PassengerRideState.inRide:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showEmergencyOptions(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[600],
                  side: BorderSide(color: Colors.red[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emergency, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Emergency',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showSafetyOptions(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Safety',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        
      case PassengerRideState.completed:
        if (_hasRated == null) {
          // Still checking rating status
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Checking rating status...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (_hasRated == true) {
          // Already rated - show confirmation
          final rating = _existingRating?['rating']?.toDouble() ?? 0.0;
          final comment = _existingRating?['comment'] as String?;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border.all(color: Colors.green[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Review Submitted',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(5, (index) => Icon(
                      Icons.star,
                      size: 16,
                      color: index < rating ? Colors.amber : Colors.grey[300],
                    )),
                    const SizedBox(width: 8),
                    Text(
                      '${rating.toStringAsFixed(1)} stars',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"$comment"',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );
        } else {
          // Not rated yet - show rating button
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showRatingDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Rate Your Driver',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
        
      default:
        return const SizedBox.shrink();
    }
  }

  IconData _getStatusIcon() {
    switch (widget.rideInfo.state) {
      case PassengerRideState.requestPending:
        return Icons.hourglass_empty;
      case PassengerRideState.matched:
        return Icons.person_add;
      case PassengerRideState.driverEnRoute:
        return Icons.directions_car;
      case PassengerRideState.driverArrived:
        return Icons.location_on;
      case PassengerRideState.inRide:
        return Icons.navigation;
      case PassengerRideState.completed:
        return Icons.check_circle;
      case PassengerRideState.cancelled:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor() {
    switch (widget.rideInfo.state) {
      case PassengerRideState.requestPending:
        return Colors.orange;
      case PassengerRideState.matched:
        return Colors.blue;
      case PassengerRideState.driverEnRoute:
        return Colors.purple;
      case PassengerRideState.driverArrived:
        return Colors.green;
      case PassengerRideState.inRide:
        return Colors.blue;
      case PassengerRideState.completed:
        return Colors.green;
      case PassengerRideState.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (widget.rideInfo.state) {
      case PassengerRideState.requestPending:
        return 'PENDING';
      case PassengerRideState.matched:
        return 'MATCHED';
      case PassengerRideState.driverEnRoute:
        return 'EN ROUTE';
      case PassengerRideState.driverArrived:
        return 'ARRIVED';
      case PassengerRideState.inRide:
        return 'IN RIDE';
      case PassengerRideState.completed:
        return 'COMPLETED';
      case PassengerRideState.cancelled:
        return 'CANCELLED';
      default:
        return 'UNKNOWN';
    }
  }

  String _formatTime(DateTime dateTime, BuildContext context) {
    return TimeOfDay.fromDateTime(dateTime).format(context);
  }

  String _getFlexibilityText() {
    final minutes = widget.rideInfo.request.flexibilityWindow.inMinutes;
    if (minutes == 0) {
      return 'Exact time';
    } else if (minutes < 60) {
      return '±${minutes}m';
    } else {
      return '±${(minutes / 60).toStringAsFixed(1)}h';
    }
  }

Future<void> _showRatingDialog(BuildContext context) async {
  final result = await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => RideReviewScreen(
        revieweeName: widget.rideInfo.driver?.profile.displayName ?? 'your driver',
        title: 'Rate Your Driver',
        subtitle: 'Share your experience so we can keep rides safe and friendly.',
        onSubmit: (rating, comment) async {
          await widget.onRate(rating, comment);
          // After successful rating, refresh the rating status
          await _checkRatingStatus();
        },
      ),
    ),
  );
  
  // If the user successfully rated, refresh the status
  if (result == true && mounted) {
    await _checkRatingStatus();
  }
}

  void _showEmergencyOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency'),
        content: const Text('This will immediately contact emergency services and share your location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement emergency protocol
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Emergency services contacted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Call 911'),
          ),
        ],
      ),
    );
  }

  void _showSafetyOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Safety Options',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.share_location),
              title: const Text('Share Trip'),
              subtitle: const Text('Share your trip details with a trusted contact'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement trip sharing
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report Issue'),
              subtitle: const Text('Report a safety concern or inappropriate behavior'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement issue reporting
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Call Support'),
              subtitle: const Text('Contact UVA Rideshare support'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement support call
              },
            ),
          ],
        ),
      ),
    );
  }
}
