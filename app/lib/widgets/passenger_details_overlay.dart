import 'package:flutter/material.dart';
import '../models/ride_model.dart';
import '../services/passenger_service.dart';
import '../screens/profile/user_reviews_screen.dart';

class PassengerDetailsOverlay extends StatelessWidget {
  final PassengerInfo passenger;
  final VoidCallback? onMarkArrived;
  final VoidCallback? onMarkPickedUp;
  final VoidCallback? onMarkDroppedOff;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final VoidCallback? onRatePassenger;

  const PassengerDetailsOverlay({
    super.key,
    required this.passenger,
    this.onMarkArrived,
    this.onMarkPickedUp,
    this.onMarkDroppedOff,
    this.onCall,
    this.onMessage,
    this.onRatePassenger,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Passenger info header
                _buildPassengerHeader(context),
                const SizedBox(height: 20),
                
                // Status section
                _buildStatusSection(context),
                const SizedBox(height: 20),
                
                // Contact section
                _buildContactSection(),
                const SizedBox(height: 20),
                
                // Preferences section
                _buildPreferencesSection(),
                const SizedBox(height: 20),
                
                // Action buttons
                _buildActionButtons(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPassengerHeader(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundImage: passenger.user.profile.photoURL.isNotEmpty
              ? NetworkImage(passenger.user.profile.photoURL)
              : null,
          child: passenger.user.profile.photoURL.isEmpty
              ? Text(
                  passenger.user.profile.displayName.isNotEmpty
                      ? passenger.user.profile.displayName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                passenger.user.profile.displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (passenger.user.profile.pronouns.isNotEmpty)
                Text(
                  passenger.user.profile.pronouns,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              if (passenger.user.profile.bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    passenger.user.profile.bio,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        // Rating display - always show, even if no ratings yet
        InkWell(
          onTap: () => _navigateToPassengerReviews(context, passenger.user),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text(
                  passenger.user.ratings.asRider.totalRatings > 0 
                      ? passenger.user.ratings.asRider.averageRating.toStringAsFixed(1)
                      : 'New',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, color: Colors.orange, size: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    final passengerService = PassengerService();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(passenger.pickupStatus),
                  color: _getStatusColor(passenger.pickupStatus),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pickup Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(passenger.pickupStatus).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(passenger.pickupStatus).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                passengerService.getPickupStatusDisplayName(passenger.pickupStatus),
                style: TextStyle(
                  color: _getStatusColor(passenger.pickupStatus),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.contact_phone, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Contact',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onMessage,
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (passenger.user.profile.phoneNumber.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Phone: ${passenger.user.profile.phoneNumber}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    final prefs = passenger.user.preferences;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Preferences',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPreferenceChip(
                  icon: Icons.smoking_rooms,
                  label: prefs.allowSmoking ? 'Smoking OK' : 'No Smoking',
                  color: prefs.allowSmoking ? Colors.orange : Colors.green,
                ),
                _buildPreferenceChip(
                  icon: Icons.pets,
                  label: prefs.allowPets ? 'Pets OK' : 'No Pets',
                  color: prefs.allowPets ? Colors.brown : Colors.green,
                ),
                _buildPreferenceChip(
                  icon: Icons.music_note,
                  label: prefs.musicPreference,
                  color: Colors.blue,
                ),
                _buildPreferenceChip(
                  icon: Icons.chat,
                  label: prefs.communicationStyle,
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final passengerService = PassengerService();
    
    return Column(
      children: [
        if (passengerService.canMarkArrived(passenger.pickupStatus))
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onMarkArrived,
              icon: const Icon(Icons.location_on),
              label: const Text('Mark as Arrived'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        
        if (passengerService.canMarkPickedUp(passenger.pickupStatus)) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onMarkPickedUp,
              icon: const Icon(Icons.person_add),
              label: const Text('Mark as Picked Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
        
        if (passengerService.canMarkDroppedOff(passenger.pickupStatus)) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onMarkDroppedOff,
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark as Dropped Off'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],

        if (passenger.pickupStatus == PickupStatus.completed && onRatePassenger != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRatePassenger,
              icon: const Icon(Icons.star_rate_rounded),
              label: const Text('Rate Passenger'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
        
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ),
      ],
    );
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

  IconData _getStatusIcon(PickupStatus status) {
    switch (status) {
      case PickupStatus.pending:
        return Icons.directions_car;
      case PickupStatus.driverArrived:
        return Icons.location_on;
      case PickupStatus.passengerPickedUp:
        return Icons.person;
      case PickupStatus.completed:
        return Icons.check_circle;
    }
  }

  void _navigateToPassengerReviews(BuildContext context, dynamic user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserReviewsScreen(user: user),
      ),
    );
  }
}
