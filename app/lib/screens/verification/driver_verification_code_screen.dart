import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../services/auth_service.dart';
import '../../utils/verification_code_utils.dart';
import '../../models/user_model.dart';

class DriverVerificationCodeScreen extends StatefulWidget {
  final RideOffer ride;

  const DriverVerificationCodeScreen({
    super.key,
    required this.ride,
  });

  @override
  State<DriverVerificationCodeScreen> createState() => _DriverVerificationCodeScreenState();
}

class _DriverVerificationCodeScreenState extends State<DriverVerificationCodeScreen> {
  final RideService _rideService = RideService();
  final AuthService _authService = AuthService();
  String? _verificationCode;
  bool _isLoading = true;
  String? _error;
  List<UserModel> _passengers = [];

  @override
  void initState() {
    super.initState();
    _loadVerificationCodeAndPassengers();
  }

  Future<void> _loadVerificationCodeAndPassengers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load verification code and passenger details in parallel
      final futures = await Future.wait([
        _rideService.getVerificationCode(widget.ride.id),
        _loadPassengerDetails(),
      ]);

      final code = futures[0] as String?;

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

  Future<void> _loadPassengerDetails() async {
    try {
      final passengers = <UserModel>[];
      for (final passengerId in widget.ride.passengerIds) {
        final doc = await _authService.getUserData(passengerId);
        if (doc != null && doc.exists) {
          passengers.add(UserModel.fromFirestore(doc));
        }
      }
      
      if (mounted) {
        setState(() {
          _passengers = passengers;
        });
      }
    } catch (e) {
      // Non-critical error, passengers list will remain empty
    }
  }

  String _getPassengerDisplayName(UserModel passenger) {
    if (passenger.profile.displayName.isNotEmpty) {
      return passenger.profile.displayName;
    }
    final firstName = passenger.profile.firstName;
    final lastName = passenger.profile.lastName;
    return firstName.isNotEmpty && lastName.isNotEmpty 
        ? '$firstName $lastName'
        : firstName.isNotEmpty ? firstName : 'Unknown Passenger';
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
        title: const Text('Show Code to Passengers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Tooltip(
            message: 'Reload verification code and passenger info',
            child: IconButton(
              onPressed: _loadVerificationCodeAndPassengers,
              icon: const Icon(Icons.sync),
            ),
          ),
        ],
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
            onPressed: _loadVerificationCodeAndPassengers,
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
            'No passengers confirmed yet\nVerification code will be generated\nonce passengers join your ride',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadVerificationCodeAndPassengers,
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
    final passengerName = _passengers.isNotEmpty ? _getPassengerDisplayName(_passengers.first) : 'your passenger';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          
          // Passenger info
          if (_passengers.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Show this code to:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._passengers.map((passenger) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _getPassengerDisplayName(passenger),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Title
          Text(
            'Your Verification Code',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Show this to $passengerName when they approach your vehicle',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 48),
          
          // Large code display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isExpired 
                  ? [Colors.red.shade50, Colors.red.shade100]
                  : [Colors.green.shade50, Colors.green.shade100],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isExpired ? Colors.red.shade300 : Colors.green.shade300,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isExpired ? Colors.red : Colors.green).shade100,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  formattedCode,
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                    color: isExpired ? Colors.red.shade700 : Colors.green.shade700,
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
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'EXPIRED',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
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
                    side: BorderSide(color: Colors.blue.shade300),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Tooltip(
                  message: 'Reload verification code.\nNew codes are only generated when the current one expires.',
                  child: ElevatedButton.icon(
                    onPressed: _loadVerificationCodeAndPassengers,
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
          
          // Security tips
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Safety Tips',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSafetyTip(
                  Icons.visibility,
                  'Keep your phone visible',
                  'Show the code clearly without handing over your phone',
                ),
                _buildSafetyTip(
                  Icons.person_search,
                  'Verify passenger identity',
                  'Ask for their name and confirm it matches your passenger list',
                ),
                _buildSafetyTip(
                  Icons.block,
                  'Don\'t start without verification',
                  'Only begin the ride after successful code verification',
                ),
              ],
            ),
          ),
          
          if (widget.ride.codeExpiresAt != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Code expires: ${_formatExpirationTime(widget.ride.codeExpiresAt!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
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

  Widget _buildSafetyTip(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.blue.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
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