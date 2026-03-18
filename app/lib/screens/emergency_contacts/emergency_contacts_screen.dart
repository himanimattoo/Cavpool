import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ride_sharing_model.dart';
import '../../services/ride_sharing_service.dart';
import '../../providers/auth_provider.dart';
import './add_emergency_contact_screen.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final RideSharingService _rideSharingService = RideSharingService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.userModel;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Emergency Contacts'),
        ),
        body: const Center(
          child: Text('Please log in to manage emergency contacts.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Colors.blue.shade50,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
            tooltip: 'Information',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.blue.shade200),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Emergency Contacts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add contacts who can receive real-time ride updates',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EnhancedEmergencyContact>>(
              stream: _rideSharingService.getEmergencyContacts(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Error loading contacts',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final contacts = snapshot.data ?? [];

                return ListView.builder(
                  itemCount: contacts.length + 1,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    if (index == contacts.length) {
                      return _buildAddContactCard();
                    }
                    return _buildContactCard(contacts[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(EnhancedEmergencyContact contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getContactColor(contact.relationship),
                  child: Text(
                    contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            contact.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (contact.isVerified)
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.green.shade600,
                            )
                          else
                            Icon(
                              Icons.pending,
                              size: 16,
                              color: Colors.orange.shade600,
                            ),
                        ],
                      ),
                      Text(
                        contact.relationship,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  onSelected: (value) => _handleContactAction(value, contact),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'resend_verification',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 20),
                          SizedBox(width: 8),
                          Text('Resend Verification'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  contact.phoneNumber,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                if (contact.email != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.email,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    contact.email!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPreferenceChip(
                  'SMS', 
                  contact.receivesSMS, 
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildPreferenceChip(
                  'Email', 
                  contact.receivesEmail, 
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildPreferenceChip(
                  'Emergency Alerts', 
                  contact.receivesEmergencyAlerts, 
                  Colors.red,
                ),
              ],
            ),
            if (!contact.isVerified) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Verification pending. Contact will receive verification message.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceChip(String label, bool enabled, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? color.withValues(alpha: 0.3) : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: enabled ? color : Colors.grey.shade600,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAddContactCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: InkWell(
        onTap: _addNewContact,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.add,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Emergency Contact',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Add someone who can receive ride updates',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getContactColor(String relationship) {
    switch (relationship.toLowerCase()) {
      case 'parent':
      case 'father':
      case 'mother':
        return Colors.red.shade600;
      case 'sibling':
      case 'sister':
      case 'brother':
        return Colors.blue.shade600;
      case 'friend':
        return Colors.green.shade600;
      case 'partner':
      case 'spouse':
        return Colors.purple.shade600;
      case 'roommate':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  void _handleContactAction(String action, EnhancedEmergencyContact contact) {
    switch (action) {
      case 'edit':
        _editContact(contact);
        break;
      case 'resend_verification':
        _resendVerification(contact);
        break;
      case 'delete':
        _deleteContact(contact);
        break;
    }
  }

  void _addNewContact() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddEmergencyContactScreen(),
      ),
    );
  }

  void _editContact(EnhancedEmergencyContact contact) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEmergencyContactScreen(
          existingContact: contact,
        ),
      ),
    );
  }

  void _resendVerification(EnhancedEmergencyContact contact) async {
    // TODO: Implement resend verification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification message sent'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _deleteContact(EnhancedEmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
          'Are you sure you want to delete ${contact.name}? '
          'They will no longer receive ride updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _rideSharingService.removeEmergencyContact(contact.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                  ? 'Contact deleted successfully'
                  : 'Failed to delete contact',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Contacts'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency contacts will receive:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Ride start notifications with tracking link'),
            Text('• Real-time location updates during rides'),
            Text('• Immediate alerts if emergency button is used'),
            Text('• Ride completion confirmations'),
            SizedBox(height: 16),
            Text(
              'Privacy Notice:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Contacts only receive information about active rides. '
              'They cannot see your ride history or personal information.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}