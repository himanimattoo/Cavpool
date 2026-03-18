import 'dart:math';

class VerificationCodeUtils {
  static const int _codeLength = 4;
  static const int _codeExpireMinutes = 120; // 2 hours
  
  static String generateCode() {
    final random = Random();
    String code = '';
    
    for (int i = 0; i < _codeLength; i++) {
      code += random.nextInt(10).toString();
    }
    
    return code;
  }
  
  static DateTime getExpirationTime() {
    return DateTime.now().add(Duration(minutes: _codeExpireMinutes));
  }
  
  static bool isCodeExpired(DateTime? expiresAt) {
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt);
  }
  
  static bool isCodeValid(String? code) {
    if (code == null || code.isEmpty) return false;
    if (code.length != _codeLength) return false;
    return RegExp(r'^\d{4}$').hasMatch(code);
  }
  
  static String formatCodeForDisplay(String code) {
    if (code.length == 4) {
      return '${code.substring(0, 2)} ${code.substring(2, 4)}';
    }
    return code;
  }
  
  static bool codesMatch(String? code1, String? code2) {
    if (code1 == null || code2 == null) return false;
    return code1.trim() == code2.trim();
  }
}