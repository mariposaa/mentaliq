import 'package:flutter/material.dart';
import 'locale_utils.dart';
import '../services/user_dna_service.dart';

/// Uygulama dili: UserDNA'da kayıtlı veya cihaz dili (tr, en, de, es, ar).
abstract class AppLocale {
  static const String defaultLanguage = LocaleUtils.defaultLanguage;
  static const List<String> supportedLanguages = LocaleUtils.supportedLanguages;

  static const List<Locale> supportedLocales = [
    Locale('tr'),
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('ar'),
  ];

  /// Şu anki dil kodu (UserDNA öncelikli, yoksa cihaz, yoksa tr).
  static String get currentLanguageCode {
    final dna = UserDNAService.currentDNA;
    if (dna?.language != null && dna!.language!.isNotEmpty && supportedLanguages.contains(dna.language)) {
      return dna.language!;
    }
    return LocaleUtils.detectFromDevice();
  }

  static Locale get locale => Locale(currentLanguageCode);

  /// AI (Gemini) promptlarına eklenecek dil kuralı; yanıtlar kullanıcı dilinde olsun.
  static String get languageInstructionForAI {
    const names = {
      'tr': 'Turkish',
      'en': 'English',
      'de': 'German',
      'es': 'Spanish',
      'ar': 'Arabic',
    };
    final name = names[currentLanguageCode] ?? 'Turkish';
    return 'CRITICAL - LANGUAGE: You must respond ONLY in $name. All your answers, text, and JSON values must be in this language.';
  }
}
