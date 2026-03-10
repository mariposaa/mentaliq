import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../config/app_locale.dart';
import 'auth_service.dart';
import 'user_dna_service.dart';
import '../models/dream_model.dart';

class DreamService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static final _model = GenerativeModel(
    model: 'gemini-2.5-flash', 
    apiKey: _apiKey,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
    ),
  );

  /// Analyze a dream from text (Speech-to-Text result)
  static Future<DreamData?> analyzeTextDream(String dreamText) async {
    try {
      final dnaContext = await UserDNAService.getDNAForAI();

      final promptText = """
${AppLocale.languageInstructionForAI}

GÖREV: Kullanıcının anlattığı rüyayı analiz et.
ROLÜN: Sen hem modern bir "Psikanalist" (Jung/Freud) hem de kadim tabir geleneğine vakıf bir "Rüya Alimi"sin.

BAĞLAM (Kullanıcı DNA):
$dnaContext

YAPMAN GEREKENLER:
1. Metni Analiz Et: Kullanıcının rüyasındaki sembolizmi ve altında yatan duyguyu anla.
2. Modern Yorum: Bilinçaltı, stres ve psikolojik semboller üzerinden yorumla.
3. Klasik Tabir: Geleneksel tabir usulüyle yorumla. Bu bölümde:
   - Hikmetli, ölçülü ve öğretici bir alim üslubu kullan.
   - Kesin hüküm verme; "işaret eder", "yorulur", "delalet eder" gibi ihtiyatlı dil kullan.
   - Önce rüyadaki ana sembolleri tek tek çıkar.
   - Sonra her sembolün muhtemel manasını açıkla.
   - En sonda sembolleri birleştirip bütüncül klasik tabiri ver.
   - Bu bölümde modern psikoloji terminolojisi kullanma.
4. Görselleştirme: Bu rüyayı temsil edecek sinematik bir resim için İngilizce prompt yaz.

RÜYA METNİ: 
"$dreamText"

ÇIKTI FORMATI (SADECE JSON):
{
  "dream_title": "Rüyaya gizemli ve kısa bir başlık ver",
  "transcription": "$dreamText",
  "modern_analysis": "Psikolojik açıdan bu rüya...",
  "classic_tabir": "Geleneksel tabirlere göre bu rüya...",
  "mood_score": 75,
  "mood_emoji": "😰",
  "image_prompt": "Cinematic digital art of..."
}
""";

      final content = [Content.text(promptText)];
      final response = await _model.generateContent(content);
      
      if (response.text != null) {
        String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> data = jsonDecode(cleanJson);
        return DreamData.fromJson(data);
      }
    } catch (e) {
      debugPrint('Text Dream Analysis Error: $e');
    }
    return null;
  }

  static Future<DreamData?> analyzeAudioDream(String audioPath) async {
    try {
      // 1. Ses dosyasını byte olarak oku
      final file = File(audioPath);
      final audioBytes = await file.readAsBytes();

      // 2. Promptu Hazırla
      final promptText = """
${AppLocale.languageInstructionForAI}

GÖREV: Ekli ses dosyasını dinle. Kullanıcı bir rüyasını anlatıyor.
ROLÜN: Sen hem modern bir "Psikanalist" (Jung/Freud) hem de kadim tabir geleneğine vakıf bir "Rüya Alimi"sin.

YAPMAN GEREKENLER:
1. Sesi Analiz Et: Kullanıcının anlattığı rüyayı ve ses tonundaki duyguyu (korku, heyecan, huzur) anla.
2. Modern Yorum: Bilinçaltı, stres ve psikolojik semboller üzerinden yorumla.
3. Klasik Tabir: Geleneksel tabir usulüyle yorumla. Bu bölümde:
   - Hikmetli, ölçülü ve öğretici bir alim üslubu kullan.
   - Kesin hüküm verme; "işaret eder", "yorulur", "delalet eder" gibi ihtiyatlı dil kullan.
   - Önce rüyadaki ana sembolleri tek tek çıkar.
   - Sonra her sembolün muhtemel manasını açıkla.
   - En sonda sembolleri birleştirip bütüncül klasik tabiri ver.
   - Bu bölümde modern psikoloji terminolojisi kullanma.
4. Görselleştirme: Bu rüyayı temsil edecek sinematik bir resim için İngilizce prompt yaz.

ÇIKTI FORMATI (SADECE JSON):
{
  "dream_title": "Rüyaya gizemli ve kısa bir başlık ver",
  "transcription": "Kullanıcının anlattığı rüyanın yazıya dökülmüş özeti",
  "modern_analysis": "Psikolojik açıdan bu rüya...",
  "classic_tabir": "Geleneksel tabirlere göre bu rüya...",
  "mood_score": 75,
  "mood_emoji": "😰",
  "image_prompt": "Cinematic digital art of..."
}
""";

      // 3. Sesi ve Promptu Paketle
      final content = [
        Content.multi([
          TextPart(promptText),
          DataPart('audio/mp4', audioBytes), // .m4a/.mp3 formatları için 'audio/mp4' genelde yeterlidir
        ])
      ];

      // 4. Gönder ve Cevabı Al
      final response = await _model.generateContent(content);
      
      if (response.text != null) {
        // 5. JSON Temizliği ve Parse Etme
        String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> data = jsonDecode(cleanJson);
        return DreamData.fromJson(data);
      }
    } catch (e) {
      debugPrint('Multimodal Dream Error: $e');
    }
    return null;
  }

  static Future<void> saveDreamResult(DreamData data) async {
    final userId = AuthService.userId;
    if (userId == null) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    await FirebaseFirestore.instance
        .collection('dream_results')
        .doc(userId)
        .collection('history')
        .doc(timestamp)
        .set({
          ...data.toJson(),
          'created_at': FieldValue.serverTimestamp(),
          'date': dateKey,
        });
  }

  static Future<DreamData?> getLatestDream() async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('dream_results')
        .doc(userId)
        .collection('history')
        .orderBy('created_at', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return DreamData.fromJson(snapshot.docs.first.data());
    }
    return null;
  }
}
