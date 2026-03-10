import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'silent_flirt_service.dart';

class LocalSilentFlirtMessage {
  final String id;
  final String text;
  final bool isMine;
  final bool isSystem;
  final DateTime createdAt;

  const LocalSilentFlirtMessage({
    required this.id,
    required this.text,
    required this.isMine,
    required this.isSystem,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isMine': isMine,
      'isSystem': isSystem,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
    };
  }

  factory LocalSilentFlirtMessage.fromJson(Map<String, dynamic> json) {
    return LocalSilentFlirtMessage(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      isMine: json['isMine'] == true,
      isSystem: json['isSystem'] == true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

class LocalSilentFlirtChat {
  final String chatId;
  final String partnerUserId;
  final String partnerNick;
  final int matchScore;
  final bool isBlocked;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<LocalSilentFlirtMessage> messages;

  const LocalSilentFlirtChat({
    required this.chatId,
    required this.partnerUserId,
    required this.partnerNick,
    required this.matchScore,
    required this.isBlocked,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'partnerUserId': partnerUserId,
      'partnerNick': partnerNick,
      'matchScore': matchScore,
      'isBlocked': isBlocked,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'updatedAtMs': updatedAt.millisecondsSinceEpoch,
      'messages': messages.map((e) => e.toJson()).toList(),
    };
  }

  factory LocalSilentFlirtChat.fromJson(Map<String, dynamic> json) {
    final rawMessages = (json['messages'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(LocalSilentFlirtMessage.fromJson)
        .toList();
    return LocalSilentFlirtChat(
      chatId: (json['chatId'] ?? '').toString(),
      partnerUserId: (json['partnerUserId'] ?? '').toString(),
      partnerNick: (json['partnerNick'] ?? '').toString(),
      matchScore: (json['matchScore'] as num?)?.toInt() ?? 0,
      isBlocked: json['isBlocked'] == true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      messages: rawMessages,
    );
  }
}

class LocalSilentFlirtChatService {
  static const _chatsKey = 'silent_flirt_local_chats_v1';
  static const _reportsKey = 'silent_flirt_local_reports_v1';

  static Future<List<LocalSilentFlirtChat>> getChats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatsKey);
    if (raw == null || raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    final chats = decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(LocalSilentFlirtChat.fromJson)
        .toList();
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return chats;
  }

  static Future<LocalSilentFlirtChat?> getChatById(String chatId) async {
    final chats = await getChats();
    for (final chat in chats) {
      if (chat.chatId == chatId) return chat;
    }
    return null;
  }

  static Future<String> openOrCreateFromProfile({
    required SilentFlirtProfile profile,
    required int matchScore,
  }) async {
    final chats = await getChats();
    final now = DateTime.now();
    final existingIndex = chats.indexWhere((c) => c.partnerUserId == profile.userId);
    if (existingIndex >= 0) {
      final existing = chats[existingIndex];
      chats[existingIndex] = LocalSilentFlirtChat(
        chatId: existing.chatId,
        partnerUserId: existing.partnerUserId,
        partnerNick: profile.nick,
        matchScore: matchScore,
        isBlocked: existing.isBlocked,
        createdAt: existing.createdAt,
        updatedAt: now,
        messages: existing.messages,
      );
      await _saveChats(chats);
      return existing.chatId;
    }

    final chatId = 'sf_${profile.userId}_${now.millisecondsSinceEpoch}';
    final systemMessage = LocalSilentFlirtMessage(
      id: 'sys_${now.millisecondsSinceEpoch}',
      text: 'Yerel sohbet aktif. Mesajlar sadece cihazinda tutulur.',
      isMine: false,
      isSystem: true,
      createdAt: now,
    );
    chats.add(
      LocalSilentFlirtChat(
        chatId: chatId,
        partnerUserId: profile.userId,
        partnerNick: profile.nick,
        matchScore: matchScore,
        isBlocked: false,
        createdAt: now,
        updatedAt: now,
        messages: [systemMessage],
      ),
    );
    await _saveChats(chats);
    return chatId;
  }

  static Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final chats = await getChats();
    final idx = chats.indexWhere((c) => c.chatId == chatId);
    if (idx < 0) return;
    final chat = chats[idx];
    if (chat.isBlocked) return;
    final now = DateTime.now();
    final message = LocalSilentFlirtMessage(
      id: 'm_${now.millisecondsSinceEpoch}',
      text: text.trim(),
      isMine: true,
      isSystem: false,
      createdAt: now,
    );
    chats[idx] = LocalSilentFlirtChat(
      chatId: chat.chatId,
      partnerUserId: chat.partnerUserId,
      partnerNick: chat.partnerNick,
      matchScore: chat.matchScore,
      isBlocked: chat.isBlocked,
      createdAt: chat.createdAt,
      updatedAt: now,
      messages: [...chat.messages, message],
    );
    await _saveChats(chats);
  }

  static Future<void> setBlocked({
    required String chatId,
    required bool blocked,
  }) async {
    final chats = await getChats();
    final idx = chats.indexWhere((c) => c.chatId == chatId);
    if (idx < 0) return;
    final chat = chats[idx];
    chats[idx] = LocalSilentFlirtChat(
      chatId: chat.chatId,
      partnerUserId: chat.partnerUserId,
      partnerNick: chat.partnerNick,
      matchScore: chat.matchScore,
      isBlocked: blocked,
      createdAt: chat.createdAt,
      updatedAt: DateTime.now(),
      messages: chat.messages,
    );
    await _saveChats(chats);
  }

  static Future<void> closeChat(String chatId) async {
    final chats = await getChats();
    chats.removeWhere((c) => c.chatId == chatId);
    await _saveChats(chats);
  }

  static Future<void> addReport({
    required String chatId,
    required String reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reportsKey);
    final list = <Map<String, dynamic>>[];
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) list.add(Map<String, dynamic>.from(item));
        }
      }
    }
    list.add({
      'chatId': chatId,
      'reason': reason.trim(),
      'reportedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString(_reportsKey, jsonEncode(list));
  }

  static Future<void> _saveChats(List<LocalSilentFlirtChat> chats) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = chats.map((c) => c.toJson()).toList();
    await prefs.setString(_chatsKey, jsonEncode(payload));
  }
}
