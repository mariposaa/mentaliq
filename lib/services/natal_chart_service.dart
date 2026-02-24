// lib/services/natal_chart_service.dart
// Natal chart hesaplama servisi - tek seferlik, ücretsiz

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/natal_chart_model.dart';
import 'auth_service.dart';

class NatalChartService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static final _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: _apiKey,
  );
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static String? lastError;

  /// Calculate natal chart from birth data (one-time, free)
  static Future<NatalChartModel?> calculateNatalChart({
    required String birthDate,
    required String birthTime,
    required String birthLocation,
  }) async {
    lastError = null;
    debugPrint('NatalChartService: Calculating natal chart for $birthDate, $birthTime, $birthLocation');

    try {
      final prompt = _buildNatalChartPrompt(
        birthDate: birthDate,
        birthTime: birthTime,
        birthLocation: birthLocation,
      );

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        lastError = 'Gemini yanıtı boş.';
        debugPrint('NatalChartService: Empty response from Gemini');
        return null;
      }

      // Extract JSON from response
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
        debugPrint('NatalChartService: Could not find JSON block');
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(jsonStr);
      data['calculated_at'] = DateTime.now().toIso8601String();
      
      final natalChart = NatalChartModel.fromJson(data);
      debugPrint('NatalChartService: Natal chart calculated successfully');
      
      return natalChart;
    } catch (e) {
      lastError = 'Hesaplama hatası: $e';
      debugPrint('NatalChartService: Error calculating natal chart: $e');
      return null;
    }
  }

  /// Save natal chart to user's DNA in Firestore
  static Future<bool> saveNatalChart(NatalChartModel chart) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        lastError = 'Kullanıcı oturumu bulunamadı.';
        return false;
      }

      await _firestore
          .collection('user_dna')
          .doc(userId)
          .set({
            'natal_chart': chart.toJson(),
            'natal_chart_updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      debugPrint('NatalChartService: Natal chart saved to Firestore');
      return true;
    } catch (e) {
      lastError = 'Kaydetme hatası: $e';
      debugPrint('NatalChartService: Error saving natal chart: $e');
      return false;
    }
  }

  /// Get saved natal chart from Firestore
  static Future<NatalChartModel?> getSavedNatalChart() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return null;

      final doc = await _firestore
          .collection('user_dna')
          .doc(userId)
          .get();

      if (doc.exists && doc.data()?['natal_chart'] != null) {
        return NatalChartModel.fromJson(doc.data()!['natal_chart']);
      }
      return null;
    } catch (e) {
      debugPrint('NatalChartService: Error loading natal chart: $e');
      return null;
    }
  }

  /// Check if user has a valid natal chart
  static Future<bool> hasValidNatalChart() async {
    final chart = await getSavedNatalChart();
    return chart != null && chart.isValid;
  }

  /// Build the premium natal chart calculation prompt
  static String _buildNatalChartPrompt({
    required String birthDate,
    required String birthTime,
    required String birthLocation,
  }) {
    return '''
You are a professional astrologer AI with deep knowledge of Western tropical astrology.

TASK: Calculate the complete natal chart for the following birth data.

BIRTH DATA:
- Date: $birthDate (format: DD.MM.YYYY)
- Time: $birthTime (format: HH:mm, 24-hour)
- Location: $birthLocation (city name)

INSTRUCTIONS:
1. Calculate the exact positions using tropical zodiac and Placidus house system.
2. Determine Rising Sign (Ascendant) based on birth time and location.
3. Calculate all 12 house cusps.
4. Determine planetary positions (sign and house placement).

IMPORTANT:
- For the Rising calculation, consider the approximate latitude/longitude of $birthLocation.
- Use standard astrological algorithms.
- All sign names must be in English (Aries, Taurus, Gemini, Cancer, Leo, Virgo, Libra, Scorpio, Sagittarius, Capricorn, Aquarius, Pisces).
- Return ONLY valid JSON, no explanations or markdown.

OUTPUT FORMAT (JSON only):
{
  "sun_sign": "Leo",
  "moon_sign": "Pisces",
  "rising_sign": "Scorpio",
  "houses": {
    "1": { "sign": "Scorpio", "degree": 15 },
    "2": { "sign": "Sagittarius", "degree": 12 },
    "3": { "sign": "Capricorn", "degree": 8 },
    "4": { "sign": "Aquarius", "degree": 5 },
    "5": { "sign": "Pisces", "degree": 3 },
    "6": { "sign": "Aries", "degree": 2 },
    "7": { "sign": "Taurus", "degree": 15 },
    "8": { "sign": "Gemini", "degree": 12 },
    "9": { "sign": "Cancer", "degree": 8 },
    "10": { "sign": "Leo", "degree": 5 },
    "11": { "sign": "Virgo", "degree": 3 },
    "12": { "sign": "Libra", "degree": 2 }
  },
  "planets": {
    "sun": { "sign": "Leo", "house": 10, "degree": 22 },
    "moon": { "sign": "Pisces", "house": 5, "degree": 14 },
    "mercury": { "sign": "Virgo", "house": 11, "degree": 5 },
    "venus": { "sign": "Cancer", "house": 9, "degree": 18 },
    "mars": { "sign": "Aries", "house": 6, "degree": 9 },
    "jupiter": { "sign": "Sagittarius", "house": 2, "degree": 25 },
    "saturn": { "sign": "Capricorn", "house": 3, "degree": 12 },
    "uranus": { "sign": "Taurus", "house": 7, "degree": 8 },
    "neptune": { "sign": "Pisces", "house": 5, "degree": 20 },
    "pluto": { "sign": "Capricorn", "house": 3, "degree": 24 }
  }
}
''';
  }
}
