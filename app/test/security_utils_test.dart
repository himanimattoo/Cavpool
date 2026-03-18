import 'package:flutter_test/flutter_test.dart';
import 'package:capstone_orange_1/utils/security_utils.dart';

void main() {
  group('SecurityUtils Tests', () {
    group('Data Hashing', () {
      test('should hash data consistently', () {
        const testData = 'test@virginia.edu';
        
        final hash1 = SecurityUtils.hashData(testData);
        final hash2 = SecurityUtils.hashData(testData);
        
        expect(hash1, equals(hash2));
        expect(hash1, isNotEmpty);
      });

      test('should produce different hashes for different data', () {
        const data1 = 'user1@virginia.edu';
        const data2 = 'user2@virginia.edu';
        
        final hash1 = SecurityUtils.hashData(data1);
        final hash2 = SecurityUtils.hashData(data2);
        
        expect(hash1, isNot(equals(hash2)));
      });
    });

    group('Secure ID Generation', () {
      test('should generate unique IDs', () {
        final id1 = SecurityUtils.generateSecureId();
        final id2 = SecurityUtils.generateSecureId();
        
        expect(id1, isNot(equals(id2)));
        expect(id1.length, equals(32)); // Default length
      });

      test('should generate IDs of specified length', () {
        final shortId = SecurityUtils.generateSecureId(length: 16);
        final longId = SecurityUtils.generateSecureId(length: 64);
        
        expect(shortId.length, equals(16));
        expect(longId.length, equals(64));
      });
    });

    group('Data Obfuscation', () {
      test('should obfuscate and deobfuscate data correctly', () {
        const originalData = 'sensitive information';
        
        final obfuscated = SecurityUtils.obfuscateData(originalData);
        final deobfuscated = SecurityUtils.deobfuscateData(obfuscated);
        
        expect(obfuscated, isNot(equals(originalData)));
        expect(deobfuscated, equals(originalData));
      });

      test('should handle empty strings', () {
        const emptyString = '';
        
        final obfuscated = SecurityUtils.obfuscateData(emptyString);
        final deobfuscated = SecurityUtils.deobfuscateData(obfuscated);
        
        expect(obfuscated, equals(emptyString));
        expect(deobfuscated, equals(emptyString));
      });
    });

    group('Input Sanitization', () {
      test('should remove script tags', () {
        const maliciousInput = '<script>alert("xss")</script>Safe text';
        
        final sanitized = SecurityUtils.sanitizeInput(maliciousInput);
        
        expect(sanitized, equals('Safe text'));
        expect(sanitized, isNot(contains('<script>')));
      });

      test('should remove javascript URLs', () {
        const maliciousInput = 'javascript:alert("xss") some text';
        
        final sanitized = SecurityUtils.sanitizeInput(maliciousInput);
        
        expect(sanitized, isNot(contains('javascript:')));
      });

      test('should remove event handlers', () {
        const maliciousInput = 'onclick=alert("xss") text here';
        
        final sanitized = SecurityUtils.sanitizeInput(maliciousInput);
        
        expect(sanitized, isNot(contains('onclick=')));
      });

      test('should handle normal text without changes', () {
        const normalText = 'This is normal user input with punctuation!';
        
        final sanitized = SecurityUtils.sanitizeInput(normalText);
        
        expect(sanitized, equals(normalText));
      });
    });

    group('Email Validation', () {
      test('should validate correct email formats', () {
        const validEmails = [
          'user@example.com',
          'test.email@domain.co.uk',
          'user123@virginia.edu',
        ];

        for (final email in validEmails) {
          expect(SecurityUtils.isValidEmail(email), isTrue, 
            reason: '$email should be valid');
        }
      });

      test('should reject invalid email formats', () {
        const invalidEmails = [
          'notanemail',
          '@example.com',
          'user@',
          'user.example.com',
        ];

        for (final email in invalidEmails) {
          expect(SecurityUtils.isValidEmail(email), isFalse,
            reason: '$email should be invalid');
        }
      });

      test('should validate UVA emails specifically', () {
        const validUVAEmails = [
          'student@virginia.edu',
          'faculty@virginia.edu',
          'staff@virginia.edu',
        ];

        for (final email in validUVAEmails) {
          expect(SecurityUtils.isValidUVAEmail(email), isTrue,
            reason: '$email should be valid UVA email');
        }
      });

      test('should reject non-UVA emails', () {
        const nonUVAEmails = [
          'user@gmail.com',
          'student@vt.edu',
          'faculty@jmu.edu',
        ];

        for (final email in nonUVAEmails) {
          expect(SecurityUtils.isValidUVAEmail(email), isFalse,
            reason: '$email should not be valid UVA email');
        }
      });
    });

    group('Phone Number Validation', () {
      test('should validate correct phone number formats', () {
        const validPhones = [
          '1234567890',
          '123-456-7890',
          '(123) 456-7890',
          '+1 123 456 7890',
        ];

        for (final phone in validPhones) {
          expect(SecurityUtils.isValidPhoneNumber(phone), isTrue,
            reason: '$phone should be valid');
        }
      });

      test('should reject invalid phone number formats', () {
        const invalidPhones = [
          '123',
          'abcdefghij',
          '123-45-6789', // Wrong format
          '12345678901', // Too many digits
        ];

        for (final phone in invalidPhones) {
          expect(SecurityUtils.isValidPhoneNumber(phone), isFalse,
            reason: '$phone should be invalid');
        }
      });
    });

    group('Sensitive Information Detection', () {
      test('should detect SSN patterns', () {
        const textWithSSN = 'My SSN is 123-45-6789 please keep it safe';
        
        expect(SecurityUtils.containsSensitiveInfo(textWithSSN), isTrue);
      });

      test('should detect email patterns', () {
        const textWithEmail = 'Contact me at user@example.com for more info';
        
        expect(SecurityUtils.containsSensitiveInfo(textWithEmail), isTrue);
      });

      test('should not flag normal text', () {
        const normalText = 'This is just normal text without sensitive data';
        
        expect(SecurityUtils.containsSensitiveInfo(normalText), isFalse);
      });
    });

    group('Data Redaction', () {
      test('should redact email addresses', () {
        const textWithEmail = 'My email is user@virginia.edu';
        
        final redacted = SecurityUtils.redactSensitiveInfo(textWithEmail);
        
        expect(redacted, contains('XXX@virginia.edu'));
        expect(redacted, isNot(contains('user@virginia.edu')));
      });

      test('should redact phone numbers', () {
        const textWithPhone = 'Call me at 123-456-7890';
        
        final redacted = SecurityUtils.redactSensitiveInfo(textWithPhone);
        
        expect(redacted, contains('XXX-XXX-7890'));
        expect(redacted, isNot(contains('123-456-7890')));
      });

      test('should redact SSNs', () {
        const textWithSSN = 'My SSN is 123-45-6789';
        
        final redacted = SecurityUtils.redactSensitiveInfo(textWithSSN);
        
        expect(redacted, contains('XXX-XX-XXXX'));
        expect(redacted, isNot(contains('123-45-6789')));
      });
    });

    group('Safety Event Data Validation', () {
      test('should validate correct safety event data', () {
        final validEventData = {
          'title': 'Valid Safety Report',
          'description': 'This is a valid description.',
          'reporterId': 'user123',
        };

        final errors = SecurityUtils.validateSafetyEventData(validEventData);
        
        expect(errors, isEmpty);
      });

      test('should catch missing required fields', () {
        final invalidEventData = <String, dynamic>{
          'title': '',
          'description': '',
          'reporterId': '',
        };

        final errors = SecurityUtils.validateSafetyEventData(invalidEventData);
        
        expect(errors, isNotEmpty);
        expect(errors.containsKey('title'), isTrue);
        expect(errors.containsKey('description'), isTrue);
        expect(errors.containsKey('reporterId'), isTrue);
      });

      test('should catch data that is too long', () {
        final longTitle = 'A' * 300; // Over 200 character limit
        final longDescription = 'A' * 6000; // Over 5000 character limit
        
        final invalidEventData = {
          'title': longTitle,
          'description': longDescription,
          'reporterId': 'user123',
        };

        final errors = SecurityUtils.validateSafetyEventData(invalidEventData);
        
        expect(errors, isNotEmpty);
        expect(errors.containsKey('title'), isTrue);
        expect(errors.containsKey('description'), isTrue);
      });

      test('should sanitize input data', () {
        final eventDataWithScript = {
          'title': '<script>alert("xss")</script>Clean Title',
          'description': 'javascript:alert("xss") Clean description',
          'reporterId': 'user123',
        };

        final errors = SecurityUtils.validateSafetyEventData(eventDataWithScript);
        
        expect(errors, isEmpty);
        expect(eventDataWithScript['title'], equals('Clean Title'));
        expect(eventDataWithScript['description'], isNot(contains('javascript:')));
      });
    });

    group('Audit Trail Generation', () {
      test('should generate valid audit entries', () {
        final auditEntry = SecurityUtils.generateAuditEntry(
          'safety_event_created',
          'user123',
          {'eventId': 'event456', 'severity': 'high'},
        );

        expect(auditEntry['timestamp'], isNotNull);
        expect(auditEntry['action'], equals('safety_event_created'));
        expect(auditEntry['userId'], equals('user123'));
        expect(auditEntry['userIdHash'], isNotNull);
        expect(auditEntry['details'], isNotNull);
        expect(auditEntry['auditId'], isNotNull);
      });
    });

    group('Privacy Compliant Data Export', () {
      test('should create privacy compliant export', () {
        final safetyEvents = [
          {
            'id': 'event1',
            'timestamp': '2024-01-01T10:00:00Z',
            'eventType': 'user_reported',
            'status': 'pending',
            'severity': 'medium',
            'description': 'User reported unsafe driving with license plate ABC-123',
            'isAnonymous': false,
            'metadata': {
              'location': 'secret location',
              'deviceInfo': 'sensitive device info',
              'reportMethod': 'in_app',
            },
          },
        ];

        final export = SecurityUtils.createPrivacyCompliantExport(
          safetyEvents,
          'user123',
        );

        expect(export['userId'], isNot(equals('user123'))); // Should be hashed
        expect(export['events'], hasLength(1));
        
        final exportedEvent = export['events'][0];
        expect(exportedEvent['description'], isNot(contains('ABC-123'))); // Should be redacted
        expect(exportedEvent['metadata'], isNot(containsPair('location', anything))); // Should be removed
        expect(exportedEvent['metadata'], containsPair('reportMethod', 'in_app')); // Should be kept
      });
    });
  });
}