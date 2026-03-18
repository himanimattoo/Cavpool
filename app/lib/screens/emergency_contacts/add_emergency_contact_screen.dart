import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/ride_sharing_model.dart';
import '../../services/ride_sharing_service.dart';
import '../../providers/auth_provider.dart';

class AddEmergencyContactScreen extends StatefulWidget {
  final EnhancedEmergencyContact? existingContact;

  const AddEmergencyContactScreen({
    super.key,
    this.existingContact,
  });

  @override
  State<AddEmergencyContactScreen> createState() => _AddEmergencyContactScreenState();
}

class _AddEmergencyContactScreenState extends State<AddEmergencyContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  final RideSharingService _rideSharingService = RideSharingService();
  
  String _selectedRelationship = 'Friend';
  bool _receivesSMS = true;
  bool _receivesEmail = true;
  bool _receivesEmergencyAlerts = true;
  RideSharingPreference _defaultSharingPreference = RideSharingPreference.askEachTime;
  bool _isLoading = false;

  final List<String> _relationships = [
    'Parent',
    'Sibling', 
    'Friend',
    'Partner',
    'Spouse',
    'Roommate',
    'Family Member',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.existingContact != null) {
      final contact = widget.existingContact!;
      _nameController.text = contact.name;
      _phoneController.text = contact.phoneNumber;
      _emailController.text = contact.email ?? '';
      _selectedRelationship = contact.relationship;
      _receivesSMS = contact.receivesSMS;
      _receivesEmail = contact.receivesEmail;
      _receivesEmergencyAlerts = contact.receivesEmergencyAlerts;
      _defaultSharingPreference = contact.defaultSharingPreference;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.userModel;
    final isEditing = widget.existingContact != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Contact' : 'Add Emergency Contact'),
        backgroundColor: Colors.blue.shade50,
        elevation: 1,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showEditInfoDialog(),
              tooltip: 'Information',
            ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text('Please log in to manage emergency contacts.'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildContactInfoCard(),
                  const SizedBox(height: 16),
                  _buildNotificationPreferencesCard(),
                  const SizedBox(height: 16),
                  _buildSharingPreferencesCard(),
                  const SizedBox(height: 24),
                  _buildSaveButton(currentUser),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emergency,
                  color: Colors.red.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Emergency Contact Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.existingContact != null
                  ? 'Update contact information and preferences.'
                  : 'Add someone who can receive real-time updates during your rides.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter contact\'s full name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '(555) 123-4567',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a phone number';
                }
                final cleaned = value.replaceAll(RegExp(r'\D'), '');
                if (cleaned.length != 10) {
                  return 'Please enter a valid 10-digit phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address (Optional)',
                hintText: 'contact@example.com',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedRelationship,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                prefixIcon: Icon(Icons.group),
                border: OutlineInputBorder(),
              ),
              items: _relationships.map((relationship) {
                return DropdownMenuItem(
                  value: relationship,
                  child: Text(relationship),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRelationship = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationPreferencesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Preferences',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how this contact will receive ride updates.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('SMS Notifications'),
              subtitle: const Text('Receive text messages for ride updates'),
              value: _receivesSMS,
              onChanged: (value) {
                setState(() {
                  _receivesSMS = value;
                });
              },
              secondary: const Icon(Icons.sms),
            ),
            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Receive email updates (requires email address)'),
              value: _receivesEmail && _emailController.text.trim().isNotEmpty,
              onChanged: _emailController.text.trim().isNotEmpty 
                  ? (value) {
                      setState(() {
                        _receivesEmail = value;
                      });
                    }
                  : null,
              secondary: const Icon(Icons.email),
            ),
            SwitchListTile(
              title: const Text('Emergency Alerts'),
              subtitle: const Text('Immediate alerts if emergency button is used'),
              value: _receivesEmergencyAlerts,
              onChanged: (value) {
                setState(() {
                  _receivesEmergencyAlerts = value;
                });
              },
              secondary: Icon(Icons.emergency, color: Colors.red.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharingPreferencesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Default Sharing Preference',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How often should this contact receive ride updates by default?',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // ignore: deprecated_member_use
            Column(
              children: RideSharingPreference.values.map((preference) {
                return ListTile(
                  leading: Radio<RideSharingPreference>(
                    value: preference,
                    // ignore: deprecated_member_use
                    groupValue: _defaultSharingPreference,
                    // ignore: deprecated_member_use
                    onChanged: (RideSharingPreference? value) {
                      if (value != null) {
                        setState(() {
                          _defaultSharingPreference = value;
                        });
                      }
                    },
                  ),
                  title: Text(_getPreferenceTitle(preference)),
                  subtitle: Text(_getPreferenceDescription(preference)),
                  onTap: () {
                    setState(() {
                      _defaultSharingPreference = preference;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(dynamic userModel) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _saveContact(userModel.uid),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.existingContact != null ? 'Update Contact' : 'Add Contact',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  String _getPreferenceTitle(RideSharingPreference preference) {
    switch (preference) {
      case RideSharingPreference.always:
        return 'Always Share';
      case RideSharingPreference.askEachTime:
        return 'Ask Each Time';
      case RideSharingPreference.manual:
        return 'Manual Only';
      case RideSharingPreference.never:
        return 'Never Share';
    }
  }

  String _getPreferenceDescription(RideSharingPreference preference) {
    switch (preference) {
      case RideSharingPreference.always:
        return 'Automatically share all rides with this contact';
      case RideSharingPreference.askEachTime:
        return 'Ask before each ride if you want to share';
      case RideSharingPreference.manual:
        return 'Only share when manually selected';
      case RideSharingPreference.never:
        return 'Never automatically share rides';
    }
  }

  Future<void> _saveContact(String userId) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      final email = _emailController.text.trim();
      final formattedPhone = '(${phone.substring(0, 3)}) ${phone.substring(3, 6)}-${phone.substring(6)}';

      if (widget.existingContact != null) {
        // Update existing contact
        final updatedContact = widget.existingContact!.copyWith(
          name: name,
          phoneNumber: formattedPhone,
          email: email.isNotEmpty ? email : null,
          relationship: _selectedRelationship,
          receivesSMS: _receivesSMS,
          receivesEmail: _receivesEmail && email.isNotEmpty,
          receivesEmergencyAlerts: _receivesEmergencyAlerts,
          defaultSharingPreference: _defaultSharingPreference,
        );

        final success = await _rideSharingService.updateEmergencyContact(updatedContact);
        
        if (mounted) {
          if (success) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contact updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update contact'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Add new contact
        final contactId = await _rideSharingService.addEmergencyContact(
          userId: userId,
          name: name,
          phoneNumber: formattedPhone,
          email: email.isNotEmpty ? email : null,
          relationship: _selectedRelationship,
        );

        if (mounted) {
          if (contactId != null) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contact added successfully. Verification message sent.'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to add contact'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  void _showEditInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Contact Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Changing phone/email requires re-verification'),
            Text('• Notification preferences take effect immediately'),
            Text('• Sharing preferences apply to future rides'),
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