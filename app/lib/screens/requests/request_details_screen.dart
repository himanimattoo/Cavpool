import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';
import '../../widgets/address_search_widget.dart';

class RequestDetailsScreen extends StatefulWidget {
  final RideRequest request;
  final bool isEditable;

  const RequestDetailsScreen({
    super.key,
    required this.request,
    this.isEditable = false,
  });

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _maxPriceController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;

  // Form fields
  RideLocation? _startLocation;
  RideLocation? _endLocation;
  DateTime? _departureTime;
  int _seatsNeeded = 1;
  Duration _flexibilityWindow = const Duration(minutes: 30);

  // Preferences
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
    _loadRequestData();
  }

  void _loadRequestData() {
    setState(() {
      _startLocation = widget.request.startLocation;
      _endLocation = widget.request.endLocation;
      _departureTime = widget.request.preferredDepartureTime;
      _seatsNeeded = widget.request.seatsNeeded;
      _flexibilityWindow = widget.request.flexibilityWindow;
      _allowSmoking = widget.request.preferences.allowSmoking;
      _allowPets = widget.request.preferences.allowPets;
      _musicPreference = widget.request.preferences.musicPreference;
      _communicationStyle = widget.request.preferences.communicationStyle;
      _notesController.text = widget.request.notes ?? '';
      _maxPriceController.text = widget.request.maxPricePerSeat.toStringAsFixed(0);
    });
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
          _isEditing ? 'Edit Request' : 'Request Details',
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
        actions: [
          if (widget.isEditable && !_isEditing && widget.request.status == RequestStatus.pending)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              _buildTimestampInfo(),
              if (_isEditing) ...[
                const SizedBox(height: 32),
                _buildActionButtons(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getRequestStatusColor(widget.request.status).withValues(alpha: 0.1),
        border: Border.all(color: _getRequestStatusColor(widget.request.status)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getRequestStatusIcon(widget.request.status),
                color: _getRequestStatusColor(widget.request.status),
              ),
              const SizedBox(width: 8),
              Text(
                'Request Status',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF232F3E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getRequestStatusColor(widget.request.status),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.request.status.name.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
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

  Widget _buildLocationFields() {
    if (_isEditing) {
      return Column(
        children: [
          AddressSearchWidget(
            hintText: 'Pick-up location',
            initialAddress: _startLocation?.address,
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
            hintText: 'Drop-off location',
            initialAddress: _endLocation?.address,
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

    return Column(
      children: [
        _buildInfoTile(
          Icons.my_location,
          'Pick-up Location',
          _startLocation?.address ?? '',
          const Color(0xFFE57200),
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          Icons.location_on,
          'Drop-off Location',
          _endLocation?.address ?? '',
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildDateTimeField() {
    if (_isEditing) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: const Icon(Icons.access_time, color: Color(0xFFE57200)),
          title: const Text('Departure Time'),
          subtitle: Text(
            '${_departureTime!.day}/${_departureTime!.month}/${_departureTime!.year} at ${TimeOfDay.fromDateTime(_departureTime!).format(context)}',
          ),
          trailing: const Icon(Icons.edit),
          onTap: _selectDateTime,
        ),
      );
    }

    return _buildInfoTile(
      Icons.access_time,
      'Departure Time',
      '${_departureTime!.day}/${_departureTime!.month}/${_departureTime!.year} at ${TimeOfDay.fromDateTime(_departureTime!).format(context)}',
      const Color(0xFFE57200),
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
                      const Icon(Icons.person, color: Color(0xFFE57200)),
                      const SizedBox(width: 8),
                      const Text(
                        'Seats Needed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
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
                          '$_seatsNeeded seat${_seatsNeeded > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      if (_isEditing)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _seatsNeeded > 1
                                    ? const Color(0xFFE57200)
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 14,
                                onPressed: _seatsNeeded > 1
                                    ? () => setState(() => _seatsNeeded--)
                                    : null,
                                icon: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _seatsNeeded < 4
                                    ? const Color(0xFFE57200)
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 14,
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
          child: _isEditing
              ? TextFormField(
                  controller: _maxPriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Bid for Ride (per seat)',
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
                )
              : Container(
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
                            const Icon(Icons.attach_money, color: Color(0xFFE57200)),
                            const SizedBox(width: 8),
                            const Text(
                              'Max Price',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${widget.request.maxPricePerSeat.toStringAsFixed(0)} per seat',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
          if (_isEditing)
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
                : 'Using defaults',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _hasNonDefaultPreferences()
                  ? const Color(0xFFE57200)
                  : Colors.grey.shade600,
            ),
          ),
          onExpansionChanged: (expanded) {
            // Handle expansion state if needed
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
                    _isEditing ? (value) => setState(() => _allowSmoking = value) : null,
                  ),
                  const SizedBox(height: 12),
                  _buildPreferenceCard(
                    'Pets',
                    'Allow pets in the vehicle',
                    _allowPets,
                    _isEditing ? (value) => setState(() => _allowPets = value) : null,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownCard(
                    'Music Preference',
                    _musicPreference,
                    _musicOptions,
                    _isEditing ? (value) => setState(() => _musicPreference = value!) : null,
                    _formatMusicOption,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownCard(
                    'Communication Style',
                    _communicationStyle,
                    _communicationOptions,
                    _isEditing ? (value) => setState(() => _communicationStyle = value!) : null,
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
    Function(bool)? onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: onChanged != null
          ? SwitchListTile(
              title: Text(title),
              subtitle: Text(subtitle),
              value: value,
              onChanged: onChanged,
              thumbColor: WidgetStateProperty.all(const Color(0xFFE57200)),
            )
          : ListTile(
              title: Text(title),
              subtitle: Text(subtitle),
              trailing: Switch(
                value: value,
                onChanged: null,
                thumbColor: WidgetStateProperty.all(
                  value ? const Color(0xFFE57200) : Colors.grey,
                ),
              ),
            ),
    );
  }

  Widget _buildDropdownCard(
    String title,
    String value,
    List<String> options,
    Function(String?)? onChanged,
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
        trailing: onChanged != null
            ? DropdownButton<String>(
                value: value,
                onChanged: onChanged,
                items: options.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(formatter(option)),
                  );
                }).toList(),
              )
            : Text(
                formatter(value),
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  Widget _buildNotesField() {
    return _isEditing
        ? TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Additional Notes (Optional)',
              hintText: 'Any specific requirements or information...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        : Container(
            width: double.infinity,
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
                      const Icon(Icons.note, color: Color(0xFFE57200)),
                      const SizedBox(width: 8),
                      Text(
                        'Notes',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.request.notes?.isNotEmpty == true
                        ? widget.request.notes!
                        : 'No additional notes',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: widget.request.notes?.isNotEmpty == true
                          ? Colors.black87
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  Widget _buildTimestampInfo() {
    return Container(
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
            'Request Information',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF232F3E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(
                'Created: ${_formatTimestamp(widget.request.createdAt)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.update, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(
                'Updated: ${_formatTimestamp(widget.request.updatedAt)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE57200),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Save Changes',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isSaving
                ? null
                : () {
                    setState(() => _isEditing = false);
                    _loadRequestData();
                  },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Colors.grey),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateTime() async {
    final dateTime = await showOmniDateTimePicker(
      context: context,
      initialDate: _departureTime!,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (dateTime != null) {
      setState(() {
        _departureTime = dateTime;
      });
    }
  }

  Future<void> _saveChanges() async {
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

    setState(() => _isSaving = true);

    final rideProvider = Provider.of<RideProvider>(context, listen: false);

    final updatedRequest = widget.request.copyWith(
      startLocation: _startLocation,
      endLocation: _endLocation,
      preferredDepartureTime: _departureTime,
      flexibilityWindow: _flexibilityWindow,
      seatsNeeded: _seatsNeeded,
      maxPricePerSeat: double.parse(_maxPriceController.text),
      preferences: RidePreferences(
        allowSmoking: _allowSmoking,
        allowPets: _allowPets,
        musicPreference: _musicPreference,
        communicationStyle: _communicationStyle,
        preferredGenders: [],
        maxPassengers: 4,
      ),
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      updatedAt: DateTime.now(),
    );

    final success = await rideProvider.updateRideRequest(updatedRequest);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rideProvider.updateError ?? 'Failed to update request',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
    }
  }

  Color _getRequestStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Colors.orange;
      case RequestStatus.matched:
        return Colors.blue;
      case RequestStatus.accepted:
        return Colors.green;
      case RequestStatus.declined:
        return Colors.red;
      case RequestStatus.completed:
        return Colors.purple;
      case RequestStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getRequestStatusIcon(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Icons.schedule;
      case RequestStatus.matched:
        return Icons.link;
      case RequestStatus.accepted:
        return Icons.check_circle;
      case RequestStatus.declined:
        return Icons.cancel;
      case RequestStatus.completed:
        return Icons.done_all;
      case RequestStatus.cancelled:
        return Icons.block;
    }
  }
}