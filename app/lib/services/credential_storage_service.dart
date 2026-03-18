import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'biometric_auth_service.dart';

class SavedCredential {
  final String uid;
  final String email;
  final String displayName;
  final String lastUsed;
  final bool isDefault;
  final bool biometricEnabled;
  final DateTime? tokenExpiry;
  final String? profilePictureUrl;

  SavedCredential({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.lastUsed,
    this.isDefault = false,
    this.biometricEnabled = false,
    this.tokenExpiry,
    this.profilePictureUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'lastUsed': lastUsed,
      'isDefault': isDefault,
      'biometricEnabled': biometricEnabled,
      'tokenExpiry': tokenExpiry?.toIso8601String(),
      'profilePictureUrl': profilePictureUrl,
    };
  }

  factory SavedCredential.fromMap(Map<String, dynamic> map) {
    return SavedCredential(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      lastUsed: map['lastUsed'] ?? '',
      isDefault: map['isDefault'] ?? false,
      biometricEnabled: map['biometricEnabled'] ?? false,
      tokenExpiry: map['tokenExpiry'] != null 
          ? DateTime.parse(map['tokenExpiry']) 
          : null,
      profilePictureUrl: map['profilePictureUrl'],
    );
  }

  SavedCredential copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? lastUsed,
    bool? isDefault,
    bool? biometricEnabled,
    DateTime? tokenExpiry,
    String? profilePictureUrl,
  }) {
    return SavedCredential(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      lastUsed: lastUsed ?? this.lastUsed,
      isDefault: isDefault ?? this.isDefault,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    );
  }

  bool get isTokenExpired {
    if (tokenExpiry == null) return true;
    return DateTime.now().isAfter(tokenExpiry!);
  }

  bool get hasValidToken {
    return !isTokenExpired;
  }
}

class CredentialStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _credentialsKey = 'saved_credentials';
  final Logger _logger = Logger();
  final BiometricAuthService _biometricService = BiometricAuthService();

  Future<void> saveAuthToken(String uid, String email, String authToken, String displayName, {DateTime? tokenExpiry, String? profilePictureUrl}) async {
    try {
      if (!_isValidUVAEmail(email)) {
        throw Exception('Invalid UVA email address');
      }

      List<SavedCredential> credentials = await getSavedCredentials();
      
      final existingIndex = credentials.indexWhere((c) => c.uid == uid);
      if (existingIndex != -1) {
        credentials.removeAt(existingIndex);
      }

      final newCredential = SavedCredential(
        uid: uid,
        email: email.toLowerCase(),
        displayName: displayName.isNotEmpty ? displayName : _extractNameFromEmail(email),
        lastUsed: DateTime.now().toIso8601String(),
        isDefault: credentials.isEmpty,
        tokenExpiry: tokenExpiry ?? DateTime.now().add(const Duration(hours: 24)),
        profilePictureUrl: profilePictureUrl,
      );

      credentials.insert(0, newCredential);

      if (credentials.length > 5) {
        credentials = credentials.take(5).toList();
      }

      await _storage.write(
        key: _credentialsKey,
        value: json.encode(credentials.map((c) => c.toMap()).toList()),
      );

      await _storage.write(
        key: '${uid}_auth_token',
        value: authToken,
      );

      _logger.i('Auth token saved for UID: $uid, email: $email');
    } catch (e) {
      _logger.e('Error saving auth token: $e');
      rethrow;
    }
  }

  Future<List<SavedCredential>> getSavedCredentials() async {
    try {
      final credentialsJson = await _storage.read(key: _credentialsKey);
      if (credentialsJson == null) return [];

      final List<dynamic> credentialsList = json.decode(credentialsJson);
      return credentialsList.map((c) => SavedCredential.fromMap(c)).toList();
    } catch (e) {
      _logger.e('Error getting saved credentials: $e');
      return [];
    }
  }

  Future<String?> getAuthToken(String uid, {bool requireBiometric = false}) async {
    try {
      final credentials = await getSavedCredentials();
      final credential = credentials.where((c) => c.uid == uid).firstOrNull;
      
      if (credential == null) {
        _logger.w('No credential found for UID: $uid');
        return null;
      }

      if (credential.isTokenExpired) {
        _logger.w('Token expired for UID: $uid, attempting refresh...');
        // Try to refresh token instead of removing credentials
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && user.uid == uid) {
            final newToken = await user.getIdToken(true);
            if (newToken != null) {
              await saveAuthToken(user.uid, user.email ?? credential.email, newToken, user.displayName ?? credential.displayName);
              _logger.i('Token refreshed successfully for UID: $uid');
              return newToken;
            } else {
              _logger.w('Failed to get token from Firebase Auth');
              await removeCredentials(uid);
              return null;
            }
          } else {
            _logger.w('No matching authenticated user for credential refresh');
            await removeCredentials(uid);
            return null;
          }
        } catch (e) {
          _logger.e('Failed to refresh token for UID $uid: $e');
          await removeCredentials(uid);
          return null;
        }
      }

      if (requireBiometric || credential.biometricEnabled) {
        final authResult = await _biometricService.authenticateForCredentialAccess(credential.email);
        if (authResult != BiometricAuthResult.success) {
          throw Exception(_biometricService.getErrorMessage(authResult));
        }
      }

      final authToken = await _storage.read(key: '${uid}_auth_token');
      if (authToken == null) {
        _logger.w('No auth token found for UID: $uid, attempting refresh...');
        // Try to refresh token instead of removing credentials
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && user.uid == uid) {
            final newToken = await user.getIdToken(true);
            if (newToken != null) {
              await saveAuthToken(user.uid, user.email ?? credential.email, newToken, user.displayName ?? credential.displayName);
              _logger.i('Token refreshed and saved for UID: $uid');
              return newToken;
            } else {
              _logger.w('Failed to get token from Firebase Auth');
              await removeCredentials(uid);
              return null;
            }
          } else {
            _logger.w('No matching authenticated user for token refresh');
            await removeCredentials(uid);
            return null;
          }
        } catch (e) {
          _logger.e('Failed to refresh token for UID $uid: $e');
          await removeCredentials(uid);
          return null;
        }
      }
      
      return authToken;
    } catch (e) {
      _logger.e('Error getting auth token for UID $uid: $e');
      rethrow;
    }
  }

  Future<String?> getAuthTokenWithBiometric(String uid) async {
    return getAuthToken(uid, requireBiometric: true);
  }

  Future<void> removeCredentials(String uid) async {
    try {
      // Check if user is currently authenticated with this UID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        _logger.i('Not removing credentials for currently authenticated user: $uid');
        return;
      }

      List<SavedCredential> credentials = await getSavedCredentials();
      credentials.removeWhere((c) => c.uid == uid);

      await _storage.write(
        key: _credentialsKey,
        value: json.encode(credentials.map((c) => c.toMap()).toList()),
      );

      await _storage.delete(key: '${uid}_auth_token');

      if (credentials.isNotEmpty && !credentials.any((c) => c.isDefault)) {
        await setDefaultAccount(credentials.first.uid);
      }

      _logger.i('Credentials removed for UID: $uid');
      _logger.d('Stack trace: ${StackTrace.current}');
    } catch (e) {
      _logger.e('Error removing credentials: $e');
      rethrow;
    }
  }

  Future<void> setDefaultAccount(String uid) async {
    try {
      List<SavedCredential> credentials = await getSavedCredentials();
      
      for (int i = 0; i < credentials.length; i++) {
        credentials[i] = SavedCredential(
          uid: credentials[i].uid,
          email: credentials[i].email,
          displayName: credentials[i].displayName,
          lastUsed: credentials[i].lastUsed,
          isDefault: credentials[i].uid == uid,
          biometricEnabled: credentials[i].biometricEnabled,
          tokenExpiry: credentials[i].tokenExpiry,
        );
      }

      await _storage.write(
        key: _credentialsKey,
        value: json.encode(credentials.map((c) => c.toMap()).toList()),
      );

      final credential = credentials.where((c) => c.uid == uid).firstOrNull;
      _logger.i('Default account set to UID: $uid, email: ${credential?.email}');
    } catch (e) {
      _logger.e('Error setting default account: $e');
      rethrow;
    }
  }

  Future<SavedCredential?> getDefaultAccount() async {
    try {
      final credentials = await getSavedCredentials();
      return credentials.where((c) => c.isDefault).firstOrNull;
    } catch (e) {
      _logger.e('Error getting default account: $e');
      return null;
    }
  }

  Future<void> updateLastUsed(String uid) async {
    try {
      List<SavedCredential> credentials = await getSavedCredentials();
      
      for (int i = 0; i < credentials.length; i++) {
        if (credentials[i].uid == uid) {
          credentials[i] = SavedCredential(
            uid: credentials[i].uid,
            email: credentials[i].email,
            displayName: credentials[i].displayName,
            lastUsed: DateTime.now().toIso8601String(),
            isDefault: credentials[i].isDefault,
            biometricEnabled: credentials[i].biometricEnabled,
            tokenExpiry: credentials[i].tokenExpiry,
          );
          break;
        }
      }

      credentials.sort((a, b) => DateTime.parse(b.lastUsed).compareTo(DateTime.parse(a.lastUsed)));

      await _storage.write(
        key: _credentialsKey,
        value: json.encode(credentials.map((c) => c.toMap()).toList()),
      );
    } catch (e) {
      _logger.e('Error updating last used: $e');
    }
  }

  Future<void> clearAllCredentials() async {
    try {
      final credentials = await getSavedCredentials();
      for (final credential in credentials) {
        await _storage.delete(key: '${credential.uid}_auth_token');
      }
      await _storage.delete(key: _credentialsKey);
      _logger.i('All credentials cleared');
    } catch (e) {
      _logger.e('Error clearing all credentials: $e');
      rethrow;
    }
  }

  Future<bool> get isBiometricAvailable => _biometricService.isBiometricAvailable;

  Future<String> get biometricDisplayName => _biometricService.getBiometricDisplayName();

  Future<bool> enableBiometricForAccount(String uid) async {
    try {
      // Get credential to find email for biometric service
      List<SavedCredential> credentials = await getSavedCredentials();
      final credential = credentials.where((c) => c.uid == uid).firstOrNull;
      
      if (credential == null) {
        throw Exception('No credential found for UID: $uid');
      }

      // First authenticate with biometric to ensure it works
      final authResult = await _biometricService.authenticateForCredentialAccess(credential.email);
      if (authResult != BiometricAuthResult.success) {
        throw Exception(_biometricService.getErrorMessage(authResult));
      }

      // Update the credential to enable biometric
      for (int i = 0; i < credentials.length; i++) {
        if (credentials[i].uid == uid) {
          credentials[i] = credentials[i].copyWith(biometricEnabled: true);
          break;
        }
      }

      await _storage.write(
        key: _credentialsKey,
        value: json.encode(credentials.map((c) => c.toMap()).toList()),
      );

      _logger.i('Biometric enabled for UID: $uid, email: ${credential.email}');
      return true;
    } catch (e) {
      _logger.e('Error enabling biometric for UID $uid: $e');
      rethrow;
    }
  }

  Future<void> disableBiometricForAccount(String uid) async {
    try {
      List<SavedCredential> credentials = await getSavedCredentials();
      
      for (int i = 0; i < credentials.length; i++) {
        if (credentials[i].uid == uid) {
          credentials[i] = credentials[i].copyWith(biometricEnabled: false);
          break;
        }
      }

      await _storage.write(
        key: _credentialsKey,
        value: json.encode(credentials.map((c) => c.toMap()).toList()),
      );

      final credential = credentials.where((c) => c.uid == uid).firstOrNull;
      _logger.i('Biometric disabled for UID: $uid, email: ${credential?.email}');
    } catch (e) {
      _logger.e('Error disabling biometric for UID $uid: $e');
      rethrow;
    }
  }

  Future<bool> isBiometricEnabledForAccount(String uid) async {
    try {
      final credentials = await getSavedCredentials();
      final credential = credentials.where((c) => c.uid == uid).firstOrNull;
      return credential?.biometricEnabled ?? false;
    } catch (e) {
      _logger.e('Error checking biometric status for UID $uid: $e');
      return false;
    }
  }

  bool _isValidUVAEmail(String email) {
    return email.toLowerCase().endsWith('@virginia.edu');
  }

  String _extractNameFromEmail(String email) {
    final prefix = email.split('@')[0];
    return prefix.split('.').map((part) => 
      part.isNotEmpty ? part[0].toUpperCase() + part.substring(1) : part
    ).join(' ');
  }


  Future<bool> isTokenValid(String uid) async {
    try {
      final credentials = await getSavedCredentials();
      final credential = credentials.where((c) => c.uid == uid).firstOrNull;
      return credential?.hasValidToken ?? false;
    } catch (e) {
      _logger.e('Error checking token validity for UID $uid: $e');
      return false;
    }
  }

  Future<void> refreshTokenExpiry(String uid, DateTime newExpiry) async {
    try {
      List<SavedCredential> credentials = await getSavedCredentials();
      
      for (int i = 0; i < credentials.length; i++) {
        if (credentials[i].uid == uid) {
          credentials[i] = credentials[i].copyWith(tokenExpiry: newExpiry);
          break;
        }
      }

      await _storage.write(
        key: _credentialsKey,
        value: json.encode(credentials.map((c) => c.toMap()).toList()),
      );

      final credential = credentials.where((c) => c.uid == uid).firstOrNull;
      _logger.i('Token expiry updated for UID: $uid, email: ${credential?.email}');
    } catch (e) {
      _logger.e('Error updating token expiry for UID $uid: $e');
      rethrow;
    }
  }
}