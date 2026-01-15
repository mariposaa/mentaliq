// lib/models/relationship_analysis_model.dart
// İlişki Analizi Model - THE AUDITOR JSON çıktısını parse eder

class RelationshipAnalysisModel {
  final String id;
  final DateTime date;
  final int score;
  final String title;
  final String analysis;
  final String personalityClash;
  final List<AnalysisRecommendation> recommendations;

  RelationshipAnalysisModel({
    required this.id,
    required this.date,
    required this.score,
    required this.title,
    required this.analysis,
    required this.personalityClash,
    required this.recommendations,
  });

  /// JSON'dan parse et (Gemini API çıktısı)
  factory RelationshipAnalysisModel.fromGeminiJson(Map<String, dynamic> json, String id) {
    final recommendations = (json['recommendations'] as List<dynamic>? ?? [])
        .map((r) => AnalysisRecommendation.fromJson(r as Map<String, dynamic>))
        .toList();

    return RelationshipAnalysisModel(
      id: id,
      date: DateTime.now(),
      score: json['score'] as int? ?? 0,
      title: json['title'] as String? ?? 'Analiz Tamamlandı',
      analysis: json['analysis'] as String? ?? '',
      personalityClash: json['personality_clash'] as String? ?? '',
      recommendations: recommendations,
    );
  }

  /// Firebase'den parse et
  factory RelationshipAnalysisModel.fromFirestore(Map<String, dynamic> json, String id) {
    final recommendations = (json['recommendations'] as List<dynamic>? ?? [])
        .map((r) => AnalysisRecommendation.fromJson(r as Map<String, dynamic>))
        .toList();

    return RelationshipAnalysisModel(
      id: id,
      date: DateTime.parse(json['date'] as String),
      score: json['score'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      analysis: json['analysis'] as String? ?? '',
      personalityClash: json['personality_clash'] as String? ?? '',
      recommendations: recommendations,
    );
  }

  /// Firebase'e kaydet
  Map<String, dynamic> toFirestore() {
    return {
      'date': date.toIso8601String(),
      'score': score,
      'title': title,
      'analysis': analysis,
      'personality_clash': personalityClash,
      'recommendations': recommendations.map((r) => r.toJson()).toList(),
    };
  }

  /// Puan rengini al
  String get scoreEmoji {
    if (score >= 80) return '💚';
    if (score >= 60) return '💛';
    if (score >= 40) return '🧡';
    return '❤️‍🩹';
  }

  /// Tarih formatı
  String get formattedDate {
    return '${date.day}.${date.month}.${date.year}';
  }
}

/// Tavsiye modeli
class AnalysisRecommendation {
  final String type; // 'communication', 'action', 'mindset'
  final String text;
  final bool isHardPill;

  AnalysisRecommendation({
    required this.type,
    required this.text,
    required this.isHardPill,
  });

  factory AnalysisRecommendation.fromJson(Map<String, dynamic> json) {
    return AnalysisRecommendation(
      type: json['type'] as String? ?? 'action',
      text: json['text'] as String? ?? '',
      isHardPill: json['is_hard_pill'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'text': text,
      'is_hard_pill': isHardPill,
    };
  }

  /// Tip ikonu
  String get typeIcon {
    switch (type) {
      case 'communication':
        return '💬';
      case 'action':
        return '⚡';
      case 'mindset':
        return '🧠';
      default:
        return '💡';
    }
  }

  /// Tip adı
  String get typeName {
    switch (type) {
      case 'communication':
        return 'İletişim';
      case 'action':
        return 'Aksiyon';
      case 'mindset':
        return 'Zihniyet';
      default:
        return 'Tavsiye';
    }
  }
}
