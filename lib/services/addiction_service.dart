import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user_dna_model.dart';
import '../services/user_dna_service.dart';
import '../services/gemini_service.dart';

/// ACTIVE ADDICTION SERVICE (MASTER PLAN)
class AddictionService {
  
  // --- SYSTEM PROMPTS (MULTI-ROLE) ---

  static String _getAuditorPrompt() {
    return '''
You are 'The Auditor'. The user is fighting gambling addiction.
Identity: World-class Behavioral Economist & Math Expert. Cold, analytical, truth-focused.
Psychological Framework: 'Prospect Theory' & 'Cognitive Debiasing'.
Core Tasks:
1. DEBUNK: Use 'Gambler’s Fallacy' (The coin has no memory) to destroy "luck is due" thoughts.
2. FINANCIAL REALITY: Constantly reference 'Total Lost Capital'. Show the 'Opportunity Cost' (e.g., "With that 5000TL, you burnt a vacation").
3. TONE: No empathy for value destruction. Sobering, mathematical, high-impact.
Language: Detect user's system language and respond in that language.
''';
  }

  static String _getBioHackerPrompt() {
    return '''
You are 'The Bio-Hacker'. User is fighting substance addiction (Smoking/Sugar).
Identity: Neurochemistry & Physiology Expert. 
Psychological Framework: 'Interoceptive Exposure' & 'ACT (Acceptance and Commitment Therapy)'.
Core Tasks:
1. URGE SURFING: Remind them cravings follow a wave pattern (peak at 3 mins, then subside).
2. PHYSIOLOGY: Give somatic commands (e.g., "activate mammalian dive reflex with cold water").
3. REFRAMING: Shift focus from "deprivation" to "healing dopamine receptors".
Tone: Clinical, calm, authoritative but grounding.
Language: Detect user's system language and respond in that language.
''';
  }

  static String _getArchitectPrompt() {
    return '''
You are 'The Architect'. User is fighting digital addiction (Social Media/Gaming).
Identity: Digital Minimalist & Attention Economy Strategist.
Psychological Framework: 'Environmental Design' & 'Dopamine Fasting'.
Core Tasks:
1. FRICTION: Instructions to increase physical/digital effort to access the addiction (e.g., "Grayscale mode", "Delete app icon").
2. ATTENTION: Explain how algorithms hack their 'Reward Prediction Error'.
3. REPLACEMENT: Suggest high-quality analog alternatives immediately.
Tone: Strategic, modern, 'Life-Hack' style.
Language: Detect user's system language and respond in that language.
''';
  }

  static String _getSystemPromptFor(String id) {
    if (id == 'gambling') return _getAuditorPrompt();
    if (['smoking', 'sugar', 'vaping'].contains(id)) return _getBioHackerPrompt();
    if (['social_media', 'gaming'].contains(id)) return _getArchitectPrompt();
    return _getBioHackerPrompt(); // Default fallback
  }

  // --- METHODS ---

  /// 1. ENTRY GREETING (Reality Check)
  static Future<String> getEntryGreeting(String addictionId) async {
    try {
      final dna = await UserDNAService.getDNAForAI();
      final sysPrompt = _getSystemPromptFor(addictionId);
      
      final response = await GeminiService.generateResponse(
        '$dna\nUSER JUST OPENED THE APP. Give a short, punchy reality check or question based on their stats.',
        'addiction_entry',
        customSystemPrompt: sysPrompt
      );
      return response;
    } catch (e) {
      return "Savaş devam ediyor. Hazır mısın?";
    }
  }

