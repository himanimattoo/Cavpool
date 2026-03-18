import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StripePaymentService {
  static final StripePaymentService _instance = StripePaymentService._internal();
  factory StripePaymentService() => _instance;
  StripePaymentService._internal();

  final Dio _dio = Dio();
  String get _baseUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000/api';

  /// Initialize the payment service
  Future<void> initialize() async {
    try {
      // Configure Dio with default settings
      _dio.options.baseUrl = _baseUrl;
      _dio.options.connectTimeout = const Duration(seconds: 10);
      _dio.options.receiveTimeout = const Duration(seconds: 10);
      
      // Add interceptors for logging in debug mode
      if (kDebugMode) {
        _dio.interceptors.add(LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: false,
          responseHeader: false,
        ));
      }
      
      debugPrint('StripePaymentService initialized with base URL: $_baseUrl');
    } catch (e) {
      debugPrint('Error initializing StripePaymentService: $e');
    }
  }

  /// Create a payment intent for a ride payment
  Future<PaymentIntent> createPaymentIntent({
    required double amount,
    required String currency,
    required String rideId,
    required String customerId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _dio.post('/create-payment-intent', data: {
        'amount': (amount * 100).round(), // Convert to cents
        'currency': currency,
        'metadata': {
          'ride_id': rideId,
          'customer_id': customerId,
          ...?metadata,
        },
      });

      if (response.statusCode == 200) {
        final clientSecret = response.data['client_secret'];
        return await Stripe.instance.retrievePaymentIntent(clientSecret);
      } else {
        throw Exception('Failed to create payment intent: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('Error creating payment intent: $e');
      if (e is DioException) {
        throw Exception('Network error: ${e.message}');
      }
      rethrow;
    }
  }

  /// Process a payment for a ride
  Future<PaymentResult> processPayment({
    required String paymentIntentClientSecret,
    required PaymentMethodData paymentMethodData,
  }) async {
    try {
      // Confirm the payment intent
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: paymentIntentClientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: paymentMethodData,
        ),
        options: const PaymentMethodOptions(
          setupFutureUsage: PaymentIntentsFutureUsage.OffSession,
        ),
      );

      return PaymentResult(
        success: true,
        message: 'Payment processed successfully',
      );
    } on StripeException catch (e) {
      debugPrint('Stripe error: ${e.error}');
      return PaymentResult(
        success: false,
        message: e.error.localizedMessage ?? 'Payment failed',
        error: e.error.code.name,
      );
    } catch (e) {
      debugPrint('Error processing payment: $e');
      return PaymentResult(
        success: false,
        message: 'An unexpected error occurred',
        error: 'unknown_error',
      );
    }
  }

  /// Create a setup intent for saving a payment method
  Future<SetupIntent> createSetupIntent({
    required String customerId,
  }) async {
    try {
      final response = await _dio.post('/create-setup-intent', data: {
        'customer_id': customerId,
      });

      if (response.statusCode == 200) {
        final clientSecret = response.data['client_secret'];
        return await Stripe.instance.retrieveSetupIntent(clientSecret);
      } else {
        throw Exception('Failed to create setup intent: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('Error creating setup intent: $e');
      if (e is DioException) {
        throw Exception('Network error: ${e.message}');
      }
      rethrow;
    }
  }

  /// Save a payment method for future use
  Future<PaymentResult> savePaymentMethod({
    required String setupIntentClientSecret,
    required PaymentMethodData paymentMethodData,
  }) async {
    try {
      await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: setupIntentClientSecret,
        params: PaymentMethodParams.card(
          paymentMethodData: paymentMethodData,
        ),
      );

      return PaymentResult(
        success: true,
        message: 'Payment method saved successfully',
      );
    } on StripeException catch (e) {
      debugPrint('Stripe error: ${e.error}');
      return PaymentResult(
        success: false,
        message: e.error.localizedMessage ?? 'Failed to save payment method',
        error: e.error.code.name,
      );
    } catch (e) {
      debugPrint('Error saving payment method: $e');
      return PaymentResult(
        success: false,
        message: 'An unexpected error occurred',
        error: 'unknown_error',
      );
    }
  }

  /// Get saved payment methods for a customer
  Future<List<PaymentMethodSummary>> getSavedPaymentMethods(String customerId) async {
    try {
      final response = await _dio.get('/payment-methods/$customerId');

      if (response.statusCode == 200) {
        final List<dynamic> paymentMethods = response.data['payment_methods'];
        return paymentMethods
            .map((pm) => PaymentMethodSummary.fromJson(pm))
            .toList();
      } else {
        throw Exception('Failed to get payment methods: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('Error getting saved payment methods: $e');
      if (e is DioException) {
        throw Exception('Network error: ${e.message}');
      }
      return [];
    }
  }

  /// Calculate ride cost with fees
  RideCostBreakdown calculateRideCost({
    required double baseAmount,
    double platformFeePercentage = 0.05, // 5%
    double processingFeePercentage = 0.029, // 2.9%
    double processingFeeFixed = 0.30, // $0.30
  }) {
    final platformFee = baseAmount * platformFeePercentage;
    final processingFee = (baseAmount * processingFeePercentage) + processingFeeFixed;
    final totalAmount = baseAmount + platformFee + processingFee;

    return RideCostBreakdown(
      baseAmount: baseAmount,
      platformFee: platformFee,
      processingFee: processingFee,
      totalAmount: totalAmount,
    );
  }

  /// Process refund for a ride
  Future<PaymentResult> processRefund({
    required String paymentIntentId,
    double? amount, // If null, full refund
    String? reason,
  }) async {
    try {
      final response = await _dio.post('/process-refund', data: {
        'payment_intent_id': paymentIntentId,
        if (amount != null) 'amount': (amount * 100).round(),
        if (reason != null) 'reason': reason,
      });

      if (response.statusCode == 200) {
        return PaymentResult(
          success: true,
          message: 'Refund processed successfully',
        );
      } else {
        throw Exception('Failed to process refund: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('Error processing refund: $e');
      if (e is DioException) {
        return PaymentResult(
          success: false,
          message: 'Network error: ${e.message}',
          error: 'network_error',
        );
      }
      return PaymentResult(
        success: false,
        message: 'Failed to process refund',
        error: 'refund_failed',
      );
    }
  }
}

/// Result class for payment operations
class PaymentResult {
  final bool success;
  final String message;
  final String? error;
  final Map<String, dynamic>? data;

  PaymentResult({
    required this.success,
    required this.message,
    this.error,
    this.data,
  });
}

/// Summary of a saved payment method
class PaymentMethodSummary {
  final String id;
  final String type;
  final String? last4;
  final String? brand;
  final int? expMonth;
  final int? expYear;

  PaymentMethodSummary({
    required this.id,
    required this.type,
    this.last4,
    this.brand,
    this.expMonth,
    this.expYear,
  });

  factory PaymentMethodSummary.fromJson(Map<String, dynamic> json) {
    return PaymentMethodSummary(
      id: json['id'],
      type: json['type'],
      last4: json['card']?['last4'],
      brand: json['card']?['brand'],
      expMonth: json['card']?['exp_month'],
      expYear: json['card']?['exp_year'],
    );
  }

  String get displayName {
    if (type == 'card' && brand != null && last4 != null) {
      return '${brand!.toUpperCase()} •••• $last4';
    }
    return type.toUpperCase();
  }
}

/// Breakdown of ride costs
class RideCostBreakdown {
  final double baseAmount;
  final double platformFee;
  final double processingFee;
  final double totalAmount;

  RideCostBreakdown({
    required this.baseAmount,
    required this.platformFee,
    required this.processingFee,
    required this.totalAmount,
  });

  Map<String, dynamic> toJson() {
    return {
      'base_amount': baseAmount,
      'platform_fee': platformFee,
      'processing_fee': processingFee,
      'total_amount': totalAmount,
    };
  }
}