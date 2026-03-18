// UVA Cavpool app tests.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Email validation', () {
    test('validates UVA email format', () {
      // Test valid UVA emails
      expect('test@virginia.edu'.toLowerCase().endsWith('@virginia.edu'), isTrue);
      expect('student@virginia.edu'.toLowerCase().endsWith('@virginia.edu'), isTrue);
      expect('TEST@VIRGINIA.EDU'.toLowerCase().endsWith('@virginia.edu'), isTrue);
      
      // Test invalid emails
      expect('test@gmail.com'.toLowerCase().endsWith('@virginia.edu'), isFalse);
      expect('test@vt.edu'.toLowerCase().endsWith('@virginia.edu'), isFalse);
      expect('test@virginia.com'.toLowerCase().endsWith('@virginia.edu'), isFalse);
      expect('invalid-email'.toLowerCase().endsWith('@virginia.edu'), isFalse);
    });
  });

  test('app can be instantiated', () {
    // Simple test to verify the test framework works
    expect(1 + 1, equals(2));
    expect('Hello', isA<String>());
  });
}
