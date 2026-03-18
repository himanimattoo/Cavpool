import 'package:flutter_test/flutter_test.dart';
import 'package:capstone_orange_1/models/safety_event_model.dart';

void main() {
  group('SafetyService Tests', () {
    test('should create safety event model with valid data', () {
      // Test the data model instead of Firebase service calls
      final now = DateTime.now();
      final testEvent = SafetyEventModel(
        id: 'test-123',
        eventType: SafetyEventType.userReported,
        incidentType: SafetyIncidentType.harassment,
        reporterId: 'test-user-123',
        reportedUserId: 'reported-user-456',
        title: 'Inappropriate behavior',
        description: 'Driver was making inappropriate comments',
        severity: SafetyEventSeverity.medium,
        status: SafetyEventStatus.pending,
        evidence: [],
        createdAt: now,
        updatedAt: now,
        tags: ['harassment', 'driver'],
        systemData: {'source': 'mobile_app'},
        isAnonymous: false,
        timestamp: now,
        metadata: {
          'rideId': 'ride-789',
          'reportMethod': 'in_app',
        },
      );

      // Test model properties
      expect(testEvent.eventType, equals(SafetyEventType.userReported));
      expect(testEvent.title, equals('Inappropriate behavior'));
      expect(testEvent.reporterId, equals('test-user-123'));
      expect(testEvent.severity, equals(SafetyEventSeverity.medium));
      expect(testEvent.isAnonymous, equals(false));
    });

    test('should validate required safety event fields', () {
      // Test that required fields are present
      final now = DateTime.now();
      final validEvent = SafetyEventModel(
        id: 'test-456',
        eventType: SafetyEventType.emergencyButton,
        incidentType: SafetyIncidentType.other,
        reporterId: 'user-123',
        reportedUserId: null,
        title: 'Emergency Button Pressed',
        description: 'User activated emergency button',
        severity: SafetyEventSeverity.high,
        status: SafetyEventStatus.pending,
        evidence: [],
        createdAt: now,
        updatedAt: now,
        tags: ['emergency'],
        systemData: {'source': 'emergency_button'},
        isAnonymous: false,
        timestamp: now,
        metadata: {
          'location': '38.0356,-78.5034',
          'batteryLevel': '85%',
        },
      );

      expect(validEvent.reporterId.isNotEmpty, isTrue);
      expect(validEvent.title.isNotEmpty, isTrue);
      expect(validEvent.description.isNotEmpty, isTrue);
      expect(validEvent.eventType, equals(SafetyEventType.emergencyButton));
      expect(validEvent.severity, equals(SafetyEventSeverity.high));
    });
  });
}