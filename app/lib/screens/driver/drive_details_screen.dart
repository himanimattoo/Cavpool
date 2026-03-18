import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';

class DriveDetailsScreen extends StatefulWidget {
  final RideOffer offer;
  final bool isEditable;

  const DriveDetailsScreen({super.key, required this.offer, this.isEditable = false});

  @override
  State<DriveDetailsScreen> createState() => _DriveDetailsScreenState();
}

class _DriveDetailsScreenState extends State<DriveDetailsScreen> {
  bool _isNotesExpanded = false;
  late Future<List<RideRequest>> _acceptedRequestsFuture;

  @override
  void initState() {
    super.initState();
    _acceptedRequestsFuture = _fetchAcceptedRequests();
  }

  @override
  void didUpdateWidget(covariant DriveDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offer.id != widget.offer.id) {
      _acceptedRequestsFuture = _fetchAcceptedRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF232F3E),
        title: Text('Drive Details',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCombinedInfoCard(),
            const SizedBox(height: 16),
            _buildAcceptedRequestsSection(),
            const SizedBox(height: 16),
            if (widget.offer.notes?.isNotEmpty == true) ...[
              _buildExpandableNotesSection(widget.offer.notes!),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 24),
            _buildCancelButton(),
          ],
        ),
      ),
    );
  }

  Future<List<RideRequest>> _fetchAcceptedRequests() {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    return rideProvider.getAcceptedRequestsForRide(widget.offer.id);
  }

  void _refreshAcceptedRequests() {
    setState(() {
      _acceptedRequestsFuture = _fetchAcceptedRequests();
    });
  }

  Widget _buildCombinedInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _sectionDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationRow(
            icon: Icons.my_location,
            label: 'Pickup',
            address: widget.offer.startLocation.address,
            time: TimeOfDay.fromDateTime(widget.offer.departureTime).format(context),
            iconColor: Colors.green,
          ),
          const SizedBox(height: 16),
          _buildLocationRow(
            icon: Icons.location_on,
            label: 'Drop-off',
            address: widget.offer.endLocation.address,
            iconColor: Colors.red,
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.event_seat,
                  label: 'Seats',
                  value: '${widget.offer.availableSeats}/${widget.offer.totalSeats}',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.attach_money,
                  label: 'Price',
                  value: '\$${widget.offer.pricePerSeat.toStringAsFixed(0)}',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: '${widget.offer.departureTime.month}/${widget.offer.departureTime.day}',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedRequestsSection() {
    return FutureBuilder<List<RideRequest>>(
      future: _acceptedRequestsFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;
        final requests = snapshot.data ?? [];

        Widget content;
        if (isLoading) {
          content = const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (hasError) {
          content = _buildAcceptedEmptyMessage('Unable to load accepted requests.');
        } else if (requests.isEmpty) {
          content = _buildAcceptedEmptyMessage('No accepted requests yet.');
        } else {
          content = Column(
            children: [
              for (int i = 0; i < requests.length; i++) ...[
                _buildAcceptedRequestCard(requests[i]),
                if (i != requests.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _sectionDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Accepted Requests',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: isLoading ? null : _refreshAcceptedRequests,
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh requests',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              content,
            ],
          ),
        );
      },
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
          child: Icon(icon, size: 16, color: iconColor),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
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

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[900],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableNotesSection(String notes) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isNotesExpanded = !_isNotesExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notes',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isNotesExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    notes,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _isNotesExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedRequestCard(RideRequest request) {
    final prefs = request.preferences;
    final totalBid = request.maxPricePerSeat * request.seatsNeeded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildRequestStat(
                  icon: Icons.event_seat,
                  color: Colors.deepPurple,
                  value: '${request.seatsNeeded} passenger${request.seatsNeeded == 1 ? '' : 's'}',
                  label: 'Seats requested',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRequestStat(
                  icon: Icons.attach_money,
                  color: Colors.green.shade700,
                  value: '\$${request.maxPricePerSeat.toStringAsFixed(2)} / seat',
                  label: 'Bid amount',
                  helper: 'Est. \$${totalBid.toStringAsFixed(2)} total',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Rider preferences',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          _buildPreferenceChips(prefs),
          if ((request.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Notes to driver',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              request.notes!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestStat({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    String? helper,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(
              helper,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferenceChips(RidePreferences prefs) {
    final chips = <Widget>[
      _preferenceChip(
        icon: prefs.allowSmoking ? Icons.smoking_rooms : Icons.smoke_free,
        label: prefs.allowSmoking ? 'Smoking OK' : 'Smoke-free ride',
      ),
      _preferenceChip(
        icon: prefs.allowPets ? Icons.pets : Icons.do_not_touch,
        label: prefs.allowPets ? 'Pets welcome' : 'No pets',
      ),
      _preferenceChip(
        icon: Icons.music_note,
        label: _formatMusicPreference(prefs.musicPreference),
      ),
      _preferenceChip(
        icon: Icons.chat_bubble_outline,
        label: _formatCommunicationStyle(prefs.communicationStyle),
      ),
      _preferenceChip(
        icon: Icons.people_outline,
        label: _formatPreferredGenders(prefs.preferredGenders),
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _preferenceChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedEmptyMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  String _formatMusicPreference(String preference) {
    switch (preference) {
      case 'driver_choice':
        return 'Driver\'s choice';
      case 'passenger_choice':
        return 'Passenger\'s choice';
      case 'no_music':
        return 'No music';
      case 'acoustic':
        return 'Acoustic vibes';
      case 'pop':
        return 'Pop hits';
      case 'rock':
        return 'Rock';
      case 'hip_hop':
        return 'Hip hop';
      case 'classical':
        return 'Classical';
      default:
        return _titleCase(preference);
    }
  }

  String _formatCommunicationStyle(String style) {
    switch (style) {
      case 'friendly':
        return 'Friendly chatter';
      case 'quiet':
        return 'Quiet ride';
      case 'professional':
        return 'Professional tone';
      case 'chatty':
        return 'Love to chat';
      default:
        return _titleCase(style);
    }
  }

  String _formatPreferredGenders(List<String> genders) {
    if (genders.isEmpty) {
      return 'Any rider';
    }
    return genders.map(_titleCase).join(', ');
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'[_\s]+'))
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment[0].toUpperCase() + segment.substring(1))
        .join(' ');
  }

  BoxDecoration _sectionDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return Consumer<RideProvider>(
      builder: (context, rp, _) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _showCancelConfirmation(rp),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Cancel Drive',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelConfirmation(RideProvider rp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Drive?'),
        content: const Text('Are you sure you want to cancel this drive? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Drive'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop();
              final ok = await rp.cancelRideOffer(widget.offer.id);
              if (mounted) {
                messenger.showSnackBar(SnackBar(
                  backgroundColor: ok ? Colors.green : Colors.red,
                  content: Text(ok ? 'Drive cancelled' : 'Failed to cancel drive'),
                ));
                if (ok) navigator.pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Drive'),
          ),
        ],
      ),
    );
  }
}
