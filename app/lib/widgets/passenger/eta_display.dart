import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/passenger_provider.dart';
import '../../services/eta_service.dart';

class ETADisplay extends StatelessWidget {
  final ETAUpdate? pickupETA;
  final ETAUpdate? dropoffETA;
  final PassengerRideState state;

  const ETADisplay({
    super.key,
    this.pickupETA,
    this.dropoffETA,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    if (pickupETA == null && dropoffETA == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: Colors.blue[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Estimated Time',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (pickupETA != null && _shouldShowPickupETA())
            _buildETAItem(
              icon: Icons.my_location,
              iconColor: Colors.green,
              label: 'Driver arrives in',
              time: _formatDuration(pickupETA!.estimatedDuration),
              distance: _formatDistance(pickupETA!.distanceRemaining),
              trafficCondition: pickupETA!.trafficCondition,
            ),
          
          if (dropoffETA != null && _shouldShowDropoffETA()) ...[
            if (pickupETA != null && _shouldShowPickupETA())
              const SizedBox(height: 12),
            _buildETAItem(
              icon: Icons.location_on,
              iconColor: Colors.red,
              label: 'Arrive at destination in',
              time: _formatDuration(dropoffETA!.estimatedDuration),
              distance: _formatDistance(dropoffETA!.distanceRemaining),
              trafficCondition: dropoffETA!.trafficCondition,
            ),
          ],
          
          if (_getTrafficCondition() != null) ...[
            const SizedBox(height: 12),
            _buildTrafficAlert(),
          ],
        ],
      ),
    );
  }

  Widget _buildETAItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String time,
    required String distance,
    String? trafficCondition,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Row(
                children: [
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '($distance)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        if (trafficCondition != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getTrafficColor(trafficCondition),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              trafficCondition.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrafficAlert() {
    final condition = _getTrafficCondition();
    if (condition == null || condition == 'light') return const SizedBox.shrink();

    final isHeavy = condition == 'heavy';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHeavy ? Colors.red[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHeavy ? Colors.red[200]! : Colors.orange[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.traffic,
            size: 20,
            color: isHeavy ? Colors.red[600] : Colors.orange[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHeavy ? 'Heavy Traffic Alert' : 'Moderate Traffic',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isHeavy ? Colors.red[800] : Colors.orange[800],
                  ),
                ),
                Text(
                  isHeavy 
                      ? 'Expect delays due to heavy traffic conditions'
                      : 'Some delays possible due to traffic',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isHeavy ? Colors.red[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowPickupETA() {
    return state == PassengerRideState.driverEnRoute || 
           state == PassengerRideState.driverArrived;
  }

  bool _shouldShowDropoffETA() {
    return state == PassengerRideState.inRide;
  }

  String? _getTrafficCondition() {
    if (pickupETA?.trafficCondition != null && _shouldShowPickupETA()) {
      return pickupETA!.trafficCondition;
    }
    if (dropoffETA?.trafficCondition != null && _shouldShowDropoffETA()) {
      return dropoffETA!.trafficCondition;
    }
    return null;
  }

  Color _getTrafficColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'light':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'heavy':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return 'Now';
    }
  }

  String _formatDistance(double distance) {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    } else {
      return '${distance.toInt()} m';
    }
  }
}