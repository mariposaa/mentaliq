import 'package:shared_preferences/shared_preferences.dart';

/// Answer modes for AI responses
enum AnswerMode {
  comfort,   // Beni Teselli Et - İyimser
  realistic, // Gerçekçi Ol - Realist
  harsh,     // Ağzının Payını Ver - Acımasız
}

/// Service for managing answer mode preference
class AnswerModeService {
  static const String _key = 'answer_mode';

  /// Get current saved answer mode
  static Future<AnswerMode> getSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_key);
    if (savedMode != null) {
      return AnswerMode.values.firstWhere(
        (m) => m.name == savedMode,
        orElse: () => AnswerMode.realistic, // Default: Gerçekçi Ol
      );
    }
    return AnswerMode.realistic; // Default: Gerçekçi Ol
  }

  /// Save answer mode
  static Future<void> saveMode(AnswerMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
