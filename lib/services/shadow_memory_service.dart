import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/app_locale.dart';
import '../models/partner_model.dart';
import 'partner_service.dart';
import 'user_dna_service.dart';
import 'memory_trigger_config_service.dart';

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
Aşağıdaki kullanıcı mesajını analiz et. Amacın üç şeyi güncel tutmaktır:
1. KULLANICI hakkındaki Psikolojik Master DNA'yı
2. PARTNER hakkındaki bilgileri (ilişki kategorisindeyse)
3. BAĞIMLILIK TAKİBİ bilgileri (bağımlılık kategorisindeyse)

### YAPMAN GEREKENLER:
1. Kullanıcının KENDİSİ hakkında verdiği derin bilgileri tespit et:
   - Temel: Yaş, Burç, Meslek, MBTI, Yaşam Evresi
   - Derinlik: Travmalar, Korkular, Tetikleyiciler (Triggers)
   - Potansiyel: Güçlü Yanlar, Hedefler, Değerler, Hobiler
   - İlişkiler: Anne, baba, eş gibi spesifik kişi bazlı durumlar

2. Kullanıcının PARTNERİ hakkında verdiği bilgileri tespit et (İlişki kategorisindeyse):
   - Partner özellikleri, burcu, davranışları

3. BAĞIMLILIK TAKİBİ (bağımlılık kategorisindeyse):
   - Bağımlılık türü: dijital (oyun, sosyal medya, telefon), davranışsal (kumar, alışveriş), madde (alkol, sigara), yeme bozukluğu
   - Tetikleyiciler: Kullanıcının bağımlılık davranışını neyin tetiklediği (stres, yalnızlık, can sıkıntısı, öfke, yorgunluk vb.)
   - Nüks anları: Kullanıcının "yine yaptım", "bozdum", "dayanamadım" gibi ifadeleri
   - Başarı anları: Kullanıcının direniş, kaçınma veya başarılı anlarını

4. Anlık duygu durumlarını (Örn: "Şu an sinirliyim") KAYDETME. Sadece kalıcı veya uzun süreli bilgileri al.

5. Eğer yeni bilgi yoksa ilgili alanı null veya boş liste olarak bırak.

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
  },
  "addiction_data": {
    "addiction_type": null,
    "triggers_detected": [],
    "relapse_noted": false,
    "success_noted": false,
    "notes": null
  }
}

Önemli: Sadece JSON döndür, açıklama ekleme.
''';


  /// Initialize shadow memory service
  static void initialize(String apiKey) {
    try {
      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
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
      final triggerTags = await _detectTriggerTags(userMessage);
      
      final prompt = '''
$_shadowMemoryPrompt

### GİRDİ:
Kullanıcı Mesajı: "$userMessage"
Kategori: ${category ?? 'genel'}
Tetik Etiketleri: ${triggerTags.isEmpty ? 'yok' : triggerTags.join(', ')}
$partnerInfo
''';

      final promptWithLang = '${AppLocale.languageInstructionForAI}\n\n$prompt';
      final response = await _model!.generateContent([Content.text(promptWithLang)]);
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
        
        // Apply Addiction tracking updates (only in bagimliliklar category)
        if (category == 'bagimliliklar') {
          await _applyAddictionUpdates(updates);
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

  /// Apply User DNA updates (always)
  static Future<void> _applyUserDNAUpdates(Map<String, dynamic> updates) async {
    final userDNA = updates['user_dna'] as Map<String, dynamic>?;
    if (userDNA == null) return;

    final dnaUpdates = UserDNAService.parseUpdatesFromJson(updates);
    if (dnaUpdates != null) {
      await UserDNAService.updateDNA(dnaUpdates);
      debugPrint('ShadowMemory: User DNA updated ✓');
      
      // Check for memory bloat and prune if necessary
      await _checkAndPruneMemory();
    }
  }
  
  /// Check Memory Bloat (Hafıza Şişkinliği Kontrolü)
  static Future<void> _checkAndPruneMemory() async {
    final dns = UserDNAService.currentDNA;
    if (dns == null) return;
    
    // Thresholds
    const int maxListSize = 15;
    
    List<String> pruningTargets = [];
    
    if ((dns.triggers?.length ?? 0) > maxListSize) pruningTargets.add('triggers');
    if ((dns.fears?.length ?? 0) > maxListSize) pruningTargets.add('fears');
    if ((dns.goals?.length ?? 0) > maxListSize) pruningTargets.add('goals');
    
    if (pruningTargets.isNotEmpty) {
      debugPrint('ShadowMemory: Memory bloat detected in $pruningTargets. Starting Garbage Collection...');
      await _pruneListWithAI(dns, pruningTargets);
    }
  }
  
  /// Prune specific lists using AI summarization
  static Future<void> _pruneListWithAI(dynamic currentDNA, List<String> targets) async {
    if (_model == null) return;
    
    try {
      final prompt = '''
