import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;
  final Logger _logger = Logger();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Force token refresh for debugging authentication issues
  Future<String?> forceTokenRefresh() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _logger.w('No authenticated user for token refresh');
        return null;
      }

      _logger.i('Forcing token refresh for user: ${user.email}');
      final token = await user.getIdToken(true);
      
      // Small delay to ensure token propagation
      await Future.delayed(const Duration(milliseconds: 200));
      
      _logger.i('Token refreshed successfully');
      return token;
    } catch (e) {
      _logger.e('Error forcing token refresh: $e');
      rethrow;
    }
  }

  // Debug authentication state
  Future<Map<String, dynamic>> getAuthDebugInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'authenticated': false};
      }

      final tokenResult = await user.getIdTokenResult(true);
      
      return {
        'authenticated': true,
        'uid': user.uid,
        'email': user.email,
        'emailVerified': user.emailVerified,
        'isUVAEmail': _isValidUVAEmail(user.email ?? ''),
        'tokenClaims': tokenResult.claims,
        'tokenExpiration': tokenResult.expirationTime?.toIso8601String(),
      };
    } catch (e) {
      _logger.e('Error getting auth debug info: $e');
      return {'error': e.toString()};
    }
  }

  // Auth state changes stream with error handling
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (e) {
      _logger.e('Error accessing auth state changes: $e');
      // Return a stream that emits null to indicate no authenticated user
      return Stream.value(null);
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      // Validate UVA email
      if (!_isValidUVAEmail(email)) {
        throw Exception('Please use a valid @virginia.edu email address');
      }

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } catch (e) {
      _logger.e('Error signing in: $e');
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
      String email, String password, Map<String, dynamic> userData) async {
    try {
      // Validate UVA email
      if (!_isValidUVAEmail(email)) {
        throw Exception('Please use a valid @virginia.edu email address');
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      if (result.user != null) {
        await _createUserDocument(result.user!, userData);
      }

      return result;
    } catch (e) {
      _logger.e('Error registering: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      _logger.e('Error signing out: $e');
      rethrow;
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      _logger.e('Error sending email verification: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      if (!_isValidUVAEmail(email)) {
        throw Exception('Please use a valid @virginia.edu email address');
      }
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      _logger.e('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Sign in with Google (UVA NetBadge)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web, use Firebase Auth popup to sign in with Google; this avoids plugin init issues
        final provider = GoogleAuthProvider();
        final UserCredential result = await _auth.signInWithPopup(provider);

        if (result.user == null) {
          throw Exception('Google sign-in failed on web');
        }

        await _createOrUpdateUserFromGoogle(
          result.user!,
          displayName: result.user!.displayName,
          photoUrl: result.user!.photoURL,
        );

        return result;
      } else {
        // Mobile/desktop flow using google_sign_in
        await _googleSignIn.signOut();

        final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

        // Validate UVA email domain
        if (!_isValidUVAEmail(googleUser.email)) {
          await _googleSignIn.signOut();
          throw Exception('Please use your @virginia.edu Google account');
        }

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final UserCredential result = await _auth.signInWithCredential(credential);

        if (result.user != null) {
          await _createOrUpdateUserFromGoogle(
            result.user!,
            displayName: googleUser.displayName,
            photoUrl: googleUser.photoUrl,
          );
        }

        return result;
      }
    } catch (e) {
      _logger.e('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
    try {
      // Check if Sign in with Apple is available
      if (!await SignInWithApple.isAvailable()) {
        throw Exception('Sign in with Apple is not available on this device');
      }

      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create Firebase credential
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with the Apple user credential
      final UserCredential result = await _auth.signInWithCredential(oauthCredential);

      // Create or update user document if this is a new user
      if (result.user != null) {
        await _createOrUpdateUserFromApple(result.user!, appleCredential);
      }

      return result;
    } catch (e) {
      _logger.e('Error signing in with Apple: $e');
      rethrow;
    }
  }

  // Validate UVA email
  bool _isValidUVAEmail(String email) {
    return email.toLowerCase().endsWith('@virginia.edu');
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(User user, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'profile': {
          'firstName': userData['firstName'] ?? '',
          'lastName': userData['lastName'] ?? '',
          'displayName': userData['displayName'] ?? user.displayName ?? '',
          'photoURL': userData['photoURL'] ?? user.photoURL ?? '',
          'pronouns': userData['pronouns'] ?? '',
          'bio': userData['bio'] ?? '',
          'phoneNumber': userData['phoneNumber'] ?? '',
        },
        'accountType': 'rider', // Default to rider
        'isVerified': false,
        'emergencyContacts': [],
        'preferences': {
          'allowSmoking': false,
          'allowPets': false,
          'musicPreference': 'driver_choice',
          'maxDetourTime': 15,
          'communicationStyle': 'friendly',
        },
        'ratings': {
          'averageRating': 0.0,
          'totalRatings': 0,
          'asDriver': {
            'averageRating': 0.0,
            'totalRatings': 0,
          },
          'asRider': {
            'averageRating': 0.0,
            'totalRatings': 0,
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Error creating user document: $e');
      rethrow;
    }
  }

  // Create user document for existing authenticated users who don't have a document
  Future<void> createUserDocumentForExistingUser(User user, Map<String, dynamic> userData) async {
    try {
      _logger.i('Creating user document for existing user: ${user.uid}');
      await _createUserDocument(user, userData);
    } catch (e) {
      _logger.e('Error creating user document for existing user: $e');
      rethrow;
    }
  }

  // Create or update user from Google sign-in
  Future<void> _createOrUpdateUserFromGoogle(User user, {String? displayName, String? photoUrl}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        // Create new user document
        final displayNameParts = (displayName ?? user.displayName ?? '').split(' ');
        final userData = {
          'firstName': displayNameParts.isNotEmpty ? displayNameParts[0] : '',
          'lastName': displayNameParts.length > 1 ? displayNameParts.sublist(1).join(' ') : '',
          'displayName': displayName ?? user.displayName ?? '',
          'photoURL': photoUrl ?? user.photoURL ?? '',
        };
        await _createUserDocument(user, userData);
      } else {
        // Update existing user with latest Google info
        await _firestore.collection('users').doc(user.uid).update({
          'profile.photoURL': photoUrl ?? user.photoURL ?? '',
          'profile.displayName': displayName ?? user.displayName ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _logger.e('Error creating/updating user from Google: $e');
      rethrow;
    }
  }

  // Create or update user from Apple sign-in
  Future<void> _createOrUpdateUserFromApple(User user, AuthorizationCredentialAppleID appleCredential) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        // Create new user document
        final givenName = appleCredential.givenName ?? '';
        final familyName = appleCredential.familyName ?? '';
        final displayName = '$givenName $familyName'.trim();
        
        final userData = {
          'firstName': givenName,
          'lastName': familyName,
          'displayName': displayName.isNotEmpty ? displayName : 'Apple User',
          'photoURL': '',
        };
        await _createUserDocument(user, userData);
      } else {
        // Update existing user with latest info if needed
        await _firestore.collection('users').doc(user.uid).update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _logger.e('Error creating/updating user from Apple: $e');
      rethrow;
    }
  }

  // Get user data from Firestore
  Future<DocumentSnapshot?> getUserData(String uid) async {
    try {
      return await _firestore.collection('users').doc(uid).get();
    } catch (e) {
      _logger.e('Error getting user data: $e');
      return null;
    }
  }

  // Update user data in Firestore
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      _logger.e('Error updating user data: $e');
      rethrow;
    }
  }
}