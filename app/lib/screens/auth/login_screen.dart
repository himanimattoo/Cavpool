import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../../providers/auth_provider.dart';
import '../../services/credential_storage_service.dart';
import '../../exceptions/auth_exceptions.dart';
import '../../utils/auth_error_handler.dart';
import '../../widgets/enhanced_quick_account_switcher.dart';
import '../../widgets/animated_widgets.dart';
import '../../utils/ui_constants.dart';
import 'register_screen.dart';
import 'account_switcher_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? prefillEmail;
  
  const LoginScreen({super.key, this.prefillEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final CredentialStorageService _credentialService = CredentialStorageService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _saveCredentials = false;
  List<SavedCredential> _savedCredentials = [];

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    
    // Check for prefilled email from session expiry
    if (widget.prefillEmail != null) {
      _emailController.text = widget.prefillEmail!;
      _saveCredentials = true;
    } else {
      _loadDefaultAccount();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final credentials = await _credentialService.getSavedCredentials();
      setState(() {
        _savedCredentials = credentials;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadDefaultAccount() async {
    try {
      final defaultAccount = await _credentialService.getDefaultAccount();
      if (defaultAccount != null) {
        setState(() {
          _emailController.text = defaultAccount.email;
          _saveCredentials = true;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _handleQuickLogin(String email) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Find the credential by email to get the UID
      final credentials = await _credentialService.getSavedCredentials();
      final credential = credentials.where((c) => c.email == email).firstOrNull;
      
      if (credential == null) {
        throw AccountNotFoundException(email: email);
      }

      // Check if we have a valid token for this account
      final isTokenValid = await _credentialService.isTokenValid(credential.uid);
      
      if (!isTokenValid) {
        throw const SessionExpiredException();
      }
      
      // For now, we'll use a simplified approach where we just set the email
      // and let the user enter their password. In a production app, you'd 
      // implement proper token-based authentication
      setState(() {
        _emailController.text = email;
        _saveCredentials = true;
      });
      
      // Update last used timestamp
      await _credentialService.updateLastUsed(credential.uid);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account selected. Please enter your password to continue.',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFF38A169),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Use the new AuthErrorHandler for consistent error handling
        await AuthErrorHandler.handleAuthError(
          context: context,
          error: e,
          expiredAccountEmail: email,
          onSignIn: () {
            // Already on login screen - just reload saved credentials
            _loadSavedCredentials();
          },
          onSwitchAccount: () async {
            await _loadSavedCredentials();
          },
          onRetry: () => _handleQuickLogin(email),
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signIn(_emailController.text.trim(), _passwordController.text);
      
      // Save auth token securely if requested
      if (_saveCredentials) {
        final displayName = _extractDisplayNameFromEmail(_emailController.text);
        final user = authProvider.user;
        
        if (user != null) {
          final token = await user.getIdToken();
          if (token != null) {
            await _credentialService.saveAuthToken(
              user.uid,
              _emailController.text.trim(),
              token,
              displayName,
              profilePictureUrl: user.photoURL,
            );
          }
        }
      }
      
      // Navigate to home after successful login
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = _getReadableErrorMessage(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFFE53E3E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
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

  String _extractDisplayNameFromEmail(String email) {
    final prefix = email.split('@')[0];
    return prefix.split('.').map((part) => 
      part.isNotEmpty ? part[0].toUpperCase() + part.substring(1) : part
    ).join(' ');
  }

  String _getReadableErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return 'No account found with this email address. Please check your email or sign up.';
    } else if (error.contains('wrong-password') || error.contains('invalid-credential')) {
      return 'Incorrect password. Please try again or reset your password.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid UVA email address.';
    } else if (error.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many failed attempts. Please wait a moment before trying again.';
    } else if (error.contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else {
      return error.replaceAll('Exception: ', '');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        String errorMessage = _getReadableErrorMessage(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFFE53E3E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
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

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithApple();
    } catch (e) {
      if (mounted) {
        String errorMessage = _getReadableErrorMessage(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFFE53E3E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: UVAGradients.primaryBackground,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(UVASpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const SizedBox(height: UVASpacing.lg),
              FadeInSlide(
                delay: 100,
                child: Text(
                  'Welcome to',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: UVASpacing.md),
              // Enhanced UVA Logo with animations
              FadeInSlide(
                delay: 200,
                child: Hero(
                  tag: 'uva_logo',
                  child: Container(
                    height: 120,
                    width: 120,
                    margin: const EdgeInsets.symmetric(horizontal: UVASpacing.xxxl),
                    decoration: BoxDecoration(
                      gradient: UVAGradients.orangeAccent,
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: UVAColors.primaryOrange.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: UVASpacing.xl),
              FadeInSlide(
                delay: 400,
                child: Text(
                  'UVA Cavpool',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: UVASpacing.sm),
              FadeInSlide(
                delay: 600,
                child: Text(
                  'Connect with fellow Hoos for safe rides',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: UVASpacing.xl),
              FadeInSlide(
                delay: 800,
                child: EnhancedQuickAccountSwitcher(
                  onAccountSelected: (email) {
                    _handleQuickLogin(email);
                  },
                ),
              ),
              const SizedBox(height: UVASpacing.lg),
              FadeInSlide(
                delay: 1000,
                child: GlassMorphismCard(
                  padding: const EdgeInsets.all(UVASpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: UVACardStyles.modernTextField(
                            labelText: 'UVA Email',
                            hintText: 'abc1de@virginia.edu',
                            prefixIcon: const Icon(Icons.email, color: UVAColors.primaryOrange),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.toLowerCase().endsWith('@virginia.edu')) {
                              return 'Please use your @virginia.edu email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: UVASpacing.md),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: UVACardStyles.modernTextField(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock, color: UVAColors.primaryOrange),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: UVAColors.grey500,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: UVASpacing.lg),
                        BounceTap(
                          onTap: _isLoading ? null : _handleLogin,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: _isLoading ? null : UVAGradients.orangeAccent,
                              color: _isLoading ? UVAColors.grey400 : null,
                              borderRadius: BorderRadius.circular(UVABorderRadius.md),
                              boxShadow: _isLoading ? [] : [
                                BoxShadow(
                                  color: UVAColors.primaryOrange.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'Sign In',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_savedCredentials.isNotEmpty) ...[
                const SizedBox(height: UVASpacing.md),
                FadeInSlide(
                  delay: 1200,
                  child: BounceTap(
                    onTap: _isLoading ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AccountSwitcherScreen(
                            onAccountSelected: (email) {
                              _handleQuickLogin(email);
                            },
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: UVASpacing.md,
                        vertical: UVASpacing.sm,
                      ),
                      decoration: UVACardStyles.glassMorphism(
                        borderRadius: UVABorderRadius.md,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.manage_accounts,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: UVASpacing.sm),
                          Text(
                            'Manage Accounts (${_savedCredentials.length})',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: UVASpacing.md),
              Row(
                children: [
                  Transform.scale(
                    scale: 1.1,
                    child: Checkbox(
                      value: _saveCredentials,
                      onChanged: (value) {
                        setState(() {
                          _saveCredentials = value ?? false;
                        });
                      },
                      activeColor: UVAColors.primaryOrange,
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Remember this account',
                      style: GoogleFonts.inter(
                        color: UVAColors.grey600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: UVASpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.inter(
                      color: UVAColors.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: UVASpacing.lg),
              FadeInSlide(
                delay: 1400,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: UVASpacing.md),
                      child: Text(
                        'OR',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UVASpacing.md),
              FadeInSlide(
                delay: 1600,
                child: BounceTap(
                  onTap: _isLoading ? null : _handleGoogleSignIn,
                  child: GlassMorphismCard(
                    padding: const EdgeInsets.symmetric(vertical: UVASpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.g_mobiledata,
                            color: UVAColors.primaryOrange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: UVASpacing.md),
                        Text(
                          'Continue with Google',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Show Apple Sign In only on iOS
              if (!kIsWeb && Platform.isIOS) ...[
                const SizedBox(height: UVASpacing.sm),
                FadeInSlide(
                  delay: 1800,
                  child: BounceTap(
                    onTap: _isLoading ? null : () => _handleAppleSignIn(),
                    child: GlassMorphismCard(
                      padding: const EdgeInsets.symmetric(vertical: UVASpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.apple,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: UVASpacing.md),
                          Text(
                            'Continue with Apple',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: UVASpacing.xl),
              FadeInSlide(
                delay: 2000,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Don\'t have an account? ',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    BounceTap(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Sign Up',
                        style: GoogleFonts.inter(
                          color: UVAColors.primaryOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UVASpacing.lg),
            ],
            ),
          ),
        ),
      ),
    );
  }
}