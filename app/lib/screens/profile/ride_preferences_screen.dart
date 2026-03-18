import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

class RidePreferencesScreen extends StatefulWidget {
  const RidePreferencesScreen({super.key});

  @override
  State<RidePreferencesScreen> createState() => _RidePreferencesScreenState();
}

class _RidePreferencesScreenState extends State<RidePreferencesScreen> {
  // Preferences
  bool _allowSmoking = false;
  bool _allowPets = false;
  String _musicPreference = 'driver_choice';
  String _communicationStyle = 'friendly';
  // final List<String> _preferredGenders = []; // Commented out for now
  int _defaultSeatsNeeded = 1;
  int _defaultFlexibilityMinutes = 30;

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

  // final List<String> _genderOptions = [ // Commented out for now
  //   'Male',
  //   'Female', 
  //   'Non-binary',
  //   'No preference',
  // ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPreferences();
  }

  void _loadCurrentPreferences() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userModel != null) {
      final prefs = authProvider.userModel!.preferences;
      setState(() {
        _allowSmoking = prefs.allowSmoking;
        _allowPets = prefs.allowPets;
        
        // Ensure music preference is valid, fallback to default if not
        _musicPreference = _musicOptions.contains(prefs.musicPreference) 
            ? prefs.musicPreference 
            : 'driver_choice';
            
        // Ensure communication style is valid, fallback to default if not
        _communicationStyle = _communicationOptions.contains(prefs.communicationStyle)
            ? prefs.communicationStyle
            : 'friendly';
            
        // _preferredGenders.clear(); // Commented out for now
        // _preferredGenders.addAll(prefs.preferredGenders); // Commented out for now
        _defaultSeatsNeeded = prefs.defaultSeatsNeeded;
        _defaultFlexibilityMinutes = prefs.defaultFlexibilityMinutes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Ride Preferences',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF232F3E), // UVA Navy
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _savePreferences,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Default Ride Settings',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF232F3E),
              ),
            ),
            const SizedBox(height: 16),

            // Default seats needed
            _buildNumberPicker(
              'Default seats needed',
              _defaultSeatsNeeded,
              1,
              4,
              (value) => setState(() => _defaultSeatsNeeded = value),
            ),
            const SizedBox(height: 16),

            // Default flexibility
            _buildFlexibilityPicker(),
            const SizedBox(height: 24),

            Text(
              'Ride Preferences',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF232F3E),
              ),
            ),
            const SizedBox(height: 16),

            // Smoking preference
            _buildSwitchTile(
              'Allow smoking',
              _allowSmoking,
              (value) => setState(() => _allowSmoking = value),
            ),

            // Pets preference
            _buildSwitchTile(
              'Allow pets',
              _allowPets,
              (value) => setState(() => _allowPets = value),
            ),

            const SizedBox(height: 16),

            // Music preference
            _buildDropdown(
              'Music preference',
              _musicPreference,
              _musicOptions,
              (value) => setState(() => _musicPreference = value!),
              _formatMusicOption,
            ),
            const SizedBox(height: 16),

            // Communication style
            _buildDropdown(
              'Communication style',
              _communicationStyle,
              _communicationOptions,
              (value) => setState(() => _communicationStyle = value!),
              _formatCommunicationOption,
            ),
            const SizedBox(height: 16),

            // Preferred genders - Commented out for now
            // _buildMultiSelect(
            //   'Preferred driver genders',
            //   _genderOptions,
            //   _preferredGenders,
            // ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPicker(
    String label,
    int value,
    int min,
    int max,
    Function(int) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: const Color(0xFF232F3E),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value.toString(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
              color: const Color(0xFF232F3E),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlexibilityPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Default flexibility window',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _defaultFlexibilityMinutes,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [15, 30, 45, 60, 90, 120].map((minutes) {
            return DropdownMenuItem(
              value: minutes,
              child: Text('$minutes minutes'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _defaultFlexibilityMinutes = value!);
          },
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFE57200), // UVA Orange
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
    String label,
    T value,
    List<T> items,
    Function(T?) onChanged,
    String Function(T) formatter,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(formatter(item)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // Commented out for now - preferred genders functionality
  // Widget _buildMultiSelect(String label, List<String> options, List<String> selected) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         label,
  //         style: GoogleFonts.inter(
  //           fontSize: 16,
  //           fontWeight: FontWeight.w500,
  //         ),
  //       ),
  //       const SizedBox(height: 8),
  //       Wrap(
  //         spacing: 8,
  //         runSpacing: 8,
  //         children: options.map((option) {
  //           final isSelected = selected.contains(option);
  //           return FilterChip(
  //             label: Text(option),
  //             selected: isSelected,
  //             onSelected: (selected) {
  //               setState(() {
  //                 if (selected) {
  //                   _preferredGenders.add(option);
  //                 } else {
  //                   _preferredGenders.remove(option);
  //                 }
  //               });
  //             },
  //             selectedColor: const Color(0xFFE57200).withValues(alpha: 0.2),
  //             checkmarkColor: const Color(0xFF232F3E),
  //           );
  //         }).toList(),
  //       ),
  //     ],
  //   );
  // }

  String _formatMusicOption(String option) {
    switch (option) {
      case 'driver_choice':
        return 'Driver\'s choice';
      case 'no_music':
        return 'No music';
      case 'hip_hop':
        return 'Hip Hop';
      default:
        return option[0].toUpperCase() + option.substring(1);
    }
  }

  String _formatCommunicationOption(String option) {
    return option[0].toUpperCase() + option.substring(1);
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userModel != null) {
        final currentUser = authProvider.userModel!;
        
        final updatedPreferences = UserPreferences(
          allowSmoking: _allowSmoking,
          allowPets: _allowPets,
          musicPreference: _musicPreference,
          maxDetourTime: currentUser.preferences.maxDetourTime, // Keep existing
          communicationStyle: _communicationStyle,
          // preferredGenders: _preferredGenders, // Commented out for now
          defaultSeatsNeeded: _defaultSeatsNeeded,
          defaultFlexibilityMinutes: _defaultFlexibilityMinutes,
          preferredUnits: currentUser.preferences.preferredUnits, // Keep existing
        );

        // Update user preferences in auth provider
        await authProvider.updateUserData({
          'preferences': updatedPreferences.toMap(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ride preferences saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
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