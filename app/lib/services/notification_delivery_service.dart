import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum NotificationDeliveryMethod { sms, email, push }

enum NotificationDeliveryStatus { 
  pending, 
  sent, 
  delivered, 
  failed, 
  retrying 
}

class NotificationDeliveryService {
  static final NotificationDeliveryService _instance = NotificationDeliveryService._internal();
  factory NotificationDeliveryService() => _instance;
  NotificationDeliveryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _deliveryQueueCollection = 'notification_delivery_queue';

  // Configuration - In production, these would come from secure environment variables
static const String _twilioAccountSid = 'your_twilio_account_sid';
static const String _twilioAuthToken = 'your_twilio_auth_token';
static const String _messagingServiceSid = 'your_messaging_service_sid';
static const String _sendGridApiKey = 'your_sendgrid_api_key';
static const String _fromEmail = 'safety@cavpool.virginia.edu';

  /// Send SMS message via Twilio
  Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
    String? emergencyType,
  }) async {
    try {
      // For development/demo: Queue the message instead of actual sending
      if (kDebugMode || _twilioAccountSid == 'your_twilio_account_sid') {
        return await _queueNotification(
          method: NotificationDeliveryMethod.sms,
          recipient: phoneNumber,
          message: message,
          emergencyType: emergencyType,
        );
      }

      // Production SMS sending via Twilio
      final url = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Messages.json');
      final auth = base64Encode(utf8.encode('$_twilioAccountSid:$_twilioAuthToken'));

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $auth',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'To': phoneNumber,
          'MessagingServiceSid': _messagingServiceSid,
          'Body': message,
        },
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        await _logDeliveryAttempt(
          method: NotificationDeliveryMethod.sms,
          recipient: phoneNumber,
          status: NotificationDeliveryStatus.sent,
          externalId: responseData['sid'],
          message: message,
        );
        debugPrint('SMS sent successfully to $phoneNumber');
        return true;
      } else {
        await _logDeliveryAttempt(
          method: NotificationDeliveryMethod.sms,
          recipient: phoneNumber,
          status: NotificationDeliveryStatus.failed,
          error: 'HTTP ${response.statusCode}: ${response.body}',
          message: message,
        );
        debugPrint('Failed to send SMS: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      await _logDeliveryAttempt(
        method: NotificationDeliveryMethod.sms,
        recipient: phoneNumber,
        status: NotificationDeliveryStatus.failed,
        error: e.toString(),
        message: message,
      );
      debugPrint('Error sending SMS: $e');
      return false;
    }
  }

  /// Send email via SendGrid
  Future<bool> sendEmail({
    required String email,
    required String subject,
    required String message,
    String? emergencyType,
  }) async {
    try {
      // For development/demo: Queue the message instead of actual sending
      if (kDebugMode || _sendGridApiKey == 'your_sendgrid_api_key') {
        return await _queueNotification(
          method: NotificationDeliveryMethod.email,
          recipient: email,
          message: message,
          subject: subject,
          emergencyType: emergencyType,
        );
      }

      // Production email sending via SendGrid
      final url = Uri.parse('https://api.sendgrid.com/v3/mail/send');

      final emailData = {
        'personalizations': [
          {
            'to': [
              {'email': email}
            ],
            'subject': subject,
          }
        ],
        'from': {'email': _fromEmail, 'name': 'CavPool Safety Team'},
        'content': [
          {
            'type': 'text/plain',
            'value': message,
          }
        ],
        'categories': ['emergency', 'safety'],
        'custom_args': {
          'emergency_type': emergencyType ?? 'general',
          'platform': 'cavpool',
        },
      };

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_sendGridApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(emailData),
      );

      if (response.statusCode == 202) {
        await _logDeliveryAttempt(
          method: NotificationDeliveryMethod.email,
          recipient: email,
          status: NotificationDeliveryStatus.sent,
          message: message,
          subject: subject,
        );
        debugPrint('Email sent successfully to $email');
        return true;
      } else {
        await _logDeliveryAttempt(
          method: NotificationDeliveryMethod.email,
          recipient: email,
          status: NotificationDeliveryStatus.failed,
          error: 'HTTP ${response.statusCode}: ${response.body}',
          message: message,
          subject: subject,
        );
        debugPrint('Failed to send email: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      await _logDeliveryAttempt(
        method: NotificationDeliveryMethod.email,
        recipient: email,
        status: NotificationDeliveryStatus.failed,
        error: e.toString(),
        message: message,
        subject: subject,
      );
      debugPrint('Error sending email: $e');
      return false;
    }
  }

  /// Send emergency notification (both SMS and email for redundancy)
  Future<Map<NotificationDeliveryMethod, bool>> sendEmergencyNotification({
    required String phoneNumber,
    required String email,
    required String message,
    String emergencyType = 'emergency',
  }) async {
    final results = <NotificationDeliveryMethod, bool>{};

    // Send SMS
    if (phoneNumber.isNotEmpty) {
      results[NotificationDeliveryMethod.sms] = await sendSMS(
        phoneNumber: phoneNumber,
        message: message,
        emergencyType: emergencyType,
      );
    }

    // Send Email
    if (email.isNotEmpty) {
      results[NotificationDeliveryMethod.email] = await sendEmail(
        email: email,
        subject: '🚨 CavPool Emergency Alert',
        message: message,
        emergencyType: emergencyType,
      );
    }

    return results;
  }

  /// Queue notification for later processing (development/fallback)
  Future<bool> _queueNotification({
    required NotificationDeliveryMethod method,
    required String recipient,
    required String message,
    String? subject,
    String? emergencyType,
  }) async {
    try {
      final queueEntry = {
        'method': method.name,
        'recipient': recipient,
        'message': message,
        'subject': subject,
        'emergencyType': emergencyType,
        'status': NotificationDeliveryStatus.pending.name,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'scheduledFor': Timestamp.fromDate(DateTime.now()),
        'attempts': 0,
        'maxAttempts': 3,
        'lastAttemptAt': null,
        'metadata': {
          'platform': 'mobile',
          'priority': emergencyType == 'emergency' ? 'critical' : 'normal',
        },
      };

      await _firestore.collection(_deliveryQueueCollection).add(queueEntry);

      // In development, also log to console for visibility
      debugPrint('📱 ${method.name.toUpperCase()} queued for $recipient');
      debugPrint('📄 Message: ${message.substring(0, 100)}${message.length > 100 ? "..." : ""}');
      
      return true;
    } catch (e) {
      debugPrint('Error queueing notification: $e');
      return false;
    }
  }

  /// Log delivery attempt for audit and retry logic
  Future<void> _logDeliveryAttempt({
    required NotificationDeliveryMethod method,
    required String recipient,
    required NotificationDeliveryStatus status,
    String? externalId,
    String? error,
    String? message,
    String? subject,
  }) async {
    try {
      await _firestore.collection('notification_delivery_logs').add({
        'method': method.name,
        'recipient': _sanitizeRecipient(recipient),
        'status': status.name,
        'externalId': externalId,
        'error': error,
        'messageLength': message?.length ?? 0,
        'subject': subject,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'userAgent': 'CavPool-Mobile-App',
      });
    } catch (e) {
      debugPrint('Error logging delivery attempt: $e');
    }
  }

  /// Sanitize recipient data for logging (privacy)
  String _sanitizeRecipient(String recipient) {
    if (recipient.contains('@')) {
      // Email: show first char + domain
      final parts = recipient.split('@');
      return '${parts[0][0]}***@${parts[1]}';
    } else {
      // Phone: show last 4 digits
      return '***${recipient.substring(recipient.length - 4)}';
    }
  }

  /// Process queued notifications (for background processing)
  Future<void> processQueuedNotifications() async {
    try {
      final pendingNotifications = await _firestore
          .collection(_deliveryQueueCollection)
          .where('status', isEqualTo: NotificationDeliveryStatus.pending.name)
          .where('scheduledFor', isLessThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .limit(10)
          .get();

      for (final doc in pendingNotifications.docs) {
        await _processQueuedNotification(doc.id, doc.data());
      }
    } catch (e) {
      debugPrint('Error processing queued notifications: $e');
    }
  }

  /// Process individual queued notification
  Future<void> _processQueuedNotification(String docId, Map<String, dynamic> data) async {
    try {
      final method = NotificationDeliveryMethod.values.firstWhere(
        (m) => m.name == data['method'],
      );

      bool success = false;

      switch (method) {
        case NotificationDeliveryMethod.sms:
          success = await sendSMS(
            phoneNumber: data['recipient'],
            message: data['message'],
            emergencyType: data['emergencyType'],
          );
          break;
        case NotificationDeliveryMethod.email:
          success = await sendEmail(
            email: data['recipient'],
            subject: data['subject'] ?? 'CavPool Notification',
            message: data['message'],
            emergencyType: data['emergencyType'],
          );
          break;
        case NotificationDeliveryMethod.push:
          // Push notifications would be handled here
          break;
      }

      // Update queue entry
      final attempts = (data['attempts'] ?? 0) + 1;
      final updateData = {
        'attempts': attempts,
        'lastAttemptAt': Timestamp.fromDate(DateTime.now()),
      };

      if (success) {
        updateData['status'] = NotificationDeliveryStatus.sent.name;
        updateData['sentAt'] = Timestamp.fromDate(DateTime.now());
      } else {
        if (attempts >= (data['maxAttempts'] ?? 3)) {
          updateData['status'] = NotificationDeliveryStatus.failed.name;
        } else {
          updateData['status'] = NotificationDeliveryStatus.retrying.name;
          // Schedule retry with exponential backoff
          updateData['scheduledFor'] = Timestamp.fromDate(
            DateTime.now().add(Duration(minutes: attempts * attempts * 5))
          );
        }
      }

      await _firestore.collection(_deliveryQueueCollection).doc(docId).update(updateData);

    } catch (e) {
      debugPrint('Error processing individual notification: $e');
    }
  }

  /// Get delivery statistics
  Future<Map<String, dynamic>> getDeliveryStats() async {
    try {
      final stats = <String, dynamic>{};
      
      for (final method in NotificationDeliveryMethod.values) {
        final methodStats = await _getMethodStats(method);
        stats[method.name] = methodStats;
      }
      
      return stats;
    } catch (e) {
      debugPrint('Error getting delivery stats: $e');
      return {};
    }
  }

  /// Get statistics for specific delivery method
  Future<Map<String, int>> _getMethodStats(NotificationDeliveryMethod method) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    
    final logs = await _firestore
        .collection('notification_delivery_logs')
        .where('method', isEqualTo: method.name)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
        .get();

    int sent = 0;
    int failed = 0;
    
    for (final doc in logs.docs) {
      final status = doc.data()['status'];
      if (status == NotificationDeliveryStatus.sent.name || 
          status == NotificationDeliveryStatus.delivered.name) {
        sent++;
      } else if (status == NotificationDeliveryStatus.failed.name) {
        failed++;
      }
    }
    
    return {
      'sent': sent,
      'failed': failed,
      'total': sent + failed,
    };
  }
}