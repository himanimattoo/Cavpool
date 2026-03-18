import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/driver_verification_model.dart';

class UserProfileProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  
  UserModel? _userProfile;
  bool _isLoading = false;
  bool _isUploading = false;
  
  UserModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  
  Future<void> loadUserProfile(String uid) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final doc = await _authService.getUserData(uid);
      if (doc != null && doc.exists) {
        _userProfile = UserModel.fromFirestore(doc);
      } else {
        debugPrint('User profile document does not exist for uid: $uid');
        _userProfile = null;
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      _userProfile = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> updateProfile(UserModel updatedProfile) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _authService.updateUserData(updatedProfile.uid, updatedProfile.toMap());
      _userProfile = updatedProfile;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<String?> uploadProfileImage(String uid) async {
    try {
      _isUploading = true;
      notifyListeners();
      
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image == null) return null;
      
      // Create storage reference
      final storageRef = _storage.ref().child('users').child(uid).child('profile').child('profile.jpg');
      
      // Debug auth info
      final user = _auth.currentUser;
      debugPrint('Current user email: ${user?.email}');
      debugPrint('User email verified: ${user?.emailVerified}');
      
      // Upload image
      final uploadTask = await storageRef.putFile(File(image.path));
      
      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      debugPrint('Upload path: users/$uid/profile/profile.jpg');
      rethrow;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }
  
  Future<String?> uploadProfileImageFromCamera(String uid) async {
    try {
      _isUploading = true;
      notifyListeners();
      
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image == null) return null;
      
      // Create storage reference
      final storageRef = _storage.ref().child('users').child(uid).child('profile').child('profile.jpg');
      
      // Upload image
      final uploadTask = await storageRef.putFile(File(image.path));
      
      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile image from camera: $e');
      debugPrint('Upload path: users/$uid/profile/profile.jpg');
      rethrow;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }
  
  Future<void> updateProfileWithNewPhoto(String uid, UserModel updatedProfile, String? newPhotoUrl) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Update profile with new photo URL if provided
      if (newPhotoUrl != null) {
        final updatedProfileData = UserProfile(
          firstName: updatedProfile.profile.firstName,
          lastName: updatedProfile.profile.lastName,
          displayName: updatedProfile.profile.displayName,
          photoURL: newPhotoUrl,
          pronouns: updatedProfile.profile.pronouns,
          bio: updatedProfile.profile.bio,
          phoneNumber: updatedProfile.profile.phoneNumber,
        );
        
        final finalProfile = UserModel(
          uid: updatedProfile.uid,
          email: updatedProfile.email,
          profile: updatedProfileData,
          accountType: updatedProfile.accountType,
          isVerified: updatedProfile.isVerified,
          emergencyContacts: updatedProfile.emergencyContacts,
          preferences: updatedProfile.preferences,
          ratings: updatedProfile.ratings,
          createdAt: updatedProfile.createdAt,
          updatedAt: DateTime.now(),
        );
        
        await _authService.updateUserData(uid, finalProfile.toMap());
        _userProfile = finalProfile;
      } else {
        // Update profile without photo change
        await _authService.updateUserData(uid, updatedProfile.toMap());
        _userProfile = updatedProfile;
      }
    } catch (e) {
      debugPrint('Error updating profile with image: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> updateProfilePhoto(String uid, String photoUrl) async {
    if (_userProfile == null) {
      debugPrint('Cannot update profile photo: _userProfile is null');
      return;
    }
    
    debugPrint('Updating profile photo: $photoUrl');
    
    try {
      final updatedProfile = UserProfile(
        firstName: _userProfile!.profile.firstName,
        lastName: _userProfile!.profile.lastName,
        displayName: _userProfile!.profile.displayName,
        photoURL: photoUrl,
        pronouns: _userProfile!.profile.pronouns,
        bio: _userProfile!.profile.bio,
        phoneNumber: _userProfile!.profile.phoneNumber,
      );
      
      final updatedUserModel = UserModel(
        uid: _userProfile!.uid,
        email: _userProfile!.email,
        profile: updatedProfile,
        accountType: _userProfile!.accountType,
        isVerified: _userProfile!.isVerified,
        emergencyContacts: _userProfile!.emergencyContacts,
        preferences: _userProfile!.preferences,
        ratings: _userProfile!.ratings,
        createdAt: _userProfile!.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await _authService.updateUserData(uid, {'profile.photoURL': photoUrl, 'updatedAt': DateTime.now()});
      _userProfile = updatedUserModel;
      debugPrint('Profile photo updated successfully in Firestore and local state');
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile photo: $e');
      rethrow;
    }
  }

  /// Submit driver verification request with vehicle information
  Future<void> submitDriverVerification(String uid, String licenseNumber, VehicleInfo vehicleInfo) async {
    if (_userProfile == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final verificationRequest = DriverVerificationRequest(
        uid: uid,
        licenseNumber: licenseNumber,
        vehicleInfo: vehicleInfo,
        submittedAt: DateTime.now(),
        status: VerificationStatus.pending,
      );

      // Store verification request in separate collection
      await FirebaseFirestore.instance
          .collection('driver_verification_requests')
          .doc(uid)
          .set(verificationRequest.toMap());

      // Update user's account type and verification status
      await _authService.updateUserData(uid, {
        'accountType': 'driver',
        'driverVerificationStatus': 'pending',
        'vehicleInfo': vehicleInfo.toMap(),
        'updatedAt': DateTime.now(),
      });

      // Update local copy
      final updatedUserModel = UserModel(
        uid: _userProfile!.uid,
        email: _userProfile!.email,
        profile: _userProfile!.profile,
        accountType: 'driver',
        isVerified: _userProfile!.isVerified,
        emergencyContacts: _userProfile!.emergencyContacts,
        preferences: _userProfile!.preferences,
        ratings: _userProfile!.ratings,
        createdAt: _userProfile!.createdAt,
        updatedAt: DateTime.now(),
        driverVerificationStatus: VerificationStatus.pending,
        vehicleInfo: vehicleInfo,
      );

      _userProfile = updatedUserModel;
      notifyListeners();
    } catch (e) {
      debugPrint('Error submitting driver verification: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Request driver verification (legacy method for backward compatibility)
  Future<void> requestDriverVerification(String uid) async {
    if (_userProfile == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Update user's account type and set pending verification status
      await _authService.updateUserData(uid, {
        'accountType': 'driver',
        'driverVerificationStatus': 'pending',
        'updatedAt': DateTime.now(),
      });

      // Update local copy
      final updatedUserModel = UserModel(
        uid: _userProfile!.uid,
        email: _userProfile!.email,
        profile: _userProfile!.profile,
        accountType: 'driver',
        isVerified: _userProfile!.isVerified,
        emergencyContacts: _userProfile!.emergencyContacts,
        preferences: _userProfile!.preferences,
        ratings: _userProfile!.ratings,
        createdAt: _userProfile!.createdAt,
        updatedAt: DateTime.now(),
        driverVerificationStatus: VerificationStatus.pending,
        vehicleInfo: _userProfile!.vehicleInfo,
      );

      _userProfile = updatedUserModel;
      notifyListeners();
    } catch (e) {
      debugPrint('Error requesting driver verification: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get driver verification status
  Future<DriverVerificationRequest?> getDriverVerificationRequest(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('driver_verification_requests')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        return DriverVerificationRequest.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting driver verification request: $e');
      return null;
    }
  }

  /// Update driver verification status (admin function)
  Future<void> updateDriverVerificationStatus(
    String uid, 
    VerificationStatus status, 
    {String? rejectionReason}
  ) async {
    try {
      final updateData = {
        'status': status.toString().split('.').last,
        'verifiedAt': status == VerificationStatus.approved || status == VerificationStatus.rejected 
            ? DateTime.now().toIso8601String() 
            : null,
        'rejectionReason': rejectionReason,
      };

      // Update verification request
      await FirebaseFirestore.instance
          .collection('driver_verification_requests')
          .doc(uid)
          .update(updateData);

      // Update user model
      await _authService.updateUserData(uid, {
        'driverVerificationStatus': status.toString().split('.').last,
        'isVerified': status == VerificationStatus.approved,
        'updatedAt': DateTime.now(),
      });

      // Update local copy if this is the current user
      if (_userProfile?.uid == uid) {
        final updatedUserModel = UserModel(
          uid: _userProfile!.uid,
          email: _userProfile!.email,
          profile: _userProfile!.profile,
          accountType: _userProfile!.accountType,
          isVerified: status == VerificationStatus.approved,
          emergencyContacts: _userProfile!.emergencyContacts,
          preferences: _userProfile!.preferences,
          ratings: _userProfile!.ratings,
          createdAt: _userProfile!.createdAt,
          updatedAt: DateTime.now(),
          driverVerificationStatus: status,
          vehicleInfo: _userProfile!.vehicleInfo,
        );

        _userProfile = updatedUserModel;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating driver verification status: $e');
      rethrow;
    }
  }
  
  void clearProfile() {
    _userProfile = null;
    notifyListeners();
  }
}