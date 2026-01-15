// lib/services/relationship_analysis_service.dart
// THE AUDITOR - İlişki Müfettişi Servisi

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/relationship_analysis_model.dart';
import 'auth_service.dart';
import 'partner_service.dart';

/// THE AUDITOR - Baş İlişki Müfettişi
/// Modlardan bağımsız, objektif ilişki analizi servisi
class RelationshipAnalysisService {
  static GenerativeModel? _model;
  static bool _isAnalyzing = false;
  static const _uuid = Uuid();

  static bool get isAnalyzing => _isAnalyzing;

  // ============================================================
  // THE AUDITOR PROMPT
  // ============================================================
  static const String _auditorPrompt = '''
### KİMLİK:
Sen Mentaliq uygulamasının "Baş İlişki Müfettişisin" (Chief Relationship Auditor).
Görevin: Sohbet etmek değil. Eline gelen verileri (Profil, Geçmiş Olaylar, Son Mesajlar) inceleyip, duygusuz ve %100 objektif bir "Durum Raporu" ve "Kurtuluş Reçetesi" hazırlamaktır.

### KURALLAR:
1. **ASLA TARAF TUTMA:** Kullanıcı hatalıysa yüzüne vur. Partner hatalıysa belirt.
2. **REÇETE YAZ:** Sadece "İlişkiniz kötü" deme. "Şunu yapmalısın" diye emir kipiyle somut görevler ver.
3. **FORMAT:** Cevabın SADECE geçerli bir JSON objesi olmalı. Markdown (```json) veya sohbet metni ekleme.

### İSTENEN JSON ÇIKTISI VE DETAYLARI:
Cevabı tam olarak şu anahtarlarla (keys) üret:

1.  **score (0-100):** İlişkinin sağlık puanı.
2.  **title (String):** Durumu özetleyen vurucu başlık. (Örn: "Toksik Sarmal", "Gizli Hayranlık").
3.  **analysis (String):** Senin öznel değerlendirmen. Neden bu puanı verdin? Temel sorun ne? (Max 3 cümle).
4.  **personality_clash (String):** Kullanıcı ve Partner arasındaki karakter çatışması analizi. (Örn: "Senin duygusallığın vs. Onun mantıkçılığı").
5.  **recommendations (Array):** Senin "kendi düşüncene göre" kullanıcıya verdiğin özel tavsiyeler listesi.
    * **type:** Tavsiye türü ('communication', 'action', 'mindset').
    * **text:** Tavsiye metni.
    * **is_hard_pill:** (Boolean) Eğer bu tavsiye kullanıcının duymak istemediği sert bir gerçekse true yap.
''';