GÖREV: Hafıza Temizliği (Memory Garbage Collection)
Aşağıdaki kullanıcı verileri çok şişti. Lütfen bu listeleri analiz et, birbirini tekrar edenleri birleştir ve EN ÖNEMLİ, KÖK maddeleri seçerek listeyi kısalt.

MEVCUT VERİLER:
${targets.contains('triggers') ? 'Tetikleyiciler (${currentDNA.triggers?.length}): ${currentDNA.triggers}' : ''}
${targets.contains('fears') ? 'Korkular (${currentDNA.fears?.length}): ${currentDNA.fears}' : ''}
${targets.contains('goals') ? 'Hedefler (${currentDNA.goals?.length}): ${currentDNA.goals}' : ''}

İSTENEN ÇIKTI (JSON):
{
  "user_dna": {
    ${targets.contains('triggers') ? '"triggers": ["...en önemli 5-7 madde..."],' : ''}
    ${targets.contains('fears') ? '"fears": ["...en önemli 5-7 madde..."],' : ''}
    ${targets.contains('goals') ? '"goals": ["...en önemli 5-7 madde..."]' : ''}
  }
}
''';

      final promptWithLang = '${AppLocale.languageInstructionForAI}\n\n$prompt';
      final response = await _model!.generateContent([Content.text(promptWithLang)]);
      final updates = _parseResponse(response.text ?? '');
      
      if (updates != null) {
        final dnaUpdates = UserDNAService.parseUpdatesFromJson(updates);
        if (dnaUpdates != null) {
          // We need to OVERWRITE the specific lists, not merge.
          // UserDNAService.updateDNA merges by default.
          // To support overwrite, we might need a specific flag or method, 
          // bu for now, let's assume updateDNA's merge logic simply adds. 
          // WAIT: To prune, we must REPLACE the list. 
          // Since UserDNAService.merge ADDS to the list, we need to handle this.
          // Solution: We will manually update Firestore to overwrite these specific fields.
          
          // Actually, UserDNAService has updateDNA which merges. 
          // Let's rely on UserDNAService exposing a 'replace' method or similar.
          // or we can implement a custom overwrite here using Firestore directly if we had access, 
          // but we don't have AuthService imported here properly for direct use maybe? 
          // UserDNAService imports AuthService.
          
          // Let's try to just call updateDNA for now, but realizing merge will keep old ones.
          // Modification: The simplest way without changing UserDNAService architecture 
          // is to allow 'updateDNA' to accept an 'overwrite' flag or similar? 
          // Or simpler: UserDNAService.updateDNA logic: 
          // _mergeList(existing, updates) -> joins them.
          
          // Okay, I need to modify UserDNAService to allow overwriting lists or
          // I can call a new method in UserDNAService 'overwriteDNA' which I will create?
          // No, let's just use a special method in UserDNAService if possible.
          // Or easier: Update UserDNAService.mergeList logic to handle a 'REPLACE' command? No.
          
          // Best approach: Add a forceOverwrite option to updateDNA in UserDNAService.
          // But I cannot modify UserDNAService right now in this single tool call easily.
          // I will assume for this step I write the logic, but I should also update UserDNAService 
          // to support list replacement. 
          
          // However, for this specific request, the user said "Implement Memory Pruning".
          // I will implement the logic here and then in the next step update UserDNAService 
          // to support list replacement (resetting lists).
          
          // For now, let's just log the pruned lists would be applied.
          // BUT to be functional, I really need that capability.
          
          // Let's implement _overwriteSpecificLists method here that calls Firestore directly?
          // ShadowMemoryService imports UserDNAService. It does NOT import AuthService.
          // So I can't call Firestore directly.
          
          // I will proceed with this change, and then add a method in UserDNAService called `overrideLists`.
          
          await UserDNAService.overrideLists(dnaUpdates); 
          debugPrint('ShadowMemory: Garbage Collection Complete. Memory optimized. 🧹');
        }
      }
    } catch (e) {
      debugPrint('ShadowMemory: Pruning failed: $e');
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

  static Future<List<String>> _detectTriggerTags(String message) async {
    final text = message.toLowerCase();
    final cfg = await MemoryTriggerConfigService.getConfig();
    final tags = <String>[];
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
    }
    if (hasAny(cfg.explicit)) {
      tags.add('explicit');
    }
    return tags;
  }

  /// Apply Addiction tracking updates to User DNA
  static Future<void> _applyAddictionUpdates(Map<String, dynamic> updates) async {
    final addictionData = updates['addiction_data'] as Map<String, dynamic>?;
    if (addictionData == null) return;

    try {
      List<String> newTriggers = [];
      
      // Extract addiction type
      final addictionType = addictionData['addiction_type'];
      if (addictionType != null && addictionType.toString().isNotEmpty) {
        debugPrint('ShadowMemory: Addiction type detected: $addictionType');
      }
      
      // Extract triggers detected from addiction conversation
      final triggersDetected = addictionData['triggers_detected'] as List<dynamic>?;
      if (triggersDetected != null && triggersDetected.isNotEmpty) {
        for (final trigger in triggersDetected) {
          final triggerStr = trigger.toString();
          if (triggerStr.isNotEmpty) {
            newTriggers.add(triggerStr);
          }
        }
      }
      
      // Check for relapse or success notes
      final relapseNoted = addictionData['relapse_noted'] as bool? ?? false;
      final successNoted = addictionData['success_noted'] as bool? ?? false;
      
      if (relapseNoted) {
        debugPrint('ShadowMemory: Relapse noted in conversation');
      }
      if (successNoted) {
        debugPrint('ShadowMemory: Success/resistance noted in conversation');
      }
      
      // Add new triggers to User DNA
      if (newTriggers.isNotEmpty) {
        final currentDNA = UserDNAService.currentDNA;
        final existingTriggers = currentDNA?.triggers ?? [];
        
        // Merge triggers (avoid duplicates)
        final mergedTriggers = <String>{...existingTriggers};
        for (final trigger in newTriggers) {
          if (!mergedTriggers.any((t) => t.toLowerCase() == trigger.toLowerCase())) {
            mergedTriggers.add(trigger);
          }
        }
        
        if (mergedTriggers.length > existingTriggers.length) {
          // Create update with new triggers
          final dnaUpdate = UserDNAService.parseUpdatesFromJson({
            'user_dna': {
              'triggers': mergedTriggers.toList(),
            }
          });
          
          if (dnaUpdate != null) {
            await UserDNAService.updateDNA(dnaUpdate);
            debugPrint('ShadowMemory: Addiction triggers saved to DNA ✓ (${newTriggers.join(", ")})');
          }
        }
      }
    } catch (e) {
      debugPrint('ShadowMemory: Error applying addiction updates: $e');
    }
  }
}
