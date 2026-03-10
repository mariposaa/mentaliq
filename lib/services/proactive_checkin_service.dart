import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'user_dna_service.dart';
import 'addiction_service.dart';
import 'safety_event_service.dart';

class CheckInSchedule {
  final bool enabled;
  final List<int> hours;

  const CheckInSchedule({
    required this.enabled,
    required this.hours,
  });
}

class ProactiveCheckInService {
  static const String _enabledKey = 'proactive_checkin_enabled';
  static const String _hoursKey = 'proactive_checkin_hours';
  static const List<int> _defaultHours = [10, 16, 21];
  static Timer? _inAppTimer;
  static bool _schedulerStarted = false;

  static Future<void> initialize() async {
    await runDueCheckIns();
    startInAppScheduler();
  }

  static void startInAppScheduler() {
    if (_schedulerStarted) return;
    _schedulerStarted = true;
    _inAppTimer?.cancel();
    _inAppTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      runDueCheckIns();
    });
  }

  static Future<CheckInSchedule> getSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? true;
    final stored = prefs.getStringList(_hoursKey);
    final parsed = (stored ?? _defaultHours.map((h) => '$h').toList())
        .map(int.tryParse)
        .whereType<int>()
        .where((h) => h >= 0 && h <= 23)
        .toSet()
        .toList()
      ..sort();

    return CheckInSchedule(enabled: enabled, hours: parsed.isEmpty ? _defaultHours : parsed);
  }

  static Future<void> saveSchedule(CheckInSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, schedule.enabled);
    await prefs.setStringList(_hoursKey, schedule.hours.map((h) => '$h').toList());
  }

  static String _slotKey(DateTime now) {
    return '${now.year}-${now.month}-${now.day}-${now.hour}';
  }

  static Future<void> runDueCheckIns({DateTime? now}) async {
    final uid = AuthService.userId;
    if (uid == null) return;

    final schedule = await getSchedule();
    if (!schedule.enabled) return;

    final current = now ?? DateTime.now();
    if (!schedule.hours.contains(current.hour)) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'proactive_checkin_sent_${_slotKey(current)}';
    if (prefs.getBool(key) == true) return;

    final addictions = UserDNAService.currentDNA?.activeAddictions ?? const [];
    if (addictions.isEmpty) return;

    final sorted = [...addictions]..sort((a, b) {
      final sa = AddictionService.getSnapshot(a.id).riskScore;
      final sb = AddictionService.getSnapshot(b.id).riskScore;
      return sb.compareTo(sa);
    });
    final top = sorted.first;
    final topSnapshot = AddictionService.getSnapshot(top.id);
    final nudge = await AddictionService.getProactiveNudge(top.id);

    try {
      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'type': 'addiction_checkin',
        'title': 'Proactive Check-in',
        'message': nudge,
        'addictionId': top.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (topSnapshot.riskScore >= 85) {
        await AuthService.firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .add({
          'type': 'addiction_mandatory_checkin',
          'title': 'High Risk Check-in Required',
          'message': 'Risk seviyesi cok yuksek. Simdi 60 sn check-in yap.',
          'addictionId': top.id,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await SafetyEventService.log(
          type: SafetyEventType.forcedCheckInTriggered,
          addictionId: top.id,
          severity: 'high',
          data: {'riskScore': topSnapshot.riskScore},
        );
      }

      await prefs.setBool(key, true);
    } catch (e) {
      debugPrint('ProactiveCheckInService create notification error: $e');
    }
  }
}
