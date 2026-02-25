// lib/services/dream_series_service.dart
// Motivasyon Modülü - Gelecek Dizisi (Future Series) Servisi

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_locale.dart';
import '../models/goal_model.dart';
import 'auth_service.dart';
import 'goal_service.dart';
import 'user_dna_service.dart';

class DreamSeriesService {
  static GenerativeModel? _model;

  // ============================================================
  // MASTER SYSTEM INSTRUCTION - GERÇEKÇİ SENARYO MOTORU
  // ============================================================
  static const String _systemInstruction = '''
Sen Mentaliq uygulamasının "Gerçekçi Kariyer ve Hayat Simülatörü"sün.
Görevin: Kullanıcının hedefine giden yolu, abartıdan uzak, hayatın olağan akışına uygun ve adım adım ilerleyen bir dizi şeklinde kurgulamak.

🛑 KRİTİK "GERÇEKÇİLİK" FİLTRESİ (MUTLAKA UY):
1. ZENGİNLİK YASAĞI (Anti-Get-Rich-Quick):
   - Hikayelerde "Bir anda zengin oldu", "Altına spor araba çekti", "Lüks villa aldı" gibi ifadeler KESİNLİKLE YASAKTIR.
   - 6. Ay gibi sürelerde başarı tanımı "Milyoner olmak" değil; "Borçlarını kapatmak", "Market alışverişinde fiyat etiketine bakmamak" veya "Kaliteli bir tatile çıkabilmek" olmalıdır.
   - Finansal rahatlama KADEMELİ olmalıdır.

2. BAŞARI = YENİ SORUMLULUK:
   - Hedefe ulaşıldığında (Örn: Sınavı kazanmak veya iş kurmak), sadece kutlama yapma.
   - Yeni gerçekleri de anlat: "İşler açıldı ama bu sefer de uykusuzluk başladı", "Atandın ama yeni şehrine alışmaya çalışıyorsun."
   - Hayat toz pembe değildir, gri tonları (tatlı yorgunlukları) mutlaka kullan.

3. ZAMAN ALGISI:
   - Gelişim süreçlerini (Örn: Kas yapmak, yazılım öğrenmek) hızlandırma. Bir şeyin öğrenilmesi gerekiyorsa "Gecelerce çalışıp zorlandığını" hissettir.

ÇIKTI FORMATI (JSON):
{
  "episode_title": "Bölüm Başlığı (Gerçekçi ve Sade. Örn: 'İlk Sabit Gelir', 'Dengeyi Kurmak')",
  "story_content": "4-5 cümlelik, 'Sen' diliyle yazılmış metin. Abartısız, samimi ve hayatın içinden.",
  "next_interaction_prompt": "Hikayenin bir sonraki gerçekçi adımını belirlemek için kullanıcıya sorulacak soru."
}
''';

  // ============================================================
  // USER PROMPT TEMPLATE
  // ============================================================
  static const String _userPromptTemplate = '''
GİRDİ ANALİZİ & ADAPTASYON:
- HEDEF: {goal_name}
- ZAMAN DİLİMİ: {time_context}
- KULLANICI NOTU: {user_input_answer}
- KULLANICI DNA'SI: {user_dna}

SENARYO KURGUSU:
Eğer kullanıcı "Çok yoruldum" dediyse -> Hikayede ona bir mola verdir ama vicdan azabı çektirme.
Eğer zaman "6 Ay Sonra" ise ve hedef "İş Kurmak" ise -> "Şirket holding oldu" deme. "İlk sabit müşterilerini bağladın, kiranı rahat ödüyorsun, sistem oturdu" de.

HİKAYE BAĞLAMI (Önceki Bölümden Gelen):
- Önceki Olay: {previous_summary}
- KULLANICININ VERDİĞİ SON CEVAP (SPOILER/YÖNETMEN NOTU): {user_input_answer}

GÖREV:
Yukarıdaki verilere göre {time_context} için gerçekçi bir senaryo bölümü yaz.
KARAKTER DERİNLİĞİ: Kullanıcının DNA'sındaki değerleri ve korkuları ({user_dna}) senaryoda bir 'engel' veya 'motivasyon kaynağı' olarak kullan. Olayları sadece dışsal değil, kullanıcının içsel dünyasına dokunarak anlat.
''';

