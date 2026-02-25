import 'package:cloud_firestore/cloud_firestore.dart';

/// postType: confession | photo_story | idea_question | daily_answer
class ForumPost {
  final String id;
  final String postType;
  final String language;
  final String? authorId;
  final String? authorName;
  final bool isAnonymous;
  final String text;
  final String? imageUrl;
  final String? dailyQuestionId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool deleted;
  /// Çeviri cache'i: {'en': 'translated text', 'de': '...'}
  final Map<String, String> translations;
  /// Destek sayısı
  final int supportCount;
  /// Destek veren kullanıcı ID'leri
  final List<String> supportedBy;
  /// Yorum sayısı (denormalized, performans için)
  final int commentCount;

  ForumPost({
    required this.id,
    required this.postType,
    required this.language,
    this.authorId,
    this.authorName,
    this.isAnonymous = false,
    required this.text,
    this.imageUrl,
    this.dailyQuestionId,
    required this.createdAt,
    this.updatedAt,
    this.deleted = false,
    this.translations = const {},
    this.supportCount = 0,
    this.supportedBy = const [],
    this.commentCount = 0,
  });

  factory ForumPost.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawTrans = d['translations'];
    final translations = <String, String>{};
    if (rawTrans is Map) {
      rawTrans.forEach((k, v) {
        if (k is String && v is String) translations[k] = v;
      });
    }
    return ForumPost(
      id: doc.id,
      postType: d['postType'] as String? ?? 'confession',
      language: d['language'] as String? ?? 'tr',
      authorId: d['authorId'] as String?,
      authorName: d['authorName'] as String?,
      isAnonymous: d['isAnonymous'] as bool? ?? false,
      text: d['text'] as String? ?? '',
      imageUrl: d['imageUrl'] as String?,
      dailyQuestionId: d['dailyQuestionId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      deleted: d['deleted'] as bool? ?? false,
      translations: translations,
      supportCount: d['supportCount'] as int? ?? 0,
      supportedBy: (d['supportedBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      commentCount: d['commentCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postType': postType,
      'language': language,
      'authorId': authorId,
      'authorName': authorName,
      'isAnonymous': isAnonymous,
      'text': text,
      'imageUrl': imageUrl,
      'dailyQuestionId': dailyQuestionId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'deleted': deleted,
      'translations': translations,
      'supportCount': supportCount,
      'supportedBy': supportedBy,
      'commentCount': commentCount,
    };
  }

  /// Kullanıcı bu gönderiyi destekliyor mu?
  bool isSupportedBy(String? userId) {
    if (userId == null) return false;
    return supportedBy.contains(userId);
  }

  /// Kullanıcının diline göre metni döndürür: cache varsa cache, yoksa orijinal
  String getTextForLanguage(String targetLang) {
    if (language == targetLang) return text;
    return translations[targetLang] ?? text;
  }

  /// Çeviri var mı kontrol et
  bool hasTranslation(String targetLang) {
    return language == targetLang || translations.containsKey(targetLang);
  }

  String get displayAuthorName => isAnonymous ? 'Anonim' : (authorName ?? 'Anonim');
}