  /// Initialize service
  static void initialize(String apiKey) {
    try {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4, // Düşük - tutarlı JSON çıktısı
          topP: 0.9,
          maxOutputTokens: 1024,
        ),
      );
      debugPrint('RelationshipAnalysisService initialized');
    } catch (e) {
      debugPrint('Error initializing RelationshipAnalysisService: $e');
    }
  }

  /// Perform relationship analysis
  static Future<RelationshipAnalysisModel?> performAnalysis() async {
    if (_model == null) {
      debugPrint('AnalysisService: Model not initialized');
      return null;
    }

    if (_isAnalyzing) {
      debugPrint('AnalysisService: Already analyzing');
      return null;
    }

    _isAnalyzing = true;

    try {
      // 1. Get Partner Profile
      final partnerContext = await PartnerService.getPartnerContextForAI();
      if (partnerContext.isEmpty) {
        debugPrint('AnalysisService: No partner data');
        _isAnalyzing = false;
        return null;
      }

      // 2. Get Shadow Memory (Critical events)
      final shadowMemory = await _getShadowMemoryContext();

      // 3. Get Last 15 Messages
      final recentMessages = await _getRecentMessagesContext();

      // Build full prompt
      final dataPackage = '''
### ANALİZ EDİLECEK VERİLER:

$partnerContext

$shadowMemory

$recentMessages
''';

      final fullPrompt = '''
$_auditorPrompt

$dataPackage

Şimdi yukarıdaki verileri analiz et ve SADECE JSON formatında cevap ver.
''';

      debugPrint('AnalysisService: Sending analysis request...');
      
      final response = await _model!.generateContent([Content.text(fullPrompt)]);
      final responseText = response.text?.trim() ?? '';

      debugPrint('AnalysisService raw response: $responseText');

      // Parse JSON response
      final analysis = _parseAnalysisResponse(responseText);
      
      if (analysis != null) {
        // Save to Firebase
        await _saveAnalysis(analysis);
        debugPrint('AnalysisService: Analysis completed and saved ✓');
      }

      return analysis;

    } catch (e) {
      debugPrint('AnalysisService error: $e');
      return null;
    } finally {
      _isAnalyzing = false;
    }
  }

  /// Get Shadow Memory context
  static Future<String> _getShadowMemoryContext() async {
    try {
      final partner = PartnerService.currentPartner;
      if (partner == null) return '[GÖLGE HAFIZA: Veri yok]';

      final traits = <String>[];
      
      if (partner.negativeTraits != null && partner.negativeTraits!.isNotEmpty) {
        traits.addAll(partner.negativeTraits!.map((t) => '⚠️ $t'));
      }
      if (partner.positiveTraits != null && partner.positiveTraits!.isNotEmpty) {
        traits.addAll(partner.positiveTraits!.map((t) => '✓ $t'));
      }
      if (partner.conflictTopics != null && partner.conflictTopics!.isNotEmpty) {
        traits.addAll(partner.conflictTopics!.map((t) => '💥 Çatışma: $t'));
      }

      if (traits.isEmpty) {
        return '[GÖLGE HAFIZA: Henüz tespit edilen kritik olay yok]';
      }

      return '''
[GÖLGE HAFIZA - TESPİT EDİLEN KRİTİK OLAYLAR]:
${traits.join('\n')}
''';
    } catch (e) {
      debugPrint('Error getting shadow memory: $e');
      return '[GÖLGE HAFIZA: Veri alınamadı]';
    }
  }

  /// Get recent messages context
  static Future<String> _getRecentMessagesContext() async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return '[SON MESAJLAR: Veri yok]';

      // Get recent chat sessions for 'iliskiler' category
      final sessionsSnapshot = await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .where('category', isEqualTo: 'iliskiler')
          .orderBy('lastMessageAt', descending: true)
          .limit(3)
          .get();

      if (sessionsSnapshot.docs.isEmpty) {
        return '[SON MESAJLAR: Henüz sohbet yok]';
      }

      final messages = <String>[];
      
      for (final session in sessionsSnapshot.docs) {
        final messagesSnapshot = await session.reference
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();

        for (final msgDoc in messagesSnapshot.docs) {
          final data = msgDoc.data();
          final isUser = data['isUser'] as bool? ?? false;
          final content = data['content'] as String? ?? '';
          if (isUser && content.isNotEmpty) {
            messages.add('- Kullanıcı: "${content.length > 100 ? content.substring(0, 100) + '...' : content}"');
          }
        }
      }

      if (messages.isEmpty) {
        return '[SON MESAJLAR: Analiz edilecek mesaj yok]';
      }

      return '''
[SON KULLANICI MESAJLARI - İLİŞKİ TANSİYONU]:
${messages.take(15).join('\n')}
''';
    } catch (e) {
      debugPrint('Error getting recent messages: $e');
      return '[SON MESAJLAR: Veri alınamadı]';
    }
  }

  /// Parse analysis response
  static RelationshipAnalysisModel? _parseAnalysisResponse(String responseText) {
    try {
      // Clean response - remove markdown code blocks if present
      String cleanJson = responseText;
      if (cleanJson.contains('```json')) {
        cleanJson = cleanJson.split('```json')[1].split('```')[0].trim();
      } else if (cleanJson.contains('```')) {
        cleanJson = cleanJson.split('```')[1].split('```')[0].trim();
      }

      final Map<String, dynamic> data = json.decode(cleanJson);
      final id = _uuid.v4();
      
      return RelationshipAnalysisModel.fromGeminiJson(data, id);
    } catch (e) {
      debugPrint('AnalysisService: Failed to parse JSON: $e');
      return null;
    }
  }

  /// Save analysis to Firebase
  static Future<void> _saveAnalysis(RelationshipAnalysisModel analysis) async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return;

      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('relationship_analyses')
          .doc(analysis.id)
          .set(analysis.toFirestore());

      debugPrint('Analysis saved: ${analysis.id}');
    } catch (e) {
      debugPrint('Error saving analysis: $e');
    }
  }

  /// Get all analyses for current user
  static Future<List<RelationshipAnalysisModel>> getAnalyses() async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return [];

      final snapshot = await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('relationship_analyses')
          .orderBy('date', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => RelationshipAnalysisModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting analyses: $e');
      return [];
    }
  }

  /// Get single analysis by ID
  static Future<RelationshipAnalysisModel?> getAnalysis(String id) async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return null;

      final doc = await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('relationship_analyses')
          .doc(id)
          .get();

      if (!doc.exists) return null;
      
      return RelationshipAnalysisModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('Error getting analysis: $e');
      return null;
    }
  }

  /// Update recommendation completion status
  static Future<void> toggleRecommendation(String analysisId, int recommendationIndex, bool completed) async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return;

      // Get current analysis
      final doc = await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('relationship_analyses')
          .doc(analysisId)
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;
      final recommendations = List<Map<String, dynamic>>.from(data['recommendations'] ?? []);
      
      if (recommendationIndex < recommendations.length) {
        recommendations[recommendationIndex]['completed'] = completed;
        
        await doc.reference.update({'recommendations': recommendations});
        debugPrint('Recommendation $recommendationIndex toggled: $completed');
      }
    } catch (e) {
      debugPrint('Error toggling recommendation: $e');
    }
  }
}
