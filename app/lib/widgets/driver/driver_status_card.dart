import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/driver_status_service.dart';

class DriverStatusCard extends StatelessWidget {
  final DriverStatus status;
  final bool acceptingRequests;
  final VoidCallback onToggleOnline;
  final VoidCallback onToggleRequests;
  final bool isLoading;

  const DriverStatusCard({
    super.key,
    required this.status,
    required this.acceptingRequests,
    required this.onToggleOnline,
    required this.onToggleRequests,
    this.isLoading = false,
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
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Driver Status',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Status Display
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Status',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusText(status),
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Online/Offline Toggle
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isLoading ? null : onToggleOnline,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == DriverStatus.offline 
                                ? Icons.play_arrow 
                                : Icons.pause,
                            size: 20,
                            color: status == DriverStatus.offline 
                                ? Colors.green[600] 
                                : Colors.red[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status == DriverStatus.offline 
                                ? 'Go Online' 
                                : 'Go Offline',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: status == DriverStatus.offline 
                                  ? Colors.green[600] 
                                  : Colors.red[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Accepting Requests Toggle (only when online)
          if (status != DriverStatus.offline && status != DriverStatus.inRide) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accepting Requests',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                        Text(
                          acceptingRequests 
                              ? 'You will receive new ride requests'
                              : 'New requests are paused',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: acceptingRequests,
                    onChanged: isLoading ? null : (_) => onToggleRequests(),
                    activeTrackColor: Colors.green[600],
                    activeThumbColor: Colors.white,
                  ),
                ],
              ),
            ),
          ],
          
          // Status Description
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(status),
                  size: 16,
                  color: _getStatusColor(status),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusDescription(status, acceptingRequests),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.online:
        return Colors.green;
      case DriverStatus.busy:
        return Colors.orange;
      case DriverStatus.inRide:
        return Colors.blue;
      case DriverStatus.offline:
        return Colors.grey;
    }
  }

  String _getStatusText(DriverStatus status) {
    switch (status) {
      case DriverStatus.online:
        return 'Online';
      case DriverStatus.busy:
        return 'Busy';
      case DriverStatus.inRide:
        return 'In Ride';
      case DriverStatus.offline:
        return 'Offline';
    }
  }

  IconData _getStatusIcon(DriverStatus status) {
    switch (status) {
      case DriverStatus.online:
        return Icons.check_circle;
      case DriverStatus.busy:
        return Icons.access_time;
      case DriverStatus.inRide:
        return Icons.directions_car;
      case DriverStatus.offline:
        return Icons.cancel;
    }
  }

  String _getStatusDescription(DriverStatus status, bool acceptingRequests) {
    switch (status) {
      case DriverStatus.online:
        return acceptingRequests 
            ? 'Ready to receive ride requests'
            : 'Online but not accepting new requests';
      case DriverStatus.busy:
        return 'Handling a ride request';
      case DriverStatus.inRide:
        return 'Currently on a ride with passengers';
      case DriverStatus.offline:
        return 'Not available for rides';
    }
  }
}