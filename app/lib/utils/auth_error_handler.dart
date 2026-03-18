import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../exceptions/auth_exceptions.dart';
import '../services/credential_storage_service.dart';

class AuthErrorHandler {
  static const Color _primaryColor = Color(0xFFE57200); // UVA Orange
  static const Color _navyColor = Color(0xFF232F3E); // UVA Navy

  /// Shows an appropriate error dialog or snackbar based on the exception type
  static Future<void> handleAuthError({
    required BuildContext context,
    required dynamic error,
    VoidCallback? onRetry,
    VoidCallback? onSignIn,
    VoidCallback? onSwitchAccount,
    String? expiredAccountEmail,
  }) async {
    if (!context.mounted) return;

    if (error is AuthException) {
      // Handle session expiry specially - remove from quick access and populate email
      if (error.type == AuthExceptionType.sessionExpired && expiredAccountEmail != null) {
        await _handleSessionExpiry(
          context: context,
          expiredEmail: expiredAccountEmail,
          onSignIn: onSignIn,
        );
      } else {
        await _showAuthErrorDialog(
          context: context,
          exception: error,
          onRetry: onRetry,
          onSignIn: onSignIn,
          onSwitchAccount: onSwitchAccount,
        );
      }
    } else {
      // Fallback for generic errors
      _showErrorSnackbar(
        context: context,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Shows a user-friendly error dialog with appropriate actions
  static Future<void> _showAuthErrorDialog({
    required BuildContext context,
    required AuthException exception,
    VoidCallback? onRetry,
    VoidCallback? onSignIn,
    VoidCallback? onSwitchAccount,
  }) async {
    final IconData icon;
    final Color iconColor;
    final String title;
    final List<Widget> actions;

    switch (exception.type) {
      case AuthExceptionType.sessionExpired:
        icon = Icons.timer_off;
        iconColor = Colors.orange;
        title = 'Session Expired';
        actions = [
          if (onSwitchAccount != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onSwitchAccount();
              },
              child: Text(
                'Switch Account',
                style: GoogleFonts.inter(color: Colors.grey.shade600),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSignIn?.call();
            },
            child: Text(
              'Sign In',
              style: GoogleFonts.inter(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ];
        break;

      case AuthExceptionType.accountNotFound:
        icon = Icons.person_off;
        iconColor = Colors.red;
        title = 'Account Not Found';
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSignIn?.call();
            },
            child: Text(
              'Sign In',
              style: GoogleFonts.inter(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ];
        break;

      case AuthExceptionType.biometricFailed:
        icon = Icons.fingerprint_outlined;
        iconColor = Colors.amber;
        title = 'Authentication Failed';
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(
                'Try Again',
                style: GoogleFonts.inter(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSignIn?.call();
            },
            child: Text(
              'Use Password',
              style: GoogleFonts.inter(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ];
        break;

      default:
        icon = Icons.error_outline;
        iconColor = Colors.red;
        title = 'Authentication Error';
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(
                'Try Again',
                style: GoogleFonts.inter(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ];
        break;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: _navyColor,
                ),
              ),
            ],
          ),
          content: Text(
            exception.userFriendlyMessage,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: Colors.grey.shade700,
            ),
          ),
          actions: actions,
        );
      },
    );
  }

  /// Shows a simple error snackbar for non-critical errors
  static void _showErrorSnackbar({
    required BuildContext context,
    required String message,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Shows a success message
  static void showSuccessMessage({
    required BuildContext context,
    required String message,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Handles session expiry by removing expired account and redirecting to login with email populated
  static Future<void> _handleSessionExpiry({
    required BuildContext context,
    required String expiredEmail,
    VoidCallback? onSignIn,
  }) async {
    try {
      // Remove the expired account from quick access
      final credentialService = CredentialStorageService();
      final credentials = await credentialService.getSavedCredentials();
      final expiredCredential = credentials.where((c) => c.email == expiredEmail).firstOrNull;
      
      if (expiredCredential != null) {
        await credentialService.removeCredentials(expiredCredential.uid);
      }
    } catch (e) {
      // Log error but don't block the flow
    }

    // Show a brief message and navigate to login with email populated
    if (context.mounted) {
      _showErrorSnackbar(
        context: context,
        message: 'Session expired. Please sign in again.',
      );
      
      // Navigate to login screen with the expired email populated
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
        arguments: {'prefillEmail': expiredEmail},
      );
    }
  }
}