import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/partner_model.dart';
import 'partner_service.dart';
import 'user_dna_service.dart';

/// Shadow Memory Service - Background AI that updates partner profile AND user DNA
/// Runs silently after each conversation to extract new information
class ShadowMemoryService {
  static GenerativeModel? _model;
  static bool _isAnalyzing = false;

  static bool get isAnalyzing => _isAnalyzing;

  // ============================================================
  // GÖLGE HAFIZA PROMPTU - İKİLİ ÇIKTI (User DNA + Partner)
  // ============================================================
  static const String _shadowMemoryPrompt = '''
### GÖREV:
Aşağıdaki kullanıcı mesajını analiz et. Amacın iki şeyi güncel tutmaktır:
1. KULLANICI hakkındaki Psikolojik Master DNA'yı
2. PARTNER hakkındaki bilgileri (ilişki kategorisindeyse)

### YAPMAN GEREKENLER:
1. Kullanıcının KENDİSİ hakkında verdiği derin bilgileri tespit et:
   - Temel: Yaş, Burç, Meslek, MBTI, Yaşam Evresi
   - Derinlik: Travmalar, Korkular, Tetikleyiciler (Triggers)
   - Potansiyel: Güçlü Yanlar, Hedefler, Değerler, Hobiler
   - İlişkiler: Anne, baba, eş gibi spesifik kişi bazlı durumlar

2. Kullanıcının PARTNERİ hakkında verdiği bilgileri tespit et (İlişki kategorisindeyse):
   - Partner özellikleri, burcu, davranışları

3. Anlık duygu durumlarını (Örn: "Şu an sinirliyim") KAYDETME. Sadece kalıcı veya uzun süreli bilgileri al.

4. Eğer yeni bilgi yoksa ilgili alanı null veya boş liste olarak bırak.

### ÇIKTI FORMATI (Sadece JSON, başka hiçbir şey yazma):
{
  "user_dna": {
    "age": null,
    "zodiac": null,
    "profession": null,
    "mbti": null,
    "life_stage": null,
    "relationship_status": null,
    "traumas": [],
    "fears": [],
    "triggers": [],
    "strengths": [],
    "goals": [],
    "core_values": [],
    "hobbies": [],
    "personality_traits": [],
    "dynamic_relationships": {}
  },
  "partner_data": {
    "new_traits": [],
    "relationship_status_change": null,
    "detected_zodiac": null,
    "detected_age": null,
    "detected_name": null
  }
}

Önemli: Sadece JSON döndür, açıklama ekleme.
''';


