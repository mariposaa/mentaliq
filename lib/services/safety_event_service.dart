import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

enum SafetyEventType {
  crisisKeywordDetected,
  crisisChatMessage,
  safetyActionsOpened,
  emergencyContactCallAttempt,
  emergencyContactSmsAttempt,
  hotlineCallAttempt,
  forcedCheckInTriggered,
}

class SafetyEventService {
  static const List<String> severityLevels = ['all', 'critical', 'high', 'medium', 'low'];

  static String _typeKey(SafetyEventType type) {
    switch (type) {
      case SafetyEventType.crisisKeywordDetected:
        return 'crisis_keyword_detected';
      case SafetyEventType.crisisChatMessage:
        return 'crisis_chat_message';
      case SafetyEventType.safetyActionsOpened:
        return 'safety_actions_opened';
      case SafetyEventType.emergencyContactCallAttempt:
        return 'emergency_contact_call_attempt';
      case SafetyEventType.emergencyContactSmsAttempt:
        return 'emergency_contact_sms_attempt';
      case SafetyEventType.hotlineCallAttempt:
        return 'hotline_call_attempt';
      case SafetyEventType.forcedCheckInTriggered:
        return 'forced_checkin_triggered';
    }
  }

  static Future<void> log({
    required SafetyEventType type,
    String? addictionId,
    String? severity,
    Map<String, dynamic>? data,
  }) async {
    final uid = AuthService.userId;
    if (uid == null) return;
    try {
      await AuthService.firestore.collection('safety_events').add({
        'uid': uid,
        'type': _typeKey(type),
        'addictionId': addictionId ?? '',
        'severity': severity ?? 'medium',
        'data': data ?? const <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('SafetyEventService log error: $e');
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamRecent({
    int limit = 50,
  }) {
    return AuthService.firestore
        .collection('safety_events')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}
