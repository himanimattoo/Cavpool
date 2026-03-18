import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

class SecurityUtils {
  static const String _encryptionKey = 'CAVPOOL_SAFETY_KEY_2024'; // In production, use secure key management
  
  /// Hash sensitive data using a simple hash (not cryptographically secure)
  /// For production use, implement proper SHA-256 with crypto package
  static String hashData(String data) {
    return data.hashCode.abs().toString();
  }

  /// Generate a secure random string for IDs or tokens
  static String generateSecureId({int length = 32}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        length, 
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// Simple obfuscation for sensitive data (not true encryption, but better than plain text)
  /// For true encryption, use packages like encrypt or pointycastle
  static String obfuscateData(String data) {
    if (data.isEmpty) return data;
    
    try {
      final bytes = utf8.encode(data);
      final key = utf8.encode(_encryptionKey);
      
      // Simple XOR obfuscation
      final obfuscated = <int>[];
      for (int i = 0; i < bytes.length; i++) {
        obfuscated.add(bytes[i] ^ key[i % key.length]);
      }
      
      return base64.encode(obfuscated);
    } catch (e) {
      debugPrint('Error obfuscating data: $e');
      return data; // Return original if obfuscation fails
    }
  }

  /// Deobfuscate data that was obfuscated with obfuscateData
  static String deobfuscateData(String obfuscatedData) {
    if (obfuscatedData.isEmpty) return obfuscatedData;
    
    try {
      final obfuscated = base64.decode(obfuscatedData);
      final key = utf8.encode(_encryptionKey);
      
      // Simple XOR deobfuscation (same operation as obfuscation)
      final deobfuscated = <int>[];
      for (int i = 0; i < obfuscated.length; i++) {
        deobfuscated.add(obfuscated[i] ^ key[i % key.length]);
      }
      
      return utf8.decode(deobfuscated);
    } catch (e) {
      debugPrint('Error deobfuscating data: $e');
      return obfuscatedData; // Return original if deobfuscation fails
    }
  }

  /// Sanitize user input to prevent injection attacks
  static String sanitizeInput(String input) {
    if (input.isEmpty) return input;
    
    return input
      .replaceAll(RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>'), '') // Remove script tags
      .replaceAll(RegExp(r'javascript:', caseSensitive: false), '') // Remove javascript: URLs
      .replaceAll(RegExp(r'on\w+\s*='), '') // Remove event handlers
      .trim();
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  /// Validate UVA email specifically
  static bool isValidUVAEmail(String email) {
    if (!isValidEmail(email)) return false;
    return email.toLowerCase().endsWith('@virginia.edu');
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phone) {
    // Clean the phone number but preserve structure for validation
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return false;
    
    // Check for valid US phone number patterns
    final phoneRegex = RegExp(r'^\+?1?[-.\s]?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})$');
    
    // Also check digit count - only accept 10 digits for plain numbers, 11 only if properly formatted with country code
    final digitsOnly = cleaned.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length == 10) {
      return phoneRegex.hasMatch(cleaned);
    } else if (digitsOnly.length == 11) {
      // 11 digits only valid if it starts with +1 or 1 and has proper formatting
      return phoneRegex.hasMatch(cleaned) && (cleaned.startsWith('+1') || cleaned.startsWith('1 ') || cleaned.startsWith('1-') || cleaned.startsWith('1.'));
    } else {
      return false;
    }
  }

  /// Check if a string contains potentially sensitive information
  static bool containsSensitiveInfo(String text) {
    final sensitivePatterns = [
      RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), // SSN pattern
      RegExp(r'\b4[0-9]{12}(?:[0-9]{3})?\b'), // Visa card pattern
      RegExp(r'\b5[1-5][0-9]{14}\b'), // Mastercard pattern
      RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'), // Generic card pattern
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), // Email pattern
    ];

    for (final pattern in sensitivePatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  /// Mask detailed address information for privacy while preserving general location context
  static String maskAddress(String fullAddress, {bool preserveStreetName = true}) {
    if (fullAddress.isEmpty) return fullAddress;
    
    try {
      // Common address patterns to mask
      var maskedAddress = fullAddress;
      
      // Mask house/building numbers but preserve street names
      if (preserveStreetName) {
        // Pattern for addresses starting with numbers (123 Main St)
        maskedAddress = maskedAddress.replaceAllMapped(
          RegExp(r'^(\d+)\s+(.+)$'),
          (match) => 'Near ${match.group(2)}',
        );
        
        // Pattern for addresses with apartment/unit numbers (123 Main St Apt 4B)
        maskedAddress = maskedAddress.replaceAllMapped(
          RegExp(r'^(\d+)\s+(.+?)\s+(Apt|Unit|Suite|#)\s*(.+)$', caseSensitive: false),
          (match) => 'Near ${match.group(2)}',
        );
      } else {
        // More aggressive masking - only show general area
        maskedAddress = maskedAddress.replaceAllMapped(
          RegExp(r'^.*?([A-Za-z\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way|Circle|Cir|Court|Ct|Place|Pl)).*$', caseSensitive: false),
          (match) => 'Near ${match.group(1)}',
        );
      }
      
      // Remove specific unit/apartment details
      maskedAddress = maskedAddress.replaceAll(RegExp(r'\s+(Apt|Unit|Suite|#)\s*\w+', caseSensitive: false), '');
      
      // Clean up extra spaces
      maskedAddress = maskedAddress.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      return maskedAddress;
    } catch (e) {
      debugPrint('Error masking address: $e');
      return 'General Area'; // Fallback to generic location
    }
  }
  
  /// Get neighborhood or general area from full address
  static String getGeneralLocation(String fullAddress) {
    if (fullAddress.isEmpty) return fullAddress;
    
    try {
      // Extract neighborhood, city, or area information
      final parts = fullAddress.split(',');
      
      if (parts.length >= 2) {
        // Return the second part which is usually neighborhood/city
        return parts[1].trim();
      } else {
        // Fallback to masked street name
        return maskAddress(fullAddress, preserveStreetName: true);
      }
    } catch (e) {
      debugPrint('Error extracting general location: $e');
      return 'General Area';
    }
  }

  /// Redact sensitive information from text
  static String redactSensitiveInfo(String text) {
    var redacted = text;
    
    // Redact license plates first (more specific patterns)
    // Common US license plate formats
    redacted = redacted.replaceAll(
      RegExp(r'\b[A-Z]{3}-\d{3}\b|\b[A-Z]{2}\d{4}\b|\b\d{3}[A-Z]{3}\b|\b[A-Z]\d{2}[A-Z]\d{2}\b'),
      '[REDACTED PLATE]',
    );
    
    // Redact SSN
    redacted = redacted.replaceAll(RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), 'XXX-XX-XXXX');
    
    // Redact phone numbers (keep last 4 digits)
    redacted = redacted.replaceAllMapped(
      RegExp(r'\b(\+?1?[-.\s]?\(?[0-9]{3}\)?[-.\s]?[0-9]{3})[-.\s]?([0-9]{4})\b'),
      (match) => 'XXX-XXX-${match.group(2)}',
    );
    
    // Redact email addresses (keep domain)
    redacted = redacted.replaceAllMapped(
      RegExp(r'\b([A-Za-z0-9._%+-]+)@([A-Za-z0-9.-]+\.[A-Z|a-z]{2,})\b'),
      (match) => 'XXX@${match.group(2)}',
    );
    
    return redacted;
  }

  /// Generate a safety event audit trail entry
  static Map<String, dynamic> generateAuditEntry(
    String action,
    String userId,
    Map<String, dynamic> details,
  ) {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'action': action,
      'userId': userId,
      'userIdHash': hashData(userId),
      'details': details,
      'auditId': generateSecureId(length: 16),
    };
  }

