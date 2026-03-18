import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/stripe_payment_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/ride_model.dart';

class PaymentScreen extends StatefulWidget {
  final RideOffer ride;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.ride,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final StripePaymentService _paymentService = StripePaymentService();
  
  bool _isLoading = false;
  PaymentIntent? _paymentIntent;
  RideCostBreakdown? _costBreakdown;
  List<PaymentMethodSummary> _savedPaymentMethods = [];
  String? _selectedPaymentMethodId;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate cost breakdown
      _costBreakdown = _paymentService.calculateRideCost(
        baseAmount: widget.amount,
      );

      // Get user info
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId != null) {
        // Load saved payment methods
        _savedPaymentMethods = await _paymentService.getSavedPaymentMethods(userId);

        // Create payment intent
        _paymentIntent = await _paymentService.createPaymentIntent(
          amount: _costBreakdown!.totalAmount,
          currency: 'usd',
          rideId: widget.ride.id,
          customerId: userId,
          metadata: {
            'ride_from': widget.ride.startLocation.address,
            'ride_to': widget.ride.endLocation.address,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing payment: $e'),
            backgroundColor: Colors.red,
          ),
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

  Future<void> _processPayment() async {
    if (_paymentIntent == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      PaymentResult result;

      if (_selectedPaymentMethodId != null) {
        // Use saved payment method
        result = await _paymentService.processPayment(
          paymentIntentClientSecret: _paymentIntent!.clientSecret,
          paymentMethodData: PaymentMethodData(),
        );
      } else {
        // Show payment sheet for new payment method
        await Stripe.instance.presentPaymentSheet();
        
        result = PaymentResult(
          success: true,
          message: 'Payment completed successfully',
        );
      }

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Return success
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
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

  Future<void> _showPaymentSheet() async {
    if (_paymentIntent == null) return;

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: _paymentIntent!.clientSecret,
          style: ThemeMode.system,
          merchantDisplayName: 'UVA Cavpool',
          allowsDelayedPaymentMethods: false,
        ),
      );

      await _processPayment();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting up payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ride Summary
                  _buildRideSummary(),
                  const SizedBox(height: 24),

                  // Cost Breakdown
                  if (_costBreakdown != null) _buildCostBreakdown(),
                  const SizedBox(height: 24),

                  // Payment Methods
                  _buildPaymentMethods(),
                  const SizedBox(height: 32),

                  // Pay Button
                  _buildPayButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildRideSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ride Details',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'From: ${widget.ride.startLocation.address}',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To: ${widget.ride.endLocation.address}',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Date: ${_formatDateTime(widget.ride.departureTime)}',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostBreakdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost Breakdown',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildCostRow('Ride fare', _costBreakdown!.baseAmount),
            _buildCostRow('Platform fee', _costBreakdown!.platformFee),
            _buildCostRow('Processing fee', _costBreakdown!.processingFee),
            const Divider(),
            _buildCostRow(
              'Total',
              _costBreakdown!.totalAmount,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Method',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Saved payment methods
            if (_savedPaymentMethods.isNotEmpty) ...[
              ...(_savedPaymentMethods.map((method) => _buildPaymentMethodTile(method))),
              const SizedBox(height: 8),
            ],
            
            // Add new payment method option
            _buildNewPaymentMethodTile(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(PaymentMethodSummary method) {
    final isSelected = _selectedPaymentMethodId == method.id;
    
    return ListTile(
      title: Text(method.displayName),
      subtitle: method.expMonth != null && method.expYear != null
          ? Text('Expires ${method.expMonth}/${method.expYear}')
          : null,
      leading: IconButton(
        icon: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
        onPressed: () {
          setState(() {
            _selectedPaymentMethodId = method.id;
          });
        },
      ),
      trailing: Icon(
        method.brand?.toLowerCase() == 'visa'
            ? Icons.credit_card
            : Icons.payment,
      ),
      onTap: () {
        setState(() {
          _selectedPaymentMethodId = method.id;
        });
      },
    );
  }

  Widget _buildNewPaymentMethodTile() {
    final isSelected = _selectedPaymentMethodId == null;
    
    return ListTile(
      title: const Text('Add new payment method'),
      subtitle: const Text('Credit or debit card'),
      leading: IconButton(
        icon: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
        onPressed: () {
          setState(() {
            _selectedPaymentMethodId = null;
          });
        },
      ),
      trailing: const Icon(Icons.add_card),
      onTap: () {
        setState(() {
          _selectedPaymentMethodId = null;
        });
      },
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading || _paymentIntent == null ? null : _processPaymentFlow,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF232F3E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Pay \$${_costBreakdown?.totalAmount.toStringAsFixed(2) ?? '0.00'}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _processPaymentFlow() async {
    if (_selectedPaymentMethodId != null) {
      // Use saved payment method
      await _processPayment();
    } else {
      // Show payment sheet for new method
      await _showPaymentSheet();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${TimeOfDay.fromDateTime(dateTime).format(context)}';
  }
}

