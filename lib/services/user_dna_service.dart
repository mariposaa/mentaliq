// lib/services/user_dna_service.dart
// Kullanıcı DNA Servisi - Ana gölge profil yönetimi

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_dna_model.dart';
import 'auth_service.dart';

/// UserDNA - Kullanıcının dijital kimliği
/// Tüm kategorilerde erişilebilir merkezi profil
class UserDNAService {
  static UserDNAModel? _cachedDNA;

  /// Get cached DNA
  static UserDNAModel? get currentDNA => _cachedDNA;

  /// Get DNA from Firebase
  static Future<UserDNAModel?> getDNA() async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return null;

      final doc = await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('user_data')
          .doc('dna')
          .get();

      if (!doc.exists) {
        _cachedDNA = UserDNAModel();
        return _cachedDNA;
      }

      _cachedDNA = UserDNAModel.fromFirestore(doc.data()!);
      return _cachedDNA;
    } catch (e) {
      debugPrint('UserDNAService: Error getting DNA: $e');
      return null;
    }
  }

  /// Update DNA with new data
  static Future<bool> updateDNA(UserDNAModel updates) async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return false;

      // Get current DNA
      final currentDNA = _cachedDNA ?? await getDNA() ?? UserDNAModel();
      
      // Merge with updates
      final mergedDNA = currentDNA.merge(updates);
      
      // Save to Firebase
      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('user_data')
          .doc('dna')
          .set(mergedDNA.toFirestore(), SetOptions(merge: true));

      // Update cache
      _cachedDNA = mergedDNA;
      
      debugPrint('UserDNAService: DNA updated successfully');
      return true;
    } catch (e) {
      debugPrint('UserDNAService: Error updating DNA: $e');
      return false;
    }
  }

  /// Override specific lists (For Memory Pruning - Garbage Collection)
  static Future<bool> overrideLists(UserDNAModel updates) async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return false;

      // Create data map manually to ensure overwrite, not merge
      final Map<String, dynamic> data = {};
      
      if (updates.traumas != null) data['traumas'] = updates.traumas;
      if (updates.triggers != null) data['triggers'] = updates.triggers;
      if (updates.fears != null) data['fears'] = updates.fears;
      if (updates.goals != null) data['goals'] = updates.goals;
      if (updates.strengths != null) data['strengths'] = updates.strengths;
      
      if (data.isEmpty) return false;
      
      data['last_updated'] = DateTime.now().toIso8601String();

      // Use update() to only change specified fields but OVERWRITE them completely
      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('user_data')
          .doc('dna')
          .set(data, SetOptions(merge: true));

      // Update cache
      if (_cachedDNA != null) {
        _cachedDNA = UserDNAModel(
          age: _cachedDNA!.age,
          zodiac: _cachedDNA!.zodiac,
          profession: _cachedDNA!.profession,
          mbti: _cachedDNA!.mbti,
          personalityTraits: _cachedDNA!.personalityTraits,
          coreValues: _cachedDNA!.coreValues,
          fears: updates.fears ?? _cachedDNA!.fears, // Replace if updated
          hobbies: _cachedDNA!.hobbies,
          lifeStage: _cachedDNA!.lifeStage,
          relationshipStatus: _cachedDNA!.relationshipStatus,
          birthDate: _cachedDNA!.birthDate,
          birthTime: _cachedDNA!.birthTime,
          birthLocation: _cachedDNA!.birthLocation,
          traumas: updates.traumas ?? _cachedDNA!.traumas, // Replace if updated
          triggers: updates.triggers ?? _cachedDNA!.triggers, // Replace if updated
          strengths: updates.strengths ?? _cachedDNA!.strengths, // Replace if updated
          goals: updates.goals ?? _cachedDNA!.goals, // Replace if updated
          dynamicRelationships: _cachedDNA!.dynamicRelationships,
          lastUpdated: DateTime.now(),
        );
      }
      
      debugPrint('UserDNAService: List Override (Pruning) Successful');
      return true;
    } catch (e) {
      debugPrint('UserDNAService: Error overriding lists: $e');
      return false;
    }
  }

  /// Get DNA context for AI prompt
  static Future<String> getDNAForAI() async {
    try {
      final dna = _cachedDNA ?? await getDNA();
      if (dna == null) return '';
      
      return dna.toPromptContext();
    } catch (e) {
      debugPrint('UserDNAService: Error getting DNA for AI: $e');
      return '';
    }
  }

  /// Parse updates from shadow analysis JSON
  static UserDNAModel? parseUpdatesFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    
    try {
      final dnaData = json['user_dna'] as Map<String, dynamic>?;
      if (dnaData == null) return null;

      // Check if any actual data exists
      final hasData = dnaData.values.any((v) {
        if (v == null) return false;
        if (v is List) return v.isNotEmpty;
        if (v is String) return v.isNotEmpty;
        return true;
      });

      if (!hasData) return null;

      return UserDNAModel(
        age: dnaData['age'] as int?,
        zodiac: dnaData['zodiac'] as String?,
        profession: dnaData['profession'] as String?,
        mbti: dnaData['mbti'] as String?,
        personalityTraits: _parseStringList(dnaData['personality_traits']),
        coreValues: _parseStringList(dnaData['core_values']),
        fears: _parseStringList(dnaData['fears']),
        hobbies: _parseStringList(dnaData['hobbies']),
        lifeStage: dnaData['life_stage'] as String?,
        relationshipStatus: dnaData['relationship_status'] as String?,
        birthDate: dnaData['birth_date'] as String?,
        birthTime: dnaData['birth_time'] as String?,
        birthLocation: dnaData['birth_location'] as String?,
        traumas: _parseStringList(dnaData['traumas']),
        triggers: _parseStringList(dnaData['triggers']),
        strengths: _parseStringList(dnaData['strengths']),
        goals: _parseStringList(dnaData['goals']),
        dynamicRelationships: dnaData['dynamic_relationships'] != null 
            ? Map<String, dynamic>.from(dnaData['dynamic_relationships']) 
            : null,
      );

    } catch (e) {
      debugPrint('UserDNAService: Error parsing DNA updates: $e');
      return null;
    }
  }

  static List<String>? _parseStringList(dynamic data) {
    if (data == null) return null;
    if (data is List) {
      return data.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return null;
  }

  /// Clear cache (for logout)
  static void clearCache() {
    _cachedDNA = null;
  }

  /// Initialize DNA on app start
  static Future<void> initialize() async {
    await getDNA();
    debugPrint('UserDNAService: Initialized with DNA: ${_cachedDNA?.toPromptContext()}');
  }
}
