import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/address_search_widget.dart';
import '../../services/directions_service.dart';

class DriverPostRideScreen extends StatefulWidget {
  const DriverPostRideScreen({super.key});

  @override
  State<DriverPostRideScreen> createState() => _DriverPostRideScreenState();
}

class _DriverPostRideScreenState extends State<DriverPostRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _priceController = TextEditingController();
  final DirectionsService _directionsService = DirectionsService();

  RideLocation? _startLocation;
  RideLocation? _endLocation;
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 2));
  int _seatsAvailable = 3;
  Duration _flexibilityWindow = const Duration(minutes: 30);
  double? _recommendedPrice;

  bool _allowSmoking = false;
  bool _allowPets = false;
  String _musicPreference = 'driver_choice';
  String _communicationStyle = 'friendly';

  final List<String> _musicOptions = [
    'driver_choice',
    'pop',
    'rock',
    'hip_hop',
    'country',
    'classical',
    'no_music',
  ];

  final List<String> _communicationOptions = [
    'friendly',
    'quiet',
    'professional',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDriverDefaults());
  }

  void _loadDriverDefaults() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final prefs = authProvider.userModel?.preferences;
    if (prefs != null) {
      setState(() {
        _allowSmoking = prefs.allowSmoking;
        _allowPets = prefs.allowPets;

        final prefMusic = prefs.musicPreference.toLowerCase();
        _musicPreference =
            _musicOptions.contains(prefMusic) ? prefMusic : 'driver_choice';

        final prefComm = prefs.communicationStyle.toLowerCase();
        _communicationStyle =
            _communicationOptions.contains(prefComm) ? prefComm : 'friendly';
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  bool _hasNonDefaultPreferences() {
    return _allowSmoking != false ||
        _allowPets != false ||
        _musicPreference != 'driver_choice' ||
        _communicationStyle != 'friendly';
  }

  Future<void> _calculateRecommendedPrice() async {
    if (_startLocation == null || _endLocation == null) return;

    try {
      // Calculate distance using Haversine formula (fallback)
      final distance = _directionsService.calculateDistance(
        _startLocation!.coordinates,
        _endLocation!.coordinates,
      );
      
      // Convert meters to miles for pricing calculation
      final distanceInMiles = distance * 0.000621371;
      
      // Updated pricing assumptions for better driver compensation:
      const double avgGasPricePerGallon = 2.95;      // Current national average (Dec 2025)
      const double avgVehicleMPG = 26.0;              // More realistic for variety of vehicles
      const double vehicleWearCostPerMile = 0.15;     // IRS-based vehicle depreciation/maintenance
      const double driverTimeValuePerHour = 15.0;     // Fair hourly compensation
      const double avgSpeedMph = 45.0;                // Mixed city/highway driving
      
      // Calculate trip duration for time compensation
      final estimatedTripHours = distanceInMiles / avgSpeedMph;
      
      // 1. Fuel costs
      final gallonsNeeded = distanceInMiles / avgVehicleMPG;
      final totalFuelCost = gallonsNeeded * avgGasPricePerGallon;
      
      // 2. Vehicle wear and depreciation
      final vehicleWearCost = distanceInMiles * vehicleWearCostPerMile;
      
      // 3. Driver time compensation
      final driverTimeCost = estimatedTripHours * driverTimeValuePerHour;
      
      // 4. Calculate base cost per trip
      final baseCostPerTrip = totalFuelCost + vehicleWearCost + driverTimeCost;
      
      // 5. Split cost among available seats (driver keeps all passenger payments)
      final costPerSeat = baseCostPerTrip / _seatsAvailable;
      
      // 6. Apply distance-based pricing tiers for market competitiveness
      double distanceMultiplier = 1.0;
      if (distanceInMiles < 5) {
        distanceMultiplier = 1.4;        // Higher rate for short trips (startup cost)
      } else if (distanceInMiles < 15) {
        distanceMultiplier = 1.2;        // Moderate rate for medium trips
      } else if (distanceInMiles < 50) {
        distanceMultiplier = 1.1;        // Slight premium for long trips
      } else {
        distanceMultiplier = 1.0;        // Base rate for very long trips
      }
      
      // 7. Add profit margin (30% for driver profit + platform sustainability)
      final recommendedPrice = costPerSeat * distanceMultiplier * 1.3;
      
      // 8. Apply minimum price and round to nearest $0.25 for cleaner pricing
      final minPrice = distanceInMiles < 3 ? 5.0 : 4.0;
      final finalPrice = (recommendedPrice.clamp(minPrice, double.infinity) * 4).round() / 4;
      
      setState(() {
        _recommendedPrice = finalPrice;
      });
    } catch (e) {
      // Handle error silently - recommendation is optional
      setState(() {
        _recommendedPrice = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Post a Drive',
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Trip Details'),
              const SizedBox(height: 16),
              _buildLocationFields(),
              const SizedBox(height: 16),
              _buildDateTimeField(),
              const SizedBox(height: 16),
              _buildSeatsAndPrice(),
              const SizedBox(height: 24),

              _buildSectionTitle('Flexibility'),
              const SizedBox(height: 16),
              _buildFlexibilityField(),
              const SizedBox(height: 24),

              _buildExpandablePreferences(),
              const SizedBox(height: 24),

              _buildSectionTitle('Additional Notes'),
              const SizedBox(height: 16),
              _buildNotesField(),
              const SizedBox(height: 32),

              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF232F3E),
        ),
      );

  Widget _buildLocationFields() {
    return Column(
      children: [
        AddressSearchWidget(
          hintText: 'Pick-up location',
          onAddressSelected: (result) {
            setState(() {
              _startLocation = RideLocation(
                coordinates: result.location,
                address: result.formattedAddress,
              );
            });
            _calculateRecommendedPrice();
          },
        ),
        const SizedBox(height: 12),
        AddressSearchWidget(
          hintText: 'Drop-off location',
          onAddressSelected: (result) {
            setState(() {
              _endLocation = RideLocation(
                coordinates: result.location,
                address: result.formattedAddress,
              );
            });
            _calculateRecommendedPrice();
          },
        ),
      ],
    );
  }

  Widget _buildDateTimeField() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.access_time, color: Color(0xFFE57200)),
        title: const Text('Departure Time'),
        subtitle: Text(
          '${_departureTime.month}/${_departureTime.day}/${_departureTime.year} at ${TimeOfDay.fromDateTime(_departureTime).format(context)}',
        ),
        trailing: const Icon(Icons.edit),
        onTap: _selectDateTime,
      ),
    );
  }

  Widget _buildSeatsAndPrice() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_seat, color: Color(0xFFE57200)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: const Text(
                          'Seats Available',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$_seatsAvailable seat${_seatsAvailable > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _seatsAvailable > 1
                                  ? const Color(0xFFE57200)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 14,
                              onPressed: _seatsAvailable > 1
                                  ? () {
                                      setState(() => _seatsAvailable--);
                                      _calculateRecommendedPrice();
                                    }
                                  : null,
                              icon: const Icon(Icons.remove, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _seatsAvailable < 6
                                  ? const Color(0xFFE57200)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 14,
                              onPressed: _seatsAvailable < 6
                                  ? () {
                                      setState(() => _seatsAvailable++);
                                      _calculateRecommendedPrice();
                                    }
                                  : null,
                              icon: const Icon(Icons.add, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Price per Seat',
              prefixText: '\$',
              helperText: _recommendedPrice != null 
                  ? 'Recommended: \$${_recommendedPrice!.toStringAsFixed(2)}'
                  : null,
              helperStyle: TextStyle(
                color: const Color(0xFFE57200),
                fontWeight: FontWeight.w500,
              ),
              suffixIcon: _recommendedPrice != null
                  ? IconButton(
                      icon: const Icon(Icons.auto_fix_high, 
                          color: Color(0xFFE57200)),
                      onPressed: () {
                        _priceController.text = _recommendedPrice!.toStringAsFixed(2);
                      },
                      tooltip: 'Use recommended price',
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter price';
              if (double.tryParse(value) == null) return 'Invalid price';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlexibilityField() => Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.schedule, color: Color(0xFFE57200)),
              title: const Text('Time Flexibility'),
              subtitle: Text('±${_flexibilityWindow.inMinutes} minutes'),
            ),
            Slider(
              value: _flexibilityWindow.inMinutes.toDouble(),
              min: 15,
              max: 120,
              divisions: 7,
              label: '±${_flexibilityWindow.inMinutes} min',
              thumbColor: const Color(0xFFE57200),
              onChanged: (value) {
                setState(() =>
                    _flexibilityWindow = Duration(minutes: value.round()));
              },
            ),
          ],
        ),
      );

  Widget _buildExpandablePreferences() => Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const Icon(Icons.tune, color: Color(0xFF232F3E)),
            title: Text(
              'Ride Preferences',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF232F3E),
              ),
            ),
            subtitle: Text(
              _hasNonDefaultPreferences()
                  ? 'Customized'
                  : 'Using defaults from profile',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _hasNonDefaultPreferences()
                    ? const Color(0xFFE57200)
                    : Colors.grey.shade600,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildPreferenceCard(
                      'Smoking',
                      'Allow smoking in the vehicle',
                      _allowSmoking,
                      (v) => setState(() => _allowSmoking = v),
                    ),
                    const SizedBox(height: 12),
                    _buildPreferenceCard(
                      'Pets',
                      'Allow pets in the vehicle',
                      _allowPets,
                      (v) => setState(() => _allowPets = v),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownCard(
                      'Music',
                      _musicPreference,
                      _musicOptions,
                      (v) => setState(() => _musicPreference = v!),
                      _formatMusicOption,
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownCard(
                      'Communication',
                      _communicationStyle,
                      _communicationOptions,
                      (v) => setState(() => _communicationStyle = v!),
                      _formatCommunicationOption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildPreferenceCard(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) =>
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SwitchListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          value: value,
          onChanged: onChanged,
          thumbColor: WidgetStateProperty.all(const Color(0xFFE57200)),
        ),
      );

  Widget _buildDropdownCard(
    String title,
    String value,
    List<String> options,
    Function(String?) onChanged,
    String Function(String) formatter,
  ) =>
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          title: Text(title),
          subtitle: Text(formatter(value)),
          trailing: DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            items: options
                .map((opt) => DropdownMenuItem(
                      value: opt,
                      child: Text(formatter(opt)),
                    ))
                .toList(),
          ),
        ),
      );

  Widget _buildNotesField() => TextFormField(
        controller: _notesController,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Additional Notes (Optional)',
          hintText: 'Any details about your drive...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _buildSubmitButton() => Consumer<RideProvider>(
        builder: (context, rideProvider, child) => SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: rideProvider.isCreatingOffer ? null : _submitOffer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE57200),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: rideProvider.isCreatingOffer
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Post Drive',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      );

  Future<void> _selectDateTime() async {
    final dateTime = await showOmniDateTimePicker(
      context: context,
      initialDate: _departureTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (dateTime != null) {
      setState(() {
        _departureTime = dateTime;
      });
    }
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startLocation == null || _endLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pick-up and drop-off locations'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final rideProvider = Provider.of<RideProvider>(context, listen: false);

    final offer = RideOffer(
  id: '', // Firestore will set
  driverId: rideProvider.currentUserId!,
  startLocation: _startLocation!,           // RideLocation
  endLocation: _endLocation!,               // RideLocation
  departureTime: _departureTime,            // DateTime

  // Seats (model-aligned)
  availableSeats: _seatsAvailable,          // int
  totalSeats: _seatsAvailable,              // int

  pricePerSeat: double.parse(_priceController.text),

  // Passengers / requests
  passengerIds: const <String>[],           // start empty
  pendingRequestIds: const <String>[],      // start empty
  passengerPickupStatus: const <String, PickupStatus>{},
  passengerSeatPrices: const <String, double>{},
  passengerPickupLocations: const <String, RideLocation>{},
  passengerDropoffLocations: const <String, RideLocation>{},
  passengerSeatCounts: const <String, int>{},

  // Status / lifecycle
  status: RideStatus.active,
  isArchived: false,

  // Preferences (mirroring Rider form precedent)
  preferences: RidePreferences(
    allowSmoking: _allowSmoking,
    allowPets: _allowPets,
    musicPreference: _musicPreference,
    communicationStyle: _communicationStyle,
    preferredGenders: const [],             // keep empty for now
    maxPassengers: _seatsAvailable,         // keep in sync with seats
  ),

  notes: _notesController.text.isNotEmpty ? _notesController.text : null,

  // Optional routing fields for now
  waypoints: null,
  estimatedDistance: 0,                     // fill later when you compute
  estimatedDuration: Duration.zero,         // fill later when you compute

  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);


    final success = await rideProvider.createRideOffer(offer);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drive posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rideProvider.creationError ?? 'Failed to post drive',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatMusicOption(String option) {
    switch (option) {
      case 'driver_choice':
        return "Driver's Choice";
      case 'pop':
        return 'Pop';
      case 'rock':
        return 'Rock';
      case 'hip_hop':
        return 'Hip Hop';
      case 'country':
        return 'Country';
      case 'classical':
        return 'Classical';
      case 'no_music':
        return 'No Music';
      default:
        return option;
    }
  }

  String _formatCommunicationOption(String option) {
    switch (option) {
      case 'friendly':
        return 'Friendly Chat';
      case 'quiet':
        return 'Quiet Ride';
      case 'professional':
        return 'Professional';
      default:
        return option;
    }
  }
}
