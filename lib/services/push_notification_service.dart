import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

class PushNotificationService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;

      // Request user permission for push notifications.
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await _syncCurrentToken();

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        await _saveToken(token);
      });
    } catch (e) {
      debugPrint('PushNotificationService init error: $e');
    }
  }

  static Future<void> _syncCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await _saveToken(token);
    } catch (e) {
      debugPrint('PushNotificationService getToken error: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    final uid = AuthService.userId;
    if (uid == null || token.trim().isEmpty) return;

    try {
      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens')
          .doc(token)
          .set({
        'token': token,
        'enabled': true,
        'platform': _platformName(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PushNotificationService saveToken error: $e');
    }
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
