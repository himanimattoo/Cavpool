import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/address_search_widget.dart';
import '../home/home_screen.dart';

class RideRequestScreen extends StatefulWidget {
  const RideRequestScreen({
    super.key,
    this.initialOffer,
    this.initialPickup,
    this.initialDropoff,
    this.initialDepartureTime,
    this.initialSeatsNeeded,
    this.initialFlexibility,
    this.initialPricePerSeat,
    this.initialPreferences,
    this.initialNotes,
  });

  final RideOffer? initialOffer;
  final RideLocation? initialPickup;
  final RideLocation? initialDropoff;
  final DateTime? initialDepartureTime;
  final int? initialSeatsNeeded;
  final Duration? initialFlexibility;
  final double? initialPricePerSeat;
  final RidePreferences? initialPreferences;
  final String? initialNotes;

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _maxPriceController = TextEditingController();

  // Form fields
  RideLocation? _startLocation;
  RideLocation? _endLocation;
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 2));
  int _seatsNeeded = 1;
  Duration _flexibilityWindow = const Duration(minutes: 30);

  // Preferences
  bool _allowSmoking = false;
  bool _allowPets = false;
  String _musicPreference = 'driver_choice';
  String _communicationStyle = 'friendly';
  // final List<String> _preferredGenders = []; // Commented out for now


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
    _initializeForm();
  }

  void _initializeForm() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final prefs = authProvider.userModel?.preferences;

    if (prefs != null) {
      _allowSmoking = prefs.allowSmoking;
      _allowPets = prefs.allowPets;

      final prefMusic = prefs.musicPreference.toLowerCase();
      _musicPreference = _musicOptions.contains(prefMusic)
          ? prefMusic
          : 'driver_choice';

      final prefComm = prefs.communicationStyle.toLowerCase();
      _communicationStyle = _communicationOptions.contains(prefComm)
          ? prefComm
          : 'friendly';

      _seatsNeeded = prefs.defaultSeatsNeeded;
      _flexibilityWindow = Duration(minutes: prefs.defaultFlexibilityMinutes);
    }

    _applyPrefillData();
  }

  void _applyPrefillData() {
    final offer = widget.initialOffer;

    _startLocation = widget.initialPickup ?? offer?.startLocation ?? _startLocation;
    _endLocation = widget.initialDropoff ?? offer?.endLocation ?? _endLocation;
    _departureTime = widget.initialDepartureTime ?? offer?.departureTime ?? _departureTime;

    if (widget.initialSeatsNeeded != null) {
      final maxSeats = offer?.availableSeats ?? 4;
      _seatsNeeded = widget.initialSeatsNeeded!.clamp(1, maxSeats).toInt();
    } else if (offer != null) {
      _seatsNeeded = _seatsNeeded.clamp(1, offer.availableSeats).toInt();
    }

    if (widget.initialFlexibility != null) {
      _flexibilityWindow = widget.initialFlexibility!;
    }

    final price = widget.initialPricePerSeat ?? offer?.pricePerSeat;
    if (price != null) {
      _maxPriceController.text = _formatPrice(price);
    }

    final prefs = widget.initialPreferences ?? offer?.preferences;
    if (prefs != null) {
      _allowSmoking = prefs.allowSmoking;
      _allowPets = prefs.allowPets;

      final prefMusic = prefs.musicPreference.toLowerCase();
      if (_musicOptions.contains(prefMusic)) {
        _musicPreference = prefMusic;
      }

      final prefComm = prefs.communicationStyle.toLowerCase();
      if (_communicationOptions.contains(prefComm)) {
        _communicationStyle = prefComm;
      }
    }

    if (widget.initialNotes != null && widget.initialNotes!.isNotEmpty) {
      _notesController.text = widget.initialNotes!;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  bool _hasNonDefaultPreferences() {
    return _allowSmoking != false ||
        _allowPets != false ||
        _musicPreference != 'driver_choice' ||
        _communicationStyle != 'friendly';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request a Ride',
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
              if (widget.initialOffer != null) ...[
                _buildSectionTitle('Driver Offer'),
                const SizedBox(height: 12),
                _buildOfferSummary(widget.initialOffer!),
                const SizedBox(height: 24),
              ],
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF232F3E),
      ),
    );
  }

  Widget _buildOfferSummary(RideOffer offer) {
    final departureText =
        '${offer.departureTime.month}/${offer.departureTime.day} at ${TimeOfDay.fromDateTime(offer.departureTime).format(context)}';

    final preferenceBadges = <String>[
      offer.preferences.allowSmoking ? 'Smoking OK' : 'Smoke-free',
      offer.preferences.allowPets ? 'Pets welcome' : 'No pets',
      'Music: ${_formatMusicOption(offer.preferences.musicPreference)}',
      'Vibe: ${_formatCommunicationOption(offer.preferences.communicationStyle)}',
      '${offer.availableSeats} seat${offer.availableSeats == 1 ? '' : 's'} open',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _offerDetailRow(Icons.my_location, 'Pick-up', offer.startLocation.address),
          const SizedBox(height: 8),
          _offerDetailRow(Icons.place, 'Drop-off', offer.endLocation.address),
          const SizedBox(height: 8),
          _offerDetailRow(Icons.access_time, 'Departure', departureText),
          const SizedBox(height: 8),
          _offerDetailRow(Icons.attach_money, 'Price per seat', '\$${_formatPrice(offer.pricePerSeat)}'),
          if (offer.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _offerDetailRow(Icons.notes, 'Driver notes', offer.notes!),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: preferenceBadges.map(_offerChip).toList(),
          ),
        ],
      ),
    );
  }

  Widget _offerDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFFE57200)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _offerChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFF232F3E),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLocationFields() {
    return Column(
      children: [
        AddressSearchWidget(
          key: ValueKey('pickup_${_startLocation?.address ?? ''}'),
          initialAddress: _startLocation?.address,
          hintText: 'Pick-up location',
          onAddressSelected: (result) {
            setState(() {
              _startLocation = RideLocation(
                coordinates: result.location,
                address: result.formattedAddress,
              );
            });
          },
        ),
        const SizedBox(height: 12),
        AddressSearchWidget(
          key: ValueKey('dropoff_${_endLocation?.address ?? ''}'),
          initialAddress: _endLocation?.address,
          hintText: 'Drop-off location',
          onAddressSelected: (result) {
            setState(() {
              _endLocation = RideLocation(
                coordinates: result.location,
                address: result.formattedAddress,
              );
            });
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
                      const Icon(Icons.person, color: Color(0xFFE57200), size: 20),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Seats Needed',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_seatsNeeded seat${_seatsNeeded > 1 ? 's' : ''}',
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
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _seatsNeeded > 1
                                  ? const Color(0xFFE57200)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 12,
                              onPressed: _seatsNeeded > 1
                                  ? () => setState(() => _seatsNeeded--)
                                  : null,
                              icon: const Icon(
                                Icons.remove,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _seatsNeeded < 4
                                  ? const Color(0xFFE57200)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 12,
                              onPressed: _seatsNeeded < 4
                                  ? () => setState(() => _seatsNeeded++)
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
            controller: _maxPriceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Maximum Fare (per seat)',
              prefixText: '\$',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter max price';
              }
              if (double.tryParse(value) == null) {
                return 'Invalid price';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlexibilityField() {
    return Container(
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
              setState(() {
                _flexibilityWindow = Duration(minutes: value.round());
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExpandablePreferences() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.tune, color: const Color(0xFF232F3E)),
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
          onExpansionChanged: (expanded) {
            // Expansion state is managed by ExpansionTile internally
          },
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildPreferenceCard(
                    'Smoking',
                    'Allow smoking in the vehicle',
                    _allowSmoking,
                    (value) => setState(() => _allowSmoking = value),
                  ),
                  const SizedBox(height: 12),
                  _buildPreferenceCard(
                    'Pets',
                    'Allow pets in the vehicle',
                    _allowPets,
                    (value) => setState(() => _allowPets = value),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownCard(
                    'Music Preference',
                    _musicPreference,
                    _musicOptions,
                    (value) => setState(() => _musicPreference = value!),
                    _formatMusicOption,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownCard(
                    'Communication Style',
                    _communicationStyle,
                    _communicationOptions,
                    (value) => setState(() => _communicationStyle = value!),
                    _formatCommunicationOption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceCard(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
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
  }

  Widget _buildDropdownCard(
    String title,
    String value,
    List<String> options,
    Function(String?) onChanged,
    String Function(String) formatter,
  ) {
    return Container(
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
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(formatter(option)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Additional Notes (Optional)',
        hintText: 'Any specific requirements or information...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, child) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: rideProvider.isCreatingRequest ? null : _submitRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE57200),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: rideProvider.isCreatingRequest
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    widget.initialOffer != null ? 'Send Bid' : 'Submit Request',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }

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

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
    final userId = rideProvider.currentUserId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to send a request.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final parsedPrice = double.tryParse(_maxPriceController.text);
    if (parsedPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid price per seat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final rideRequest = RideRequest(
      id: '', // Will be set by Firebase
      requesterId: userId,
      startLocation: _startLocation!,
      endLocation: _endLocation!,
      preferredDepartureTime: _departureTime,
      flexibilityWindow: _flexibilityWindow,
      seatsNeeded: _seatsNeeded,
      maxPricePerSeat: parsedPrice,
      status: RequestStatus.pending,
      matchedOfferId: widget.initialOffer?.id,
      declinedOfferIds: const [],
      preferences: RidePreferences(
        allowSmoking: _allowSmoking,
        allowPets: _allowPets,
        musicPreference: _musicPreference,
        communicationStyle: _communicationStyle,
        preferredGenders: const [], // _preferredGenders commented out for now
        maxPassengers: _seatsNeeded,
      ),
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await rideProvider.createRideRequest(rideRequest);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to home screen (rider tab) instead of staying on searching screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rideProvider.creationError ?? 'Failed to submit request',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatPrice(double price) {
    return price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
  }

  String _formatMusicOption(String option) {
    switch (option) {
      case 'driver_choice':
        return 'Driver\'s Choice';
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
