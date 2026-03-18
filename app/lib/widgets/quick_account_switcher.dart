import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/credential_storage_service.dart';
import '../exceptions/auth_exceptions.dart';
import '../utils/auth_error_handler.dart';

class QuickAccountSwitcher extends StatefulWidget {
  final Function(String email)? onAccountSelected;
  final bool showBiometricOption;

  const QuickAccountSwitcher({
    super.key,
    this.onAccountSelected,
    this.showBiometricOption = true,
  });

  @override
  State<QuickAccountSwitcher> createState() => _QuickAccountSwitcherState();
}

class _QuickAccountSwitcherState extends State<QuickAccountSwitcher> {
  final CredentialStorageService _credentialService = CredentialStorageService();
  List<SavedCredential> _savedCredentials = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final credentials = await _credentialService.getSavedCredentials();
      setState(() {
        _savedCredentials = credentials.take(3).toList(); // Show top 3 recent accounts
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _selectAccount(SavedCredential credential) async {
    if (widget.onAccountSelected == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate biometric authentication if enabled
      if (credential.biometricEnabled && widget.showBiometricOption) {
        // Try biometric authentication first - this validates the user
        await _credentialService.getAuthTokenWithBiometric(credential.uid);
      } else {
        // Check if we have a valid token stored
        final hasValidToken = await _credentialService.isTokenValid(credential.uid);
        if (!hasValidToken) {
          throw const SessionExpiredException();
        }
      }

      // If we get here, authentication was successful
      await _credentialService.updateLastUsed(credential.uid);
      widget.onAccountSelected!(credential.email);
    } catch (e) {
      if (mounted) {
        await AuthErrorHandler.handleAuthError(
          context: context,
          error: e,
          expiredAccountEmail: credential.email,
          onSignIn: () {
            // Navigate to login screen
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

  Widget _buildAccountChip(SavedCredential credential, {bool isCompact = false}) {
    final initials = credential.displayName.isNotEmpty
        ? credential.displayName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase()
        : credential.email[0].toUpperCase();
    
    // Dynamic sizing based on layout
    final avatarRadius = isCompact ? 14.0 : 16.0;
    final fontSize = isCompact ? 11.0 : 12.0;
    final textFontSize = isCompact ? 12.0 : 13.0;
    final horizontalPadding = isCompact ? 10.0 : 12.0;
    final verticalPadding = isCompact ? 6.0 : 8.0;
    final borderRadius = isCompact ? 20.0 : 25.0;

    return InkWell(
      onTap: _isLoading ? null : () => _selectAccount(credential),
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        margin: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: credential.isDefault 
                ? const Color(0xFFE57200) 
                : Colors.white.withValues(alpha: 0.3),
            width: credential.isDefault ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: const Color(0xFFE57200),
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: fontSize,
                    ),
                  ),
                ),
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
                        size: isCompact ? 8 : 10,
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
                        fontSize: isCompact ? 9 : 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_savedCredentials.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final accountCount = _savedCredentials.length;
    
    // Determine layout based on account count and screen width
    final shouldUseCompactLayout = accountCount > 2 || screenWidth < 400;
    final shouldCenterContent = accountCount <= 3;

    Widget accountsRow = Row(
      mainAxisSize: shouldCenterContent ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: shouldCenterContent ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        ..._savedCredentials.map((credential) => _buildAccountChip(
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
        Text(
          'Quick Access',
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: shouldCenterContent ? TextAlign.center : TextAlign.left,
        ),
        const SizedBox(height: 8),
        // Use scrollable for many accounts, centered layout for few
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