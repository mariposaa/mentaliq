import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Mood tracking service - stores daily moods for analysis
class MoodService {
  static FirebaseFirestore get _firestore => AuthService.firestore;

  /// Available moods with Turkish labels and descriptions
  static const List<Map<String, String>> availableMoods = [
    {'id': 'mutlu', 'emoji': '😊', 'label': 'Mutlu', 'color': '0xFF4CAF50'},
    {'id': 'huzurlu', 'emoji': '😌', 'label': 'Huzurlu', 'color': '0xFF81C784'},
    {'id': 'notr', 'emoji': '😐', 'label': 'Nötr', 'color': '0xFF9E9E9E'},
    {'id': 'yorgun', 'emoji': '😩', 'label': 'Yorgun', 'color': '0xFFFF9800'},
    {'id': 'uzgun', 'emoji': '😢', 'label': 'Üzgün', 'color': '0xFF2196F3'},
    {'id': 'gergin', 'emoji': '😤', 'label': 'Gergin', 'color': '0xFFF44336'},
    {'id': 'endiseli', 'emoji': '😰', 'label': 'Endişeli', 'color': '0xFF9C27B0'},
    {'id': 'kaygi', 'emoji': '😟', 'label': 'Kaygılı', 'color': '0xFFE91E63'},
  ];

  /// Save today's mood
  static Future<void> saveMood(String moodId) async {
    final uid = AuthService.userId;
    if (uid == null) return;

    try {
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      // Save to user document
      await _firestore.collection('users').doc(uid).set({
        'currentMood': moodId,
        'lastMoodAt': FieldValue.serverTimestamp(),
        'moodHistory': {
          dateKey: {
            'mood': moodId,
            'timestamp': FieldValue.serverTimestamp(),
          }
        }
      }, SetOptions(merge: true));

      debugPrint('Mood saved: $moodId');
    } catch (e) {
      debugPrint('Error saving mood: $e');
    }
  }

  /// Get current mood
  static Future<String?> getCurrentMood() async {
    final uid = AuthService.userId;
    if (uid == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['currentMood'] as String?;
    } catch (e) {
      debugPrint('Error getting mood: $e');
      return null;
    }
  }

  /// Get mood history for last N days
  static Future<Map<String, dynamic>> getMoodHistory({int days = 7}) async {
    final uid = AuthService.userId;
    if (uid == null) return {};

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final history = doc.data()?['moodHistory'] as Map<String, dynamic>?;
      return history ?? {};
    } catch (e) {
      debugPrint('Error getting mood history: $e');
      return {};
    }
  }

  /// Get mood info by ID
  static Map<String, String>? getMoodInfo(String moodId) {
    return availableMoods.firstWhere(
      (m) => m['id'] == moodId,
      orElse: () => {},
    );
  }

  /// Get mood summary for AI context
  static Future<String> getMoodForPrompt() async {
    final currentMood = await getCurrentMood();
    if (currentMood == null) return '';
    
    final moodInfo = getMoodInfo(currentMood);
    if (moodInfo == null || moodInfo.isEmpty) return '';
    
    return 'Kullanıcının şu anki ruh hali: ${moodInfo['label']}';
  }
}
