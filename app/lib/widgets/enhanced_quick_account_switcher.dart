import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/credential_storage_service.dart';
import '../utils/auth_error_handler.dart';

class EnhancedQuickAccountSwitcher extends StatefulWidget {
  final Function(String email)? onAccountSelected;
  final bool showBiometricOption;

  const EnhancedQuickAccountSwitcher({
    super.key,
    this.onAccountSelected,
    this.showBiometricOption = true,
  });

  @override
  State<EnhancedQuickAccountSwitcher> createState() => _EnhancedQuickAccountSwitcherState();
}

class _EnhancedQuickAccountSwitcherState extends State<EnhancedQuickAccountSwitcher> {
  final CredentialStorageService _credentialService = CredentialStorageService();
  List<SavedCredential> _savedCredentials = [];
  List<SavedCredential> _smartSuggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final credentials = await _credentialService.getSavedCredentials();
      final suggestions = _getSmartSuggestions(credentials);
      setState(() {
        _savedCredentials = credentials.take(4).toList(); // Show top 4 accounts
        _smartSuggestions = suggestions;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  List<SavedCredential> _getSmartSuggestions(List<SavedCredential> allCredentials) {
    final now = DateTime.now();
    final timeOfDay = now.hour;
    
    // Smart suggestions based on time and usage patterns
    final List<SavedCredential> suggestions = [];
    
    for (final credential in allCredentials) {
      final lastUsed = DateTime.parse(credential.lastUsed);
      final daysSinceUsed = now.difference(lastUsed).inDays;
      
      // Prioritize based on various factors
      int score = 0;
      
      // Recency score (more recent = higher score)
      if (daysSinceUsed == 0) {
        score += 10;
      } else if (daysSinceUsed <= 1) {
        score += 8;
      } else if (daysSinceUsed <= 7) {
        score += 5;
      }
      
      // Time-based suggestions for work/school hours
      if (timeOfDay >= 8 && timeOfDay <= 18) {
        score += 2; // Bonus during typical work/school hours
      }
      
      // Default account gets bonus
      if (credential.isDefault) {
        score += 3;
      }
      
      // Biometric accounts are more convenient
      if (credential.biometricEnabled) {
        score += 2;
      }
      
      if (score >= 5) {
        suggestions.add(credential);
      }
    }
    
    // Sort by score (we'd need to track scores separately in a real implementation)
    return suggestions.take(3).toList();
  }

  Future<void> _selectAccount(SavedCredential credential) async {
    if (widget.onAccountSelected == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // For automatic sign-in, we need to check if user still has valid Firebase auth
      // If they have biometric enabled, use that for verification
      if (credential.biometricEnabled && widget.showBiometricOption) {
        final token = await _credentialService.getAuthTokenWithBiometric(credential.uid);
        if (token != null) {
          // Biometric auth successful - try automatic sign-in
          await _attemptAutomaticSignIn(credential);
          return;
        }
      } else {
        // Check if we have valid stored token
        final hasValidToken = await _credentialService.isTokenValid(credential.uid);
        if (hasValidToken) {
          // Try automatic sign-in
          final success = await _attemptAutomaticSignIn(credential);
          if (success) {
            return;
          }
        }
      }

      // If automatic sign-in fails, fall back to manual entry
      await _credentialService.updateLastUsed(credential.uid);
      widget.onAccountSelected!(credential.email);
    } catch (e) {
      if (mounted) {
        await AuthErrorHandler.handleAuthError(
          context: context,
          error: e,
          expiredAccountEmail: credential.email,
          onSignIn: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          },
          onSwitchAccount: () async {
            await _loadSavedCredentials();
          },
          onRetry: () => _selectAccount(credential),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _attemptAutomaticSignIn(SavedCredential credential) async {
    try {
      // Check if Firebase already has this user signed in
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null && currentUser.uid == credential.uid) {
        // User is already signed in with Firebase
        await _credentialService.updateLastUsed(credential.uid);
        
        if (mounted) {
          // Navigate to home screen directly since user is authenticated
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
        return true;
      }

      // If user is not currently signed in with Firebase, check if we can refresh their auth
      // This would require implementing custom token refresh logic
      // For now, fall back to manual sign-in
      return false;
    } catch (e) {
      return false;
    }
  }

  Widget _buildAccountAvatar(SavedCredential credential, {double radius = 16.0}) {
    if (credential.profilePictureUrl != null && credential.profilePictureUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(credential.profilePictureUrl!),
        backgroundColor: const Color(0xFFE57200),
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback to initials if image fails to load
        },
        child: credential.profilePictureUrl == null ? _buildInitialsWidget(credential, radius) : null,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE57200),
      child: _buildInitialsWidget(credential, radius),
    );
  }

  Widget _buildInitialsWidget(SavedCredential credential, double radius) {
    final initials = credential.displayName.isNotEmpty
        ? credential.displayName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase()
        : credential.email[0].toUpperCase();
    
    return Text(
      initials,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: radius * 0.7,
      ),
    );
  }

  Widget _buildAccountChip(SavedCredential credential, {bool isCompact = false}) {
    final avatarRadius = isCompact ? 14.0 : 18.0;
    final textFontSize = isCompact ? 11.0 : 13.0;
    final horizontalPadding = isCompact ? 8.0 : 12.0;
    final verticalPadding = isCompact ? 6.0 : 8.0;
    final borderRadius = isCompact ? 18.0 : 22.0;

    return GestureDetector(
      onTap: _isLoading ? null : () => _selectAccount(credential),
      onLongPress: () => _showAccountPreview(credential),
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          margin: EdgeInsets.symmetric(horizontal: isCompact ? 3 : 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: credential.isDefault 
                  ? const Color(0xFFE57200) 
                  : Colors.white.withValues(alpha: 0.3),
              width: credential.isDefault ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  _buildAccountAvatar(credential, radius: avatarRadius),
                  // Biometric indicator
                  if (credential.biometricEnabled && widget.showBiometricOption)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fingerprint,
                          size: isCompact ? 6 : 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: isCompact ? 6 : 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credential.displayName.isNotEmpty
                          ? credential.displayName
                          : credential.email.split('@')[0],
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: textFontSize,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (credential.isDefault)
                      Text(
                        'Default',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE57200),
                          fontSize: isCompact ? 8 : 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountPreview(SavedCredential credential) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AccountPreviewSheet(
        credential: credential,
        onSignIn: () {
          Navigator.pop(context);
          _selectAccount(credential);
        },
        onSetDefault: () async {
          Navigator.pop(context);
          await _credentialService.setDefaultAccount(credential.uid);
          await _loadSavedCredentials();
        },
        onRemove: () async {
          Navigator.pop(context);
          await _credentialService.removeCredentials(credential.uid);
          await _loadSavedCredentials();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allAccounts = [
      ..._smartSuggestions,
      ..._savedCredentials.where((c) => !_smartSuggestions.any((s) => s.uid == c.uid))
    ].take(4).toList();

    if (allAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final accountCount = allAccounts.length;
    final shouldUseCompactLayout = accountCount > 3 || screenWidth < 400;
    final shouldCenterContent = accountCount <= 3;

    Widget accountsRow = Row(
      mainAxisSize: shouldCenterContent ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: shouldCenterContent ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        ...allAccounts.map((credential) => _buildAccountChip(
          credential, 
          isCompact: shouldUseCompactLayout,
        )),
        if (_isLoading)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: shouldUseCompactLayout ? 12 : 16, 
              vertical: shouldUseCompactLayout ? 8 : 12,
            ),
            child: SizedBox(
              width: shouldUseCompactLayout ? 14 : 16,
              height: shouldUseCompactLayout ? 14 : 16,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFE57200),
              ),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        shouldCenterContent
            ? Center(child: accountsRow)
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: accountsRow,
              ),
      ],
    );
  }
}

class AccountPreviewSheet extends StatelessWidget {
  final SavedCredential credential;
  final VoidCallback onSignIn;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  const AccountPreviewSheet({
    super.key,
    required this.credential,
    required this.onSignIn,
    required this.onSetDefault,
    required this.onRemove,
  });

  Widget _buildAccountAvatar() {
    if (credential.profilePictureUrl != null && credential.profilePictureUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundImage: NetworkImage(credential.profilePictureUrl!),
        backgroundColor: const Color(0xFFE57200),
      );
    }
    
    final initials = credential.displayName.isNotEmpty
        ? credential.displayName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase()
        : credential.email[0].toUpperCase();
    
    return CircleAvatar(
      radius: 30,
      backgroundColor: const Color(0xFFE57200),
      child: Text(
        initials,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastUsed = DateTime.parse(credential.lastUsed);
    final timeAgo = _getTimeAgoString(lastUsed);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          _buildAccountAvatar(),
          const SizedBox(height: 16),
          Text(
            credential.displayName.isNotEmpty ? credential.displayName : credential.email.split('@')[0],
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            credential.email,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (credential.biometricEnabled)
                _buildInfoChip('BIOMETRIC', Colors.green.shade100, Colors.green.shade700),
              if (credential.isDefault) ...[
                if (credential.biometricEnabled) const SizedBox(width: 8),
                _buildInfoChip('DEFAULT', Colors.orange.shade100, Colors.orange.shade700),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Last used: $timeAgo',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRemove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: Text(
                    'Remove',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!credential.isDefault) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSetDefault,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE57200),
                      side: const BorderSide(color: Color(0xFFE57200)),
                    ),
                    child: Text(
                      'Set Default',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: credential.isDefault ? 2 : 1,
                child: ElevatedButton(
                  onPressed: onSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57200),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _getTimeAgoString(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}