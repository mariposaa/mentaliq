// lib/services/user_dna_service.dart
// Kullanıcı DNA Servisi - Ana gölge profil yönetimi

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/locale_utils.dart';
import '../models/user_dna_model.dart';
import 'memory_trigger_config_service.dart';
import 'auth_service.dart';

/// UserDNA - Kullanıcının dijital kimliği
/// Tüm kategorilerde erişilebilir merkezi profil
class UserDNAService {
  static UserDNAModel? _cachedDNA;
  static final Map<String, DateTime> _memoryCooldown = {};
  static const Duration _memoryCooldownWindow = Duration(minutes: 20);

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
      try {
        final uid = AuthService.userId;
        if (uid != null) {
          await AuthService.firestore
              .collection('users')
              .doc(uid)
              .collection('user_data')
              .doc('dna')
              .set(updates.toFirestore(), SetOptions(merge: true));
          _cachedDNA = (_cachedDNA ?? UserDNAModel()).merge(updates);
          debugPrint('UserDNAService: Fallback DNA update succeeded');
          return true;
        }
      } catch (fallbackError) {
        debugPrint('UserDNAService: Fallback DNA update failed: $fallbackError');
      }
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
          willpowerIndex: _cachedDNA!.willpowerIndex,
          activeAddictions: _cachedDNA!.activeAddictions,
          recentInterventions: _cachedDNA!.recentInterventions,
          language: _cachedDNA!.language,
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

  /// Trigger-aware context builder.
  /// - No trigger: returns short/light context
  /// - Trigger detected: returns selected deep context with cooldown
  static Future<String> getContextForMessage({
    required String message,
    required String category,
  }) async {
    try {
      final dna = _cachedDNA ?? await getDNA();
      if (dna == null) return '';

      final triggers = await _classifyMessageTriggers(message, category);
      if (triggers.isEmpty) {
        return _buildLightContext(dna);
      }

      final selected = <String>[];
      final lowerCategory = category.toLowerCase();
      final now = DateTime.now();

      if ((triggers.contains('identity') || triggers.contains('explicit')) &&
          !_isCooling('identity', now)) {
        final identity = _buildIdentitySignal(dna);
        if (identity.isNotEmpty) {
          selected.add(identity);
          _markUsed('identity', now);
        }
      }

      if ((triggers.contains('relationship') ||
              lowerCategory == 'iliskiler' ||
              triggers.contains('explicit')) &&
          !_isCooling('relationship', now)) {
        final relationship = _pickSignal(
          tag: 'ILISKI DESENI',
          values: [
            ...?dna.fears,
            ...?dna.triggers,
            ...?dna.coreValues,
          ],
          maxItems: 2,
        );
        if (relationship.isNotEmpty) {
          selected.add(relationship);
          _markUsed('relationship', now);
        }
      }

      if ((triggers.contains('addiction') ||
              lowerCategory == 'bagimliliklar' ||
              triggers.contains('explicit')) &&
          !_isCooling('addiction', now)) {
        final addiction = _buildAddictionSignal(dna);
        if (addiction.isNotEmpty) {
          selected.add(addiction);
          _markUsed('addiction', now);
        }
      }

      if ((triggers.contains('crisis') || triggers.contains('selfworth')) &&
          !_isCooling('emotional', now)) {
        final emotional = _pickSignal(
          tag: 'DUYGUSAL TETIK',
          values: [...?dna.traumas, ...?dna.triggers, ...?dna.fears],
          maxItems: 2,
        );
        if (emotional.isNotEmpty) {
          selected.add(emotional);
          _markUsed('emotional', now);
        }
      }

      if (selected.isEmpty) {
        return _buildLightContext(dna);
      }

      return '''
### TETIK ODAKLI BAGLAM (SADECE GEREKTIGINDE KULLAN):
${selected.take(4).join('\n')}
''';
    } catch (e) {
      debugPrint('UserDNAService: Error building trigger context: $e');
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
        language: dnaData['language'] as String?,
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
    _memoryCooldown.clear();
  }

  /// Initialize DNA on app start; dil yoksa cihaz dilini UserDNA'ya yazar.
  static Future<void> initialize() async {
    await getDNA();
    final hasLanguage = _cachedDNA?.language != null && _cachedDNA!.language!.isNotEmpty;
    if (!hasLanguage && AuthService.userId != null) {
      final code = LocaleUtils.detectFromDevice();
      await updateDNA(UserDNAModel(language: code));
      debugPrint('UserDNAService: Language set from device: $code');
    }
    debugPrint('UserDNAService: Initialized with DNA: ${_cachedDNA?.toPromptContext()}');
  }

  static bool _isCooling(String key, DateTime now) {
    final last = _memoryCooldown[key];
    if (last == null) return false;
    return now.difference(last) < _memoryCooldownWindow;
  }

  static void _markUsed(String key, DateTime now) {
    _memoryCooldown[key] = now;
  }

  static Future<Set<String>> _classifyMessageTriggers(
    String message,
    String category,
  ) async {
    final text = message.toLowerCase();
    final tags = <String>{};
    final cfg = await MemoryTriggerConfigService.getConfig();

    bool hasAny(List<String> words) =>
        words.any((w) => w.isNotEmpty && text.contains(w.toLowerCase()));

    if (hasAny(cfg.crisis)) {
      tags.add('crisis');
    }

    if (hasAny(cfg.relationship)) {
      tags.add('relationship');
    }

    if (hasAny(cfg.addiction)) {
      tags.add('addiction');
    }

    if (hasAny(cfg.selfworth)) {
      tags.add('selfworth');
      tags.add('identity');
    }

    if (hasAny(cfg.explicit)) {
      tags.add('explicit');
    }

    final c = category.toLowerCase();
    if (c == 'iliskiler' || c == 'bagimliliklar') {
      tags.add('identity');
    }

    return tags;
  }

  static String _buildLightContext(UserDNAModel dna) {
    final base = <String>[];
    if (dna.age != null) base.add('${dna.age} yas');
    if (dna.zodiac != null && dna.zodiac!.isNotEmpty) base.add('${dna.zodiac} burcu');
    if (dna.profession != null && dna.profession!.isNotEmpty) {
      base.add('Meslek: ${dna.profession}');
    }
    if (base.isEmpty) return '';
    return '### HAFIF BAGLAM:\n- ${base.join(' | ')}';
  }

  static String _buildIdentitySignal(UserDNAModel dna) {
    final values = <String>[];
    if (dna.mbti != null && dna.mbti!.isNotEmpty) values.add('MBTI: ${dna.mbti}');
    if (dna.lifeStage != null && dna.lifeStage!.isNotEmpty) {
      values.add('Yasam evresi: ${dna.lifeStage}');
    }
    if (dna.coreValues != null && dna.coreValues!.isNotEmpty) {
      values.add('Deger: ${dna.coreValues!.take(1).join(", ")}');
    }
    if (values.isEmpty) return '';
    return '[KIMLIK ODAK] ${values.join(' | ')}';
  }

  static String _buildAddictionSignal(UserDNAModel dna) {
    final addictions = dna.activeAddictions;
    if (addictions == null || addictions.isEmpty) return '';
    final top = addictions.first;
    return '[BAGIMLILIK RISK] ${top.id}: irade ${top.willpowerIndex.toStringAsFixed(2)}, temiz gun ${top.streakDays}';
  }

  static String _pickSignal({
    required String tag,
    required List<String> values,
    int maxItems = 2,
  }) {
    final cleaned = values.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleaned.isEmpty) return '';
    return '[$tag] ${cleaned.take(maxItems).join(', ')}';
  }
}
