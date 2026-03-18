import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/profile_avatar_widget.dart';
import '../../widgets/notification_widgets.dart';
import '../../models/notification_model.dart';
import '../../services/local_notification_service.dart';
import '../profile/profile_view_screen.dart';
import '../profile/ride_preferences_screen.dart';
// Rider tab now shows driver offers
import '../rider/offers_list_screen.dart';
// Driver tab (two-pane + FAB -> post form)
import '../driver/driver_tab_screen.dart';
// Active/Profile/etc
import '../settings/settings_screen.dart';
import '../driver/driver_verification_screen.dart';
import '../driver/driver_requests_screen.dart';
import '../rides/ride_history_screen.dart';
import '../rides/active_tab_screen.dart';
import '../testing/test_users_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _showArchived = false;

  // Now only 4 tabs total: Rider, Driver, Active, Profile
  List<Widget> get _screens => [
        OffersListScreen(), // 0: Rider
        const DriverTabScreen(),                         // 1: Driver
        const ActiveTabScreen(),                         // 2: Active
        const ProfileTab(),                              // 3: Profile
      ];


  // Get appropriate title for each tab
  String get _currentTabTitle {
    switch (_selectedIndex) {
      case 0:
        return 'Find Rides';
      case 1:
        return 'Driver Dashboard';
      case 2:
        return 'Active Rides';
      case 3:
        return 'Profile';
      default:
        return 'Cavpool';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, NotificationProvider>(
      builder: (context, authProvider, notificationProvider, child) {
        // Initialize notifications for the current user
        final userId = authProvider.user?.uid;
        if (userId != null && notificationProvider.currentUserId != userId) {
          notificationProvider.initializeForUser(userId);
        }

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 60,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIndex = 3; // Navigate to profile tab
                      });
                    },
                    child: ProfileAvatarWidget(
                      photoUrl: authProvider.userModel?.profile.photoURL,
                      radius: 18,
                      fallbackText: authProvider.userModel?.profile.displayName ?? 'U',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hi, ${authProvider.userModel?.profile.firstName ?? 'there'}!',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _currentTabTitle,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF232F3E), Color(0xFF1A252F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 2,
        shadowColor: Colors.black26,
        // Actions based on selected tab
        actions: _selectedIndex == 0
            ? [
                // Archive toggle for Find Rides tab
                IconButton(
                  icon: Icon(
                    _showArchived ? Icons.unarchive : Icons.archive,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _showArchived = !_showArchived;
                    });
                  },
                  tooltip: _showArchived ? 'Show Active' : 'Show Archived',
                ),
              ]
            : _selectedIndex == 1
                ? [
                    // Notifications for My Rides (Driver) tab
                    NotificationBadge(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                      },
                      child: IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ]
                : null,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE57200), // UVA Orange
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '', // Empty but required
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: '', // Empty but required
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_taxi),
            label: '', // Empty but required
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '', // Empty but required
          ),
        ],
      ),
        );
      },
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final userModel = authProvider.userModel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF232F3E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ProfileAvatarWidget(
                  photoUrl: userModel?.profile.photoURL,
                  radius: 40,
                  fallbackText: userModel?.profile.displayName ?? user?.email,
                ),
                const SizedBox(height: 12),
                Text(
                  userModel?.profile.displayName ?? 'UVA Student',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  user?.email ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE57200),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    userModel?.accountType.toUpperCase() ?? 'RIDER',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Menu Items
          _buildMenuItem(
            icon: Icons.person,
            title: 'View Profile',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProfileViewScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.tune,
            title: 'Ride Preferences',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RidePreferencesScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.car_rental,
            title: 'Become a Driver',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DriverVerificationScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.notification_important,
            title: 'Driver Requests',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DriverRequestsScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.history,
            title: 'Ride History',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RideHistoryScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.bug_report,
            title: 'Test Users (Dev)',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TestUsersScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.notifications_active,
            title: 'Test Notifications',
            onTap: () => _testNotifications(context),
          ),
          _buildMenuItem(
            icon: Icons.add_alert,
            title: 'Add Sample Notifications',
            onTap: () => _addSampleNotifications(context),
          ),

          const SizedBox(height: 32),
          // Sign Out Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await authProvider.signOut();
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Sign Out',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF232F3E)),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _testNotifications(BuildContext context) async {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    
    if (userId == null) return;
    
    // Create a test ride request notification
    final testNotification = AppNotification(
      id: '',
      userId: userId,
      type: NotificationType.newRideRequest,
      title: 'Test Ride Request',
      message: 'John Doe wants a ride from Grounds to Downtown',
      priority: NotificationPriority.high,
      isActionable: true,
      actionText: 'View Request',
      createdAt: DateTime.now(),
    );
    
    await notificationProvider.createNotification(testNotification);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification created!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _addSampleNotifications(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    
    if (userId == null) return;
    
    // Force local mode
    notificationProvider.enableLocalMode();
    
    // Add sample notifications via local service
    LocalNotificationService().addSampleNotifications(userId);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample notifications added! Switch to My Rides tab to see them.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
