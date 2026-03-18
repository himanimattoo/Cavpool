import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../models/user_model.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _pronounsController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();

  String _accountType = 'rider';
  bool _isInitialized = false;
  List<EmergencyContact> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProfile();
    });
  }

  void _initializeProfile() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    
    if (authProvider.userModel != null) {
      final user = authProvider.userModel!;
      _firstNameController.text = user.profile.firstName;
      _lastNameController.text = user.profile.lastName;
      _displayNameController.text = user.profile.displayName;
      _pronounsController.text = user.profile.pronouns;
      _bioController.text = user.profile.bio;
      _phoneController.text = user.profile.phoneNumber;
      _accountType = user.accountType;
      _emergencyContacts = List.from(user.emergencyContacts);
      
      profileProvider.loadUserProfile(user.uid);
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _displayNameController.dispose();
    _pronounsController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Profile Photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _uploadFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _uploadFromCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _uploadFromGallery() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    
    if (authProvider.user == null) return;
    
    try {
      final photoUrl = await profileProvider.uploadProfileImage(authProvider.user!.uid);
      if (photoUrl != null) {
        await profileProvider.updateProfilePhoto(authProvider.user!.uid, photoUrl);
        // Refresh the auth provider to get the updated profile
        await authProvider.reloadUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: $e')),
        );
      }
    }
  }

  void _uploadFromCamera() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    
    if (authProvider.user == null) return;
    
    try {
      final photoUrl = await profileProvider.uploadProfileImageFromCamera(authProvider.user!.uid);
      if (photoUrl != null) {
        await profileProvider.updateProfilePhoto(authProvider.user!.uid, photoUrl);
        // Refresh the auth provider to get the updated profile
        await authProvider.reloadUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: $e')),
        );
      }
    }
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    
    if (authProvider.userModel == null) return;

    try {
      final currentUser = authProvider.userModel!;
      
      final updatedProfile = UserProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        photoURL: currentUser.profile.photoURL,
        pronouns: _pronounsController.text.trim(),
        bio: _bioController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      final updatedUser = UserModel(
        uid: currentUser.uid,
        email: currentUser.email,
        profile: updatedProfile,
        accountType: _accountType,
        isVerified: currentUser.isVerified,
        emergencyContacts: _emergencyContacts,
        preferences: currentUser.preferences,
        ratings: currentUser.ratings,
        createdAt: currentUser.createdAt,
        updatedAt: DateTime.now(),
        driverVerificationStatus: currentUser.driverVerificationStatus,
        vehicleInfo: currentUser.vehicleInfo,
      );

      await profileProvider.updateProfile(updatedUser);
      await authProvider.updateUserData(updatedUser.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  Future<void> _addEmergencyContact() async {
    // Show choice dialog first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: const Text('How would you like to add a contact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickFromContacts();
            },
            child: const Text('From Contacts'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showManualContactDialog();
            },
            child: const Text('Enter Manually'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _pickFromContacts() async {
    try {
      final hasPermission = await FlutterContacts.requestPermission(readonly: true);
      if (hasPermission) {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null && mounted) {
          _showEmergencyContactDialog(contact);
          return;
        }
      }
      
      // If permission denied or no contact selected, show manual entry option
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to access device contacts'),
            action: SnackBarAction(
              label: 'Manual Entry',
              onPressed: _showManualContactDialog,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Contact picker error: $e');
      if (mounted) {
        _showManualContactDialog();
      }
    }
  }
  
  void _showManualContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: relationshipController,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                border: OutlineInputBorder(),
                helperText: 'e.g., Mother, Father, Spouse, Friend',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty &&
                  phoneController.text.trim().isNotEmpty &&
                  relationshipController.text.trim().isNotEmpty) {
                setState(() {
                  _emergencyContacts.add(EmergencyContact(
                    name: nameController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                    relationship: relationshipController.text.trim(),
                  ));
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }


  void _showEmergencyContactDialog(Contact contact) {
    final relationshipController = TextEditingController();
    String? selectedPhone;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Adding: ${contact.displayName}'),
            const SizedBox(height: 16),
            if (contact.phones.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                items: contact.phones.map((phone) => 
                  DropdownMenuItem(
                    value: phone.number,
                    child: Text(phone.number),
                  ),
                ).toList(),
                onChanged: (value) => selectedPhone = value,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: relationshipController,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                border: OutlineInputBorder(),
                helperText: 'e.g., Mother, Father, Spouse, Friend',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (selectedPhone != null && relationshipController.text.trim().isNotEmpty) {
                setState(() {
                  _emergencyContacts.add(EmergencyContact(
                    name: contact.displayName,
                    phoneNumber: selectedPhone!,
                    relationship: relationshipController.text.trim(),
                  ));
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeEmergencyContact(int index) {
    setState(() {
      _emergencyContacts.removeAt(index);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Sign Out'),
                    onTap: () async {
                      await authProvider.signOut();
                      // AuthWrapper will automatically handle navigation
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer2<AuthProvider, UserProfileProvider>(
        builder: (context, authProvider, profileProvider, child) {
          if (!_isInitialized || authProvider.userModel == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profileProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = authProvider.userModel!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Profile Photo Section
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: user.profile.photoURL.isNotEmpty
                              ? NetworkImage(user.profile.photoURL)
                              : null,
                          child: user.profile.photoURL.isEmpty
                              ? const Icon(Icons.person, size: 60, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF232F3E),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white),
                              onPressed: profileProvider.isUploading ? null : _showImagePickerDialog,
                            ),
                          ),
                        ),
                        if (profileProvider.isUploading)
                          const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // First Name
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your first name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Last Name
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your last name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Display Name
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                      helperText: 'This is how others will see your name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a display name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Pronouns
                  TextFormField(
                    controller: _pronounsController,
                    decoration: const InputDecoration(
                      labelText: 'Pronouns (Optional)',
                      border: OutlineInputBorder(),
                      helperText: 'e.g., he/him, she/her, they/them',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone Number
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),


                  // Bio
                  TextFormField(
                    controller: _bioController,
                    decoration: const InputDecoration(
                      labelText: 'Bio (Optional)',
                      border: OutlineInputBorder(),
                      helperText: 'Tell others a bit about yourself',
                    ),
                    maxLines: 3,
                    maxLength: 200,
                  ),
                  const SizedBox(height: 24),

                  // Emergency Contacts Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Emergency Contacts',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addEmergencyContact,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Contact'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'These contacts can be called during an emergency while on a ride.',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          if (_emergencyContacts.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No emergency contacts added yet.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _emergencyContacts.length,
                              itemBuilder: (context, index) {
                                final contact = _emergencyContacts[index];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(contact.name),
                                  subtitle: Text('${contact.relationship} • ${contact.phoneNumber}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeEmergencyContact(index),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: profileProvider.isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF232F3E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: profileProvider.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Profile'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}