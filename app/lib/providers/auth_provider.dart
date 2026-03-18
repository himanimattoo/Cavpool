import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  
  // Callbacks to cleanup other providers on logout
  final List<VoidCallback> _cleanupCallbacks = [];

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  // Add cleanup callback for other providers
  void addCleanupCallback(VoidCallback callback) {
    _cleanupCallbacks.add(callback);
  }

  // Execute all cleanup callbacks (called on logout)
  void _executeCleanupCallbacks() {
    debugPrint('Executing ${_cleanupCallbacks.length} cleanup callbacks');
    for (final callback in _cleanupCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error executing cleanup callback: $e');
      }
    }
  }

  AuthProvider() {
    try {
      _authService.authStateChanges.listen(
        (User? user) {
          _user = user;
          if (user != null) {
            reloadUserData();
          } else {
            _userModel = null;
            // Execute cleanup callbacks when user logs out
            _executeCleanupCallbacks();
          }
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Auth state error: $error');
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Error setting up auth listener: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadUserData() async {
    if (_user == null) return;
    
    try {
      final doc = await _authService.getUserData(_user!.uid);
      if (doc != null && doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
      } else {
        debugPrint('User document does not exist for uid: ${_user!.uid}');
        // Create a user document for existing authenticated users
        await _createMissingUserDocument();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      _userModel = null;
    }
    notifyListeners();
  }

  Future<void> _createMissingUserDocument() async {
    if (_user == null) return;
    
    try {
      debugPrint('Creating missing user document for uid: ${_user!.uid}');
      
      // Extract name from email or display name
      String firstName = '';
      String lastName = '';
      String displayName = _user!.displayName ?? '';
      
      if (displayName.isNotEmpty) {
        final nameParts = displayName.split(' ');
        firstName = nameParts.isNotEmpty ? nameParts[0] : '';
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      } else if (_user!.email != null) {
        // Extract name from email prefix
        final emailPrefix = _user!.email!.split('@')[0];
        displayName = emailPrefix;
        firstName = emailPrefix;
      }
      
      final userData = {
        'firstName': firstName,
        'lastName': lastName,
        'displayName': displayName,
        'photoURL': _user!.photoURL ?? '',
      };
      
      // Create the document directly using the auth service
      await _authService.createUserDocumentForExistingUser(_user!, userData);
      
      // Try to load the user data again
      final doc = await _authService.getUserData(_user!.uid);
      if (doc != null && doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
        debugPrint('Successfully created and loaded user document');
      }
      
    } catch (e) {
      debugPrint('Error creating missing user document: $e');
      _userModel = null;
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signInWithEmailAndPassword(email, password);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signUp(String email, String password, Map<String, dynamic> userData) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.registerWithEmailAndPassword(email, password, userData);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      // Explicitly clear user data to prevent stale state
      _user = null;
      _userModel = null;
      // Execute cleanup callbacks on explicit logout
      _executeCleanupCallbacks();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signInWithApple() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signInWithApple();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateUserData(Map<String, dynamic> data) async {
    if (_user == null) return;

    try {
      await _authService.updateUserData(_user!.uid, data);
      await reloadUserData(); // Reload user data after update
    } catch (e) {
      rethrow;
    }
  }
}