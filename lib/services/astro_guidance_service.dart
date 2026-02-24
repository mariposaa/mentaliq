// lib/services/astro_guidance_service.dart
// Premium günlük astroloji yönerge servisi - 15 token

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/natal_chart_model.dart';
import '../models/daily_guidance_model.dart';
import 'auth_service.dart';
import 'user_dna_service.dart';
import 'natal_chart_service.dart';

class AstroGuidanceService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static final _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: _apiKey,
  );
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static String? lastError;

  /// Generate daily guidance (costs 15 tokens)
  static Future<DailyGuidanceModel?> generateDailyGuidance() async {
    lastError = null;
    debugPrint('AstroGuidanceService: Generating daily guidance');

    try {
      // 1. Get user's natal chart
      final natalChart = await NatalChartService.getSavedNatalChart();
      if (natalChart == null || !natalChart.isValid) {
        lastError = 'Natal harita bulunamadı. Önce doğum bilgilerinizi kaydedin.';
        return null;
      }

      // 2. Get user's Master DNA context
      final dnaContext = await UserDNAService.getDNAForAI();

      // 3. Build and send prompt
      final prompt = _buildDailyGuidancePrompt(
        natalChart: natalChart,
        dnaContext: dnaContext,
      );

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        lastError = 'Gemini yanıtı boş.';
        return null;
      }

      // 4. Extract JSON
      String text = response.text!;
      String jsonStr = '';
      
      if (text.contains('{')) {
        final firstOpen = text.indexOf('{');
        final lastClose = text.lastIndexOf('}');
        if (firstOpen != -1 && lastClose != -1 && lastClose > firstOpen) {
          jsonStr = text.substring(firstOpen, lastClose + 1);
        }
      }

      if (jsonStr.isEmpty) {
        lastError = 'JSON bloğu bulunamadı.';
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(jsonStr);
      data['generated_at'] = DateTime.now().toIso8601String();
      
      final guidance = DailyGuidanceModel.fromJson(data);
      
      // 5. Save to Firestore
      await _saveDailyGuidance(guidance);
      
      debugPrint('AstroGuidanceService: Daily guidance generated successfully');
      return guidance;
    } catch (e) {
      lastError = 'Yönerge oluşturma hatası: $e';
      debugPrint('AstroGuidanceService: Error generating guidance: $e');
      return null;
    }
  }

  /// Get today's saved guidance (if exists)
  static Future<DailyGuidanceModel?> getTodaysGuidance() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return null;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final doc = await _firestore
          .collection('astro_guidance')
          .doc(userId)
          .collection('daily')
          .doc(today)
          .get();

      if (doc.exists && doc.data() != null) {
        return DailyGuidanceModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('AstroGuidanceService: Error loading today guidance: $e');
      return null;
    }
  }

  /// Check if user already has guidance for today
  static Future<bool> hasGuidanceForToday() async {
    final guidance = await getTodaysGuidance();
    return guidance != null;
  }

  /// Save daily guidance to Firestore
  static Future<void> _saveDailyGuidance(DailyGuidanceModel guidance) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      await _firestore
          .collection('astro_guidance')
          .doc(userId)
          .collection('daily')
          .doc(today)
          .set({
            ...guidance.toJson(),
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('AstroGuidanceService: Error saving guidance: $e');
    }
  }

  /// Build the premium daily guidance prompt
  static String _buildDailyGuidancePrompt({
    required NatalChartModel natalChart,
    required String dnaContext,
  }) {
    final today = DateFormat('dd MMMM yyyy', 'en').format(DateTime.now());
    final natalJson = jsonEncode(natalChart.toJson());

    return '''
You are a world-class consulting astrologer combining Jungian psychology, behavioral science, and traditional astrological wisdom. Your guidance is actionable, psychologically insightful, and deeply personalized.

TODAY'S DATE: $today
CURRENT PLANETARY TRANSITS: Calculate today's major planetary positions and aspects based on the date.

USER'S NATAL CHART:
$natalJson

USER'S PSYCHOLOGICAL PROFILE (Master DNA):
$dnaContext

---

TASK: Generate premium daily astrological guidance by analyzing how today's transits interact with the user's natal chart, filtered through their psychological profile.

ANALYSIS FRAMEWORK:
1. Identify which natal houses are activated by today's transits.
2. Cross-reference activated themes with user's DNA (fears, goals, traumas, strengths).
3. Provide specific, actionable guidance for each relevant life area.

TONE: Sophisticated yet accessible. No generic fortune-telling. Every insight must feel personally crafted. Write all guidance text in TURKISH language.

OUTPUT FORMAT (JSON only, no markdown):
{
  "date": "$today",
  "overall_energy": 78,
  "cosmic_weather": "Bugün Merkür natal Venüs'ünle kavuşum yaparak 7. evini aktive ediyor. Satürn'ün 4. evindeki transiti duygusal temellerini yeniden yapılandırmaya devam ediyor.",
  "focus_houses": [7, 4, 10],
  "house_guidance": {
    "1": {
      "house_name": "Benlik & Kimlik",
      "theme_icon": "🪞",
      "activation_level": "low",
      "short_advice": "Kişisel enerjin için sakin bir gün. Kimlik sektörüne büyük kozmik baskı yok.",
      "detailed_action": null
    },
    "2": {
      "house_name": "Kaynaklar & Değerler",
      "theme_icon": "💎",
      "activation_level": "medium",
      "short_advice": "Jüpiter'in açısı beklenmedik kaynak fırsatları sunuyor.",
      "detailed_action": "Ertelediğin bir finansal kararı gözden geçir. Değer bazlı seçimler için sezgilerine her zamankinden daha fazla güvenebilirsin."
    },
    "3": {
      "house_name": "İletişim & Zihin",
      "theme_icon": "🗣️",
      "activation_level": "low",
      "short_advice": "Net düşünce var ama acil kozmik mesaj yok.",
      "detailed_action": null
    },
    "4": {
      "house_name": "Yuva & Kökler",
      "theme_icon": "🏠",
      "activation_level": "high",
      "short_advice": "Satürn duygusal güvenlik kalıpların üzerinde derin çalışmaya devam ediyor.",
      "detailed_action": "Bugün yuva istikrarı hissini pekiştiren küçük bir eylem için ideal. Kişisel alanını düzenlemek bile sayılır."
    },
    "5": {
      "house_name": "Yaratıcılık & Neşe",
      "theme_icon": "🎨",
      "activation_level": "medium",
      "short_advice": "Yaratıcı dürtüler akıyor. Akşamdan önce harekete geç.",
      "detailed_action": "Bugün herhangi bir yaratıcı çıkışa 20 dakika ayır—kozmik pencere akşam 18:00'de kapanıyor."
    },
    "6": {
      "house_name": "Sağlık & Rutinler",
      "theme_icon": "⚕️",
      "activation_level": "low",
      "short_advice": "Mevcut rutinleri koru. Kesinti beklenmiyor.",
      "detailed_action": null
    },
    "7": {
      "house_name": "İlişkiler & Ortaklık",
      "theme_icon": "💞",
      "activation_level": "high",
      "short_advice": "Merkür-Venüs kavuşumu ortaklık sektöründe: önemli konuşmalar mümkün.",
      "detailed_action": "Yakın biriyle söylenmemiş bir şey varsa, bugünün enerjisi nazik doğruluğu destekliyor. Otantik iletişim için bu farkındalığı kullan."
    },
    "8": {
      "house_name": "Dönüşüm & Paylaşım",
      "theme_icon": "🔮",
      "activation_level": "low",
      "short_advice": "Derin psikolojik sular bugün sakin.",
      "detailed_action": null
    },
    "9": {
      "house_name": "Keşif & Bilgelik",
      "theme_icon": "🌍",
      "activation_level": "medium",
      "short_advice": "Öğrenme ve geniş perspektifler destekleniyor.",
      "detailed_action": "Dünya görüşünü genişleten bir şey oku veya izle. Vizyonunla bağlantılı içerikler bul."
    },
    "10": {
      "house_name": "Kariyer & İtibar",
      "theme_icon": "🏆",
      "activation_level": "high",
      "short_advice": "Güneş transiti profesyonel görünürlüğü öne çıkarıyor.",
      "detailed_action": "Profesyonel alanında görünür bir adım at. Bir meslektaşına düşünceli bir mesaj bile yeterli."
    },
    "11": {
      "house_name": "Topluluk & Gelecek",
      "theme_icon": "🌐",
      "activation_level": "low",
      "short_advice": "Sosyal sektör sessiz. Başka yerlere odaklan.",
      "detailed_action": null
    },
    "12": {
      "house_name": "Bilinçaltı & Ruhsallık",
      "theme_icon": "🌙",
      "activation_level": "medium",
      "short_advice": "Rüyalar canlı olabilir. Sembollere dikkat et.",
      "detailed_action": "Bu gece yatağının yanında rüya notu tut. Bilinçaltın önemli temalar işliyor."
    }
  },
  "power_hour": "14:00 - 16:00",
  "daily_motto": "Bağlantıdaki özgünlük, aradığın güvenliği yaratır.",
  "cosmic_warning": "11:00-13:00 arasında Ay Neptün'e kare yaptığında büyük finansal taahhütlerden kaçın.",
  "lucky_element": { "color": "Koyu Mavi", "number": 7, "direction": "Batı" }
}

CRITICAL RULES:
1. Replace all placeholder examples with actual analysis based on the user's natal chart and DNA.
2. "detailed_action" should be null for houses with "low" activation.
3. Every "high" activation house MUST have a specific, actionable detailed_action in Turkish.
4. Reference user's DNA elements (fears, goals, traumas, profession) naturally where relevant.
5. The guidance must feel like it was written by a personal astrologer who knows this specific person.
6. ALL text content must be in TURKISH language.
7. Return ONLY valid JSON, no markdown code blocks or explanations.
''';
  }
}