  /// Validate safety event data before storing
  static Map<String, String> validateSafetyEventData(Map<String, dynamic> eventData) {
    final errors = <String, String>{};
    
    // Required fields validation
    if (eventData['title']?.toString().trim().isEmpty ?? true) {
      errors['title'] = 'Title is required';
    }
    
    if (eventData['description']?.toString().trim().isEmpty ?? true) {
      errors['description'] = 'Description is required';
    }
    
    if (eventData['reporterId']?.toString().trim().isEmpty ?? true) {
      errors['reporterId'] = 'Reporter ID is required';
    }
    
    // Data length validation
    if ((eventData['title']?.toString().length ?? 0) > 200) {
      errors['title'] = 'Title must be 200 characters or less';
    }
    
    if ((eventData['description']?.toString().length ?? 0) > 5000) {
      errors['description'] = 'Description must be 5000 characters or less';
    }
    
    // Sanitize text fields
    if (eventData['title'] != null) {
      eventData['title'] = sanitizeInput(eventData['title'].toString());
    }
    
    if (eventData['description'] != null) {
      eventData['description'] = sanitizeInput(eventData['description'].toString());
    }
    
    return errors;
  }

  /// Create a privacy-compliant data export for a user
  static Map<String, dynamic> createPrivacyCompliantExport(
    List<Map<String, dynamic>> safetyEvents,
    String userId,
  ) {
    final exportData = <String, dynamic>{
      'exportDate': DateTime.now().toIso8601String(),
      'userId': hashData(userId), // Use hash instead of actual ID
      'events': [],
    };
    
    for (final event in safetyEvents) {
      final exportEvent = <String, dynamic>{
        'eventId': event['id'],
        'timestamp': event['timestamp'],
        'eventType': event['eventType'],
        'status': event['status'],
        'severity': event['severity'],
        'description': redactSensitiveInfo(event['description'] ?? ''),
        'isAnonymous': event['isAnonymous'] ?? false,
      };
      
      // Only include non-sensitive metadata
      if (event['metadata'] != null) {
        final metadata = Map<String, dynamic>.from(event['metadata']);
        metadata.removeWhere((key, value) => 
          key.toLowerCase().contains('location') ||
          key.toLowerCase().contains('device') ||
          key.toLowerCase().contains('ip'));
        exportEvent['metadata'] = metadata;
      }
      
      exportData['events'].add(exportEvent);
    }
    
    return exportData;
  }

  /// Log security events for monitoring
  static void logSecurityEvent(String eventType, Map<String, dynamic> details) {
    final logEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'eventType': eventType,
      'details': details,
      'severity': _getSecurityEventSeverity(eventType),
    };
    
    // In production, send to security monitoring system
    debugPrint('SECURITY EVENT: ${jsonEncode(logEntry)}');
  }

  static String _getSecurityEventSeverity(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'unauthorized_access':
      case 'data_breach':
      case 'injection_attempt':
        return 'critical';
      case 'failed_authentication':
      case 'suspicious_activity':
        return 'high';
      case 'rate_limit_exceeded':
      case 'invalid_input':
        return 'medium';
      default:
        return 'low';
    }
  }
}