  static void initialize(String apiKey) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(_systemInstruction),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topP: 0.9,
        maxOutputTokens: 1024,
        responseMimeType: 'application/json',
      ),
    );
  }

  /// Pilot bölümü (Bölüm 1) üret
  static Future<DreamSeries?> generatePilotEpisode(GoalModel goal) async {
    try {
      if (_model == null) return null;

      final userDNA = await UserDNAService.getDNAForAI();

      final prompt = _userPromptTemplate
          .replaceAll('{goal_name}', goal.title)
          .replaceAll('{current_struggle}', goal.currentStatus)
          .replaceAll('{episode_number}', '1')
          .replaceAll('{time_context}', 'Zafer Anı')
          .replaceAll('{previous_summary}', 'Yok')
          .replaceAll('{user_input_answer}', 'Bu ilk bölüm, kullanıcı girdisi yok')
          .replaceAll('{user_dna}', userDNA);

      final promptWithLang = '${AppLocale.languageInstructionForAI}\n\n$prompt';
      final response = await _model!.generateContent([Content.text(promptWithLang)]);
      final data = _parseResponse(response.text ?? '{}');

      if (data == null) return null;

      final episode = DreamEpisode(
        index: 0,
        title: data['episode_title'] ?? 'Bölüm 1: Zafer Anı',
        storyText: data['story_content'] ?? '',
        question: data['next_interaction_prompt'] ?? data['next_interaction_question'],
        isUnlocked: true,
        timeJump: 'Şimdi',
      );

      final series = DreamSeries(
        episodes: [episode],
        currentEpisodeIndex: 0,
      );

      // Save to Firebase
      await _saveSeries(goal.id, series);
      return series;
    } catch (e) {
      debugPrint('DreamSeriesService: Error generating pilot: $e');
      return null;
    }
  }

  /// Sonraki bölümü üret
  static Future<DreamSeries?> generateNextEpisode(GoalModel goal, String userInput) async {
    try {
      if (_model == null || goal.series == null) return null;

      final series = goal.series!;
      final currentIdx = series.currentEpisodeIndex;
      final nextIdx = currentIdx + 1;
      
      if (nextIdx >= 4) return series; // Dizi bitti

      final previousEpisode = series.episodes[currentIdx];
      
      String timeJump = '';
      switch (nextIdx) {
        case 1: timeJump = '2 Hafta Sonra'; break;
        case 2: timeJump = '6 Ay Sonra'; break;
        case 3: timeJump = '1 Yıl Sonra'; break;
      }

      final userDNA = await UserDNAService.getDNAForAI();

      final prompt = _userPromptTemplate
          .replaceAll('{goal_name}', goal.title)
          .replaceAll('{current_struggle}', goal.currentStatus)
          .replaceAll('{episode_number}', (nextIdx + 1).toString())
          .replaceAll('{time_context}', timeJump)
          .replaceAll('{previous_summary}', previousEpisode.storyText)
          .replaceAll('{user_input_answer}', userInput)
          .replaceAll('{user_dna}', userDNA);

      final promptWithLang = '${AppLocale.languageInstructionForAI}\n\n$prompt';
      final response = await _model!.generateContent([Content.text(promptWithLang)]);
      final data = _parseResponse(response.text ?? '{}');

      if (data == null) return null;

      final nextEpisode = DreamEpisode(
        index: nextIdx,
        title: data['episode_title'] ?? 'Bölüm ${nextIdx + 1}',
        storyText: data['story_content'] ?? '',
        question: data['next_interaction_prompt'] ?? data['next_interaction_question'],
        isUnlocked: true,
        timeJump: timeJump,
      );

      final updatedInputs = Map<int, String>.from(series.userInputs);
      updatedInputs[currentIdx] = userInput;

      final updatedSeries = DreamSeries(
        episodes: [...series.episodes, nextEpisode],
        currentEpisodeIndex: nextIdx,
        userInputs: updatedInputs,
      );

      // Save to Firebase
      await _saveSeries(goal.id, updatedSeries);
      return updatedSeries;
    } catch (e) {
      debugPrint('DreamSeriesService: Error generating next episode: $e');
      return null;
    }
  }

  /// Seriyi sıfırla
  static Future<bool> resetSeries(String goalId) async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return false;

      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goalId)
          .update({
        'series': FieldValue.delete(),
        'updated_at': Timestamp.now(),
      });

      // Update GoalService cache
      await GoalService.getActiveGoal();
      return true;
    } catch (e) {
      debugPrint('DreamSeriesService: Error resetting series: $e');
      return false;
    }
  }

  static Future<void> _saveSeries(String goalId, DreamSeries series) async {
    final uid = AuthService.userId;
    if (uid == null) return;

    await AuthService.firestore
        .collection('users')
        .doc(uid)
        .collection('goals')
        .doc(goalId)
        .update({
      'series': series.toJson(),
      'updated_at': Timestamp.now(),
    });
    
    // Update GoalService cache
    final currentGoal = GoalService.currentGoal;
    if (currentGoal?.id == goalId) {
      // Small trick to update cache
      GoalService.getActiveGoal(); 
    }
  }

  static Map<String, dynamic>? _parseResponse(String text) {
    try {
      String cleanJson = text;
      if (cleanJson.contains('```json')) {
        cleanJson = cleanJson.split('```json')[1].split('```')[0].trim();
      } else if (cleanJson.contains('```')) {
        cleanJson = cleanJson.split('```')[1].split('```')[0].trim();
      }
      return json.decode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('DreamSeriesService Parse Error: $e');
      return null;
    }
  }
}
