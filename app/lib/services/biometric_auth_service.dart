import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final Logger _logger = Logger();

  Future<bool> get isDeviceSupported async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      _logger.e('Error checking device support: $e');
      return false;
    }
  }

  Future<bool> get canCheckBiometrics async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      _logger.e('Error checking biometric availability: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometricTypes = await _localAuth.getAvailableBiometrics();
      return biometricTypes;
    } catch (e) {
      _logger.e('Error getting available biometrics: $e');
      return [];
    }
  }

  Future<String> getBiometricDisplayName() async {
    try {
      final biometrics = await getAvailableBiometrics();
      
      if (biometrics.contains(BiometricType.face)) {
        return 'Face ID';
      } else if (biometrics.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      } else if (biometrics.contains(BiometricType.iris)) {
        return 'Iris';
      } else {
        return 'Biometric';
      }
    } catch (e) {
      _logger.e('Error getting biometric display name: $e');
      return 'Biometric';
    }
  }

  Future<bool> get isBiometricAvailable async {
    try {
      final isSupported = await isDeviceSupported;
      final canCheck = await canCheckBiometrics;
      final biometrics = await getAvailableBiometrics();
      
      return isSupported && canCheck && biometrics.isNotEmpty;
    } catch (e) {
      _logger.e('Error checking biometric availability: $e');
      return false;
    }
  }

  Future<BiometricAuthResult> authenticateWithBiometrics({
    String reason = 'Please verify your identity to access your saved accounts',
    bool stickyAuth = true,
  }) async {
    try {
      if (!await isBiometricAvailable) {
        return BiometricAuthResult.notAvailable;
      }

      final biometricName = await getBiometricDisplayName();
      final customReason = reason.replaceAll('biometric', biometricName);

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: customReason,
        options: AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: stickyAuth,
          sensitiveTransaction: true,
        ),
      );

      return didAuthenticate 
          ? BiometricAuthResult.success 
          : BiometricAuthResult.cancelled;

    } on PlatformException catch (e) {
      _logger.e('Biometric authentication error: ${e.code} - ${e.message}');
      
      switch (e.code) {
        case auth_error.notAvailable:
          return BiometricAuthResult.notAvailable;
        case auth_error.notEnrolled:
          return BiometricAuthResult.notEnrolled;
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return BiometricAuthResult.lockedOut;
        case auth_error.biometricOnlyNotSupported:
          return BiometricAuthResult.notSupported;
        default:
          return BiometricAuthResult.error;
      }
    } catch (e) {
      _logger.e('Unexpected biometric authentication error: $e');
      return BiometricAuthResult.error;
    }
  }

  Future<BiometricAuthResult> authenticateForCredentialAccess(String email) async {
    final biometricName = await getBiometricDisplayName();
    return await authenticateWithBiometrics(
      reason: 'Use $biometricName to sign in as ${email.split('@')[0]}',
    );
  }

  Future<BiometricAuthResult> authenticateForAccountManagement() async {
    final biometricName = await getBiometricDisplayName();
    return await authenticateWithBiometrics(
      reason: 'Use $biometricName to manage your saved accounts',
    );
  }

  String getErrorMessage(BiometricAuthResult result) {
    switch (result) {
      case BiometricAuthResult.success:
        return '';
      case BiometricAuthResult.cancelled:
        return 'Authentication was cancelled';
      case BiometricAuthResult.notAvailable:
        return 'Biometric authentication is not available';
      case BiometricAuthResult.notEnrolled:
        return 'No biometric credentials are enrolled. Please set up Face ID, Touch ID, or fingerprint authentication in your device settings.';
      case BiometricAuthResult.lockedOut:
        return 'Biometric authentication is temporarily locked. Please try again later or use your device passcode.';
      case BiometricAuthResult.notSupported:
        return 'Biometric authentication is not supported on this device';
      case BiometricAuthResult.error:
        return 'An error occurred during biometric authentication. Please try again.';
    }
  }
}

enum BiometricAuthResult {
  success,
  cancelled,
  notAvailable,
  notEnrolled,
  lockedOut,
  notSupported,
  error,
}