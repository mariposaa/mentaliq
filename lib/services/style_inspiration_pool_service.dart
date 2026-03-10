import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'admin_role_service.dart';
import 'gemini_service.dart';

class StyleInspirationItem {
  final String id;
  final String title;
  final String imageUrl;
  final String category;
  final List<String> tags;
  final List<String> seasons;
  final String reason;
  final DateTime? createdAt;

  const StyleInspirationItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.category,
    required this.tags,
    required this.seasons,
    required this.reason,
    required this.createdAt,
  });

  factory StyleInspirationItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data['createdAt'];
    return StyleInspirationItem(
      id: doc.id,
      title: (data['title'] ?? 'Parca').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      category: (data['category'] ?? 'other').toString(),
      tags: List<String>.from(data['tags'] ?? const []),
      seasons: List<String>.from(data['seasons'] ?? const []),
      reason: (data['reason'] ?? '').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class StyleInspirationPoolService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      AuthService.firestore.collection('style_inspiration_pool');

  static Future<List<StyleInspirationItem>> getLatest({int limit = 20}) async {
    final snap =
        await _col.orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map(StyleInspirationItem.fromDoc).toList();
  }

  static Future<StyleInspirationItem> classifyAndAdd({
    required String imageUrl,
    required String note,
  }) async {
    final canManage = await AdminRoleService.isCurrentUserAdmin();
    if (!canManage) {
      throw Exception('Bu işlem için admin yetkisi gerekli.');
    }

    final classification =
        await _classifyWithAI(imageUrl: imageUrl, note: note);
    final payload = <String, dynamic>{
      'title': classification['title'],
      'imageUrl': imageUrl,
      'category': classification['category'],
      'tags': classification['tags'],
      'seasons': classification['seasons'],
      'reason': classification['reason'],
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': AuthService.userId,
      'createdByEmail': AuthService.userEmail,
    };
    final doc = await _col.add(payload);
    final saved = await doc.get();
    return StyleInspirationItem.fromDoc(saved);
  }

  static Future<Map<String, dynamic>> _classifyWithAI({
    required String imageUrl,
    required String note,
  }) async {
    final prompt = '''
Bir stil ilham havuzu parcasi siniflandir.

Gorsel URL: $imageUrl
Admin notu: $note

Kurallar:
- category yalnizca: top, bottom, shoes, outerwear, accessory, dress, bag, other
- tags en fazla 6 kisa etiket olsun
- seasons sadece: spring, summer, autumn, winter
- reason 1 cumle olsun
- Sadece JSON don:
{
  "title": "Kisa urun adi",
  "category": "top",
  "tags": ["minimal", "casual"],
  "seasons": ["spring", "summer"],
  "reason": "Hibrit kombinleri tamamlayan rahat bir ust parca."
}
''';
    try {
      final raw =
          await GeminiService.generateResponse(prompt, 'stil_danismanligi');
      final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(clean) as Map<String, dynamic>;
      return {
        'title': (decoded['title'] ?? 'Ilham Parcasi').toString(),
        'category': (decoded['category'] ?? 'other').toString(),
        'tags': List<String>.from(decoded['tags'] ?? const []),
        'seasons': List<String>.from(decoded['seasons'] ?? const []),
        'reason': (decoded['reason'] ?? '').toString(),
      };
    } catch (e) {
      debugPrint('Inspiration classify failed, fallback: $e');
      return {
        'title': 'Ilham Parcasi',
        'category': 'other',
        'tags': <String>['hybrid'],
        'seasons': <String>[],
        'reason': 'Admin tarafindan eklenen parca.',
      };
    }
  }
}
