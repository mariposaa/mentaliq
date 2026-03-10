import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';

class EmergencyContact {
  final String name;
  final String phone;
  final String relation;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });

  bool get isValid => name.trim().isNotEmpty && phone.trim().isNotEmpty;
}

class EmergencyContactService {
  static const String _docId = 'emergency_contact';

  static Future<EmergencyContact?> getContact() async {
    final uid = AuthService.userId;
    if (uid == null) return null;
    try {
      final doc = await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('safety')
          .doc(_docId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      final contact = EmergencyContact(
        name: (data['name'] ?? '').toString(),
        phone: (data['phone'] ?? '').toString(),
        relation: (data['relation'] ?? '').toString(),
      );
      return contact.isValid ? contact : null;
    } catch (e) {
      debugPrint('EmergencyContactService get error: $e');
      return null;
    }
  }

  static Future<void> saveContact(EmergencyContact contact) async {
    final uid = AuthService.userId;
    if (uid == null) return;
    await AuthService.firestore
        .collection('users')
        .doc(uid)
        .collection('safety')
        .doc(_docId)
        .set({
      'name': contact.name.trim(),
      'phone': contact.phone.trim(),
      'relation': contact.relation.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  static String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  static Future<bool> callContact(EmergencyContact contact) async {
    final phone = _normalizePhone(contact.phone);
    final uri = Uri.parse('tel:$phone');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('EmergencyContactService call error: $e');
      return false;
    }
  }

  static Future<bool> smsContact(EmergencyContact contact, String message) async {
    final phone = _normalizePhone(contact.phone);
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('EmergencyContactService sms error: $e');
      return false;
    }
  }
}
