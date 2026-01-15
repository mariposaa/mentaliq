import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/style_item.dart';
import 'auth_service.dart';
import 'gemini_service.dart';

class StyleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _collection = 'style_closet';

  /// Fotoğraf yükler ve Gemini ile analiz edip arşive ekler
  static Future<StyleItem?> addToCloset(XFile imageFile) async {
    final userId = AuthService.userId;
    if (userId == null) {
      debugPrint('StyleService: User ID is null');
      return null;
    }

    try {
      debugPrint('StyleService: Starting upload for user $userId');
      // 1. Fotoğrafı Storage'a yükle
      final fileName = 'style_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('users/$userId/closet/$fileName');
      
      final imageBytes = await imageFile.readAsBytes();
      debugPrint('StyleService: Image bytes read, total: ${imageBytes.length}');
      
      try {
        if (kIsWeb) {
          debugPrint('StyleService: Uploading Data (Web) - Timeout set to 30s...');
          final task = ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
          await task.whenComplete(() => debugPrint('StyleService: putData complete')).timeout(const Duration(seconds: 30));
        } else {
          debugPrint('StyleService: Uploading Data (Mobile)...');
          await ref.putData(imageBytes).timeout(const Duration(seconds: 30)); 
        }
      } catch (timeoutError) {
        debugPrint('StyleService: Upload Timeout or Error: $timeoutError');
        throw Exception('Resim yükleme zaman aşımına uğradı. Lütfen internet bağlantını ve Firebase Storage kurallarını kontrol et.');
      }
      
      final imageUrl = await ref.getDownloadURL();
      debugPrint('StyleService: Image uploaded. URL: $imageUrl');

      // 2. Multimodal Analiz (Gemini)
      debugPrint('StyleService: Calling Gemini Analysis...');
      final analysisResult = await _analyzeStyleItem(imageBytes);
      debugPrint('StyleService: Gemini Analysis Completed: $analysisResult');

      // 3. Firestore'a kaydet
      final newItem = StyleItem(
        id: '', 
        imageUrl: imageUrl,
        category: analysisResult['category'] ?? 'Diğer',
        tags: List<String>.from(analysisResult['tags'] ?? []),
        season: analysisResult['season'] ?? 'Dört Mevsim',
        aiDescription: analysisResult['description'] ?? '',
        createdAt: DateTime.now(),
      );

      debugPrint('StyleService: Saving to Firestore...');
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection(_collection)
          .add(newItem.toFirestore());

      debugPrint('StyleService: Saved to Firestore with ID: ${docRef.id}');

      return StyleItem(
        id: docRef.id,
        imageUrl: imageUrl,
        category: newItem.category,
        tags: newItem.tags,
        season: newItem.season,
        aiDescription: newItem.aiDescription,
        createdAt: newItem.createdAt,
      );
    } catch (e) {
      debugPrint('StyleService Error: $e');
      return null;
    }
  }

  /// Arşivi getir
  static Stream<List<StyleItem>> getClosetStream() {
    final userId = AuthService.userId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => StyleItem.fromFirestore(doc)).toList());
  }

  /// Tüm arşivi liste olarak getir
  static Future<List<StyleItem>> getClosetItems() async {
    final userId = AuthService.userId;
    if (userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection(_collection)
        .get();

    return snapshot.docs.map((doc) => StyleItem.fromFirestore(doc)).toList();
  }

  /// Tüm arşivi metin olarak hazırla (AI tavsiyesi için)
  static Future<String> getClosetAsText() async {
    final userId = AuthService.userId;
    if (userId == null) return '';

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection(_collection)
        .get();

    if (snapshot.docs.isEmpty) return 'Kullanıcının gardırobu henüz boş.';

    final buffer = StringBuffer('Kullanıcının Gardırobu:\n');
    for (var i = 0; i < snapshot.docs.length; i++) {
      final item = StyleItem.fromFirestore(snapshot.docs[i]);
      buffer.writeln('${i + 1}. ${item.category}: ${item.tags.join(', ')} (${item.season})');
    }
    return buffer.toString();
  }

  /// Gemini ile tek seferlik görsel analizi
  static Future<Map<String, dynamic>> _analyzeStyleItem(Uint8List imageBytes) async {
    const prompt = '''
Bu kıyafeti bir moda uzmanı gibi analiz et ve SADECE aşağıdaki JSON formatında yanıt ver:
{
  "category": "Üst/Alt/Dış Giyim/Ayakkabı/Aksesuar",
  "tags": ["renk", "kumaş", "kesim", "stil_etiketi"],
  "season": "Yaz/Kış/Bahar/Dört Mevsim",
  "description": "Kısa bir sözel tanımlama"
}
''';
    
    try {
      final response = await GeminiService.analyzeImage(imageBytes, prompt, category: 'stil_danismanligi');
      return _parsingSimulatedJson(response);
    } catch (e) {
      debugPrint('StyleService: _analyzeStyleItem error: $e');
      return {'category': 'Diğer', 'tags': ['hata'], 'description': 'Analiz sırasında hata oluştu.'};
    }
  }

  static Map<String, dynamic> _parsingSimulatedJson(String text) {
    try {
      String cleanedText = text.trim();
      if (cleanedText.contains('```')) {
        final firstIndex = cleanedText.indexOf('{');
        final lastIndex = cleanedText.lastIndexOf('}');
        if (firstIndex != -1 && lastIndex != -1) {
          cleanedText = cleanedText.substring(firstIndex, lastIndex + 1);
        }
      }

      final Map<String, dynamic> data = jsonDecode(cleanedText);
      
      return {
        'category': data['category'] ?? 'Tespit Edilen', 
        'tags': List<String>.from(data['tags'] ?? ['Genel']), 
        'season': data['season'] ?? 'Dört Mevsim',
        'description': data['description'] ?? 'Tanımlanamadı'
      };
    } catch (e) {
      debugPrint('StyleService: JSON Parse Error: $e - Response: $text');
      return {
        'category': 'Tespit Edilen', 
        'tags': ['Trend'], 
        'description': text.length > 50 ? text.substring(0, 50) : text
      };
    }
  }
}
