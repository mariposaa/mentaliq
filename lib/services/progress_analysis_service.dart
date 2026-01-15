// lib/services/progress_analysis_service.dart
// Motivasyon Modülü - İlerleme Analizi Servisi

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/goal_model.dart';
import 'goal_service.dart';
import 'user_dna_service.dart';

/// Progress Analysis Service - İlerleme analizi ve AI yorumu
class ProgressAnalysisService {
  static GenerativeModel? _model;

  // ============================================================
  // TAB 4 PROMPT - ANALİZ MOTORU
  // ============================================================
  static const String _analysisPrompt = '''
GÖREV: Kullanıcının ilerlemesini analiz et.

VERİ:
- Ana Hedef: {user_goal}
- Toplam Adım: {total_steps}
- Tamamlanan Adım: {completed_steps}
- İlerleme Oranı: %{progress_rate}
- Kullanıcı Notları: {user_notes}
- KULLANICI DNA'SI: {user_dna}

ÇIKTI FORMATI (SADECE JSON):
{
  "summary": "3 cümlelik samimi ama analitik durum değerlendirmesi. Kullanıcının notlarını dikkate al ve tavsiye ver.",
  "strengths": ["İyi gittiği alan 1", "İyi gittiği alan 2"],
  "improvements": ["Geliştirilmesi gereken alan"],
  "next_focus": "Yarın için önerilen odak alanı"
}

KURALLAR:
1. SADECE JSON ver, açıklama yapma.
2. Samimi ama analitik ol.
3. Kullanıcının notlarındaki sorunları dikkate al.
4. Motive edici ama gerçekçi ol.
5. Türkçe yaz.
6. PSİKOLOJİK DERİNLİK: Analizini kullanıcının DNA'sındaki ({user_dna}) kişilik özelliklerine göre yap. Eğer kullanıcı "başarısızlık korkusu" olan biriyse, raporu daha cesaretlendirici ve iyileştirici bir tonda yaz.
''';

  /// Initialize service
  static void initialize(String apiKey) {
    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topP: 0.9,
          maxOutputTokens: 512,
        ),
      );
      debugPrint('ProgressAnalysisService initialized');
    } catch (e) {
      debugPrint('Error initializing ProgressAnalysisService: $e');
    }
  }

  /// Calculate progress stats from goal
  static ProgressStats calculateStats(GoalModel? goal) {
    if (goal == null || goal.roadmap == null) {
      return ProgressStats(
        totalSteps: 0,
        completedSteps: 0,
        progressRate: 0,
        totalTasks: 0,
        completedTasks: 0,
      );
    }

    final steps = goal.roadmap!.steps;
    final completedSteps = steps.where((s) => s.isCompleted).length;
    
    // Count all tasks
    int totalTasks = 0;
    int completedTasks = 0;
    
    for (final step in steps) {
      final tasks = step.description.split('\n').where((t) => t.trim().isNotEmpty);
      totalTasks += tasks.length;
      if (step.isCompleted) {
        completedTasks += tasks.length;
      }
    }

    final progressRate = steps.isEmpty ? 0 : ((completedSteps / steps.length) * 100).round();

    return ProgressStats(
      totalSteps: steps.length,
      completedSteps: completedSteps,
      progressRate: progressRate,
      totalTasks: totalTasks,
      completedTasks: completedTasks,
    );
  }

  /// Generate AI analysis
  static Future<ProgressAnalysis?> generateAnalysis() async {
    if (_model == null) {
      debugPrint('ProgressAnalysis: Model not initialized');
      return null;
    }

    try {
      final goal = await GoalService.getActiveGoal();
      if (goal == null) {
        return _getDefaultAnalysis();
      }

      final stats = calculateStats(goal);
      
      // Collect user notes from progress logs
      final userNotes = goal.progressLogs
          ?.map((log) => log.note)
          .where((n) => n.isNotEmpty)
          .join('. ') ?? 'Henüz not eklenmemiş';

      debugPrint('ProgressAnalysis: Generating for goal: ${goal.title}');

      final userDNA = await UserDNAService.getDNAForAI();

      // Build prompt
      final prompt = _analysisPrompt
          .replaceAll('{user_goal}', goal.title)
          .replaceAll('{total_steps}', stats.totalSteps.toString())
          .replaceAll('{completed_steps}', stats.completedSteps.toString())
          .replaceAll('{progress_rate}', stats.progressRate.toString())
          .replaceAll('{user_notes}', userNotes)
          .replaceAll('{user_dna}', userDNA);

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text?.trim() ?? '';

      debugPrint('ProgressAnalysis raw response: $responseText');

      final analysis = _parseAnalysisResponse(responseText);
      
      if (analysis != null) {
        // Save to goal
        await _saveAnalysis(goal.id, analysis, stats);
        debugPrint('ProgressAnalysis: Generated successfully ✓');
      }

      return analysis ?? _getDefaultAnalysis();
    } catch (e) {
      debugPrint('ProgressAnalysis error: $e');
      return _getDefaultAnalysis();
    }
  }

  /// Parse AI response
  static ProgressAnalysis? _parseAnalysisResponse(String responseText) {
    try {
      String cleanJson = responseText;
      if (cleanJson.contains('```json')) {
        cleanJson = cleanJson.split('```json')[1].split('```')[0].trim();
      } else if (cleanJson.contains('```')) {
        cleanJson = cleanJson.split('```')[1].split('```')[0].trim();
      }

      final Map<String, dynamic> data = json.decode(cleanJson);
      
      return ProgressAnalysis(
        summary: data['summary'] ?? 'Analiz tamamlandı.',
        strengths: (data['strengths'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
        improvements: (data['improvements'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
        nextFocus: data['next_focus'] ?? 'Çalışmaya devam et.',
      );
    } catch (e) {
      debugPrint('ProgressAnalysis: Failed to parse JSON: $e');
      return null;
    }
  }

  /// Save analysis to Firebase
  static Future<void> _saveAnalysis(String goalId, ProgressAnalysis analysis, ProgressStats stats) async {
    try {
      final goalAnalysis = GoalAnalysis(
        successRate: stats.progressRate,
        aiComment: analysis.summary,
        lastUpdatedAt: DateTime.now(),
      );

      final goal = GoalService.currentGoal;
      if (goal != null) {
        final updatedGoal = goal.copyWith(analysis: goalAnalysis);
        await GoalService.updateGoal(updatedGoal);
      }
    } catch (e) {
      debugPrint('ProgressAnalysis: Error saving: $e');
    }
  }

  /// Default analysis
  static ProgressAnalysis _getDefaultAnalysis() {
    return ProgressAnalysis(
      summary: 'Henüz yeterli veri yok. Görevlerine başla ve ilerlemeni takip et!',
      strengths: [],
      improvements: [],
      nextFocus: 'İlk adımı at.',
    );
  }
}

/// Progress Stats Model
class ProgressStats {
  final int totalSteps;
  final int completedSteps;
  final int progressRate;
  final int totalTasks;
  final int completedTasks;

  ProgressStats({
    required this.totalSteps,
    required this.completedSteps,
    required this.progressRate,
    required this.totalTasks,
    required this.completedTasks,
  });
}

/// Progress Analysis Model
class ProgressAnalysis {
  final String summary;
  final List<String> strengths;
  final List<String> improvements;
  final String nextFocus;

  ProgressAnalysis({
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.nextFocus,
  });
}
