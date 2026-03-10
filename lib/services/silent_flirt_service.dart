import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

class SilentFlirtProfile {
  final String userId;
  final String nick;
  final String ageRange;
  final String intent;
  final String mood;
  final List<String> traits;
  final String chatPace;
  final String? boundary;
  final String? firstLine;
  final DateTime? expiresAt;

  const SilentFlirtProfile({
    required this.userId,
    required this.nick,
    required this.ageRange,
    required this.intent,
    required this.mood,
    required this.traits,
    required this.chatPace,
    required this.boundary,
    required this.firstLine,
    required this.expiresAt,
  });

  factory SilentFlirtProfile.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final expiresRaw = d['expiresAt'];
    return SilentFlirtProfile(
      userId: (d['userId'] ?? doc.id).toString(),
      nick: (d['nick'] ?? '').toString(),
      ageRange: (d['ageRange'] ?? '').toString(),
      intent: (d['intent'] ?? '').toString(),
      mood: (d['mood'] ?? '').toString(),
      traits: (d['traits'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      chatPace: (d['chatPace'] ?? '').toString(),
      boundary: d['boundary']?.toString(),
      firstLine: d['firstLine']?.toString(),
      expiresAt: expiresRaw is Timestamp ? expiresRaw.toDate() : null,
    );
  }
}

class SilentFlirtService {
  static CollectionReference<Map<String, dynamic>> get _profiles =>
      AuthService.firestore.collection('silent_flirt_profiles');

  static Stream<SilentFlirtProfile?> watchMyProfile() {
    final uid = AuthService.userId;
    if (uid == null) return Stream.value(null);
    return _profiles.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final profile = SilentFlirtProfile.fromDoc(doc);
      final expiresAt = profile.expiresAt;
      if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
        return null;
      }
      return profile;
    });
  }

  static Future<SilentFlirtProfile?> getMyProfile() async {
    final uid = AuthService.userId;
    if (uid == null) return null;
    final doc = await _profiles.doc(uid).get();
    if (!doc.exists) return null;
    final profile = SilentFlirtProfile.fromDoc(doc);
    final expiresAt = profile.expiresAt;
    if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
      return null;
    }
    return profile;
  }

  static Stream<List<SilentFlirtProfile>> watchDiscoverProfiles() {
    final uid = AuthService.userId;
    if (uid == null) return Stream.value(const []);
    return _profiles
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: false)
        .limit(60)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(SilentFlirtProfile.fromDoc)
              .where((p) =>
                  p.userId != uid &&
                  p.expiresAt != null &&
                  p.expiresAt!.isAfter(DateTime.now()))
              .toList(),
        );
  }

  static Future<void> saveMyProfile({
    required String nick,
    required String ageRange,
    required String intent,
    required String mood,
    required List<String> traits,
    required String chatPace,
    String? boundary,
    String? firstLine,
  }) async {
    final uid = AuthService.userId;
    if (uid == null) return;

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));
    await _profiles.doc(uid).set({
      'userId': uid,
      'nick': nick.trim(),
      'ageRange': ageRange,
      'intent': intent,
      'mood': mood,
      'traits': traits,
      'chatPace': chatPace,
      'boundary': boundary?.trim().isEmpty == true ? null : boundary?.trim(),
      'firstLine': firstLine?.trim().isEmpty == true ? null : firstLine?.trim(),
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    }, SetOptions(merge: true));
  }

  static int matchScore({
    required SilentFlirtProfile mine,
    required SilentFlirtProfile other,
  }) {
    final traitMatch = mine.traits.toSet().intersection(other.traits.toSet()).length;
    int score = traitMatch;
    if (mine.intent == other.intent) score += 1;
    if (mine.ageRange == other.ageRange) score += 1;
    return score;
  }
}