  /// Initialize shadow memory service
  static void initialize(String apiKey) {
    try {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3,
          topP: 0.9,
          maxOutputTokens: 1024, // Increased for dual output
        ),
      );
      debugPrint('ShadowMemoryService initialized');
    } catch (e) {
      debugPrint('Error initializing ShadowMemoryService: $e');
    }
  }

  /// Analyze conversation and update both User DNA and Partner profile
  /// Called silently after each AI response - works for ALL categories
  static Future<void> analyzeAndUpdate(String userMessage, {String? category}) async {
    if (_model == null) {
      debugPrint('ShadowMemory: Model not initialized');
      return;
    }

    // Prevent concurrent analysis
    if (_isAnalyzing) {
      debugPrint('ShadowMemory: Already analyzing');
      return;
    }

    _isAnalyzing = true;

    try {
      debugPrint('ShadowMemory: Analyzing message for category: $category');
      
      // Get partner name if available (for relationship category)
      final partner = PartnerService.currentPartner;
      final partnerInfo = partner != null 
          ? 'Mevcut Partner İsmi: ${partner.name}'
          : 'Partner bilgisi yok';
      
      final prompt = '''
$_shadowMemoryPrompt

### GİRDİ:
Kullanıcı Mesajı: "$userMessage"
Kategori: ${category ?? 'genel'}
$partnerInfo
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text?.trim() ?? '';

      debugPrint('ShadowMemory raw response: $responseText');

      // Parse JSON response
      final updates = _parseResponse(responseText);
      
      if (updates != null) {
        // Apply User DNA updates (always)
        await _applyUserDNAUpdates(updates);
        
        // Apply Partner updates (only if partner exists and in relationship category)
        if (partner != null && category == 'iliskiler') {
          await _applyPartnerUpdates(partner, updates);
        }
      }

    } catch (e) {
      debugPrint('ShadowMemory error: $e');
    } finally {
      _isAnalyzing = false;
    }
  }

  /// Parse AI response to extract updates
  static Map<String, dynamic>? _parseResponse(String responseText) {
    try {
      // Clean response - remove markdown code blocks if present
      String cleanJson = responseText;
      if (cleanJson.contains('```json')) {
        cleanJson = cleanJson.split('```json')[1].split('```')[0].trim();
      } else if (cleanJson.contains('```')) {
        cleanJson = cleanJson.split('```')[1].split('```')[0].trim();
      }

      final Map<String, dynamic> data = json.decode(cleanJson);
      
      // Check if there's anything to update in either section
      final userDNA = data['user_dna'] as Map<String, dynamic>?;
      final partnerData = data['partner_data'] as Map<String, dynamic>?;

      final hasUserDNAUpdates = _hasNonEmptyValues(userDNA);
      final hasPartnerUpdates = _hasNonEmptyValues(partnerData);

      if (!hasUserDNAUpdates && !hasPartnerUpdates) {
        debugPrint('ShadowMemory: No updates detected');
        return null;
      }

      debugPrint('ShadowMemory: Found updates - DNA: $hasUserDNAUpdates, Partner: $hasPartnerUpdates');
      return data;
    } catch (e) {
      debugPrint('ShadowMemory: Failed to parse JSON: $e');
      return null;
    }
  }

  /// Check if a map has any non-empty values
  static bool _hasNonEmptyValues(Map<String, dynamic>? map) {
    if (map == null) return false;
    return map.values.any((v) {
      if (v == null) return false;
      if (v is List) return v.isNotEmpty;
      if (v is String) return v.isNotEmpty;
      return true;
    });
  }

  /// Apply User DNA updates
  static Future<void> _applyUserDNAUpdates(Map<String, dynamic> updates) async {
    final userDNA = updates['user_dna'] as Map<String, dynamic>?;
    if (userDNA == null) return;

    final dnaUpdates = UserDNAService.parseUpdatesFromJson(updates);
    if (dnaUpdates != null) {
      await UserDNAService.updateDNA(dnaUpdates);
      debugPrint('ShadowMemory: User DNA updated ✓');
    }
  }

  /// Apply Partner updates
  static Future<void> _applyPartnerUpdates(PartnerModel partner, Map<String, dynamic> updates) async {
    final partnerData = updates['partner_data'] as Map<String, dynamic>?;
    if (partnerData == null) return;

    bool hasChanges = false;
    List<String> currentNegativeTraits = List.from(partner.negativeTraits ?? []);
    List<String> currentPositiveTraits = List.from(partner.positiveTraits ?? []);
    String? newRelationType = partner.relationshipType;
    String? newZodiac = partner.zodiacSign;
    int? newAge = partner.age;

    // Process new traits
    final newTraits = partnerData['new_traits'] as List<dynamic>?;
    if (newTraits != null && newTraits.isNotEmpty) {
      for (final trait in newTraits) {
        final traitStr = trait.toString().toLowerCase();
        
        // Classify trait as positive or negative
        if (_isNegativeTrait(traitStr)) {
          if (!currentNegativeTraits.any((t) => t.toLowerCase() == traitStr)) {
            currentNegativeTraits.add(trait.toString());
            hasChanges = true;
            debugPrint('ShadowMemory: Added negative trait: $trait');
          }
        } else {
          if (!currentPositiveTraits.any((t) => t.toLowerCase() == traitStr)) {
            currentPositiveTraits.add(trait.toString());
            hasChanges = true;
            debugPrint('ShadowMemory: Added positive trait: $trait');
          }
        }
      }
    }

    // Process relationship status change
    final statusChange = partnerData['relationship_status_change'];
    if (statusChange != null && statusChange.toString().isNotEmpty) {
      newRelationType = statusChange.toString();
      hasChanges = true;
      debugPrint('ShadowMemory: Relationship status changed to: $statusChange');
    }

    // Process zodiac
    final zodiac = partnerData['detected_zodiac'];
    if (zodiac != null && zodiac.toString().isNotEmpty && partner.zodiacSign == null) {
      newZodiac = zodiac.toString();
      hasChanges = true;
      debugPrint('ShadowMemory: Detected zodiac: $zodiac');
    }

    // Process age
    final age = partnerData['detected_age'];
    if (age != null && partner.age == null) {
      newAge = int.tryParse(age.toString());
      if (newAge != null) {
        hasChanges = true;
        debugPrint('ShadowMemory: Detected age: $age');
      }
    }

    // Apply updates to Firebase
    if (hasChanges) {
      final updatedPartner = partner.copyWith(
        negativeTraits: currentNegativeTraits.isEmpty ? null : currentNegativeTraits,
        positiveTraits: currentPositiveTraits.isEmpty ? null : currentPositiveTraits,
        relationshipType: newRelationType,
        zodiacSign: newZodiac,
        age: newAge,
      );

      final success = await PartnerService.updatePartner(updatedPartner);
      if (success) {
        debugPrint('ShadowMemory: Partner profile updated ✓');
      }
    }
  }

  /// Check if a trait is negative
  static bool _isNegativeTrait(String trait) {
    const negativeKeywords = [
      'yalancı', 'yalan', 'aldatıcı', 'aldatma', 'güvenilmez',
      'cimri', 'bencil', 'kıskanç', 'agresif', 'manipülatif',
      'toksik', 'kontrolcü', 'ilgisiz', 'soğuk', 'narsist',
      'pasif-agresif', 'sinirli', 'kavgacı', 'küsük', 'umursamaz',
      'geç cevap', 'mesajlara bakmıyor', 'ilgisiz', 'uzak',
    ];

    return negativeKeywords.any((keyword) => trait.contains(keyword));
  }
}
