import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../services/request_notification_service.dart';

class IncomingRequestModal extends StatefulWidget {
  final List<IncomingRequestNotification> requests;
  final Function(IncomingRequestNotification) onAccept;
  final Function(IncomingRequestNotification, {String? reason}) onDecline;

  const IncomingRequestModal({
    super.key,
    required this.requests,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingRequestModal> createState() => _IncomingRequestModalState();
}

class _IncomingRequestModalState extends State<IncomingRequestModal>
    with TickerProviderStateMixin {
  Timer? _countdownTimer;
  final Map<String, int> _remainingSeconds = {};
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeCountdowns();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
  }

  void _initializeCountdowns() {
    for (final request in widget.requests) {
      final elapsed = DateTime.now().difference(request.timestamp);
      final remaining = request.timeoutDuration.inSeconds - elapsed.inSeconds;
      _remainingSeconds[request.id] = remaining > 0 ? remaining : 0;
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        for (final request in widget.requests) {
          final currentRemaining = _remainingSeconds[request.id] ?? 0;
          if (currentRemaining > 0) {
            _remainingSeconds[request.id] = currentRemaining - 1;
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.requests.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxHeight: 600),
              child: widget.requests.length == 1
                  ? _buildSingleRequest(widget.requests.first)
                  : _buildMultipleRequests(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleRequest(IncomingRequestNotification request) {
    final remainingTime = _remainingSeconds[request.id] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
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
                      'New Ride Request',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    Text(
                      'Expires in ${remainingTime}s',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: remainingTime <= 30 ? Colors.red[600] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Countdown Circle
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      value: remainingTime / request.timeoutDuration.inSeconds,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        remainingTime <= 30 ? Colors.red : Colors.blue,
                      ),
                      strokeWidth: 4,
                    ),
                    Center(
                      child: Text(
                        '$remainingTime',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: remainingTime <= 30 ? Colors.red : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Passenger Info
          _buildPassengerInfo(request),
          
          const SizedBox(height: 24),
          
          // Trip Details
          _buildTripDetails(request),
          
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildDeclineButton(request),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildAcceptButton(request),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleRequests() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Multiple Ride Requests',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),
          
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.requests.length,
              separatorBuilder: (context, index) => const Divider(height: 20),
              itemBuilder: (context, index) {
                final request = widget.requests[index];
                return _buildRequestListItem(request);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestListItem(IncomingRequestNotification request) {
    final remainingTime = _remainingSeconds[request.id] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.passenger.profile.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              Text(
                '${remainingTime}s',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: remainingTime <= 30 ? Colors.red : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request.request.startLocation.address,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleDecline(request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[600],
                    side: BorderSide(color: Colors.red[300]!),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleAccept(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerInfo(IncomingRequestNotification request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue[100],
            backgroundImage: request.passenger.profile.photoURL.isNotEmpty
                ? NetworkImage(request.passenger.profile.photoURL)
                : null,
            child: request.passenger.profile.photoURL.isEmpty
                ? Text(
                    request.passenger.profile.displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
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
                  request.passenger.profile.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                if (request.passenger.ratings.asRider.averageRating > 0)
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${request.passenger.ratings.asRider.averageRating.toStringAsFixed(1)} (${request.passenger.ratings.asRider.totalRatings} rides)',
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
        ],
      ),
    );
  }

  Widget _buildTripDetails(IncomingRequestNotification request) {
    return Column(
      children: [
        _buildLocationRow(
          icon: Icons.my_location,
          iconColor: Colors.green,
          label: 'Pickup',
          address: request.request.startLocation.address,
        ),
        const SizedBox(height: 12),
        _buildLocationRow(
          icon: Icons.location_on,
          iconColor: Colors.red,
          label: 'Dropoff',
          address: request.request.endLocation.address,
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: _buildInfoChip(
                icon: Icons.people,
                label: '${request.request.seatsNeeded} seat${request.request.seatsNeeded > 1 ? 's' : ''}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoChip(
                icon: Icons.attach_money,
                label: '\$${request.request.maxPricePerSeat.toStringAsFixed(2)}',
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
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
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
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[900],
                ),
                maxLines: 2,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.blue[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptButton(IncomingRequestNotification request) {
    return ElevatedButton(
      onPressed: () => _handleAccept(request),
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
          const Icon(Icons.check, size: 20),
          const SizedBox(width: 8),
          Text(
            'Accept Ride',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclineButton(IncomingRequestNotification request) {
    return OutlinedButton(
      onPressed: () => _handleDecline(request),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red[600],
        side: BorderSide(color: Colors.red[300]!),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.close, size: 20),
          const SizedBox(width: 8),
          Text(
            'Decline',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _handleAccept(IncomingRequestNotification request) {
    _animationController.reverse().then((_) {
      widget.onAccept(request);
    });
  }

  void _handleDecline(IncomingRequestNotification request) {
    _animationController.reverse().then((_) {
      widget.onDecline(request, reason: 'Driver declined');
    });
  }
}