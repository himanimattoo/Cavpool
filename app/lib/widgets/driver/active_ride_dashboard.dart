import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/active_ride_management_service.dart';
import '../../models/ride_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_profile_provider.dart';
import '../../utils/units_formatter.dart';
import 'passenger_contact_card.dart';

class ActiveRideDashboard extends StatelessWidget {
  final ActiveRideInfo rideInfo;
  final Function(String) onPickupPassenger;
  final Function(String) onDropoffPassenger;
  final Function(String) onCallPassenger;
  final Function(String, String) onSendSMS;
  final VoidCallback onStartRide;
  final VoidCallback onCompleteRide;

  const ActiveRideDashboard({
    super.key,
    required this.rideInfo,
    required this.onPickupPassenger,
    required this.onDropoffPassenger,
    required this.onCallPassenger,
    required this.onSendSMS,
    required this.onStartRide,
    required this.onCompleteRide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context),
          const SizedBox(height: 20),
          
          // Ride Overview
          _buildRideOverview(context),
          const SizedBox(height: 20),
          
          // Passengers List
          _buildPassengersList(),
          const SizedBox(height: 20),
          
          // Action Buttons
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.directions_car,
            color: Colors.blue[600],
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Ride',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              Text(
                rideInfo.ride.status.name.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(rideInfo.ride.status),
                ),
              ),
            ],
          ),
        ),
        
        // Trip Info Button
        IconButton(
          onPressed: () => _showTripDetails(context),
          icon: Icon(
            Icons.info_outline,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRideOverview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildOverviewItem(
                  icon: Icons.people,
                  label: 'Passengers',
                  value: '${rideInfo.passengers.length}',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              Expanded(
                child: Builder(
                  builder: (context) => _buildOverviewItem(
                    icon: Icons.route,
                    label: 'Distance',
                    value: _formatDistance(context, rideInfo.totalDistance),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              Expanded(
                child: _buildOverviewItem(
                  icon: Icons.access_time,
                  label: 'Duration',
                  value: _formatDuration(rideInfo.estimatedDuration),
                ),
              ),
            ],
          ),
          
          if (rideInfo.estimatedCompletion != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Est. completion: ${_formatTime(rideInfo.estimatedCompletion!, context)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPassengersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passengers',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        const SizedBox(height: 12),
        
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rideInfo.passengers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final passenger = rideInfo.passengers[index];
            return PassengerContactCard(
              passengerInfo: passenger,
              onPickup: () => onPickupPassenger(passenger.passengerId),
              onDropoff: () => onDropoffPassenger(passenger.passengerId),
              onCall: () => _handleCall(passenger),
              onMessage: () => _handleMessage(context, passenger),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final canStartRide = rideInfo.ride.status.name == 'active';
    final canCompleteRide = rideInfo.ride.status.name == 'inProgress' &&
        rideInfo.passengers.every((p) => p.pickupStatus.name == 'completed');
    
    return Column(
      children: [
        if (canStartRide)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStartRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Start Ride',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        if (canCompleteRide)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                try {
                  onCompleteRide();
                } catch (e) {
                  // Show error to user but don't crash
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error completing ride: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Complete Ride',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        const SizedBox(height: 12),
        
        // Emergency button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _handleEmergency(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[600],
              side: BorderSide(color: Colors.red[300]!),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emergency, size: 18),
                const SizedBox(width: 8),
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
      ],
    );
  }

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return Colors.orange;
      case RideStatus.inProgress:
        return Colors.blue;
      case RideStatus.completed:
        return Colors.green;
      case RideStatus.cancelled:
        return Colors.red;
      case RideStatus.full:
        return Colors.grey;
      case RideStatus.expired:
        return Colors.red[300]!;
    }
  }

  String _formatTime(DateTime dateTime, BuildContext context) {
    return TimeOfDay.fromDateTime(dateTime).format(context);
  }

  void _handleCall(PassengerContactInfo passenger) {
    if (passenger.phoneNumber != null) {
      onCallPassenger(passenger.phoneNumber!);
    }
  }

  void _handleMessage(BuildContext context, PassengerContactInfo passenger) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MessageSheetWidget(
        passenger: passenger,
        onSendSMS: onSendSMS,
      ),
    );
  }

  void _showTripDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trip Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ride ID: ${rideInfo.ride.id}'),
            const SizedBox(height: 8),
            Text('Start: ${rideInfo.ride.startLocation.address}'),
            const SizedBox(height: 8),
            Text('End: ${rideInfo.ride.endLocation.address}'),
            const SizedBox(height: 8),
            Text('Distance: ${_formatDistance(context, rideInfo.totalDistance)}'),
            const SizedBox(height: 8),
            Text('Duration: ${_formatDuration(rideInfo.estimatedDuration)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleEmergency(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency'),
        content: const Text('This will alert emergency services and share your location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Emergency services contacted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Call Emergency'),
          ),
        ],
      ),
    );
  }

  String _formatDistance(BuildContext context, double distanceInKilometers) {
    final userProvider = context.read<UserProfileProvider>();
    final unit = UnitsFormatter.getUnitFromPreferences(userProvider.userProfile?.preferences);
    
    if (unit == DistanceUnit.metric) {
      return '${distanceInKilometers.toStringAsFixed(1)} km';
    } else {
      // Convert km to miles: 1 km = 0.621371 miles
      final miles = distanceInKilometers * 0.621371;
      return '${miles.toStringAsFixed(1)} mi';
    }
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      if (minutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${minutes}m';
      }
    } else if (totalMinutes > 0) {
      return '${totalMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

class _MessageSheetWidget extends StatefulWidget {
  final PassengerContactInfo passenger;
  final Function(String, String) onSendSMS;

  const _MessageSheetWidget({
    required this.passenger,
    required this.onSendSMS,
  });

  @override
  State<_MessageSheetWidget> createState() => _MessageSheetWidgetState();
}

class _MessageSheetWidgetState extends State<_MessageSheetWidget> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Use the onSendSMS callback which now uses Firestore messaging
      final success = await widget.onSendSMS(
        widget.passenger.phoneNumber ?? '',
        message.trim(),
      );

      if (success) {
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
                'Send Message to ${widget.passenger.passenger.profile.displayName}',
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