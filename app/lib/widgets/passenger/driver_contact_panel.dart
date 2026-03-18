import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';

class DriverContactPanel extends StatelessWidget {
  final UserModel driver;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  const DriverContactPanel({
    super.key,
    required this.driver,
    required this.onCall,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Driver',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              // Driver Avatar
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.blue[100],
                backgroundImage: driver.profile.photoURL.isNotEmpty
                    ? NetworkImage(driver.profile.photoURL)
                    : null,
                child: driver.profile.photoURL.isEmpty
                    ? Text(
                        driver.profile.displayName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              
              const SizedBox(width: 16),
              
              // Driver Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.profile.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    
                    // Rating
                    if (driver.ratings.asDriver.averageRating > 0)
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${driver.ratings.asDriver.averageRating.toStringAsFixed(1)} (${driver.ratings.asDriver.totalRatings} rides)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    
                    // Vehicle Info (if available)
                    if (driver.profile.bio.isNotEmpty)
                      Text(
                        driver.profile.bio,
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
              
              // Contact Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildContactButton(
                    icon: Icons.phone,
                    color: Colors.green,
                    onTap: onCall,
                  ),
                  const SizedBox(width: 8),
                  _buildContactButton(
                    icon: Icons.message,
                    color: Colors.blue,
                    onTap: onMessage,
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Driver Preferences & Safety Info
          _buildDriverInfo(),
        ],
      ),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          icon,
          size: 20,
          color: color.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildDriverInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.verified_user,
            label: 'Verified Driver',
            value: 'UVA Student',
            color: Colors.green,
          ),
          
          const SizedBox(height: 8),
          
          _buildInfoRow(
            icon: Icons.security,
            label: 'Safety Score',
            value: '5.0/5.0',
            color: Colors.blue,
          ),
          
          const SizedBox(height: 8),
          
          _buildPreferenceChips(),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceChips() {
    final preferences = <String>[];
    
    // Add preferences based on driver settings
    if (!driver.preferences.allowSmoking) {
      preferences.add('No Smoking');
    }
    if (driver.preferences.allowPets) {
      preferences.add('Pet Friendly');
    }
    if (driver.preferences.musicPreference.isNotEmpty) {
      preferences.add(driver.preferences.musicPreference);
    }
    
    if (preferences.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: preferences.map((pref) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          pref,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.blue[700],
          ),
        ),
      )).toList(),
    );
  }
}