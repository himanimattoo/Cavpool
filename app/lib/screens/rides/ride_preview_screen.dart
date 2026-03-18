import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/active_ride_management_service.dart';
import '../../services/auth_service.dart';
import '../../services/directions_service.dart';
import '../../utils/units_formatter.dart';

/// Preview screen shown when driver has accepted a ride but hasn't started it yet
class RidePreviewScreen extends StatefulWidget {
  final ActiveRideInfo rideInfo;
  final VoidCallback onStartRide;
  final VoidCallback onCancelRide;

  const RidePreviewScreen({
    super.key,
    required this.rideInfo,
    required this.onStartRide,
    required this.onCancelRide,
  });

  @override
  State<RidePreviewScreen> createState() => _RidePreviewScreenState();
}

class _RidePreviewScreenState extends State<RidePreviewScreen> {
  GoogleMapController? _mapController;
  final AuthService _authService = AuthService();
  final DirectionsService _directionsService = DirectionsService();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Cache for passenger data
  final Map<String, UserModel?> _passengerData = {};
  
  // Expansion states
  bool _isNotesExpanded = false;
  bool _isSeatsExpanded = false;

  @override
  void initState() {
    super.initState();
    _setupMapMarkers();
  }

  void _setupMapMarkers() async {
    final ride = widget.rideInfo.ride;
    
    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: ride.startLocation.coordinates,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Pickup Location',
          snippet: ride.startLocation.address,
        ),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: ride.endLocation.coordinates,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Dropoff Location',
          snippet: ride.endLocation.address,
        ),
      ),
    };

    // Try to get actual route from Google Directions API
    try {
      final directionsResult = await _directionsService.getDirections(
        origin: ride.startLocation.coordinates,
        destination: ride.endLocation.coordinates,
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
    final ride = widget.rideInfo.ride;
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          ride.startLocation.coordinates,
          ride.endLocation.coordinates,
        ],
        color: const Color(0xFF2196F3),
        width: 5,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Ride Preview',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => _showCancelConfirmation(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map Section
          Expanded(
            flex: 2,
            child: _buildMapSection(),
          ),
          
          // Details Section
          Expanded(
            flex: 3,
            child: _buildDetailsSection(),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  Widget _buildMapSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.rideInfo.ride.startLocation.coordinates,
            zoom: 13,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            _fitMarkersInView();
          },
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header
          _buildStatusHeader(),
          const SizedBox(height: 16),
          
          // Combined Info Card
          _buildCombinedInfoCard(),
          const SizedBox(height: 16),
          
          // Passengers Section (only if there are passengers)
          if (widget.rideInfo.passengers.isNotEmpty) ...[
            _buildPassengersSection(),
            const SizedBox(height: 16),
          ],
          
          // Notes Section (only if notes exist)
          if (widget.rideInfo.ride.notes?.isNotEmpty == true) ...[
            _buildExpandableNotesSection(widget.rideInfo.ride.notes!),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    final ride = widget.rideInfo.ride;
    final now = DateTime.now();
    final isPastDeparture = ride.departureTime.isBefore(now);
    final timeDiff = ride.departureTime.difference(now);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPastDeparture ? Colors.orange[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPastDeparture ? Colors.orange[200]! : Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPastDeparture ? Colors.orange[600] : Colors.blue[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPastDeparture ? Icons.warning : Icons.schedule,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPastDeparture ? 'Departure Time Passed' : 'Ride Accepted',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isPastDeparture ? Colors.orange[800] : Colors.blue[800],
                  ),
                ),
                Text(
                  isPastDeparture 
                    ? 'Departed ${_formatTimeAgo(-timeDiff)} ago'
                    : 'Ready to start when you are',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isPastDeparture ? Colors.orange[700] : Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    }
  }

  Widget _buildCombinedInfoCard() {
    final ride = widget.rideInfo.ride;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Information
          _buildLocationRow(
            icon: Icons.my_location,
            label: 'Pickup',
            address: ride.startLocation.address,
            time: TimeOfDay.fromDateTime(ride.departureTime).format(context),
            iconColor: Colors.green,
          ),
          const SizedBox(height: 16),
          _buildLocationRow(
            icon: Icons.location_on,
            label: 'Drop-off',
            address: ride.endLocation.address,
            iconColor: Colors.red,
          ),
          
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          
          // Key Info Grid
          Row(
            children: [
              Expanded(
                child: _buildExpandableSeatsItem(ride),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.attach_money,
                  label: 'Price',
                  value: '\$${ride.pricePerSeat.toStringAsFixed(0)}',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: _formatDistance(context, ride.estimatedDistance),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          
          // Expandable Seats Detail Section
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                _buildSeatsDetailSection(),
              ],
            ),
            crossFadeState: _isSeatsExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSeatsItem(dynamic ride) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSeatsExpanded = !_isSeatsExpanded;
        });
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, color: Colors.blue, size: 24),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _isSeatsExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    color: Colors.blue,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seats',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${ride.availableSeats}/${ride.totalSeats}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatsDetailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seat Assignments',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        
        // Occupied Seats
        if (widget.rideInfo.passengers.isNotEmpty) ...[
          Text(
            'Passengers (${widget.rideInfo.passengers.length})',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 8),
          ...widget.rideInfo.passengers.map((passenger) => 
            _buildPassengerSeatTile(passenger),
          ),
          const SizedBox(height: 12),
        ],
        
        // Available Seats
        if (widget.rideInfo.ride.availableSeats > 0) ...[
          Text(
            'Available (${widget.rideInfo.ride.availableSeats})',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            widget.rideInfo.ride.availableSeats,
            (index) => _buildAvailableSeatTile(index + widget.rideInfo.passengers.length + 1),
          ),
        ],
      ],
    );
  }

  Widget _buildPassengerSeatTile(dynamic passenger) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.person, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passenger.passenger.profile.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  'Pickup: ${passenger.pickupLocation.address}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (passenger.dropoffLocation.address != widget.rideInfo.ride.endLocation.address)
                  Text(
                    'Dropoff: ${passenger.dropoffLocation.address}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(passenger.pickupStatus),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getStatusText(passenger.pickupStatus),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableSeatTile(int seatNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.person_outline, color: Colors.grey[600], size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            'Seat $seatNumber - Available',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(dynamic status) {
    switch (status.toString()) {
      case 'PickupStatus.pending':
        return Colors.orange;
      case 'PickupStatus.arrived':
        return Colors.blue;
      case 'PickupStatus.pickedUp':
        return Colors.green;
      case 'PickupStatus.droppedOff':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(dynamic status) {
    switch (status.toString()) {
      case 'PickupStatus.pending':
        return 'PENDING';
      case 'PickupStatus.arrived':
        return 'ARRIVED';
      case 'PickupStatus.pickedUp':
        return 'PICKED UP';
      case 'PickupStatus.droppedOff':
        return 'DROPPED OFF';
      default:
        return 'UNKNOWN';
    }
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


  Widget _buildPassengersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Text(
            'Passengers (${widget.rideInfo.passengers.length})',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 12),
          
          ...widget.rideInfo.passengers.map((passenger) => 
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildPassengerTile(passenger),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildPassengerTile(PassengerContactInfo passenger) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue[100],
            backgroundImage: passenger.passenger.profile.photoURL.isNotEmpty
                ? NetworkImage(passenger.passenger.profile.photoURL)
                : null,
            child: passenger.passenger.profile.photoURL.isEmpty
                ? Text(
                    passenger.passenger.profile.displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
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
                  passenger.passenger.profile.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                Text(
                  'Status: ${passenger.pickupStatus.name}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _callPassenger(passenger.passengerId),
                icon: Icon(Icons.phone, color: Colors.green[600], size: 20),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                onPressed: () => _messagePassenger(passenger.passengerId),
                icon: Icon(Icons.message, color: Colors.blue[600], size: 20),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final ride = widget.rideInfo.ride;
    final isPastDeparture = ride.departureTime.isBefore(DateTime.now());
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _showCancelConfirmation,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[600],
                side: BorderSide(color: Colors.red[300]!),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel Ride',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isPastDeparture ? null : widget.onStartRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPastDeparture ? Colors.grey[400] : Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPastDeparture ? Icons.schedule : Icons.play_arrow, 
                    size: 20
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPastDeparture ? 'Time Passed' : 'Start Ride',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _fitMarkersInView() {
    if (_mapController == null || _markers.isEmpty) return;

    final latLngs = _markers.map((marker) => marker.position).toList();
    
    if (latLngs.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(latLngs.first, 15),
      );
    } else {
      final bounds = _getBounds(latLngs);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }

  LatLngBounds _getBounds(List<LatLng> positions) {
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final pos in positions) {
      minLat = minLat < pos.latitude ? minLat : pos.latitude;
      maxLat = maxLat > pos.latitude ? maxLat : pos.latitude;
      minLng = minLng < pos.longitude ? minLng : pos.longitude;
      maxLng = maxLng > pos.longitude ? maxLng : pos.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
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

  Future<void> _callPassenger(String passengerId) async {
    final passenger = await _getPassengerData(passengerId);
    final firstName = passenger?.profile.firstName ?? 'Passenger';
    final lastName = passenger?.profile.lastName ?? '';
    
    // Format as "FirstName L." or just "FirstName" if no lastName
    String formattedName;
    if (lastName.isNotEmpty) {
      formattedName = '$firstName ${lastName.substring(0, 1).toUpperCase()}.';
    } else {
      formattedName = firstName;
    }
    
    // Implement call functionality
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calling $formattedName')),
      );
    }
  }

  Future<void> _messagePassenger(String passengerId) async {
    final passenger = await _getPassengerData(passengerId);
    final firstName = passenger?.profile.firstName ?? 'Passenger';
    final lastName = passenger?.profile.lastName ?? '';
    
    // Format as "FirstName L." or just "FirstName" if no lastName
    String formattedName;
    if (lastName.isNotEmpty) {
      formattedName = '$firstName ${lastName.substring(0, 1).toUpperCase()}.';
    } else {
      formattedName = firstName;
    }
    
    // Implement message functionality
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Messaging $formattedName')),
      );
    }
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text('Are you sure you want to cancel this ride? Passengers will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Ride'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onCancelRide();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
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

  String _formatDistance(BuildContext context, double distanceMeters) {
    final userProvider = context.read<UserProfileProvider>();
    final unit = UnitsFormatter.getUnitFromPreferences(userProvider.userProfile?.preferences);
    
    // Convert meters to kilometers
    final kilometers = distanceMeters / 1000.0;
    
    if (unit == DistanceUnit.metric) {
      return '${kilometers.toStringAsFixed(1)} km';
    } else {
      // Convert km to miles: 1 km = 0.621371 miles
      final miles = kilometers * 0.621371;
      return '${miles.toStringAsFixed(1)} mi';
    }
  }
}