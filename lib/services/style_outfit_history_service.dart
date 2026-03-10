import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/style_outfit_record.dart';
import 'auth_service.dart';

class StyleOutfitHistoryService {
  static const String _collection = 'style_outfit_history';

  static Future<bool> saveRecord(StyleOutfitRecord record) async {
    final uid = AuthService.userId;
    if (uid == null) return false;
    try {
      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection(_collection)
          .add(record.toFirestore());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Stream<List<StyleOutfitRecord>> watchRecords() {
    final uid = AuthService.userId;
    if (uid == null) return Stream.value([]);
    return AuthService.firestore
        .collection('users')
        .doc(uid)
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(StyleOutfitRecord.fromFirestore).toList());
  }

  static Future<void> deleteRecord(String id) async {
    final uid = AuthService.userId;
    if (uid == null) return;
    await AuthService.firestore
        .collection('users')
        .doc(uid)
        .collection(_collection)
        .doc(id)
        .delete();
  }
}