  /// 2. ACTIVE MISSION GENERATION
  static Future<String> getDynamicMission(String addictionId) async {
    try {
      final dna = await UserDNAService.getDNAForAI();
      final sysPrompt = _getSystemPromptFor(addictionId);
      
      // Determine Willpower State from DNA context (implied in the dna string)
      // We explicitly guide the AI on how to use it.
      const missionLogic = '''
MISSION LOGIC based on Willpower (Flow State Principle):
- If Willpower is LOW (<40%): Assign a 'Micro-Step' or 'Environmental' task. Low friction. (e.g., "Just put the phone face down", "Drink a glass of water").
- If Willpower is HIGH (>70%): Assign a 'Cognitive Challenge' or 'Exposure' task. High reward. (e.g., "Write down your trigger analysis", "Sit with the urge for 3 mins").
- NEVER repeat yesterday's mission.
- Mission must be actionable and completable in <10 mins.
''';

      final response = await GeminiService.generateResponse(
        '$dna\n$missionLogic\nGENERATE DAILY MISSION based on user\'s current stats.',
        'addiction_mission',
        customSystemPrompt: sysPrompt
      );
      return response.replaceAll('"', '').trim();
    } catch (e) {
      return "Bugün sadece iradeni koru.";
    }
  }

  /// 3. VERIFICATION CHAT (Before Puan Artışı)
  static Future<String> verifyMissionCompletion(String addictionId, String userFeeling) async {
    try {
      final dna = await UserDNAService.getDNAForAI();
      final sysPrompt = _getSystemPromptFor(addictionId);

      final response = await GeminiService.generateResponse(
        '$dna\nUser claims mission complete. Feeling: "$userFeeling". CHALLENGE THEM or VALIDATE based on persona.',
        'addiction_verify',
        customSystemPrompt: sysPrompt
      );
      return response;
    } catch (e) {
      return "Tamam, kaydettim.";
    }
  }

  /// 4. CRISIS CHAT (SOS)
  static Future<Stream<String>> startCrisisChat(String addictionId, String userMessage) async {
    // This would ideally return a stream of tokens, for now solving with single response future logic disguised
    // In a real implementation with Gemini Stream, this would be cleaner.
    // We will just return a single Future wrapped response for this architecture step.
    return const Stream.empty(); 
  }

  /// Backward-compatible SOS helper for old screens.
  static Future<List<String>?> triggerEmergency(String addictionId) async {
    try {
      final first = await handleCrisisMessage(
        addictionId,
        'Acil durumdayım. Beni şimdi gerçekliğe döndür.',
      );
      return [
        first,
        'Kasa senden hızlıdır; dürtün senden hızlı değil.',
        'Şu an sadece 3 dakika bekle ve tek bir derin nefes döngüsü yap.',
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<String> handleCrisisMessage(String addictionId, String message) async {
     try {
      final dna = await UserDNAService.getDNAForAI();
      final sysPrompt = _getSystemPromptFor(addictionId);
      
      // Add Urgency
      final fullPrompt = '$sysPrompt\nCRISIS MODE ACTIVE. USER SAYS: "$message". RESPOND IMMEDIATELY.';

      final response = await GeminiService.generateResponse(
        '$dna\nCRISIS: $message',
        'addiction_sos',
        customSystemPrompt: fullPrompt
      );
      return response;
    } catch (e) {
      return "Nefes al. Buradayım.";
    }
  }

  // --- STATE UPDATES ---

  static Future<void> completeMission(String addictionId) async {
    final userDna = UserDNAService.currentDNA;
    if (userDna == null || userDna.activeAddictions == null) return;

    final updatedAddictions = userDna.activeAddictions!.map((a) {
      if (a.id == addictionId) {
        return AddictionDna(
          id: a.id,
          type: a.type,
          willpowerIndex: (a.willpowerIndex + 0.05).clamp(0.0, 1.0), // Boost
          streakDays: a.streakDays + 1,
          totalLostCapital: a.totalLostCapital,
          averageDailyBet: a.averageDailyBet,
          highRiskDays: a.highRiskDays,
          triggers: a.triggers,
          currentMission: a.currentMission, 
          isMissionCompleted: true, // Mark done
        );
      }
      return a;
    }).toList();

    await UserDNAService.updateDNA(UserDNAModel(activeAddictions: updatedAddictions));
  }

  static Future<void> startTracking(String id, String type) async {
    final userDna = UserDNAService.currentDNA;
    final currentList = userDna?.activeAddictions ?? [];
    
    if (currentList.any((a) => a.id == id)) return; // Already tracking

    final newList = [...currentList, AddictionDna(id: id, type: type)];
    await UserDNAService.updateDNA(UserDNAModel(activeAddictions: newList));
  }
}
