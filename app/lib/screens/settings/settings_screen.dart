import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../profile/profile_edit_screen.dart';
import '../testing/integration_test_screen.dart';
import '../testing/test_users_screen.dart';
import '../../widgets/testing/ride_booking_test_widget.dart';
import '../../widgets/testing/location_tracking_test.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            title: 'Account',
            children: [
              _buildSettingItem(
                icon: Icons.person,
                title: 'Profile Settings',
                subtitle: 'Manage your profile information',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileEditScreen(),
                    ),
                  );
                },
              ),
              _buildSettingItem(
                icon: Icons.security,
                title: 'Privacy & Security',
                subtitle: 'Control your privacy settings',
                onTap: () {
                  _showPrivacySettings(context);
                },
              ),
              _buildSettingItem(
                icon: Icons.straighten,
                title: 'Units & Measurements',
                subtitle: 'Choose distance units (feet/miles or metric)',
                onTap: () {
                  _showUnitsSettings(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Notifications',
            children: [
              _buildSettingItem(
                icon: Icons.notifications,
                title: 'Push Notifications',
                subtitle: 'Manage notification preferences',
                onTap: () {
                  _showNotificationSettings(context);
                },
              ),
              _buildSettingItem(
                icon: Icons.email,
                title: 'Email Notifications',
                subtitle: 'Control email notification settings',
                onTap: () {
                  _showEmailSettings(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Support',
            children: [
              _buildSettingItem(
                icon: Icons.help,
                title: 'Help & Support',
                subtitle: 'Get help with your account',
                onTap: () {
                  _showHelpSupport(context);
                },
              ),
              _buildSettingItem(
                icon: Icons.feedback,
                title: 'Send Feedback',
                subtitle: 'Share your thoughts with us',
                onTap: () {
                  _showFeedbackDialog(context);
                },
              ),
              _buildSettingItem(
                icon: Icons.info,
                title: 'About',
                subtitle: 'App version and information',
                onTap: () {
                  // Show about dialog
                  _showAboutDialog(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Developer & Testing',
            children: [
              _buildSettingItem(
                icon: Icons.integration_instructions,
                title: 'Integration Tests',
                subtitle: 'Run automated system tests',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const IntegrationTestScreen(),
                    ),
                  );
                },
              ),
              _buildSettingItem(
                icon: Icons.rocket_launch,
                title: 'Ride Booking Tests',
                subtitle: 'Test ride booking with UVA locations',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RideBookingTestWidget(),
                    ),
                  );
                },
              ),
              _buildSettingItem(
                icon: Icons.location_on,
                title: 'Location Tracking Test',
                subtitle: 'Test GPS and location sharing features',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LocationTrackingTest(),
                    ),
                  );
                },
              ),
              _buildSettingItem(
                icon: Icons.people,
                title: 'Test Users',
                subtitle: 'Manage test user accounts',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TestUsersScreen(),
                    ),
                  );
                },
              ),
              _buildSettingItem(
                icon: Icons.refresh,
                title: 'Force Token Refresh',
                subtitle: 'Force refresh authentication token',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final authService = AuthService();
                    await authService.forceTokenRefresh();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Token refreshed successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Token refresh failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Account Actions',
            children: [
              _buildSettingItem(
                icon: Icons.logout,
                title: 'Sign Out',
                subtitle: 'Sign out of your account',
                onTap: () async {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  try {
                    await authProvider.signOut();
                    // AuthWrapper will automatically handle navigation
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error signing out: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF232F3E),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : const Color(0xFF232F3E),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'UVA Cavpool',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version 1.0.1',
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 8),
            Text(
              'A safe and convenient rideshare platform for the UVA community.',
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2025 UVA Cavpool Team',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacySettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Privacy & Security',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrivacyOption('Profile Visibility', 'UVA Community Only'),
            const SizedBox(height: 12),
            _buildPrivacyOption('Contact Information', 'Ride Participants Only'),
            const SizedBox(height: 12),
            _buildPrivacyOption('Ride History', 'Private'),
            const SizedBox(height: 16),
            Text(
              'Your data is encrypted and only shared with verified UVA community members for safety purposes.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption(String title, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Push Notifications',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotificationOption('Ride Requests', true),
            _buildNotificationOption('Ride Updates', true),
            _buildNotificationOption('Messages', true),
            _buildNotificationOption('Safety Alerts', true),
            _buildNotificationOption('Promotions', false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationOption(String title, bool isEnabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(),
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: (value) {
              // Handle notification toggle
            },
            activeTrackColor: const Color(0xFFE57200),
          ),
        ],
      ),
    );
  }

  void _showEmailSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Email Notifications',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotificationOption('Weekly Summary', true),
            _buildNotificationOption('Ride Confirmations', true),
            _buildNotificationOption('Safety Updates', true),
            _buildNotificationOption('Newsletter', false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpOption(context, Icons.help_outline, 'FAQ', 'Common questions and answers'),
            _buildHelpOption(context, Icons.security, 'Safety Guidelines', 'Stay safe while carpooling'),
            _buildHelpOption(context, Icons.contact_support, 'Contact Support', 'Get help from our team'),
            _buildHelpOption(context, Icons.report_problem, 'Report Issue', 'Report safety concerns'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpOption(BuildContext context, IconData icon, String title, String description) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF232F3E)),
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        description,
        style: GoogleFonts.inter(fontSize: 12),
      ),
      onTap: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title feature coming soon!')),
        );
      },
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Send Feedback',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Help us improve UVA Cavpool by sharing your thoughts!',
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Tell us what you think...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE57200),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showUnitsSettings(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUnits = authProvider.userModel?.preferences.preferredUnits ?? DistanceUnit.imperial;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Units & Measurements',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            DistanceUnit selectedUnits = currentUnits;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose how distances are displayed in the app',
                  style: GoogleFonts.inter(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                RadioGroup<DistanceUnit>(
                  groupValue: selectedUnits,
                  onChanged: (DistanceUnit? value) async {
                    if (value != null && context.mounted) {
                      setState(() {
                        selectedUnits = value;
                      });
                      await _updateUnitsPreference(context, value);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<DistanceUnit>(
                        title: const Text('Imperial (feet, miles)'),
                        subtitle: const Text('Example: 1.2 mi, 500 ft'),
                        value: DistanceUnit.imperial,
                      ),
                      RadioListTile<DistanceUnit>(
                        title: const Text('Metric (meters, kilometers)'),
                        subtitle: const Text('Example: 1.9 km, 150 m'),
                        value: DistanceUnit.metric,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUnitsPreference(BuildContext context, DistanceUnit newUnits) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.userModel != null) {
      final updatedPreferences = UserPreferences(
        allowSmoking: authProvider.userModel!.preferences.allowSmoking,
        allowPets: authProvider.userModel!.preferences.allowPets,
        musicPreference: authProvider.userModel!.preferences.musicPreference,
        maxDetourTime: authProvider.userModel!.preferences.maxDetourTime,
        communicationStyle: authProvider.userModel!.preferences.communicationStyle,
        defaultSeatsNeeded: authProvider.userModel!.preferences.defaultSeatsNeeded,
        defaultFlexibilityMinutes: authProvider.userModel!.preferences.defaultFlexibilityMinutes,
        preferredUnits: newUnits,
      );

      await authProvider.updateUserData({
        'preferences': updatedPreferences.toMap(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Units preference updated to ${newUnits == DistanceUnit.imperial ? 'Imperial' : 'Metric'}'),
            backgroundColor: const Color(0xFF232F3E),
          ),
        );
      }
    }
  }
}