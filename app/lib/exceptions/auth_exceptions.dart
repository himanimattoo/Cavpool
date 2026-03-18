class AuthException implements Exception {
  final String message;
  final String userFriendlyMessage;
  final AuthExceptionType type;
  final bool isRecoverable;

  const AuthException({
    required this.message,
    required this.userFriendlyMessage,
    required this.type,
    this.isRecoverable = true,
  });

  @override
  String toString() => message;
}

enum AuthExceptionType {
  sessionExpired,
  accountNotFound,
  invalidCredentials,
  biometricFailed,
  networkError,
  unknown,
}

class SessionExpiredException extends AuthException {
  const SessionExpiredException({
    String? customMessage,
  }) : super(
          message: customMessage ?? 'Session has expired',
          userFriendlyMessage: 'Your session has expired for security. Please sign in again to continue.',
          type: AuthExceptionType.sessionExpired,
          isRecoverable: true,
        );
}

class AccountNotFoundException extends AuthException {
  const AccountNotFoundException({
    String? email,
  }) : super(
          message: 'Account not found${email != null ? ' for $email' : ''}',
          userFriendlyMessage: 'This account is no longer available. Please sign in with your current credentials.',
          type: AuthExceptionType.accountNotFound,
          isRecoverable: true,
        );
}

class BiometricAuthenticationException extends AuthException {
  const BiometricAuthenticationException({
    String? reason,
  }) : super(
          message: 'Biometric authentication failed${reason != null ? ': $reason' : ''}',
          userFriendlyMessage: 'Biometric authentication didn\'t work. Please try again or use your password.',
          type: AuthExceptionType.biometricFailed,
          isRecoverable: true,
        );
}