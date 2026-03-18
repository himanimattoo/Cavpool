import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/auth_provider.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Earnings',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF232F3E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer2<DriverProvider, AuthProvider>(
        builder: (context, driverProvider, authProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Balance Card
                _buildBalanceCard(driverProvider),
                const SizedBox(height: 16),
                
                // Quick Stats
                _buildQuickStats(driverProvider),
                const SizedBox(height: 16),
                
                // Recent Earnings
                _buildRecentEarnings(),
                const SizedBox(height: 16),
                
                // Payment Options
                _buildPaymentOptions(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(DriverProvider driverProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF232F3E), Color(0xFFE57200)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Balance',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${_getTotalEarnings().toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _requestPayout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF232F3E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Request Payout',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(DriverProvider driverProvider) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Trips',
            '${_getTotalTrips()}',
            Icons.directions_car,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'This Week',
            '\$${_getWeeklyEarnings().toStringAsFixed(0)}',
            Icons.calendar_today,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Rating',
            '${_getDriverRating().toStringAsFixed(1)}★',
            Icons.star,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEarnings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFFE57200)),
                const SizedBox(width: 8),
                Text(
                  'Recent Earnings',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Placeholder for recent earnings list
            _buildEarningItem('Airport Trip', 'Nov 26, 2:30 PM', 35.00),
            _buildEarningItem('Downtown Ride', 'Nov 26, 1:15 PM', 22.50),
            _buildEarningItem('UVA Campus', 'Nov 26, 11:45 AM', 18.75),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Navigate to full earnings history
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Full earnings history - Coming soon!')),
                );
              },
              child: const Text('View All Earnings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningItem(String trip, String time, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE57200).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.attach_money,
              color: Color(0xFFE57200),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payment, color: Color(0xFFE57200)),
                const SizedBox(width: 8),
                Text(
                  'Payment Settings',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('Bank Account'),
              subtitle: const Text('••••••••1234'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment methods - Coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Payout Schedule'),
              subtitle: const Text('Weekly on Fridays'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payout schedule - Coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Tax Documents'),
              subtitle: const Text('1099-K and more'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tax documents - Coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder methods for earnings data
  double _getTotalEarnings() {
    // TODO: Integrate with actual earnings data from DriverProvider
    return 847.50;
  }

  int _getTotalTrips() {
    // TODO: Get actual trip count from driver statistics
    return 156;
  }

  double _getWeeklyEarnings() {
    // TODO: Calculate weekly earnings from ride history
    return 235.00;
  }

  double _getDriverRating() {
    // TODO: Get actual driver rating from user profile
    return 4.8;
  }

  void _requestPayout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Payout'),
        content: const Text(
          'Your payout request will be processed within 1-3 business days. '
          'Funds will be transferred to your linked bank account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payout request submitted successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }
}