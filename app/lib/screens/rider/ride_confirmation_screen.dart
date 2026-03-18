import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/ride_model.dart';
import 'upcoming_rides_screen.dart';

class RideConfirmationScreen extends StatelessWidget {
  final RideOffer rideOffer;
  final int bookedSeats;
  final double totalPrice;
  final String bookingId;

  const RideConfirmationScreen({
    super.key,
    required this.rideOffer,
    required this.bookedSeats,
    required this.totalPrice,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Booking Confirmed',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSuccessHeader(),
            const SizedBox(height: 24),
            _buildBookingDetailsCard(),
            const SizedBox(height: 16),
            _buildRouteCard(),
            const SizedBox(height: 16),
            _buildBookingInfoCard(),
            const SizedBox(height: 16),
            _buildPaymentCard(),
            const SizedBox(height: 24),
            _buildNextStepsCard(),
            const SizedBox(height: 24),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Booking Confirmed!',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your ride has been successfully booked',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.green.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDetailsCard() {
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
                  Icons.confirmation_number,
                  color: const Color(0xFFE57200),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Booking Details',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF232F3E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Booking ID', bookingId),
            const SizedBox(height: 8),
            _buildDetailRow('Departure', _formatDateTime(rideOffer.departureTime)),
            const SizedBox(height: 8),
            _buildDetailRow('Seats Booked', '$bookedSeats seat${bookedSeats > 1 ? 's' : ''}'),
            const SizedBox(height: 8),
            _buildDetailRow('Status', 'Confirmed', isStatus: true),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route,
                  color: const Color(0xFFE57200),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Route Information',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF232F3E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLocationRow(
              Icons.radio_button_checked,
              'From',
              rideOffer.startLocation.address,
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
              rideOffer.endLocation.address,
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
                  '${rideOffer.estimatedDistance.toStringAsFixed(1)} km',
                ),
                _buildInfoChip(
                  Icons.access_time,
                  '${rideOffer.estimatedDuration.inMinutes} min',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingInfoCard() {
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
                  Icons.info_outline,
                  color: const Color(0xFFE57200),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Important Information',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF232F3E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              Icons.schedule,
              'Arrival Time',
              'Be ready 10-15 minutes before departure time',
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              Icons.phone,
              'Driver Contact',
              'You can contact the driver 1 hour before departure',
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              Icons.cancel,
              'Cancellation',
              'Free cancellation up to 2 hours before departure',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      elevation: 2,
      color: const Color(0xFFF8F9FA),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payment,
                  color: const Color(0xFFE57200),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Payment Summary',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF232F3E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                  '\$${rideOffer.pricePerSeat.toStringAsFixed(2)}',
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
                  'Seats booked:',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '$bookedSeats',
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
                  'Total Paid:',
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

  Widget _buildNextStepsCard() {
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
                  Icons.checklist,
                  color: const Color(0xFFE57200),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Next Steps',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF232F3E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStepItem(
              '1',
              'Check your upcoming rides',
              'View this booking in your rides list',
            ),
            const SizedBox(height: 12),
            _buildStepItem(
              '2',
              'Get ready for departure',
              'Be at the pickup location 10 minutes early',
            ),
            const SizedBox(height: 12),
            _buildStepItem(
              '3',
              'Contact driver if needed',
              'Use the in-app messaging feature',
            ),
            const SizedBox(height: 12),
            _buildStepItem(
              '4',
              'Enjoy your ride!',
              'Rate your experience after the trip',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE57200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.home,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Back to Home',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () {
              // Navigate to upcoming rides
              Navigator.of(context).popUntil((route) => route.isFirst);
              // Navigate to upcoming rides tab by pushing the specific screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UpcomingRidesScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE57200), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.schedule,
                  color: Color(0xFFE57200),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'View Upcoming Rides',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE57200),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        isStatus
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              )
            : Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
      ],
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

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFE57200),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(String number, String title, String description) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFE57200),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
}