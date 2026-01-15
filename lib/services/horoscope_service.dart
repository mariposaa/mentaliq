import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'user_dna_service.dart';
import '../models/horoscope_model.dart';

class HoroscopeService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static final _model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: _apiKey,
  );

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static String? lastError; // For UI debugging

  static Future<HoroscopeData?> getHoroscope({
    required String birthDate,
    required String birthTime,
    required String birthLocation,
    bool isWeekly = false,
  }) async {
    lastError = null;
    debugPrint('HoroscopeService: getHoroscope called for $birthDate, $birthTime, $birthLocation (Weekly: $isWeekly)');
    final now = DateTime.now();
    final dateKey = isWeekly 
        ? 'week_${now.year}_${_getWeekNumber(now)}'
        : DateFormat('yyyy-MM-dd').format(now);
    final period = isWeekly ? 'weekly' : 'daily';
    
    // We cache by a hash of birth info to serve specific users correctly
    final userHash = '${birthDate}_${birthTime}_${birthLocation}'.hashCode.toString();
    debugPrint('HoroscopeService: userHash: $userHash, dateKey: $dateKey');

    // 1. Check Firestore Cache
    try {
      final cacheDoc = await _firestore
          .collection('horoscope_reports')
          .doc(userHash)
          .collection(period)
          .doc(dateKey)
          .get();
          
      if (cacheDoc.exists) {
        debugPrint('HoroscopeService: Cache found for $dateKey');
        return HoroscopeData.fromJson(cacheDoc.data()!);
      }
    } catch (e) {
      debugPrint('HoroscopeService: Cache check error: $e');
    }

    debugPrint('HoroscopeService: Generating new horoscope via Gemini...');
    // 2. Generate with Gemini
    return await _generatePersonalizedHoroscope(
      birthDate: birthDate,
      birthTime: birthTime,
      birthLocation: birthLocation,
      isWeekly: isWeekly,
      dateKey: dateKey,
      userHash: userHash,
    );
  }

  static int _getWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final firstMonday = startOfYear.weekday <= 1 
        ? startOfYear.add(Duration(days: (1 - startOfYear.weekday)))
        : startOfYear.add(Duration(days: (8 - startOfYear.weekday)));
    if (date.isBefore(firstMonday)) return 0;
    return (date.difference(firstMonday).inDays / 7).floor() + 1;
  }

  static Future<HoroscopeData?> _generatePersonalizedHoroscope({
    required String birthDate,
    required String birthTime,
    required String birthLocation,
    required bool isWeekly,
    required String dateKey,
    required String userHash,
  }) async {
    try {
      final periodText = isWeekly ? 'Haftalık' : 'Günlük';
      
      final dnaContext = await UserDNAService.getDNAForAI();
      
      final prompt = """
Sen usta bir Siber-Mistik Astroloğusun. Kullanıcının Master DNA'sını ve doğum bilgilerini kullanarak ona en derinden dokunacak $periodText yorumlarını hazırlaman gerekiyor.

[KODLANMIŞ MASTER DNA]:
$dnaContext

Yorum tarzın: Zarif, etkileyici, modern ve psikolojik derinliği olan bir dil olmalı. 
ÖNEMLİ: Kullanıcının Master DNA'sındaki korkuları, travmaları veya hedefleriyle gökyüzü hareketleri arasında bağlantı kur (Örn: "Haritandaki Satürn döngüsü, DNA'ndaki 'yalnızlık' korkunu aslında bir güce dönüştürmen için seni sınıyor").

Lütfen aşağıdaki JSON formatında yanıt dön:
{
  "sun_sign": "Güneş Burcu",
  "rising_sign": "Yükselen Burcu",
  "sun_interpretation": "Güneş burcu ve DNA etkileşimi için $periodText derin yorum (3-4 cümle)",
  "rising_interpretation": "Yükselen burcu ve DNA etkileşimi için $periodText derin yorum (3-4 cümle)",
  "date": "$dateKey",
  "period": "${isWeekly ? 'weekly' : 'daily'}"
}
""";


      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text != null) {
        debugPrint('HoroscopeService: Gemini response received');
        
        // Robust JSON extraction
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
          debugPrint('HoroscopeService: Could not find JSON block in response');
          return null;
        }

        final Map<String, dynamic> data = jsonDecode(jsonStr);
        final horoscope = HoroscopeData.fromJson(data);

        // Save to Cache
        try {
          await _firestore
              .collection('horoscope_reports')
              .doc(userHash)
              .collection(isWeekly ? 'weekly' : 'daily')
              .doc(dateKey)
              .set(horoscope.toJson());
          debugPrint('HoroscopeService: Saved to cache');
        } catch (e) {
          debugPrint('HoroscopeService: Cache save error: $e');
        }

        return horoscope;
      } else {
        lastError = 'Gemini yanıtı boş.';
        debugPrint('HoroscopeService: Gemini response was empty');
      }
    } catch (e) {
      lastError = 'Hata: $e';
      debugPrint('Horoscope generation error: $e');
    }
    return null;
  }
}
