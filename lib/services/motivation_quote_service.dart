// lib/services/motivation_quote_service.dart
// Motivasyon Modülü - Kişisel Motivasyon Üretici

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/goal_model.dart';
import 'goal_service.dart';

/// Motivation Quote Service - Hedefe özel motivasyon sözleri üretir
class MotivationQuoteService {
  static GenerativeModel? _model;
  static String? _cachedQuote;
  static DateTime? _lastGeneratedAt;

  // ============================================================
  // TAB 3 PROMPT - MOTİVASYON MOTORU
  // ============================================================
  static const String _motivationPrompt = '''
GÖREV: Sen Mentaliq uygulamasının motivasyon motorusun. 
Kullanıcının hedefine ve bugünkü görevine özel, GÜÇLÜ ve VURUCU bir motivasyon mesajı üret.

GİRDİ:
- Ana Hedef: {user_goal}
- Mevcut Durum: {user_status}
- Bugünkü Görev: {today_task}
- Hafta: {current_week}

ÇIKTI FORMATI (SADECE JSON):
{
  "quote": "Vurucu, kısa ve hedefi hatırlatan motivasyon mesajı (1-3 cümle)",
  "emoji": "Mesajı temsil eden tek emoji"
}

ÖRNEKLER:
- "Tarih sadece geçmiş değildir, senin geleceğindeki atama anahtarıdır. O 20 soruyu çöz, rakiplerin uyurken öne geç."
- "Her satır kod, hayalindeki şirkete bir adım daha. Bugün zorlanacaksın ama yarın teşekkür edeceksin."
- "Matematiği sevmesen de o seni sevecek. 15 soru, sadece 15 soru."

KURALLAR:
1. SADECE JSON ver, açıklama yapma.
2. Mesaj kısa, vurucu ve hedefe özel olsun.
3. Kullanıcının bugünkü görevine referans ver.
4. Motivasyonel ama gerçekçi ol, abartma.
5. Türkçe yaz.
''';

  /// Initialize service
  static void initialize(String apiKey) {
    try {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.9, // Yaratıcılık için yüksek
          topP: 0.95,
          maxOutputTokens: 256,
        ),
      );
      debugPrint('MotivationQuoteService initialized');
    } catch (e) {
      debugPrint('Error initializing MotivationQuoteService: $e');
    }
  }

  /// Generate personalized motivation quote
  static Future<MotivationQuote?> generateQuote({bool forceRefresh = false}) async {
    if (_model == null) {
      debugPrint('MotivationQuote: Model not initialized');
      return null;
    }

    // Return cached if recent (within 1 hour) and not forcing refresh
    if (!forceRefresh && _cachedQuote != null && _lastGeneratedAt != null) {
      final hoursSinceGenerated = DateTime.now().difference(_lastGeneratedAt!).inHours;
      if (hoursSinceGenerated < 1) {
        debugPrint('MotivationQuote: Returning cached quote');
        return MotivationQuote(quote: _cachedQuote!, emoji: '🔥');
      }
    }

    try {
      final goal = await GoalService.getActiveGoal();
      if (goal == null) {
        return _getDefaultQuote();
      }

      // Get today's task from roadmap
      final todayTask = _getTodayTask(goal);
      final currentWeek = _getCurrentWeek(goal);

      debugPrint('MotivationQuote: Generating for goal: ${goal.title}');

      // Build prompt
      final prompt = _motivationPrompt
          .replaceAll('{user_goal}', goal.title)
          .replaceAll('{user_status}', goal.currentStatus)
          .replaceAll('{today_task}', todayTask)
          .replaceAll('{current_week}', currentWeek.toString());

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text?.trim() ?? '';

      debugPrint('MotivationQuote raw response: $responseText');

      final quote = _parseQuoteResponse(responseText);
      
      if (quote != null) {
        _cachedQuote = quote.quote;
        _lastGeneratedAt = DateTime.now();
        debugPrint('MotivationQuote: Generated successfully ✓');
      }

      return quote ?? _getDefaultQuote();
    } catch (e) {
      debugPrint('MotivationQuote error: $e');
      return _getDefaultQuote();
    }
  }

  /// Get today's task from roadmap
  static String _getTodayTask(GoalModel goal) {
    if (goal.roadmap == null || goal.roadmap!.steps.isEmpty) {
      return 'Hedefine doğru çalış';
    }

    // Find first incomplete step
    final incompleteStep = goal.roadmap!.steps
        .firstWhere((s) => !s.isCompleted, orElse: () => goal.roadmap!.steps.first);

    // Get first task from step description
    final tasks = incompleteStep.description.split('\n');
    return tasks.isNotEmpty ? tasks.first : incompleteStep.title;
  }

  /// Get current week number
  static int _getCurrentWeek(GoalModel goal) {
    if (goal.roadmap == null || goal.roadmap!.steps.isEmpty) return 1;

    // Find first incomplete step
    final incompleteIndex = goal.roadmap!.steps
        .indexWhere((s) => !s.isCompleted);
    
    return incompleteIndex >= 0 ? incompleteIndex + 1 : 1;
  }

  /// Parse AI response
  static MotivationQuote? _parseQuoteResponse(String responseText) {
    try {
      String cleanJson = responseText;
      if (cleanJson.contains('```json')) {
        cleanJson = cleanJson.split('```json')[1].split('```')[0].trim();
      } else if (cleanJson.contains('```')) {
        cleanJson = cleanJson.split('```')[1].split('```')[0].trim();
      }

      final Map<String, dynamic> data = json.decode(cleanJson);
      
      return MotivationQuote(
        quote: data['quote'] ?? 'Bugün de hedefine bir adım daha at.',
        emoji: data['emoji'] ?? '🔥',
      );
    } catch (e) {
      debugPrint('MotivationQuote: Failed to parse JSON: $e');
      return null;
    }
  }

  /// Default quote when no goal or error
  static MotivationQuote _getDefaultQuote() {
    return MotivationQuote(
      quote: 'Her yeni gün, yeni bir başlangıç. Hedefini belirle ve yürümeye başla.',
      emoji: '🌟',
    );
  }

  /// Clear cache
  static void clearCache() {
    _cachedQuote = null;
    _lastGeneratedAt = null;
  }
}

/// Motivation Quote Model
class MotivationQuote {
  final String quote;
  final String emoji;

  MotivationQuote({required this.quote, required this.emoji});
}
