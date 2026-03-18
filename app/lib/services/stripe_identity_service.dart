import 'package:flutter/foundation.dart';
import 'package:stripe_identity_plugin/stripe_identity_plugin.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class StripeIdentityService {
  static final StripeIdentityService _instance = StripeIdentityService._internal();
  factory StripeIdentityService() => _instance;
  StripeIdentityService._internal();

  
  /// Creates a verification session on your backend and returns the session details
  Future<Map<String, dynamic>> createVerificationSession({
    required String userId,
    String? returnUrl,
  }) async {
    try {
      // This would typically call your backend to create a Stripe Identity verification session
      // For now, we'll simulate the response structure
      // In production, replace this with actual HTTP call to your backend
      
      final response = await _mockBackendCall(userId);
      
      if (response['success']) {
        return {
          'verificationSessionId': response['verificationSessionId'],
          'ephemeralKeySecret': response['ephemeralKeySecret'],
        };
      } else {
        throw Exception('Failed to create verification session: ${response['error']}');
      }
    } catch (e) {
      debugPrint('Error creating verification session: $e');
      rethrow;
    }
  }

  /// Starts the Stripe Identity verification flow
  Future<VerificationResult> startVerification({
    required String verificationSessionId,
    required String ephemeralKeySecret,
    String? brandLogoUrl,
    bool isMock = false,
  }) async {
    try {
      // If this is a mock session, return a successful result without calling Stripe
      if (isMock || verificationSessionId.startsWith('vs_mock_')) {
        debugPrint('Using mock verification flow');
        return VerificationResult(
          isSuccess: true,
          status: VerificationResultStatus.completed,
          message: 'Mock verification completed successfully',
        );
      }
      
      final stripeIdentity = StripeIdentityPlugin();
      
      final (status, message) = await stripeIdentity.startVerification(
        id: verificationSessionId,
        key: ephemeralKeySecret,
        brandLogoUrl: brandLogoUrl,
      );

      return VerificationResult.fromStripeResult(status, message);
    } catch (e) {
      debugPrint('Error starting verification: $e');
      throw Exception('Identity verification failed: $e');
    }
  }

  /// Checks the verification status with your backend
  Future<VerificationStatus> checkVerificationStatus(String verificationSessionId) async {
    try {
      // This would call your backend to check the verification status
      // For now, simulate the response
      final response = await _mockStatusCheck(verificationSessionId);
      
      return VerificationStatus.fromString(response['status']);
    } catch (e) {
      debugPrint('Error checking verification status: $e');
      rethrow;
    }
  }

  /// Create verification session via Vercel API
  Future<Map<String, dynamic>> _mockBackendCall(String userId) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
      };
      
      // Add Vercel bypass token if available
      final bypassToken = dotenv.env['VERCEL_BYPASS_TOKEN'];
      if (bypassToken != null && bypassToken.isNotEmpty) {
        headers['x-vercel-protection-bypass'] = bypassToken;
      }
      
      final response = await http.post(
        Uri.parse('${dotenv.env['BACKEND_URL']}/identity/create-verification-session'),
        headers: headers,
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Check if this is a mock response
        if (responseData['mock'] == true) {
          // Return a successful mock response that skips actual Stripe verification
          return {
            'success': true,
            'verificationSessionId': responseData['verificationSessionId'],
            'ephemeralKeySecret': responseData['ephemeralKeySecret'],
            'mock': true,
          };
        }
        
        return responseData;
      } else {
        throw Exception('Failed to create verification session: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error calling verification API: $e');
      // Fallback to mock for development
      return {
        'success': true,
        'verificationSessionId': 'vs_test_${DateTime.now().millisecondsSinceEpoch}',
        'ephemeralKeySecret': 'ek_test_${DateTime.now().millisecondsSinceEpoch}',
      };
    }
  }

  /// Mock status check - replace with actual backend call
  Future<Map<String, dynamic>> _mockStatusCheck(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return {
      'status': 'verified', // or 'requires_input', 'processing', 'canceled'
    };
  }
}

class VerificationResult {
  final bool isSuccess;
  final String? message;
  final VerificationResultStatus status;

  VerificationResult({
    required this.isSuccess,
    required this.status,
    this.message,
  });

  factory VerificationResult.fromStripeResult(dynamic status, String? message) {
    VerificationResultStatus resultStatus;
    
    // Handle the actual return type from Stripe Identity plugin
    if (status.toString().toLowerCase().contains('completed')) {
      resultStatus = VerificationResultStatus.completed;
    } else if (status.toString().toLowerCase().contains('canceled')) {
      resultStatus = VerificationResultStatus.canceled;
    } else {
      resultStatus = VerificationResultStatus.failed;
    }
    
    return VerificationResult(
      isSuccess: resultStatus == VerificationResultStatus.completed,
      status: resultStatus,
      message: message,
    );
  }
}

enum VerificationResultStatus {
  completed,
  canceled,
  failed;

  String get displayName {
    switch (this) {
      case VerificationResultStatus.completed:
        return 'Completed';
      case VerificationResultStatus.canceled:
        return 'Canceled';
      case VerificationResultStatus.failed:
        return 'Failed';
    }
  }
}

enum VerificationStatus {
  requiresInput,
  processing,
  verified,
  canceled,
  failed;

  static VerificationStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'requires_input':
        return VerificationStatus.requiresInput;
      case 'processing':
        return VerificationStatus.processing;
      case 'verified':
        return VerificationStatus.verified;
      case 'canceled':
        return VerificationStatus.canceled;
      case 'failed':
        return VerificationStatus.failed;
      default:
        return VerificationStatus.requiresInput;
    }
  }

  String get displayName {
    switch (this) {
      case VerificationStatus.requiresInput:
        return 'Input Required';
      case VerificationStatus.processing:
        return 'Processing';
      case VerificationStatus.verified:
        return 'Verified';
      case VerificationStatus.canceled:
        return 'Canceled';
      case VerificationStatus.failed:
        return 'Failed';
    }
  }
}