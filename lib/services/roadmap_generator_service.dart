// lib/services/roadmap_generator_service.dart
// Motivasyon Modülü - Yol Haritası Üretici

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/goal_model.dart';
import 'goal_service.dart';
import 'user_dna_service.dart';

/// Roadmap Generator - Gemini ile yol haritası üretimi
class RoadmapGeneratorService {
  static GenerativeModel? _model;

  // ============================================================
  // TAB 2 PROMPT - STRATEJİ MOTORU
  // ============================================================
  static const String _roadmapPrompt = '''
GÖREV: Sen Mentaliq uygulamasının strateji ve planlama motorusun. Kullanıcının girdiği spesifik hedefe ulaşması için gerçekçi, profesyonel ve adım adım bir yol haritası (roadmap) oluşturmalısın.

GİRDİLER:
- HEDEF: {user_goal}
- MEVCUT DURUM: {user_status}
- KULLANICININ YETENEKLERİ: {user_skills}
- GÜNLÜK AYRILABİLECEK SÜRE: {user_time} saat
- ÖZEL NOTLAR: {special_notes}
- KULLANICI DNA'SI (Karakter & Değerler): {user_dna}

ÇIKTI FORMATI (KATI BİR ŞEKİLDE SADECE JSON):
{
  "roadmap_title": "Hedefe özel, motive edici başlık",
  "total_weeks": 8,
  "steps": [
    {
      "week": 1,
      "focus": "Haftanın ana teması",
      "difficulty": "Kolay/Orta/Zor",
      "tasks": [
        "Spesifik görev 1 (Duyusal ve aksiyon bazlı)",
        "Spesifik görev 2",
        "Spesifik görev 3"
      ]
    }
  ]
}

KRİTİK KURALLAR:
1. HEDEFE SADIK KAL: Kullanıcı "İnşaat" diyorsa inşaat, "Aşçılık" diyorsa aşçılık üzerine yaz. Eğer hedef yazılımla ilgili DEĞİLSE, kesinlikle Python, JavaScript gibi yazılım terimleri kullanma.
2. YETENEKLERİ KULLAN: Kullanıcının zaten bildiği veya iyi olduğu alanları ({user_skills}) plana dahil et, bu yetenekleri kaldıraç olarak kullan.
3. GERÇEKÇİ OL: Günlük süre kısıtına göre yapılabilecek görevler ver.
4. DİL: Sadece Türkçe konuş.
5. FORMAT: JSON dışında hiçbir açıklama metni ekleme.
6. DNA UYUMU: Kullanıcının korkularını ({user_dna}) tetiklemeden, değerlerine uygun bir üslup ve hız benimse.
''';

  /// Initialize generator
  static void initialize(String apiKey) {
    try {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topP: 0.9,
          maxOutputTokens: 2048,
        ),
      );
      debugPrint('RoadmapGeneratorService initialized');
    } catch (e) {
      debugPrint('Error initializing RoadmapGeneratorService: $e');
    }
  }

  /// Generate roadmap from goal
  static Future<GoalRoadmap?> generateRoadmap(GoalModel goal) async {
    if (_model == null) {
      debugPrint('RoadmapGenerator: Model not initialized');
      return null;
    }

    try {
      debugPrint('RoadmapGenerator: Generating roadmap for: ${goal.title}');

      // Build prompt with user data
      final userDNA = await UserDNAService.getDNAForAI();
      final prompt = _roadmapPrompt
          .replaceAll('{user_goal}', goal.title)
          .replaceAll('{user_status}', goal.currentStatus)
          .replaceAll('{user_skills}', goal.skills ?? 'Belirtilmedi')
          .replaceAll('{user_time}', goal.dailyHours.toString())
          .replaceAll('{special_notes}', goal.specialNotes ?? 'Yok')
          .replaceAll('{user_dna}', userDNA);

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text?.trim() ?? '';

      debugPrint('RoadmapGenerator raw response: $responseText');

      // Parse JSON response
      final roadmap = _parseRoadmapResponse(responseText);
      
      if (roadmap != null) {
        // Save to Firebase
        await GoalService.saveRoadmap(goal.id, roadmap);
        debugPrint('RoadmapGenerator: Roadmap generated and saved ✓');
      }

      return roadmap;
    } catch (e) {
      debugPrint('RoadmapGenerator error: $e');
      return null;
    }
  }

  /// Parse AI response to GoalRoadmap
  static GoalRoadmap? _parseRoadmapResponse(String responseText) {
    try {
      // Clean response - remove markdown code blocks if present
      String cleanJson = responseText;
      if (cleanJson.contains('```json')) {
        cleanJson = cleanJson.split('```json')[1].split('```')[0].trim();
      } else if (cleanJson.contains('```')) {
        cleanJson = cleanJson.split('```')[1].split('```')[0].trim();
      }

      final Map<String, dynamic> data = json.decode(cleanJson);
      
      final steps = (data['steps'] as List<dynamic>).map((stepData) {
        final List<String> taskTitles = (stepData['tasks'] as List<dynamic>)
            .map((t) => t.toString())
            .toList();
            
        final week = stepData['week'] ?? 1;
        
        // Convert titles to GoalTask objects
        final tasks = taskTitles.map((title) => GoalTask(
          id: DateTime.now().millisecondsSinceEpoch.toString() + title.hashCode.toString(),
          title: title,
          stepNo: week,
          isCompleted: false,
        )).toList();

        return RoadmapStep(
          stepNo: week,
          title: 'Hafta $week: ${stepData['focus']}',
          description: taskTitles.join('\n'), // Geriye dönük uyumluluk için tutuyoruz
          deadline: '$week. Hafta',
          difficulty: stepData['difficulty'] ?? 'Orta',
          isCompleted: false,
          tasks: tasks,
        );
      }).toList();

      return GoalRoadmap(
        steps: steps,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('RoadmapGenerator: Failed to parse JSON: $e');
      return null;
    }
  }
}
