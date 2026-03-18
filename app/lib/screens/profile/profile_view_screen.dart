import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../models/driver_verification_model.dart';
import '../../widgets/profile_avatar_widget.dart';
import 'profile_edit_screen.dart';
import '../driver/driver_verification_screen.dart';
import 'user_reviews_screen.dart';

class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  void _loadProfile() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    
    // Only load profile from ProfileProvider if AuthProvider doesn't have user data
    if (authProvider.user != null && authProvider.userModel == null) {
      profileProvider.loadUserProfile(authProvider.user!.uid);
    }
  }

  String _getAccountTypeDisplay(String accountType) {
    switch (accountType) {
      case 'rider':
        return 'Rider';
      case 'driver':
        return 'Driver';
      case 'both':
        return 'Rider & Driver';
      default:
        return 'Unknown';
    }
  }

  Color _getVerificationStatusColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.pending:
        return Colors.orange;
      case VerificationStatus.underReview:
        return Colors.blue;
      case VerificationStatus.approved:
        return Colors.green;
      case VerificationStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getVerificationStatusIcon(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.pending:
        return Icons.schedule;
      case VerificationStatus.underReview:
        return Icons.hourglass_empty;
      case VerificationStatus.approved:
        return Icons.check_circle;
      case VerificationStatus.rejected:
        return Icons.cancel;
    }
  }

  void _showDriverAccountTypeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Switch to Driver Account'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Switching to a Driver account requires verification and comes with additional responsibilities.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Driver requirements:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Valid driver\'s license'),
              Text('• Vehicle registration and insurance'),
              Text('• Background check completion'),
              Text('• Vehicle safety inspection'),
              SizedBox(height: 16),
              Text(
                'Are you sure you want to proceed with switching to a Driver account?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DriverVerificationScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF232F3E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProfileEditScreen(),
                ),
              );
            },
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Sign Out'),
                    onTap: () async {
                      await authProvider.signOut();
                      // AuthWrapper will automatically handle navigation
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer2<AuthProvider, UserProfileProvider>(
        builder: (context, authProvider, profileProvider, child) {
          // Check if user is authenticated
          if (authProvider.user == null) {
            return const Center(
              child: Text('Please sign in to view your profile.'),
            );
          }

          // Show loading while data is being fetched
          if (authProvider.isLoading || profileProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // If we have a user but no user model, show error with retry option
          if (authProvider.userModel == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load profile data.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This might be a new account that needs setup.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
                      
                      try {
                        // First try to reload user data from AuthProvider
                        await authProvider.reloadUserData();
                        
                        // If that doesn't work, try ProfileProvider
                        if (authProvider.userModel == null) {
                          await profileProvider.loadUserProfile(authProvider.user!.uid);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error loading profile: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF232F3E),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final user = authProvider.userModel!;

          return RefreshIndicator(
            onRefresh: () async {
              await profileProvider.loadUserProfile(user.uid);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  Center(
                    child: Column(
                      children: [
                        ProfileAvatarWidget(
                          photoUrl: user.profile.photoURL,
                          radius: 60,
                          fallbackText: user.profile.displayName.isNotEmpty 
                              ? user.profile.displayName 
                              : user.email,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.profile.displayName.isNotEmpty 
                              ? user.profile.displayName 
                              : '${user.profile.firstName} ${user.profile.lastName}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user.profile.pronouns.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.profile.pronouns,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF232F3E),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getAccountTypeDisplay(user.accountType),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Show driver verification status if user is a driver
                        if (user.accountType == 'driver' && user.driverVerificationStatus != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getVerificationStatusColor(user.driverVerificationStatus!),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getVerificationStatusIcon(user.driverVerificationStatus!),
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  user.driverVerificationStatus!.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Show vehicle info if user is a verified driver
                        if (user.accountType == 'driver' && user.vehicleInfo != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_car, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    user.vehicleInfo!.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  user.vehicleInfo!.licensePlate,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // If user is currently a Rider, show a button to request driver verification
                        if (user.accountType == 'rider') ...[
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: profileProvider.isLoading
                                ? null
                                : () => _showDriverAccountTypeDialog(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE57200),
                            ),
                            child: const Text('Become Driver'),
                          ),
                        ],
                        if (user.isVerified) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.green[600], size: 20),
                              const SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bio Section
                  if (user.profile.bio.isNotEmpty) ...[
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.profile.bio,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Contact Information
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.email,
                    title: 'Email',
                    value: user.email,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    icon: Icons.phone,
                    title: 'Phone',
                    value: user.profile.phoneNumber.isNotEmpty 
                        ? user.profile.phoneNumber 
                        : 'Not provided',
                  ),
                  const SizedBox(height: 24),

                  // Ratings Section
                  const Text(
                    'Ratings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRatingCard(
                          title: 'Overall Rating',
                          rating: user.ratings.averageRating,
                          count: user.ratings.totalRatings,
                          onTap: () => _navigateToReviews(user),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildRatingCard(
                          title: 'As ${user.accountType == 'driver' ? 'Driver' : 'Rider'}',
                          rating: user.accountType == 'driver' 
                              ? user.ratings.asDriver.averageRating
                              : user.ratings.asRider.averageRating,
                          count: user.accountType == 'driver'
                              ? user.ratings.asDriver.totalRatings
                              : user.ratings.asRider.totalRatings,
                          onTap: () => _navigateToReviews(user),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Member Since
                  const Text(
                    'Member Since',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.createdAt != null 
                        ? '${user.createdAt!.month}/${user.createdAt!.year}'
                        : 'Unknown',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF232F3E)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToReviews(dynamic user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserReviewsScreen(user: user),
      ),
    );
  }

  Widget _buildRatingCard({
    required String title,
    required double rating,
    required int count,
    VoidCallback? onTap,
  }) {
    Widget cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.star,
                color: rating > 0 ? Colors.amber : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$count ${count == 1 ? 'rating' : 'ratings'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );

    return onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: cardContent,
          )
        : cardContent;
  }
}