import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'silent_flirt_service.dart';

class SilentFlirtChatSummary {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNicks;
  final int matchScore;
  final List<String> blockedBy;
  final List<String> closedBy;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const SilentFlirtChatSummary({
    required this.id,
    required this.participants,
    required this.participantNicks,
    required this.matchScore,
    required this.blockedBy,
    required this.closedBy,
    required this.updatedAt,
    required this.createdAt,
  });

  factory SilentFlirtChatSummary.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final updatedTs = d['updatedAt'];
    final createdTs = d['createdAt'];
    return SilentFlirtChatSummary(
      id: doc.id,
      participants: (d['participants'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      participantNicks: Map<String, String>.from(
        (d['participantNicks'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            const {},
      ),
      matchScore: (d['matchScore'] as num?)?.toInt() ?? 0,
      blockedBy: (d['blockedBy'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      closedBy: (d['closedBy'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      updatedAt: updatedTs is Timestamp ? updatedTs.toDate() : null,
      createdAt: createdTs is Timestamp ? createdTs.toDate() : null,
    );
  }
}

class SilentFlirtChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;

  const SilentFlirtChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory SilentFlirtChatMessage.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final ts = d['createdAt'];
    return SilentFlirtChatMessage(
      id: doc.id,
      senderId: (d['senderId'] ?? '').toString(),
      text: (d['text'] ?? '').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class SilentFlirtChatService {
  static CollectionReference<Map<String, dynamic>> get _chats =>
      AuthService.firestore.collection('silent_flirt_chats');

  static String _chatIdFromUsers(String a, String b) {
    final pair = [a, b]..sort();
    return 'sf_${pair[0]}_${pair[1]}';
  }

  static Future<String> openOrCreateChat({
    required SilentFlirtProfile myProfile,
    required SilentFlirtProfile otherProfile,
    required int matchScore,
  }) async {
    final me = AuthService.userId;
    if (me == null) throw Exception('Kullanıcı bulunamadı.');
    final chatId = _chatIdFromUsers(me, otherProfile.userId);
    final chatRef = _chats.doc(chatId);
    final baseData = <String, dynamic>{
      'participants': [me, otherProfile.userId],
      'participantNicks': {
        me: myProfile.nick,
        otherProfile.userId: otherProfile.nick,
      },
      'matchScore': matchScore,
      'blockedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Use merge-set directly; reading a non-existing doc can hit rules.
    await chatRef.set(baseData, SetOptions(merge: true));
    await chatRef.set({
      'closedBy': FieldValue.arrayRemove([me]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return chatId;
  }

  static Stream<List<SilentFlirtChatSummary>> watchMyChats() {
    final uid = AuthService.userId;
    if (uid == null) return Stream.value(const []);
    return _chats
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map(SilentFlirtChatSummary.fromDoc)
          .where((c) => !c.closedBy.contains(uid))
          .toList();
      list.sort((a, b) {
        final at = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
      return list;
    });
  }

  static Stream<SilentFlirtChatSummary?> watchChat(String chatId) {
    return _chats.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SilentFlirtChatSummary.fromDoc(doc);
    });
  }

  static Stream<List<SilentFlirtChatMessage>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(SilentFlirtChatMessage.fromDoc).toList());
  }

  static Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final uid = AuthService.userId;
    if (uid == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final ref = _chats.doc(chatId);
    await ref.collection('messages').add({
      'senderId': uid,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await ref.set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setBlocked({
    required String chatId,
    required bool blocked,
  }) async {
    final uid = AuthService.userId;
    if (uid == null) return;
    await _chats.doc(chatId).set({
      'blockedBy': blocked
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> closeChat(String chatId) async {
    final uid = AuthService.userId;
    if (uid == null) return;
    await _chats.doc(chatId).set({
      'closedBy': FieldValue.arrayUnion([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> reportChat({
    required String chatId,
    required String reason,
  }) async {
    final uid = AuthService.userId;
    if (uid == null) return;
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return;
    await AuthService.firestore.collection('silent_flirt_reports').add({
      'chatId': chatId,
      'reporterId': uid,
      'reason': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
