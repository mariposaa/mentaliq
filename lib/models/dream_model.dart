class DreamData {
  final String dreamTitle;
  final String transcription;
  final String modernAnalysis;
  final String classicTabir;
  final int moodScore;
  final String moodEmoji;
  final String imagePrompt;

  DreamData({
    required this.dreamTitle,
    required this.transcription,
    required this.modernAnalysis,
    required this.classicTabir,
    required this.moodScore,
    required this.moodEmoji,
    required this.imagePrompt,
  });

  factory DreamData.fromJson(Map<String, dynamic> json) {
    return DreamData(
      dreamTitle: json['dream_title'] ?? "İsimsiz Rüya",
      transcription: json['transcription'] ?? "",
      modernAnalysis: json['modern_analysis'] ?? "",
      classicTabir: json['classic_tabir'] ?? "",
      moodScore: json['mood_score'] ?? 50,
      moodEmoji: json['mood_emoji'] ?? "✨",
      imagePrompt: json['image_prompt'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dream_title': dreamTitle,
      'transcription': transcription,
      'modern_analysis': modernAnalysis,
      'classic_tabir': classicTabir,
      'mood_score': moodScore,
      'mood_emoji': moodEmoji,
      'image_prompt': imagePrompt,
    };
  }
}
