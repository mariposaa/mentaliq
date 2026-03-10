import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../config/app_locale.dart';
import '../models/forum_post.dart';
import '../models/forum_comment.dart';
import '../models/forum_daily_question.dart';
import 'auth_service.dart';
import 'admin_role_service.dart';
import 'gemini_service.dart';

/// Kamp Ateşi forum: dil UserDNA'dan; post/comment CRUD; 18+ giriş; günün sorusu alanı.
class ForumService {
  static String get contentLanguage => AppLocale.currentLanguageCode;

  static String get contentLanguageName {
    const names = {
      'tr': 'Türkçe',
      'en': 'English',
      'de': 'Deutsch',
      'es': 'Español',
      'ar': 'العربية'
    };
    return names[contentLanguage] ?? 'Türkçe';
  }

  static Future<List<dynamic>> getCategories() async => [];

  // ─── 18+ giriş (1 defalık) ───
  static Future<bool> isCampfireAgeConfirmed() async {
    final p = await AuthService.getProfile();
    return p?['campfireAgeConfirmed'] == true;
  }

  static Future<void> setCampfireAgeConfirmed() async {
    await AuthService.updateProfile({'campfireAgeConfirmed': true});
  }

  // ─── Gönderi listesi (akış) ───
  /// Tüm dillerdeki paylaşımları çeker (dil filtresi yok).
  static Stream<List<ForumPost>> watchFeedPosts() {
    return AuthService.firestore
        .collection('forum_posts')
        .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ForumPost.fromFirestore(d))
            .where((p) => p.dailyQuestionId == null)
            .toList());
  }

  static Future<ForumPost?> getPost(String postId) async {
    final doc =
        await AuthService.firestore.collection('forum_posts').doc(postId).get();
    if (!doc.exists) return null;
    return ForumPost.fromFirestore(doc);
  }

  static Future<String> createPost({
    required String postType,
    required String text,
    bool isAnonymous = false,
    Uint8List? imageBytes,
    String? dailyQuestionId,
  }) async {
    final uid = AuthService.userId!;
    final name = (await AuthService.getProfile())?['name'] as String?;
    String? imageUrl;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      imageUrl = await _uploadPostImageBytes(uid, imageBytes);
    }
    final ref = await AuthService.firestore.collection('forum_posts').add({
      'postType': postType,
      'language': contentLanguage,
      'authorId': uid,
      'authorName': isAnonymous ? null : name,
      'isAnonymous': isAnonymous,
      'text': text,
      'imageUrl': imageUrl,
      'dailyQuestionId': dailyQuestionId,
      'createdAt': FieldValue.serverTimestamp(),
      'deleted': false,
    });
    return ref.id;
  }

  static Future<void> updatePost(String postId,
      {String? text, String? imageUrl}) async {
    final uid = AuthService.userId!;
    final ref = AuthService.firestore.collection('forum_posts').doc(postId);
    final doc = await ref.get();
    if (!doc.exists || (doc.data()?['authorId'] != uid)) return;
    final m = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (text != null) m['text'] = text;
    if (imageUrl != null) m['imageUrl'] = imageUrl;
    await ref.update(m);
  }

  static Future<void> deletePost(String postId) async {
    final uid = AuthService.userId!;
    final ref = AuthService.firestore.collection('forum_posts').doc(postId);
    final doc = await ref.get();
    if (!doc.exists) return;
    final canModerateForum = await AdminRoleService.hasPermission(
      AdminPermission.moderateForum,
    );
    final isAuthor = doc.data()?['authorId'] == uid;
    if (!isAuthor && !canModerateForum) return;
    await ref
        .update({'deleted': true, 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<String> _uploadPostImageBytes(
      String uid, Uint8List bytes) async {
    final name = 'forum/${uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(name);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  // ─── Çeviri (Lazy + Cache) ───

  /// Paylaşımı hedef dile çevirir ve Firestore'a cache'ler.
  /// Zaten çeviri varsa veya orijinal dil aynıysa çeviri yapmaz.
  /// Dönen değer: çevrilmiş metin (veya orijinal).
  static Future<String> translatePost(ForumPost post, String targetLang) async {
    // Orijinal dil aynıysa direkt döndür
    if (post.language == targetLang) return post.text;

    // Cache'de varsa cache'den döndür
    if (post.translations.containsKey(targetLang)) {
      return post.translations[targetLang]!;
    }

    // Gemini ile çevir
    try {
      final langNames = {
        'tr': 'Türkçe',
        'en': 'English',
        'de': 'Deutsch',
        'es': 'Español',
        'ar': 'العربية',
      };
      final targetLangName = langNames[targetLang] ?? 'English';

      final prompt = '''Translate the following text to $targetLangName. 
Only return the translated text, nothing else. Keep the same tone and meaning.

Text to translate:
${post.text}''';

      final translated =
          await GeminiService.generateResponse(prompt, 'translation');

      // Temizle (Gemini bazen ekstra metin ekleyebilir)
      final cleanedTranslation = translated.trim();

      // Firestore'a cache'le
      await AuthService.firestore
          .collection('forum_posts')
          .doc(post.id)
          .update({
        'translations.$targetLang': cleanedTranslation,
      });

      return cleanedTranslation;
    } catch (e) {
      debugPrint('ForumService translate error: $e');
      return post.text; // Hata durumunda orijinal metni döndür
    }
  }

  // ─── Destek (Seni destekliyorum) ───

  /// Gönderiyi destekle / desteği geri çek (toggle)
  static Future<bool> toggleSupport(String postId) async {
    final uid = AuthService.userId;
    if (uid == null) return false;

    final ref = AuthService.firestore.collection('forum_posts').doc(postId);
    final doc = await ref.get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    final supportedBy = List<String>.from(data['supportedBy'] ?? []);
    final isSupported = supportedBy.contains(uid);

    if (isSupported) {
      // Desteği geri çek
      supportedBy.remove(uid);
    } else {
      // Destek ver
      supportedBy.add(uid);
      // Bildirim gönder
      await _notifyPostAuthor(postId, type: 'support');
    }

    await ref.update({
      'supportedBy': supportedBy,
      'supportCount': supportedBy.length,
    });

    return !isSupported; // Yeni durum: destekliyor mu?
  }

  /// Kullanıcı bu gönderiyi destekliyor mu?
  static Future<bool> isSupporting(String postId) async {
    final uid = AuthService.userId;
    if (uid == null) return false;

    final doc =
        await AuthService.firestore.collection('forum_posts').doc(postId).get();
    if (!doc.exists) return false;

    final supportedBy = List<String>.from(doc.data()?['supportedBy'] ?? []);
    return supportedBy.contains(uid);
  }

  // ─── Yorumlar ───
  static Stream<List<ForumComment>> watchComments(String postId) {
    return AuthService.firestore
        .collection('forum_posts')
        .doc(postId)
        .collection('comments')
        .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ForumComment.fromFirestore(d, postId: postId))
            .toList());
  }

  static Future<String> addComment(String postId, String text) async {
    final uid = AuthService.userId!;
    final name = (await AuthService.getProfile())?['name'] as String?;
    final postRef = AuthService.firestore.collection('forum_posts').doc(postId);
    final ref = await postRef.collection('comments').add({
      'postId': postId,
      'authorId': uid,
      'authorName': name,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'deleted': false,
    });
    // Yorum sayısını artır
    await postRef.update({'commentCount': FieldValue.increment(1)});
    await _notifyPostAuthor(postId, type: 'comment', commentId: ref.id);
    return ref.id;
  }

  static Future<void> updateComment(
      String postId, String commentId, String text) async {
    final uid = AuthService.userId!;
    final ref = AuthService.firestore
        .collection('forum_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final doc = await ref.get();
    if (!doc.exists || (doc.data()?['authorId'] != uid)) return;
    await ref.update({'text': text, 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> deleteComment(String postId, String commentId) async {
    final uid = AuthService.userId!;
    final postRef = AuthService.firestore.collection('forum_posts').doc(postId);
    final ref = postRef.collection('comments').doc(commentId);
    final doc = await ref.get();
    if (!doc.exists) return;
    final canModerateForum = await AdminRoleService.hasPermission(
      AdminPermission.moderateForum,
    );
    final isAuthor = doc.data()?['authorId'] == uid;
    if (!isAuthor && !canModerateForum) return;
    await ref
        .update({'deleted': true, 'updatedAt': FieldValue.serverTimestamp()});
    // Yorum sayısını azalt
    await postRef.update({'commentCount': FieldValue.increment(-1)});
  }

  static Future<void> _notifyPostAuthor(String postId,
      {required String type, String? commentId}) async {
    try {
      final postDoc = await AuthService.firestore
          .collection('forum_posts')
          .doc(postId)
          .get();
      final authorId = postDoc.data()?['authorId'] as String?;
      if (authorId == null || authorId == AuthService.userId) return;
      await AuthService.firestore
          .collection('users')
          .doc(authorId)
          .collection('notifications')
          .add({
        'type': type,
        'postId': postId,
        'commentId': commentId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('ForumService notify error: $e');
    }
  }

  // ─── Günün sorusu (alan; kim dolduracak sonra) ───
  static Future<ForumDailyQuestion?> getTodayDailyQuestion() async {
    final start =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final end = start.add(const Duration(days: 1));
    final q = await AuthService.firestore
        .collection('forum_daily_questions')
        .where('language', isEqualTo: contentLanguage)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return ForumDailyQuestion.fromFirestore(q.docs.first);
  }

  static Stream<List<ForumPost>> watchDailyAnswers(String dailyQuestionId) {
    return AuthService.firestore
        .collection('forum_posts')
        .where('language', isEqualTo: contentLanguage)
        .where('dailyQuestionId', isEqualTo: dailyQuestionId)
        .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ForumPost.fromFirestore(d)).toList());
  }

  static Future<List<ForumPost>> getMyPosts() async {
    final uid = AuthService.userId;
    if (uid == null) return [];
    final q = await AuthService.firestore
        .collection('forum_posts')
        .where('authorId', isEqualTo: uid)
        .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    return q.docs.map((d) => ForumPost.fromFirestore(d)).toList();
  }

  // ─── Admin: Günün sorusu yönetimi ───

  /// Tarihe göre günün sorularını listeler (tüm diller).
  static Future<List<ForumDailyQuestion>> getDailyQuestionsForDate(
      DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final q = await AuthService.firestore
        .collection('forum_daily_questions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return q.docs.map((d) => ForumDailyQuestion.fromFirestore(d)).toList();
  }

  /// Günün sorusu ekler veya günceller (dil + tarih eşleşirse günceller).
  static Future<void> setDailyQuestion({
    required String language,
    required DateTime date,
    required String text,
    String? id,
  }) async {
    final canManage = await AdminRoleService.hasPermission(
        AdminPermission.manageDailyQuestions);
    if (!canManage) {
      throw Exception('Günün sorusu yönetim yetkisi gerekli.');
    }

    final start = DateTime(date.year, date.month, date.day);
    final data = {
      'language': language,
      'text': text,
      'date': Timestamp.fromDate(start),
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (id != null && id.isNotEmpty) {
      await AuthService.firestore
          .collection('forum_daily_questions')
          .doc(id)
          .update({
        'text': text,
        'language': language,
        'date': Timestamp.fromDate(start),
      });
      return;
    }
    final existing = await AuthService.firestore
        .collection('forum_daily_questions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date',
            isLessThan: Timestamp.fromDate(start.add(const Duration(days: 1))))
        .where('language', isEqualTo: language)
        .get();
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({
        'text': text,
        'date': Timestamp.fromDate(start),
      });
      return;
    }
    await AuthService.firestore.collection('forum_daily_questions').add(data);
  }

  /// Günün sorusunu siler.
  static Future<void> deleteDailyQuestion(String id) async {
    final canManage = await AdminRoleService.hasPermission(
        AdminPermission.manageDailyQuestions);
    if (!canManage) {
      throw Exception('Günün sorusu yönetim yetkisi gerekli.');
    }
    await AuthService.firestore
        .collection('forum_daily_questions')
        .doc(id)
        .delete();
  }
}
