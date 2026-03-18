import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/active_ride_management_service.dart';
import '../../models/ride_model.dart';
import '../../screens/profile/user_reviews_screen.dart';

class PassengerContactCard extends StatelessWidget {
  final PassengerContactInfo passengerInfo;
  final VoidCallback onPickup;
  final VoidCallback onDropoff;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  const PassengerContactCard({
    super.key,
    required this.passengerInfo,
    required this.onPickup,
    required this.onDropoff,
    required this.onCall,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(passengerInfo.pickupStatus).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passenger Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue[100],
                backgroundImage: passengerInfo.passenger.profile.photoURL.isNotEmpty
                    ? NetworkImage(passengerInfo.passenger.profile.photoURL)
                    : null,
                child: passengerInfo.passenger.profile.photoURL.isEmpty
                    ? Text(
                        passengerInfo.passenger.profile.displayName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                      passengerInfo.passenger.profile.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(passengerInfo.pickupStatus),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(passengerInfo.pickupStatus),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _navigateToPassengerReviews(context, passengerInfo.passenger),
                          child: Row(
                            children: [
                              Icon(Icons.star, size: 12, color: Colors.amber[600]),
                              const SizedBox(width: 2),
                              Text(
                                passengerInfo.passenger.ratings.asRider.totalRatings > 0
                                    ? passengerInfo.passenger.ratings.asRider.averageRating.toStringAsFixed(1)
                                    : 'New',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Contact Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (passengerInfo.phoneNumber != null) ...[
                    IconButton(
                      onPressed: onCall,
                      icon: Icon(Icons.phone, color: Colors.green[600]),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green[50],
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: onMessage,
                      icon: Icon(Icons.message, color: Colors.blue[600]),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Locations
          _buildLocationInfo(),
          
          const SizedBox(height: 12),
          
          // Action Buttons
          _buildActionButtons(),
          
          // Notes (if any)
          if (passengerInfo.notes != null && passengerInfo.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.note, size: 16, color: Colors.amber[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      passengerInfo.notes!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.amber[800],
                      ),
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

  Widget _buildLocationInfo() {
    return Column(
      children: [
        // Pickup Location
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.my_location, size: 14, color: Colors.green[700]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pickup',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    passengerInfo.pickupLocation.address,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (passengerInfo.eta != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ETA ${_formatETA(passengerInfo.eta!)}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey[700],
                  ),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Dropoff Location
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.location_on, size: 14, color: Colors.red[700]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dropoff',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    passengerInfo.dropoffLocation.address,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    switch (passengerInfo.pickupStatus) {
      case PickupStatus.pending:
      case PickupStatus.driverArrived:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPickup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Mark as Picked Up',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
        
      case PickupStatus.passengerPickedUp:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onDropoff,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Mark as Dropped Off',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
        
      case PickupStatus.completed:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
              const SizedBox(width: 6),
              Text(
                'Completed',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
        );
    }
  }

  Color _getStatusColor(PickupStatus status) {
    switch (status) {
      case PickupStatus.pending:
        return Colors.orange;
      case PickupStatus.driverArrived:
        return Colors.blue;
      case PickupStatus.passengerPickedUp:
        return Colors.purple;
      case PickupStatus.completed:
        return Colors.green;
    }
  }

  String _getStatusText(PickupStatus status) {
    switch (status) {
      case PickupStatus.pending:
        return 'En Route';
      case PickupStatus.driverArrived:
        return 'Arrived';
      case PickupStatus.passengerPickedUp:
        return 'In Car';
      case PickupStatus.completed:
        return 'Completed';
    }
  }

  String _formatETA(DateTime eta) {
    final now = DateTime.now();
    final difference = eta.difference(now);
    
    if (difference.inMinutes <= 0) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    }
  }

  void _navigateToPassengerReviews(BuildContext context, dynamic passenger) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserReviewsScreen(user: passenger),
      ),
    );
  }
}