import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../utils/verification_code_utils.dart';

class RiderVerificationCodeScreen extends StatefulWidget {
  final RideOffer ride;

  const RiderVerificationCodeScreen({
    super.key,
    required this.ride,
  });

  @override
  State<RiderVerificationCodeScreen> createState() => _RiderVerificationCodeScreenState();
}

class _RiderVerificationCodeScreenState extends State<RiderVerificationCodeScreen> {
  final RideService _rideService = RideService();
  String? _verificationCode;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVerificationCode();
  }

  Future<void> _loadVerificationCode() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final code = await _rideService.getVerificationCode(widget.ride.id);
      
      if (mounted) {
        setState(() {
          _verificationCode = code;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load verification code';
          _isLoading = false;
        });
      }
    }
  }

  void _copyCodeToClipboard() {
    if (_verificationCode != null) {
      Clipboard.setData(ClipboardData(text: _verificationCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verification Code'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_verificationCode == null) {
      return _buildNoCodeState();
    }

    return _buildCodeDisplayState();
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadVerificationCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCodeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 64,
            color: Colors.orange.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'Verification code will be available\nonce your ride is confirmed',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadVerificationCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Check for Code'),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeDisplayState() {
    final formattedCode = VerificationCodeUtils.formatCodeForDisplay(_verificationCode!);
    final isExpired = VerificationCodeUtils.isCodeExpired(widget.ride.codeExpiresAt);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          
          // Title
          const Text(
            'Show this code to your driver',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          const Text(
            'Ask your driver for the 4-digit code and verify it matches',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 48),
          
          // Code display card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isExpired ? Colors.red.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpired ? Colors.red.shade200 : Colors.blue.shade200,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  formattedCode,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: isExpired ? Colors.red.shade700 : Colors.blue.shade700,
                    fontFamily: 'monospace',
                  ),
                ),
                if (isExpired) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Code Expired',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyCodeToClipboard,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Tooltip(
                  message: 'Reload the current verification code.\nNew codes are only generated when the current one expires.',
                  child: ElevatedButton.icon(
                    onPressed: _loadVerificationCode,
                    icon: const Icon(Icons.sync),
                    label: const Text('Reload Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          
          // Info section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'How it works',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoStep(
                  '1',
                  'Approach your driver\'s vehicle',
                ),
                _buildInfoStep(
                  '2',
                  'Ask the driver to show you their 4-digit code',
                ),
                _buildInfoStep(
                  '3',
                  'Verify the codes match before getting in',
                ),
                _buildInfoStep(
                  '4',
                  'Enjoy your safe ride!',
                ),
              ],
            ),
          ),
          
          if (widget.ride.codeExpiresAt != null) ...[
            const SizedBox(height: 24),
            Text(
              'Code expires: ${_formatExpirationTime(widget.ride.codeExpiresAt!)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note: The same code is used until it expires. A new code is only generated after expiration.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatExpirationTime(DateTime expiresAt) {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    
    if (difference.isNegative) {
      return 'Expired';
    }
    
    if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
    } else {
      return '${difference.inMinutes}m';
    }
  }
}