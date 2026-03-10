import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/partner_model.dart';

/// Local, partner-scoped episodic memory for relationship chat.
/// Stores short hidden notes on-device (no Firebase).
class LocalRelationshipMemoryService {
  static const String _keyPrefix = 'relationship_local_memory_v1_';
  static const int _maxNotesPerPartner = 24;
  static const int _notesForPrompt = 5;

  static String buildPartnerKey(PartnerModel? partner) {
    if (partner == null) return 'unknown_partner';

    // Partner-specific key prevents mixing memories between different people.
    final raw =
        '${partner.id}|${partner.name.trim().toLowerCase()}|${(partner.zodiacSign ?? '').trim().toLowerCase()}|${(partner.relationshipType ?? '').trim().toLowerCase()}';
    return base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
  }

  static Future<String> getMemoryContextForAI({required String partnerKey}) async {
    final notes = await _loadNotes(partnerKey);
    if (notes.isEmpty) return '';

    final latest = notes.reversed.take(_notesForPrompt).toList().reversed.toList();
    final lines = latest
        .map((item) => '- ${item['note']?.toString() ?? ''}')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return '';

    return '''
### YEREL İLİŞKİ HAFIZASI (PARTNER BAZLI - GİZLİ NOTLAR)
${lines.join('\n')}
''';
  }

  static Future<LocalRelationshipOpeningInsight?> getOpeningInsight({
    required String partnerKey,
  }) async {
    final notes = await _loadNotes(partnerKey);
    if (notes.isEmpty) return null;

    final last = (notes.last['note']?.toString() ?? '').trim();
    if (last.isEmpty) return null;

    final prev = notes.length > 1 ? (notes[notes.length - 2]['note']?.toString() ?? '').trim() : '';

    final lastTag = _extractTag(last);
    final prevTag = _extractTag(prev);

    final lastState = _extractSection(last, 'Durum:', '| Öneri:') ?? _singleLine(last, max: 120);
    final focus = _extractSection(last, 'Öneri:', null) ?? 'Bugün net bir sınır cümlesiyle iletişimi sadeleştir.';

    String change;
    if (prev.isEmpty) {
      change = 'Bu partner için ilk kişisel not oluştu.';
    } else if (lastTag.isNotEmpty && prevTag.isNotEmpty && lastTag != prevTag) {
      change = 'Önceki notlara göre odak değişmiş görünüyor ($prevTag -> $lastTag).';
    } else if (lastState.toLowerCase() == (_extractSection(prev, 'Durum:', '| Öneri:') ?? '').toLowerCase()) {
      change = 'Son konuşmalarda belirgin bir değişim sinyali görünmüyor.';
    } else {
      change = 'Önceki konuşmaya göre küçük bir değişim sinyali var.';
    }

    return LocalRelationshipOpeningInsight(
      lastState: lastState,
      changeNote: change,
      todayFocus: _singleLine(focus, max: 120),
    );
  }

  static Future<void> appendMemoryNote({
    required String partnerKey,
    required String userMessage,
    required String aiResponse,
  }) async {
    final note = _buildCompactNote(userMessage, aiResponse);
    if (note.isEmpty) return;

    final notes = await _loadNotes(partnerKey);
    final fingerprint = _fingerprint(userMessage);

    // Skip near-duplicate consecutive notes.
    if (notes.isNotEmpty && notes.last['fingerprint'] == fingerprint) {
      return;
    }

    notes.add({
      'ts': DateTime.now().toIso8601String(),
      'note': note,
      'fingerprint': fingerprint,
    });

    while (notes.length > _maxNotesPerPartner) {
      notes.removeAt(0);
    }

    await _saveNotes(partnerKey, notes);
  }

  static Future<List<Map<String, dynamic>>> _loadNotes(String partnerKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$partnerKey');
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveNotes(String partnerKey, List<Map<String, dynamic>> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$partnerKey', json.encode(notes));
  }

  static String _buildCompactNote(String userMessage, String aiResponse) {
    final user = _singleLine(userMessage, max: 140);
    if (user.isEmpty) return '';

    final ai = _singleLine(aiResponse, max: 100);
    final label = _detectSignal(userMessage);

    if (label.isNotEmpty) {
      return '[$label] Durum: $user | Öneri: $ai';
    }
    return 'Durum: $user | Öneri: $ai';
  }

  static String _singleLine(String text, {required int max}) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return '';
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max)}...';
  }

  static String _fingerprint(String text) {
    final clean = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return '';
    final slice = clean.length > 80 ? clean.substring(0, 80) : clean;
    return base64Url.encode(utf8.encode(slice)).replaceAll('=', '');
  }

  static String _detectSignal(String text) {
    final t = text.toLowerCase();
    if (t.contains('ghost') || t.contains('görüldü') || t.contains('cevap vermiyor')) {
      return 'İletişim Kopması';
    }
    if (t.contains('manip') || t.contains('gaslight')) {
      return 'Manipülasyon';
    }
    if (t.contains('aldat') || t.contains('ihanet')) {
      return 'Güven Krizi';
    }
    if (t.contains('kıskan') || t.contains('kontrol')) {
      return 'Kontrol/Kıskançlık';
    }
    return '';
  }

  static String _extractTag(String note) {
    final m = RegExp(r'^\[([^\]]+)\]').firstMatch(note);
    return m?.group(1)?.trim() ?? '';
  }

  static String? _extractSection(String input, String start, String? end) {
    final s = input.indexOf(start);
    if (s == -1) return null;
    final from = s + start.length;
    if (end == null) {
      return input.substring(from).trim();
    }
    final e = input.indexOf(end, from);
    if (e == -1) return input.substring(from).trim();
    return input.substring(from, e).trim();
  }
}

class LocalRelationshipOpeningInsight {
  final String lastState;
  final String changeNote;
  final String todayFocus;

  const LocalRelationshipOpeningInsight({
    required this.lastState,
    required this.changeNote,
    required this.todayFocus,
  });
}
