import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_service.dart';

/// Manages daily inspirational message from Gemini
class DailyInsightService extends ChangeNotifier {
  static const String _cacheKey = 'daily_insight';
  static const String _cacheDateKey = 'daily_insight_date';
  
  String _insight = '';
  String _emoji = '🌿';
  bool _isLoading = false;
  
  String get insight => _insight;
  String get emoji => _emoji;
  bool get isLoading => _isLoading;
  bool get hasInsight => _insight.isNotEmpty;

  /// Load or fetch daily insight
  Future<void> loadDailyInsight() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(_cacheDateKey);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      // Check if we have a cached insight from today
      if (cachedDate == today) {
        final cachedInsight = prefs.getString(_cacheKey);
        if (cachedInsight != null && cachedInsight.isNotEmpty) {
          _parseInsight(cachedInsight);
          _isLoading = false;
          notifyListeners();
          debugPrint('Using cached daily insight');
          return;
        }
      }
      
      // Fetch new insight from Gemini
      if (GeminiService.isInitialized) {
        final response = await GeminiService.generateResponse(
          _getDailyPrompt(),
          'genel',
        );
        
        await prefs.setString(_cacheKey, response);
        await prefs.setString(_cacheDateKey, today);
        
        _parseInsight(response);
        debugPrint('Fetched new daily insight');
      } else {
        _setFallbackInsight();
      }
    } catch (e) {
      debugPrint('Error loading daily insight: $e');
      _setFallbackInsight();
    }
    
    _isLoading = false;
    notifyListeners();
  }

  /// Generate prompt for daily insight
  String _getDailyPrompt() {
    final weekday = DateTime.now().weekday;
    final dayName = _getTurkishDayName(weekday);
    
    return '''
Bugün $dayName. Kullanıcıya güne başlarken ilham verecek kısa bir mesaj yaz.

Kurallar:
- Maksimum 2 cümle
- Sıcak ve samimi ol
- Motive edici ama klişe olma
- Başına uygun bir emoji koy (🌱, ✨, 🌿, 💫, 🌸, 🦋 gibi)

Format: [emoji] [mesaj]

Örnek: 🌱 Her gün yeni bir sayfa. Bugün kendine nazik olmayı seç.
''';
  }

  String _getTurkishDayName(int weekday) {
    const days = {
      1: 'Pazartesi',
      2: 'Salı',
      3: 'Çarşamba',
      4: 'Perşembe',
      5: 'Cuma',
      6: 'Cumartesi',
      7: 'Pazar',
    };
    return days[weekday] ?? 'gün';
  }

  /// Parse insight and emoji from response
  void _parseInsight(String response) {
    final trimmed = response.trim();
    
    if (trimmed.isEmpty) {
      _setFallbackInsight();
      return;
    }
    
    // Try to extract emoji from the beginning (emojis are typically 1-2 code units or use surrogate pairs)
    // Check for common emoji patterns at the start
    final emojiPattern = RegExp(r'^[\p{Emoji}]', unicode: true);
    final match = emojiPattern.firstMatch(trimmed);
    
    if (match != null) {
      _emoji = match.group(0) ?? '🌿';
      _insight = trimmed.substring(match.end).trim();
    } else {
      _emoji = '🌿';
      _insight = trimmed;
    }
  }

  void _setFallbackInsight() {
    _emoji = '🌿';
    _insight = 'Her gün yeni bir başlangıç. Bugün kendine iyi davran.';
  }

  /// Force refresh insight (ignore cache)
  Future<void> refreshInsight() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheDateKey);
    await loadDailyInsight();
  }
}
