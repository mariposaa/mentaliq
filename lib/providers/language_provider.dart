import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_dna_service.dart';
import '../models/user_dna_model.dart';
import '../l10n/app_translations.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _prefKey = 'app_language';
  static const String defaultLanguage = 'en';
  static const List<String> supportedLanguages = ['en', 'tr', 'de', 'es', 'ar'];

  String _languageCode = defaultLanguage;

  String get languageCode => _languageCode;
  Locale get locale => Locale(_languageCode);

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('tr'),
    Locale('de'),
    Locale('es'),
    Locale('ar'),
  ];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'tr': 'Türkçe',
    'de': 'Deutsch',
    'es': 'Español',
    'ar': 'العربية',
  };

  static const Map<String, String> languageFlags = {
    'en': '🇬🇧',
    'tr': '🇹🇷',
    'de': '🇩🇪',
    'es': '🇪🇸',
    'ar': '🇸🇦',
  };

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);

    if (saved != null && supportedLanguages.contains(saved)) {
      _languageCode = saved;
    } else {
      final dna = UserDNAService.currentDNA;
      if (dna?.language != null &&
          dna!.language!.isNotEmpty &&
          supportedLanguages.contains(dna.language)) {
        _languageCode = dna.language!;
      } else {
        _languageCode = defaultLanguage;
      }
    }

    AppTranslations.setLanguage(_languageCode);
    notifyListeners();
  }

  Future<void> changeLanguage(String code) async {
    if (!supportedLanguages.contains(code) || code == _languageCode) return;

    _languageCode = code;
    AppTranslations.setLanguage(code);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);

    try {
      await UserDNAService.updateDNA(UserDNAModel(language: code));
    } catch (_) {}

    notifyListeners();
  }

  String tr(String key) => AppTranslations.get(key);

  /// AI yanıtları için dil talimatı
  String get languageInstructionForAI {
    const names = {
      'en': 'English',
      'tr': 'Turkish',
      'de': 'German',
      'es': 'Spanish',
      'ar': 'Arabic',
    };
    final name = names[_languageCode] ?? 'English';
    return 'CRITICAL - LANGUAGE: You must respond ONLY in $name. '
        'All your answers, text, and JSON values must be in this language.';
  }
}
