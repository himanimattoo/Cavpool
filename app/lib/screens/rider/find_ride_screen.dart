import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';

import '../../models/ride_model.dart';
import '../../models/ride_search_result.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../utils/security_utils.dart';
import '../../widgets/address_search_widget.dart';
import '../rides/ride_details_screen.dart';
import '../requests/ride_request_screen.dart';

class FindRideScreen extends StatefulWidget {
  const FindRideScreen({super.key});

  @override
  State<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends State<FindRideScreen> {
  static const _uvaOrange = Color(0xFFE57200);
  static const _uvaNavy = Color(0xFF232F3E);

  final _notesController = TextEditingController();

  RideLocation? _pickupLocation;
  RideLocation? _dropoffLocation;
  DateTime _rideDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _rideTime = TimeOfDay.now();
  int _seatsNeeded = 1;
  bool _hasSearched = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_pickupLocation == null || _dropoffLocation == null) return false;

    final departureDateTime = DateTime(
      _rideDate.year,
      _rideDate.month,
      _rideDate.day,
      _rideTime.hour,
      _rideTime.minute,
    );

    return !departureDateTime.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final displayDate = '${_rideDate.month}/${_rideDate.day}/${_rideDate.year}';
    final displayTime = _rideTime.format(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFEF8F4),
      appBar: AppBar(
        backgroundColor: _uvaNavy,
        foregroundColor: Colors.white,
        title: Text(
          'Find a Ride',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell us where and when you want to go. We’ll search the latest driver offers and show the closest matches.',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader('Trip Details'),
            const SizedBox(height: 12),
            AddressSearchWidget(
              hintText: 'Pickup location',
              onAddressSelected: (result) {
                setState(() {
                  _pickupLocation = RideLocation(
                    coordinates: result.location,
                    address: result.formattedAddress,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            AddressSearchWidget(
              hintText: 'Drop-off location',
              onAddressSelected: (result) {
                setState(() {
                  _dropoffLocation = RideLocation(
                    coordinates: result.location,
                    address: result.formattedAddress,
                  );
                });
              },
            ),
            const SizedBox(height: 24),
            _sectionHeader('Date & Time'),
            const SizedBox(height: 12),
            _dateTimeTile(displayDate, displayTime),
            const SizedBox(height: 24),
            _sectionHeader('Seats Needed'),
            const SizedBox(height: 12),
            _seatSelector(),
            const SizedBox(height: 24),
            _sectionHeader('Notes for driver (optional)'),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any helpful context or preferences...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit ? _onSearchPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _uvaOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Search Ride Offers',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildResultsSection(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: _uvaNavy,
      ),
    );
  }

  Widget _dateTimeTile(String displayDate, String displayTime) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: const Icon(Icons.event, color: _uvaOrange),
        title: const Text('Departure Date & Time'),
        subtitle: Text('$displayDate at $displayTime'),
        trailing: const Icon(Icons.edit_calendar),
        onTap: _pickDateTime,
      ),
    );
  }

  Widget _seatSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Passengers',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              Text(
                'you + friends',
                style: GoogleFonts.inter(color: Colors.grey.shade600),
              ),
            ],
          ),
          Row(
            children: [
              _circleButton(
                icon: Icons.remove,
                onTap: _seatsNeeded > 1
                    ? () => setState(() => _seatsNeeded--)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$_seatsNeeded',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              _circleButton(
                icon: Icons.add,
                onTap: _seatsNeeded < 6
                    ? () => setState(() => _seatsNeeded++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: onTap == null ? Colors.grey.shade300 : _uvaOrange,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final currentDateTime = DateTime(
      _rideDate.year,
      _rideDate.month,
      _rideDate.day,
      _rideTime.hour,
      _rideTime.minute,
    );
    
    final selected = await showOmniDateTimePicker(
      context: context,
      initialDate: currentDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (selected != null) {
      setState(() {
        _rideDate = DateTime(selected.year, selected.month, selected.day);
        _rideTime = TimeOfDay(hour: selected.hour, minute: selected.minute);
      });
    }
  }

  Widget _buildResultsSection() {
    if (!_hasSearched) return const SizedBox.shrink();

    return Consumer<RideProvider>(
      builder: (context, rideProvider, _) {
        if (rideProvider.isSearchingOffers) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(height: 8),
              Center(child: CircularProgressIndicator()),
            ],
          );
        }

        if (rideProvider.rideSearchError != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              rideProvider.rideSearchError!,
              style: GoogleFonts.inter(color: Colors.red),
            ),
          );
        }

        if (rideProvider.rideSearchResults.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Top Matches'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'No rides match that window yet. Try adjusting your time or checking back later.',
                    style: GoogleFonts.inter(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Top Matches'),
            const SizedBox(height: 8),
            _buildFilteringInfo(rideProvider.rideSearchResults.length),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rideProvider.rideSearchResults.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final match = rideProvider.rideSearchResults[index];
                return _matchCard(match, rideProvider);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _matchCard(RideSearchResult match, RideProvider rideProvider) {
    final offer = match.offer;
    final departureText =
        '${offer.departureTime.month}/${offer.departureTime.day} at ${TimeOfDay.fromDateTime(offer.departureTime).format(context)}';
    final timeDelta = _formatTimeDifference(match.departureDeltaMinutes);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.my_location,
                              color: _uvaOrange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              SecurityUtils.maskAddress(offer.startLocation.address),
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              SecurityUtils.maskAddress(offer.endLocation.address),
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildMatchQualityIndicator(match.qualityScore),
                    const SizedBox(height: 4),
                    Text(
                      '\$${offer.pricePerSeat.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _uvaOrange,
                      ),
                    ),
                    Text(
                      'per seat',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  departureText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.event_seat, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${offer.availableSeats} seat${offer.availableSeats == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _matchChip(Icons.schedule, timeDelta),
                if (match.qualityScore >= 85)
                  _matchChip(Icons.star, 'Perfect match'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => RideDetailsScreen(ride: offer),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _uvaOrange),
                      foregroundColor: _uvaOrange,
                    ),
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: rideProvider.isCreatingRequest
                        ? null
                        : () => _requestRide(offer),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _uvaOrange,
                      foregroundColor: Colors.white,
                    ),
                    child: rideProvider.isCreatingRequest
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Request Ride'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _uvaOrange),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _uvaNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  String _formatTimeDifference(int minutes) {
    if (minutes == 0) return 'Exact departure time';

    if (minutes < 60) {
      if (minutes <= 15) return 'Within $minutes min of your time';
      return '~$minutes min from your time';
    }

    final totalHours = minutes ~/ 60;
    final days = totalHours ~/ 24;
    final hours = totalHours % 24;

    final parts = <String>[];
    if (days > 0) {
      parts.add('$days day${days == 1 ? '' : 's'}');
    }
    if (hours > 0) {
      parts.add('$hours hr');
    }

    if (parts.isEmpty) {
      // Should only happen if minutes < 60, but keep a fallback just in case.
      return 'Within 1 hr of your time';
    }

    return '~${parts.join(' ')} from your time';
  }

  Future<void> _onSearchPressed() async {
    if (!_canSubmit) return;

    final pickup = _pickupLocation;
    final dropoff = _dropoffLocation;

    if (pickup == null || dropoff == null) return;

    final departure = DateTime(
      _rideDate.year,
      _rideDate.month,
      _rideDate.day,
      _rideTime.hour,
      _rideTime.minute,
    );

    setState(() {
      _hasSearched = true;
    });

    await context.read<RideProvider>().searchRideOffers(
          pickup: pickup,
          dropoff: dropoff,
          departureTime: departure,
          seatsNeeded: _seatsNeeded,
        );
  }

  Future<void> _requestRide(RideOffer offer) async {
    final rideProvider = context.read<RideProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = rideProvider.currentUserId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to request a ride.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final riderPrefs = authProvider.userModel?.preferences;
    final pickup = _pickupLocation ?? offer.startLocation;
    final dropoff = _dropoffLocation ?? offer.endLocation;

    final requestedDeparture = DateTime(
      _rideDate.year,
      _rideDate.month,
      _rideDate.day,
      _rideTime.hour,
      _rideTime.minute,
    );

    final flexibility =
        Duration(minutes: riderPrefs?.defaultFlexibilityMinutes ?? 45);
    final seatsRequested =
        _seatsNeeded.clamp(1, offer.availableSeats).toInt();
    final notes = _notesController.text.trim();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RideRequestScreen(
          initialOffer: offer,
          initialPickup: pickup,
          initialDropoff: dropoff,
          initialDepartureTime: requestedDeparture,
          initialSeatsNeeded: seatsRequested,
          initialFlexibility: flexibility,
          initialPricePerSeat: offer.pricePerSeat,
          initialPreferences: offer.preferences,
          initialNotes: notes.isEmpty ? null : notes,
        ),
      ),
    );
  }

  Widget _buildFilteringInfo(int resultCount) {
    if (resultCount == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Found $resultCount ride${resultCount > 1 ? 's' : ''} that work${resultCount == 1 ? 's' : ''} for your trip!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showRatingExplanation(int qualityScore, String label) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                qualityScore >= 85 ? Icons.star :
                qualityScore >= 70 ? Icons.star_half :
                qualityScore >= 50 ? Icons.star_outline : Icons.warning_amber,
                color: qualityScore >= 85 ? Colors.green :
                       qualityScore >= 70 ? _uvaOrange :
                       qualityScore >= 50 ? Colors.amber.shade600 : Colors.red.shade400,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '$label Match ($qualityScore/100)',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getRatingExplanation(qualityScore),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How we rate matches:',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• How convenient the pickup and dropoff are for the driver\n'
                      '• How much extra time/distance it adds to their trip\n'
                      '• How close your departure times are\n'
                      '• The overall convenience for both parties',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Got it',
                style: GoogleFonts.inter(
                  color: _uvaOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getRatingExplanation(int qualityScore) {
    if (qualityScore >= 85) {
      return 'This ride works perfectly with the driver\'s planned route! Your pickup and dropoff locations require minimal detours, making it very convenient for the driver while getting you where you need to go.';
    } else if (qualityScore >= 70) {
      return 'This ride works well with the driver\'s route. It may require a small detour, but it\'s still convenient for both of you. The timing and locations align nicely.';
    } else if (qualityScore >= 50) {
      return 'This ride requires some detours from the driver\'s planned route, but it\'s still manageable. Consider if the timing and convenience work for your schedule.';
    } else {
      return 'This ride requires significant detours from the driver\'s planned route. While still possible, it may not be the most convenient option for either party.';
    }
  }

  Widget _buildMatchQualityIndicator(int qualityScore) {
    String label;
    Color color;
    IconData icon;
    
    if (qualityScore >= 85) {
      label = 'Excellent';
      color = Colors.green;
      icon = Icons.star;
    } else if (qualityScore >= 70) {
      label = 'Good';
      color = _uvaOrange;
      icon = Icons.star_half;
    } else if (qualityScore >= 50) {
      label = 'Fair';
      color = Colors.amber.shade600;
      icon = Icons.star_outline;
    } else {
      label = 'Poor';
      color = Colors.red.shade400;
      icon = Icons.warning_amber;
    }
    
    return GestureDetector(
      onTap: () => _showRatingExplanation(qualityScore, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline,
              size: 12,
              color: color.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
