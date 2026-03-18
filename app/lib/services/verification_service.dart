import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../utils/verification_code_utils.dart';
import 'ride_service.dart';

class VerificationService {
  static final VerificationService _instance = VerificationService._internal();
  factory VerificationService() => _instance;
  VerificationService._internal();

  final Logger _logger = Logger();
  final RideService _rideService = RideService();

  /// Validate a verification code for a ride
  Future<VerificationResult> validateCode({
    required String rideId,
    required String inputCode,
    required String validatorUserId,
  }) async {
    try {
      _logger.i('Validating verification code for ride: $rideId');
      
      // Get the current ride data
      final ride = await _rideService.getRideOffer(rideId);
      if (ride == null) {
        return VerificationResult(
          success: false,
          error: 'Ride not found',
        );
      }

      // Check if the ride has a verification code
      if (ride.verificationCode == null || ride.verificationCode!.isEmpty) {
        return VerificationResult(
          success: false,
          error: 'No verification code available for this ride',
        );
      }

      // Validate the input code format
      if (!VerificationCodeUtils.isCodeValid(inputCode)) {
        return VerificationResult(
          success: false,
          error: 'Invalid code format. Please enter a 4-digit code',
        );
      }

      // Check if the code has expired
      if (VerificationCodeUtils.isCodeExpired(ride.codeExpiresAt)) {
        return VerificationResult(
          success: false,
          error: 'Verification code has expired',
          needsNewCode: true,
        );
      }

      // Check if the validator is authorized (driver or passenger)
      final isDriver = ride.driverId == validatorUserId;
      final isPassenger = ride.passengerIds.contains(validatorUserId);
      
      if (!isDriver && !isPassenger) {
        return VerificationResult(
          success: false,
          error: 'You are not authorized to validate this code',
        );
      }

      // Validate the code
      final codeMatches = VerificationCodeUtils.codesMatch(
        inputCode, 
        ride.verificationCode!,
      );

      if (codeMatches) {
        // Log successful verification
        await _logVerificationEvent(
          rideId: rideId,
          userId: validatorUserId,
          success: true,
          userRole: isDriver ? 'driver' : 'passenger',
        );

        return VerificationResult(
          success: true,
          message: 'Code verified successfully!',
        );
      } else {
        // Log failed verification attempt
        await _logVerificationEvent(
          rideId: rideId,
          userId: validatorUserId,
          success: false,
          userRole: isDriver ? 'driver' : 'passenger',
          failureReason: 'incorrect_code',
        );

        return VerificationResult(
          success: false,
          error: 'Incorrect verification code',
        );
      }
    } catch (e) {
      _logger.e('Error validating verification code: $e');
      return VerificationResult(
        success: false,
        error: 'An error occurred while validating the code',
      );
    }
  }

  /// Check if a user can verify a ride code
  Future<bool> canUserVerifyCode(String rideId, String userId) async {
    try {
      final ride = await _rideService.getRideOffer(rideId);
      if (ride == null) return false;

      return ride.driverId == userId || ride.passengerIds.contains(userId);
    } catch (e) {
      _logger.e('Error checking user verification permission: $e');
      return false;
    }
  }

  /// Get verification status for a ride
  Future<VerificationStatus> getVerificationStatus(String rideId) async {
    try {
      final ride = await _rideService.getRideOffer(rideId);
      if (ride == null) {
        return VerificationStatus(
          hasCode: false,
          isExpired: true,
          message: 'Ride not found',
        );
      }

      final hasCode = ride.verificationCode != null && ride.verificationCode!.isNotEmpty;
      final isExpired = VerificationCodeUtils.isCodeExpired(ride.codeExpiresAt);
      
      String message;
      if (!hasCode) {
        message = 'No verification code available';
      } else if (isExpired) {
        message = 'Verification code has expired';
      } else {
        final timeLeft = ride.codeExpiresAt!.difference(DateTime.now());
        if (timeLeft.inHours > 0) {
          message = 'Code expires in ${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m';
        } else {
          message = 'Code expires in ${timeLeft.inMinutes}m';
        }
      }

      return VerificationStatus(
        hasCode: hasCode,
        isExpired: isExpired,
        message: message,
        expiresAt: ride.codeExpiresAt,
      );
    } catch (e) {
      _logger.e('Error getting verification status: $e');
      return VerificationStatus(
        hasCode: false,
        isExpired: true,
        message: 'Error checking verification status',
      );
    }
  }

  /// Log verification events for security audit
  Future<void> _logVerificationEvent({
    required String rideId,
    required String userId,
    required bool success,
    required String userRole,
    String? failureReason,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('verification_events')
          .add({
        'rideId': rideId,
        'userId': userId,
        'success': success,
        'userRole': userRole,
        'failureReason': failureReason,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': null, // Could be added if available
      });
    } catch (e) {
      _logger.e('Error logging verification event: $e');
    }
  }

  /// Generate a new code if the current one is expired or missing
  Future<bool> regenerateCodeIfNeeded(String rideId) async {
    try {
      final ride = await _rideService.getRideOffer(rideId);
      if (ride == null) return false;

      // Only regenerate if there are passengers and the code is missing or expired
      if (ride.passengerIds.isNotEmpty &&
          (ride.verificationCode == null || 
           VerificationCodeUtils.isCodeExpired(ride.codeExpiresAt))) {
        
        final newCode = VerificationCodeUtils.generateCode();
        final expiresAt = VerificationCodeUtils.getExpirationTime();
        
        await _rideService.updateRideOffer(rideId, {
          'verificationCode': newCode,
          'codeExpiresAt': Timestamp.fromDate(expiresAt),
        });
        
        _logger.i('Regenerated verification code for ride: $rideId');
        return true;
      }
      
      return false;
    } catch (e) {
      _logger.e('Error regenerating verification code: $e');
      return false;
    }
  }

  /// Get verification attempts for a ride (for security monitoring)
  Future<List<VerificationAttempt>> getVerificationAttempts(String rideId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('verification_events')
          .where('rideId', isEqualTo: rideId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return VerificationAttempt(
          userId: data['userId'] ?? '',
          success: data['success'] ?? false,
          userRole: data['userRole'] ?? 'unknown',
          failureReason: data['failureReason'],
          timestamp: data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      _logger.e('Error getting verification attempts: $e');
      return [];
    }
  }
}

/// Result of a verification attempt
class VerificationResult {
  final bool success;
  final String? message;
  final String? error;
  final bool needsNewCode;

  VerificationResult({
    required this.success,
    this.message,
    this.error,
    this.needsNewCode = false,
  });
}

/// Status of verification for a ride
class VerificationStatus {
  final bool hasCode;
  final bool isExpired;
  final String message;
  final DateTime? expiresAt;

  VerificationStatus({
    required this.hasCode,
    required this.isExpired,
    required this.message,
    this.expiresAt,
  });
}

/// Verification attempt record for security monitoring
class VerificationAttempt {
  final String userId;
  final bool success;
  final String userRole;
  final String? failureReason;
  final DateTime timestamp;

  VerificationAttempt({
    required this.userId,
    required this.success,
    required this.userRole,
    this.failureReason,
    required this.timestamp,
  });
}