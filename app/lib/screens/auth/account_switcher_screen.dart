import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/credential_storage_service.dart';
import '../../exceptions/auth_exceptions.dart';
import '../../utils/auth_error_handler.dart';

class AccountSwitcherScreen extends StatefulWidget {
  final Function(String email)? onAccountSelected;
  
  const AccountSwitcherScreen({
    super.key,
    this.onAccountSelected,
  });

  @override
  State<AccountSwitcherScreen> createState() => _AccountSwitcherScreenState();
}

class _AccountSwitcherScreenState extends State<AccountSwitcherScreen> {
  final CredentialStorageService _credentialService = CredentialStorageService();
  List<SavedCredential> _savedCredentials = [];
  bool _isLoading = true;
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _credentialService.isBiometricAvailable;
      setState(() {
        _isBiometricAvailable = isAvailable;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final credentials = await _credentialService.getSavedCredentials();
      setState(() {
        _savedCredentials = credentials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading saved accounts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectAccount(SavedCredential credential) async {
    try {
      // Validate authentication
      if (credential.biometricEnabled && _isBiometricAvailable) {
        // Use biometric authentication to validate
        await _credentialService.getAuthTokenWithBiometric(credential.uid);
      } else {
        // Check if token is valid
        final hasValidToken = await _credentialService.isTokenValid(credential.uid);
        if (!hasValidToken) {
          throw const SessionExpiredException();
        }
      }

      // Update usage and callback
      await _credentialService.updateLastUsed(credential.uid);
      
      if (widget.onAccountSelected != null) {
        widget.onAccountSelected!(credential.email);
      } else {
        // For direct usage without callback, just show that account is selected
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account ${credential.email} selected. Please complete authentication.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        await AuthErrorHandler.handleAuthError(
          context: context,
          error: e,
          expiredAccountEmail: credential.email,
          onSignIn: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
          onSwitchAccount: () async {
            await _loadSavedCredentials();
          },
          onRetry: () => _selectAccount(credential),
        );
      }
    }
  }

  Future<void> _setDefaultAccount(String uid) async {
    try {
      await _credentialService.setDefaultAccount(uid);
      await _loadSavedCredentials();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default account updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update default account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeAccount(String uid) async {
    try {
      await _credentialService.removeCredentials(uid);
      await _loadSavedCredentials();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _enableBiometric(String uid) async {
    try {
      await _credentialService.enableBiometricForAccount(uid);
      await _loadSavedCredentials();
      
      final biometricName = await _credentialService.biometricDisplayName;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$biometricName enabled for this account'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enable biometric: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disableBiometric(String uid) async {
    try {
      await _credentialService.disableBiometricForAccount(uid);
      await _loadSavedCredentials();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication disabled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disable biometric: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRemoveAccountDialog(SavedCredential credential) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Account',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to remove ${credential.email} from saved accounts?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeAccount(credential.uid);
            },
            child: Text(
              'Remove',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232F3E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
        title: Text(
          'Saved Accounts',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE57200),
              ),
            )
          : _savedCredentials.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No saved accounts',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with an account to save it for quick access',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savedCredentials.length,
                  itemBuilder: (context, index) {
                    final credential = _savedCredentials[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: credential.isDefault
                            ? Border.all(color: const Color(0xFFE57200), width: 2)
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFE57200),
                              child: Text(
                                credential.displayName.isNotEmpty
                                    ? credential.displayName[0].toUpperCase()
                                    : credential.email[0].toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (credential.biometricEnabled)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.fingerprint,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          credential.displayName.isNotEmpty
                              ? credential.displayName
                              : credential.email.split('@')[0],
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              credential.email,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (credential.isDefault)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE57200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Default',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'default':
                                _setDefaultAccount(credential.uid);
                                break;
                              case 'biometric_enable':
                                _enableBiometric(credential.uid);
                                break;
                              case 'biometric_disable':
                                _disableBiometric(credential.uid);
                                break;
                              case 'remove':
                                _showRemoveAccountDialog(credential);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            if (!credential.isDefault)
                              PopupMenuItem<String>(
                                value: 'default',
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_outline, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Set as default',
                                      style: GoogleFonts.inter(),
                                    ),
                                  ],
                                ),
                              ),
                            if (_isBiometricAvailable && !credential.biometricEnabled)
                              PopupMenuItem<String>(
                                value: 'biometric_enable',
                                child: Row(
                                  children: [
                                    const Icon(Icons.fingerprint, size: 18, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Enable biometric',
                                      style: GoogleFonts.inter(),
                                    ),
                                  ],
                                ),
                              ),
                            if (credential.biometricEnabled)
                              PopupMenuItem<String>(
                                value: 'biometric_disable',
                                child: Row(
                                  children: [
                                    const Icon(Icons.fingerprint, size: 18, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Disable biometric',
                                      style: GoogleFonts.inter(),
                                    ),
                                  ],
                                ),
                              ),
                            PopupMenuItem<String>(
                              value: 'remove',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Remove',
                                    style: GoogleFonts.inter(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _selectAccount(credential),
                      ),
                    );
                  },
                ),
    );
  }
}