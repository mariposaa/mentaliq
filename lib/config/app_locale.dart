import 'package:flutter/material.dart';
import '../l10n/app_translations.dart';
import '../providers/language_provider.dart';

/// Backward-compatible locale helper.
/// New code should use LanguageProvider directly via Provider.
abstract class AppLocale {
  static const String defaultLanguage = LanguageProvider.defaultLanguage;
  static const List<String> supportedLanguages = LanguageProvider.supportedLanguages;

  static const List<Locale> supportedLocales = LanguageProvider.supportedLocales;

  static String get currentLanguageCode => AppTranslations.currentLanguage;

  static Locale get locale => Locale(currentLanguageCode);

  static String get languageInstructionForAI {
    const names = {
      'en': 'English',
      'tr': 'Turkish',
      'de': 'German',
      'es': 'Spanish',
      'ar': 'Arabic',
    };
    final name = names[currentLanguageCode] ?? 'English';
    return 'CRITICAL - LANGUAGE: You must respond ONLY in $name. '
        'All your answers, text, and JSON values must be in this language.';
  }
}
