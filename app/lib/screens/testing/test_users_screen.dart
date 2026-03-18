import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/test_user_service.dart';

class TestUsersScreen extends StatefulWidget {
  const TestUsersScreen({super.key});

  @override
  State<TestUsersScreen> createState() => _TestUsersScreenState();
}

class _TestUsersScreenState extends State<TestUsersScreen> {
  final TestUserService _testUserService = TestUserService();
  bool _isLoading = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Test Users Management',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF232F3E),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _status.contains('Error') ? Colors.red[50] : Colors.green[50],
                  border: Border.all(
                    color: _status.contains('Error') ? Colors.red : Colors.green,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: GoogleFonts.inter(
                    color: _status.contains('Error') ? Colors.red[800] : Colors.green[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // Action Buttons
            _buildActionButton(
              'Create All Test Users',
              Icons.person_add,
              _isLoading ? null : _createAllTestUsers,
              Colors.green,
            ),
            const SizedBox(height: 12),
            
            _buildActionButton(
              'Print Test Credentials',
              Icons.print,
              _isLoading ? null : _printCredentials,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            
            _buildActionButton(
              'Delete All Test Users',
              Icons.delete_forever,
              _isLoading ? null : _deleteAllTestUsers,
              Colors.red,
            ),
            
            const SizedBox(height: 30),
            
            // Test User Lists
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserSection('Test Drivers', TestUserService.testDrivers, true),
                    const SizedBox(height: 20),
                    _buildUserSection('Test Passengers', TestUserService.testPassengers, false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, VoidCallback? onPressed, Color color) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon),
      label: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildUserSection(String title, List<Map<String, dynamic>> users, bool isDriver) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF232F3E),
          ),
        ),
        const SizedBox(height: 12),
        ...users.map((user) => _buildUserCard(user, isDriver)),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isDriver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(user['photoURL'] ?? ''),
                backgroundColor: const Color(0xFFE57200),
                child: user['photoURL'] == null || user['photoURL'].isEmpty
                    ? Text(
                        user['displayName'].substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['displayName'],
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      user['email'],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (isDriver && user['vehicleInfo'] != null)
                      Text(
                        '${user['vehicleInfo']['year']} ${user['vehicleInfo']['make']} ${user['vehicleInfo']['model']} (${user['vehicleInfo']['color']})',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (user['bio'] != null && user['bio'].isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              user['bio'],
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createAllTestUsers() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating test users...';
    });

    try {
      await _testUserService.createAllTestUsers();
      setState(() {
        _status = 'Successfully created all test users!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error creating test users: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _printCredentials() {
    _testUserService.printTestUserCredentials();
    setState(() {
      _status = 'Test credentials printed to console/logs';
    });
  }

  Future<void> _deleteAllTestUsers() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete all test users? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _status = 'Deleting test users...';
    });

    try {
      await _testUserService.deleteAllTestUsers();
      setState(() {
        _status = 'Successfully deleted all test users!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error deleting test users: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}