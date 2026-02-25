// Cihaz dilini desteklenen dil koduna çevirir (UserDNAService'tan bağımsız, döngü yok)
import 'dart:ui' as ui;

abstract class LocaleUtils {
  static const String defaultLanguage = 'tr';
  static const List<String> supportedLanguages = ['tr', 'en', 'de', 'es', 'ar'];

  /// Telefon dilinden desteklenen kodu döndürür. Eşleşmezse default (tr).
  static String detectFromDevice() {
    final locale = ui.PlatformDispatcher.instance.locale;
    final code = locale.languageCode.toLowerCase();
    if (supportedLanguages.contains(code)) return code;
    // Kısmi eşleşmeler (örn. en_US -> en)
    if (code.startsWith('en')) return 'en';
    if (code.startsWith('de')) return 'de';
    if (code.startsWith('es')) return 'es';
    if (code.startsWith('ar')) return 'ar';
    if (code.startsWith('tr')) return 'tr';
    return defaultLanguage;
  }
}
