import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/ride_model.dart';
import '../../models/user_model.dart';
import '../../providers/ride_provider.dart';
import '../../services/auth_service.dart';
import '../../services/routes_service.dart';
import '../../services/directions_service.dart';
import '../../widgets/profile_avatar_widget.dart';
import '../verification/driver_verification_code_screen.dart';
import '../profile/user_reviews_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  final RideOffer ride;

  const RideDetailsScreen({
    super.key,
    required this.ride,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  GoogleMapController? _mapController;
  final RoutesService _routesService = RoutesService();
  final AuthService _authService = AuthService();
  final DirectionsService _directionsService = DirectionsService();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Cache for passenger and driver data
  final Map<String, UserModel?> _passengerData = {};
  UserModel? _driverData;
  
  // Notes expansion state
  bool _isNotesExpanded = false;

  @override
  void initState() {
    super.initState();
    _setupMapData();
  }

  void _setupMapData() async {
    // Create markers for start and end locations
    _markers = {
      Marker(
        markerId: const MarkerId('start'),
        position: widget.ride.startLocation.coordinates,
        infoWindow: InfoWindow(
          title: 'Pick-up',
          snippet: widget.ride.startLocation.address,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: widget.ride.endLocation.coordinates,
        infoWindow: InfoWindow(
          title: 'Drop-off',
          snippet: widget.ride.endLocation.address,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    // Try to get actual route from Google Directions API
    try {
      final directionsResult = await _directionsService.getDirections(
        origin: widget.ride.startLocation.coordinates,
        destination: widget.ride.endLocation.coordinates,
      );

      if (directionsResult != null && directionsResult.polylinePoints.isNotEmpty) {
        // Use actual route polyline
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: directionsResult.polylinePoints,
            color: const Color(0xFF2196F3),
            width: 5,
          ),
        };
      } else {
        // Fallback to straight line if API call fails
        _createStraightLinePolyline();
      }
    } catch (e) {
      // Fallback to straight line if error occurs
      _createStraightLinePolyline();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _createStraightLinePolyline() {
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          widget.ride.startLocation.coordinates,
          widget.ride.endLocation.coordinates,
        ],
        color: const Color(0xFF2196F3),
        width: 5,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bookingSection = _buildMyBookingSection();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ride Details',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF232F3E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMapSection(),
            _buildRouteInfo(),
            if (bookingSection != null) bookingSection,
            _buildDriverInfo(),
            _buildPreferencesSection(),
            _buildPassengersSection(),
            if (widget.ride.notes != null) _buildNotesSection(),
            _buildActionButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget? _buildMyBookingSection() {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return null;
    if (!widget.ride.passengerIds.contains(currentUserId)) return null;

    final pickupLocation =
        widget.ride.passengerPickupLocations[currentUserId] ?? widget.ride.startLocation;
    final dropoffLocation =
        widget.ride.passengerDropoffLocations[currentUserId] ?? widget.ride.endLocation;
    final seatCount = widget.ride.passengerSeatCounts[currentUserId] ?? 1;
    final seatPrice = widget.ride.passengerSeatPrices[currentUserId] ?? widget.ride.pricePerSeat;
    final pickupStatus =
        widget.ride.passengerPickupStatus[currentUserId] ?? PickupStatus.pending;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_seat, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Your Booking',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatPassengerStatus(pickupStatus),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBookingLocationRow(
            label: 'Your pickup',
            icon: Icons.my_location,
            address: pickupLocation.address,
          ),
          const SizedBox(height: 12),
          _buildBookingLocationRow(
            label: 'Your drop-off',
            icon: Icons.flag,
            address: dropoffLocation.address,
            iconColor: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildBookingStat(
                  'Seats reserved',
                  '$seatCount seat${seatCount == 1 ? '' : 's'}',
                  Icons.event_seat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBookingStat(
                  'Price per seat',
                  '\$${seatPrice.toStringAsFixed(2)}',
                  Icons.payments_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingLocationRow({
    required String label,
    required IconData icon,
    required String address,
    Color? iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor ?? Colors.blue.shade700, size: 18),
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
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 18),
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPassengerStatus(PickupStatus status) {
    switch (status) {
      case PickupStatus.pending:
        return 'Awaiting pickup';
      case PickupStatus.driverArrived:
        return 'Driver arrived';
      case PickupStatus.passengerPickedUp:
        return 'In ride';
      case PickupStatus.completed:
        return 'Completed';
    }
  }

  Widget _buildMapSection() {
    return SizedBox(
      height: 250,
      child: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          _fitMapToRoute();
        },
        markers: _markers,
        polylines: _polylines,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        initialCameraPosition: CameraPosition(
          target: widget.ride.startLocation.coordinates,
          zoom: 10,
        ),
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Container(
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
                        const Icon(
                          Icons.my_location,
                          color: Color(0xFFE57200),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.ride.startLocation.address,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.ride.endLocation.address,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
                  Text(
                    '\$${widget.ride.pricePerSeat.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE57200),
                    ),
                  ),
                  Text(
                    'per seat',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(
                Icons.access_time,
                _formatDateTime(widget.ride.departureTime),
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                Icons.route,
                '${(widget.ride.estimatedDistance / 1609.34).toStringAsFixed(1)} mi'
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                Icons.schedule,
                _routesService.formatDuration(widget.ride.estimatedDuration),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Driver Information',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<UserModel?>(
            future: _getDriverData(),
            builder: (context, snapshot) {
              final driver = snapshot.data;
              final displayName = driver?.profile.displayName ?? 'Driver';
              final firstName = driver?.profile.firstName ?? 'Driver';
              final lastName = driver?.profile.lastName ?? '';
              
              // Format as "FirstName L." or just "FirstName" if no lastName
              String formattedName;
              if (lastName.isNotEmpty) {
                formattedName = '$firstName ${lastName.substring(0, 1).toUpperCase()}.';
              } else {
                formattedName = firstName;
              }
              
              return Row(
                children: [
                  ProfileAvatarWidget(
                    photoUrl: driver?.profile.photoURL,
                    radius: 24,
                    fallbackText: displayName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              driver?.ratings.averageRating.toStringAsFixed(1) ?? '4.8',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${driver?.ratings.totalRatings ?? 25} rides)',
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
                  OutlinedButton(
                    onPressed: driver != null ? () => _viewDriverProfile(driver) : null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE57200)),
                      foregroundColor: const Color(0xFFE57200),
                    ),
                    child: const Text('View Profile'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 16, top: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ride Preferences',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPreferenceChip(
                widget.ride.preferences.allowSmoking ? 'Smoking OK' : 'No Smoking',
                widget.ride.preferences.allowSmoking ? Colors.orange : Colors.green,
              ),
              _buildPreferenceChip(
                widget.ride.preferences.allowPets ? 'Pets OK' : 'No Pets',
                widget.ride.preferences.allowPets ? Colors.blue : Colors.grey,
              ),
              _buildPreferenceChip(
                _formatMusicPreference(widget.ride.preferences.musicPreference),
                Colors.purple,
              ),
              _buildPreferenceChip(
                _formatCommunicationStyle(widget.ride.preferences.communicationStyle),
                Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassengersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
              Text(
                'Passengers',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.ride.passengerIds.length}/${widget.ride.totalSeats}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE57200),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.ride.passengerIds.isEmpty)
            Text(
              'No passengers yet',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
              ),
            )
          else
            ...widget.ride.passengerIds.map((passengerId) => 
              _buildPassengerTile(passengerId)
            ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
                  Expanded(
                    child: Text(
                      'Additional Notes',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isNotesExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: Colors.grey.shade600,
                      size: 24,
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
                    widget.ride.notes!,
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

  Widget _buildActionButtons() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, child) {
        final userRole = rideProvider.getUserRoleInRide(widget.ride);
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (userRole == 'passenger')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _leaveRide(rideProvider),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Leave This Ride',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              if (userRole == 'driver')
                Column(
                  children: [
                    if (widget.ride.passengerIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showDriverVerificationCode(),
                            icon: const Icon(Icons.security),
                            label: Text(
                              'Show Verification Code',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // TODO: Edit ride
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE57200)),
                              foregroundColor: const Color(0xFFE57200),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Edit Ride'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.ride.status == RideStatus.active
                                ? () => _cancelRide(rideProvider)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Cancel Ride'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Future<UserModel?> _getDriverData() async {
    if (_driverData != null) {
      return _driverData;
    }
    
    try {
      final doc = await _authService.getUserData(widget.ride.driverId);
      if (doc != null && doc.exists) {
        _driverData = UserModel.fromFirestore(doc);
        return _driverData;
      }
    } catch (e) {
      debugPrint('Error fetching driver data: $e');
    }
    
    return null;
  }

  Future<UserModel?> _getPassengerData(String passengerId) async {
    if (_passengerData.containsKey(passengerId)) {
      return _passengerData[passengerId];
    }
    
    try {
      final doc = await _authService.getUserData(passengerId);
      if (doc != null && doc.exists) {
        final userData = UserModel.fromFirestore(doc);
        _passengerData[passengerId] = userData;
        return userData;
      }
    } catch (e) {
      debugPrint('Error fetching passenger data: $e');
    }
    
    _passengerData[passengerId] = null;
    return null;
  }

  Widget _buildPassengerTile(String passengerId) {
    return FutureBuilder<UserModel?>(
      future: _getPassengerData(passengerId),
      builder: (context, snapshot) {
        // Show loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            title: Text(
              'Loading...',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            subtitle: const SizedBox(height: 16),
          );
        }

        final passenger = snapshot.data;
        
        // Use displayName as primary, with firstName as backup
        String displayName = passenger?.profile.displayName.trim() ?? '';
        if (displayName.isEmpty) {
          final firstName = passenger?.profile.firstName.trim() ?? '';
          final lastName = passenger?.profile.lastName.trim() ?? '';
          if (firstName.isNotEmpty && lastName.isNotEmpty) {
            displayName = '$firstName $lastName';
          } else if (firstName.isNotEmpty) {
            displayName = firstName;
          } else {
            displayName = 'Unknown Passenger';
          }
        }

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ProfileAvatarWidget(
            photoUrl: passenger?.profile.photoURL,
            radius: 20,
            fallbackText: displayName,
          ),
          title: Text(
            displayName,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: GestureDetector(
            onTap: passenger != null ? () => _navigateToPassengerReviews(passenger) : null,
            child: Row(
              children: [
                Icon(
                  Icons.star,
                  size: 14,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  passenger?.ratings.averageRating.toStringAsFixed(1) ?? 'New',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    decoration: passenger != null ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fitMapToRoute() async {
    if (_mapController == null) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        widget.ride.startLocation.coordinates.latitude < widget.ride.endLocation.coordinates.latitude
            ? widget.ride.startLocation.coordinates.latitude
            : widget.ride.endLocation.coordinates.latitude,
        widget.ride.startLocation.coordinates.longitude < widget.ride.endLocation.coordinates.longitude
            ? widget.ride.startLocation.coordinates.longitude
            : widget.ride.endLocation.coordinates.longitude,
      ),
      northeast: LatLng(
        widget.ride.startLocation.coordinates.latitude > widget.ride.endLocation.coordinates.latitude
            ? widget.ride.startLocation.coordinates.latitude
            : widget.ride.endLocation.coordinates.latitude,
        widget.ride.startLocation.coordinates.longitude > widget.ride.endLocation.coordinates.longitude
            ? widget.ride.startLocation.coordinates.longitude
            : widget.ride.endLocation.coordinates.longitude,
      ),
    );

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  Future<void> _leaveRide(RideProvider rideProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Ride'),
        content: const Text('Are you sure you want to leave this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await rideProvider.leaveRide(widget.ride.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Left ride successfully' : 'Failed to leave ride'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelRide(RideProvider rideProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Ride'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await rideProvider.cancelRideOffer(widget.ride.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Ride cancelled successfully' : 'Failed to cancel ride'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return 'Today at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    } else {
      return '${dateTime.month}/${dateTime.day} at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    }
  }

  String _formatMusicPreference(String preference) {
    switch (preference) {
      case 'driver_choice':
        return 'Driver\'s Choice';
      case 'pop':
        return 'Pop Music';
      case 'rock':
        return 'Rock Music';
      case 'hip_hop':
        return 'Hip Hop';
      case 'country':
        return 'Country';
      case 'classical':
        return 'Classical';
      case 'no_music':
        return 'No Music';
      default:
        return preference;
    }
  }

  String _formatCommunicationStyle(String style) {
    switch (style) {
      case 'friendly':
        return 'Friendly Chat';
      case 'quiet':
        return 'Quiet Ride';
      case 'professional':
        return 'Professional';
      default:
        return style;
    }
  }

  void _viewDriverProfile(UserModel driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ProfileAvatarWidget(
                        photoUrl: driver.profile.photoURL,
                        radius: 50,
                        fallbackText: driver.profile.displayName,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        driver.profile.displayName.isNotEmpty 
                            ? driver.profile.displayName 
                            : '${driver.profile.firstName} ${driver.profile.lastName}',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (driver.profile.pronouns.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          driver.profile.pronouns,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF232F3E),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          driver.accountType == 'driver' ? 'Driver' : 'Rider & Driver',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (driver.isVerified) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Colors.green.shade600, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: GoogleFonts.inter(
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      
                      // Vehicle Information
                      if (driver.vehicleInfo != null) ...[
                        Container(
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
                              Text(
                                'Vehicle Information',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.directions_car, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      driver.vehicleInfo!.displayName,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    driver.vehicleInfo!.licensePlate,
                                    style: GoogleFonts.inter(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Bio Section
                      if (driver.profile.bio.isNotEmpty) ...[
                        Container(
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
                              Text(
                                'About',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                driver.profile.bio,
                                style: GoogleFonts.inter(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Ratings Section
                      InkWell(
                        onTap: () => _navigateToDriverReviews(driver),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
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
                                  Text(
                                    'Ratings',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.star,
                                              color: Colors.amber.shade600,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              driver.ratings.averageRating.toStringAsFixed(1),
                                              style: GoogleFonts.inter(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Overall',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          '${driver.ratings.totalRatings} ratings',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.star,
                                              color: Colors.amber.shade600,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              driver.ratings.asDriver.averageRating.toStringAsFixed(1),
                                              style: GoogleFonts.inter(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'As Driver',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          '${driver.ratings.asDriver.totalRatings} ratings',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to view all reviews',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFFE57200),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDriverVerificationCode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DriverVerificationCodeScreen(ride: widget.ride),
      ),
    );
  }

  void _navigateToDriverReviews(UserModel driver) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserReviewsScreen(user: driver),
      ),
    );
  }

  void _navigateToPassengerReviews(UserModel passenger) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserReviewsScreen(user: passenger),
      ),
    );
  }
}
