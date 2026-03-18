import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../services/auth_service.dart';
import 'ride_confirmation_screen.dart';

class RideBookingScreen extends StatefulWidget {
  final RideOffer rideOffer;

  const RideBookingScreen({
    super.key,
    required this.rideOffer,
  });

  @override
  State<RideBookingScreen> createState() => _RideBookingScreenState();
}

class _RideBookingScreenState extends State<RideBookingScreen> {
  final RideService _rideService = RideService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  int _selectedSeats = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Book Ride',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRideInfoCard(),
            const SizedBox(height: 16),
            _buildRouteCard(),
            const SizedBox(height: 16),
            _buildSeatsSelection(),
            const SizedBox(height: 16),
            _buildPreferencesCard(),
            const SizedBox(height: 24),
            _buildPriceCard(),
            const SizedBox(height: 24),
            _buildBookButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRideInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: const Color(0xFFE57200),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Departure Time',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF232F3E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatDateTime(widget.rideOffer.departureTime),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.airline_seat_recline_normal,
                  color: const Color(0xFFE57200),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Available Seats: ${widget.rideOffer.availableSeats}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF232F3E),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildLocationRow(
              Icons.radio_button_checked,
              'From',
              widget.rideOffer.startLocation.address,
              true,
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(left: 12),
              height: 30,
              child: VerticalDivider(
                color: Colors.grey.shade300,
                thickness: 2,
              ),
            ),
            const SizedBox(height: 12),
            _buildLocationRow(
              Icons.location_on,
              'To',
              widget.rideOffer.endLocation.address,
              false,
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoChip(
                  Icons.route,
                  '${widget.rideOffer.estimatedDistance.toStringAsFixed(1)} km',
                ),
                _buildInfoChip(
                  Icons.access_time,
                  '${widget.rideOffer.estimatedDuration.inMinutes} min',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address, bool isStart) {
    return Row(
      children: [
        Icon(
          icon,
          color: isStart ? const Color(0xFF4CAF50) : const Color(0xFFE57200),
          size: 24,
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
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatsSelection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Number of Seats',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF232F3E),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: _selectedSeats > 1 ? () => setState(() => _selectedSeats--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: const Color(0xFFE57200),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_selectedSeats',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _selectedSeats < widget.rideOffer.availableSeats 
                      ? () => setState(() => _selectedSeats++) 
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFFE57200),
                ),
                const Spacer(),
                Text(
                  'Max: ${widget.rideOffer.availableSeats}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    final prefs = widget.rideOffer.preferences;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ride Preferences',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF232F3E),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPreferenceChip(
                  Icons.smoking_rooms,
                  prefs.allowSmoking ? 'Smoking OK' : 'No Smoking',
                  prefs.allowSmoking,
                ),
                _buildPreferenceChip(
                  Icons.pets,
                  prefs.allowPets ? 'Pets OK' : 'No Pets',
                  prefs.allowPets,
                ),
                _buildPreferenceChip(
                  Icons.music_note,
                  'Music: ${_formatMusicPreference(prefs.musicPreference)}',
                  true,
                ),
                _buildPreferenceChip(
                  Icons.chat,
                  'Chat: ${_formatCommunicationStyle(prefs.communicationStyle)}',
                  true,
                ),
              ],
            ),
            if (widget.rideOffer.notes != null && widget.rideOffer.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'Driver Notes:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF232F3E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.rideOffer.notes!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceChip(IconData icon, String label, bool isPositive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
        border: Border.all(
          color: isPositive ? Colors.green.shade200 : Colors.red.shade200,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isPositive ? Colors.green.shade600 : Colors.red.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isPositive ? Colors.green.shade600 : Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    final totalPrice = widget.rideOffer.pricePerSeat * _selectedSeats;
    return Card(
      elevation: 2,
      color: const Color(0xFFF8F9FA),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Price per seat:',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '\$${widget.rideOffer.pricePerSeat.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Seats selected:',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '$_selectedSeats',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Divider(color: Colors.grey.shade300, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Price:',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF232F3E),
                  ),
                ),
                Text(
                  '\$${totalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE57200),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleBookRide,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE57200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.confirmation_number,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Book Ride',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatMusicPreference(String pref) {
    switch (pref) {
      case 'driver_choice':
        return 'Driver\'s Choice';
      case 'passenger_choice':
        return 'Passenger\'s Choice';
      case 'no_music':
        return 'No Music';
      default:
        return pref;
    }
  }

  String _formatCommunicationStyle(String style) {
    switch (style) {
      case 'friendly':
        return 'Friendly';
      case 'quiet':
        return 'Quiet';
      case 'professional':
        return 'Professional';
      default:
        return style;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                   'July', 'August', 'September', 'October', 'November', 'December'];
    
    final weekday = weekdays[dateTime.weekday - 1];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    
    return '$weekday, $month $day, $year • $displayHour:$minute $amPm';
  }

  void _handleBookRide() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Join the ride with selected number of seats
      if (_selectedSeats > widget.rideOffer.availableSeats) {
        throw Exception('Not enough available seats');
      }

      // Add the user only once, but record the number of seats they're taking
      final newPassengerIds = [...widget.rideOffer.passengerIds];
      if (!newPassengerIds.contains(currentUser.uid)) {
        newPassengerIds.add(currentUser.uid);
      }
      
      // Update passenger pickup/dropoff locations and seat count
      final newPickupLocations = Map<String, RideLocation>.from(widget.rideOffer.passengerPickupLocations);
      final newDropoffLocations = Map<String, RideLocation>.from(widget.rideOffer.passengerDropoffLocations);
      final newSeatCounts = Map<String, int>.from(widget.rideOffer.passengerSeatCounts);
      final newSeatPrices = Map<String, double>.from(widget.rideOffer.passengerSeatPrices);
      final newPickupStatus = Map<String, PickupStatus>.from(widget.rideOffer.passengerPickupStatus);
      
      // Set pickup and dropoff locations for this passenger
      // For now, use the ride's start/end locations, but this could be customized
      newPickupLocations[currentUser.uid] = widget.rideOffer.startLocation;
      newDropoffLocations[currentUser.uid] = widget.rideOffer.endLocation;
      newSeatCounts[currentUser.uid] = _selectedSeats;
      newSeatPrices[currentUser.uid] = widget.rideOffer.pricePerSeat;
      newPickupStatus[currentUser.uid] = PickupStatus.pending;
      
      // Update the ride offer with new passenger data
      await _rideService.updateRideOffer(widget.rideOffer.id, {
        'passengerIds': newPassengerIds,
        'passengerPickupLocations': newPickupLocations.map((k, v) => MapEntry(k, v.toMap())),
        'passengerDropoffLocations': newDropoffLocations.map((k, v) => MapEntry(k, v.toMap())),
        'passengerSeatCounts': newSeatCounts,
        'passengerSeatPrices': newSeatPrices,
        'passengerPickupStatus': newPickupStatus.map((k, v) => MapEntry(k, v.name)),
        'availableSeats': widget.rideOffer.availableSeats - _selectedSeats,
        'status': (widget.rideOffer.availableSeats - _selectedSeats) == 0 
            ? RideStatus.full.name 
            : widget.rideOffer.status.name,
      });

      if (mounted) {
        final totalPrice = widget.rideOffer.pricePerSeat * _selectedSeats;
        final bookingId = 'BK${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => RideConfirmationScreen(
              rideOffer: widget.rideOffer,
              bookedSeats: _selectedSeats,
              totalPrice: totalPrice,
              bookingId: bookingId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error booking ride: ${e.toString()}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}