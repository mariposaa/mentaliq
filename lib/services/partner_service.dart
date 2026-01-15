import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/partner_model.dart';
import 'auth_service.dart';

/// Service for managing partner data in Firebase
/// Data structure: users/{userId}/partners/{partnerId}
class PartnerService {
  static FirebaseFirestore get _firestore => AuthService.firestore;
  static const _uuid = Uuid();

  // Cache for current partner
  static PartnerModel? _currentPartner;
  static PartnerModel? get currentPartner => _currentPartner;

  /// Get all partners for current user
  static Future<List<PartnerModel>> getPartners() async {
    final uid = AuthService.userId;
    if (uid == null) {
      debugPrint('getPartners: No user ID');
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('partners')
          .get();

      debugPrint('getPartners: Found ${snapshot.docs.length} partners');
      return snapshot.docs
          .map((doc) => PartnerModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting partners: $e');
      return [];
    }
  }

  /// Get single partner by ID
  static Future<PartnerModel?> getPartner(String partnerId) async {
    final uid = AuthService.userId;
    if (uid == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('partners')
          .doc(partnerId)
          .get();

      if (!doc.exists) return null;
      
      final partner = PartnerModel.fromJson(doc.data()!, doc.id);
      _currentPartner = partner;
      return partner;
    } catch (e) {
      debugPrint('Error getting partner: $e');
      return null;
    }
  }

  /// Get primary (first) partner - most commonly used
  static Future<PartnerModel?> getPrimaryPartner() async {
    final partners = await getPartners();
    if (partners.isEmpty) return null;
    
    _currentPartner = partners.first;
    return _currentPartner;
  }

  /// Create new partner
  static Future<PartnerModel?> createPartner({
    required String name,
    String? nickname,
    String? relationshipType,
    String? gender,
    int? age,
    DateTime? relationshipStart,
    String? zodiacSign,
    String? mbtiType,
    String? loveLanguage,
    String? communicationStyle,
    List<String>? positiveTraits,
    List<String>? negativeTraits,
    List<String>? sharedInterests,
    List<String>? conflictTopics,
    String? notes,
  }) async {
    final uid = AuthService.userId;
    if (uid == null) return null;

    try {
      final id = _uuid.v4();
      final now = DateTime.now();
      
      final partner = PartnerModel(
        id: id,
        name: name,
        nickname: nickname,
        relationshipType: relationshipType,
        gender: gender,
        age: age,
        relationshipStart: relationshipStart,
        zodiacSign: zodiacSign,
        mbtiType: mbtiType,
        loveLanguage: loveLanguage,
        communicationStyle: communicationStyle,
        positiveTraits: positiveTraits,
        negativeTraits: negativeTraits,
        sharedInterests: sharedInterests,
        conflictTopics: conflictTopics,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('partners')
          .doc(id)
          .set(partner.toJson());

      _currentPartner = partner;
      debugPrint('Partner created successfully: $name (id: $id)');
      return partner;
    } catch (e, stack) {
      debugPrint('Error creating partner: $e');
      debugPrint('Stack: $stack');
      return null;
    }
  }

  /// Update existing partner
  static Future<bool> updatePartner(PartnerModel partner) async {
    final uid = AuthService.userId;
    if (uid == null) return false;

    try {
      final updated = partner.copyWith();
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('partners')
          .doc(partner.id)
          .update(updated.toJson());

      _currentPartner = updated;
      debugPrint('Partner updated: ${partner.name}');
      return true;
    } catch (e) {
      debugPrint('Error updating partner: $e');
      return false;
    }
  }

  /// Update single field of partner
  static Future<bool> updatePartnerField(String partnerId, String field, dynamic value) async {
    final uid = AuthService.userId;
    if (uid == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('partners')
          .doc(partnerId)
          .update({
            field: value,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      // Refresh cache
      await getPartner(partnerId);
      debugPrint('Partner field updated: $field');
      return true;
    } catch (e) {
      debugPrint('Error updating partner field: $e');
      return false;
    }
  }

  /// Delete partner
  static Future<bool> deletePartner(String partnerId) async {
    final uid = AuthService.userId;
    if (uid == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('partners')
          .doc(partnerId)
          .delete();

      if (_currentPartner?.id == partnerId) {
        _currentPartner = null;
      }
      
      debugPrint('Partner deleted: $partnerId');
      return true;
    } catch (e) {
      debugPrint('Error deleting partner: $e');
      return false;
    }
  }

  /// Get partner context for AI prompts
  static Future<String> getPartnerContextForAI() async {
    final partner = _currentPartner ?? await getPrimaryPartner();
    if (partner == null) return '';
    
    return '''
[PARTNER BİLGİLERİ - Bu bilgileri ilişki tavsiyelerinde kullan]
${partner.toAIContext()}
''';
  }

  /// Get partner zodiac sign for dynamic context injection
  static Future<String?> getPartnerZodiac() async {
    final partner = _currentPartner ?? await getPrimaryPartner();
    return partner?.zodiacSign;
  }

  /// Clear cache
  static void clearCache() {
    _currentPartner = null;
  }
}
