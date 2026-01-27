import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cohort_model.dart';
import '../models/session_model.dart';
import '../models/campfire_message.dart';
import 'auth_service.dart';
import 'campfire_ai_service.dart';

/// Kamp Ateşi servis katmanı
/// Cohort, Session ve Message CRUD işlemleri
class CampfireService {
  static final _firestore = FirebaseFirestore.instance;
  static const _cohortsCollection = 'campfire_cohorts';

  // ==================== COHORT İŞLEMLERİ ====================

  /// Kullanıcının mevcut cohort'unu getir (tek aktif)
  static Future<CohortModel?> getUserCohort() async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    final query = await _firestore
        .collection(_cohortsCollection)
        .where('members', arrayContains: userId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return CohortModel.fromFirestore(query.docs.first);
  }

  /// Kullanıcının tüm cohort'larını getir (aktif + dağılmış)
  static Future<List<CohortModel>> getUserCohorts() async {
    final userId = AuthService.userId;
    if (userId == null) return [];

    final query = await _firestore
        .collection(_cohortsCollection)
        .where('members', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return query.docs
        .map((doc) => CohortModel.fromFirestore(doc))
        .toList();
  }

  /// Uygun cohort bul veya yeni oluştur (Matchmaking)
  static Future<CohortModel> findOrCreateCohort({
    required String topic,
    required String timezone,
    required String language,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli');

    // 1. Uygun bekleyen cohort ara (aynı konu + timezone + dil)
    final query = await _firestore
        .collection(_cohortsCollection)
        .where('topic', isEqualTo: topic)
        .where('timezone', isEqualTo: timezone)
        .where('language', isEqualTo: language)
        .where('memberCount', isLessThan: 6) // Max 6 kişi
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      // Mevcut cohort'a katıl
      final cohortDoc = query.docs.first;
      await cohortDoc.reference.update({
        'members': FieldValue.arrayUnion([userId]),
        'memberCount': FieldValue.increment(1),
      });
      return CohortModel.fromFirestore(
        await cohortDoc.reference.get(),
      );
    }

    // 2. Yeni cohort oluştur
    final newCohort = CohortModel(
      id: '',
      members: [userId],
      topic: topic,
      groupName: _generateGroupName(topic),
      timezone: timezone,
      language: language,
      createdAt: DateTime.now(),
      memberCount: 1,
    );

    final docRef = await _firestore
        .collection(_cohortsCollection)
        .add(newCohort.toFirestore());

    // İlk session'ı da oluştur (WAITING durumunda)
    await _createSession(docRef.id);

    return newCohort.copyWith(id: docRef.id);
  }

  /// Grup ismi oluştur
  static String _generateGroupName(String topic) {
    final topicNames = {
      'anksiyete': 'Sakin Zihinler',
      'yas': 'Işık Arayanlar',
      'kumar': 'Yeni Başlangıç',
      'ayrilik': 'Kırık Kalpler',
      'sosyal_anksiyete': 'Sessiz Yürekler',
      'bagimlilik': 'Özgür Ruhlar',
      'depresyon': 'Umut Işığı',
      'ofke': 'Dingin Sular',
    };
    final baseName = topicNames[topic] ?? 'Ateş Çevresi';
    final randomNum = DateTime.now().millisecondsSinceEpoch % 1000;
    return '$baseName #$randomNum';
  }

  /// Cohort'u dinle (realtime)
  static Stream<CohortModel?> watchCohort(String cohortId) {
    return _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .snapshots()
        .map((doc) => doc.exists ? CohortModel.fromFirestore(doc) : null);
  }

  // ==================== SESSION İŞLEMLERİ ====================

  /// Yeni session oluştur
  static Future<SessionModel> _createSession(String cohortId) async {
    final session = SessionModel(
      id: '',
      cohortId: cohortId,
      status: SessionStatus.waiting,
      participantCount: 0,
    );

    final docRef = await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .add(session.toFirestore());

    return session.copyWith(id: docRef.id);
  }

  /// Aktif veya bekleyen session'ı getir
  static Future<SessionModel?> getCurrentSession(String cohortId) async {
    // Önce ACTIVE veya LOCKED session'ı ara
    var query = await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .where('status', whereIn: ['ACTIVE', 'LOCKED'])
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return SessionModel.fromFirestore(query.docs.first, cohortId);
    }
    
    // Yoksa WAITING session'ı ara
    query = await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .where('status', isEqualTo: 'WAITING')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return SessionModel.fromFirestore(query.docs.first, cohortId);
  }

  /// Session'ı dinle (realtime)
  static Stream<SessionModel?> watchSession(String cohortId, String sessionId) {
    return _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists 
            ? SessionModel.fromFirestore(doc, cohortId) 
            : null);
  }

  /// Session durumunu güncelle
  static Future<void> updateSessionStatus(
    String cohortId,
    String sessionId,
    SessionStatus status,
  ) async {
    final updates = <String, dynamic>{
      'status': status.name.toUpperCase(),
    };

    // Durum bazlı timestamp'ler
    switch (status) {
      case SessionStatus.active:
        updates['startedAt'] = FieldValue.serverTimestamp();
        break;
      case SessionStatus.locked:
        updates['lockedAt'] = FieldValue.serverTimestamp();
        break;
      case SessionStatus.ended:
        updates['endedAt'] = FieldValue.serverTimestamp();
        break;
      default:
        break;
    }

    await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .update(updates);
  }

  /// Oturumu başlat (3 kişi dolduğunda)
  static Future<void> startSession(String cohortId, String sessionId) async {
    await updateSessionStatus(cohortId, sessionId, SessionStatus.active);
    
    // Hoş geldin mesajı
    await sendMessage(
      cohortId: cohortId,
      sessionId: sessionId,
      message: CampfireMessage.fromAI(
        'Hoş geldiniz. Ateşimiz yandı. 10 dakika boyunca kapımız açık kalacak, sonra kilitlenecek. Başlayabiliriz...',
      ),
    );
  }

  /// Oturumu kilitle (10 dk dolduğunda)
  static Future<void> lockSession(String cohortId, String sessionId) async {
    await updateSessionStatus(cohortId, sessionId, SessionStatus.locked);
    
    // Bildirim mesajı
    await sendMessage(
      cohortId: cohortId,
      sessionId: sessionId,
      message: CampfireMessage.system(
        'Kapıları kapattık. Artık biz bizeyiz. Sadece buraya odaklanalım.',
      ),
    );
  }

  /// Oturumu bitir (30 dk dolduğunda)
  static Future<void> endSession(String cohortId, String sessionId) async {
    // Cohort bilgisini al
    final cohortDoc = await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .get();
    
    if (cohortDoc.exists) {
      final cohort = CohortModel.fromFirestore(cohortDoc);
      
      // Mesajları al
      final messagesSnapshot = await _firestore
          .collection(_cohortsCollection)
          .doc(cohortId)
          .collection('sessions')
          .doc(sessionId)
          .collection('messages')
          .orderBy('timestamp')
          .get();
      
      final messages = messagesSnapshot.docs
          .map((doc) => CampfireMessage.fromFirestore(doc))
          .toList();
      
      // AI oturum sonu analizi
      await CampfireAIService.generateSessionAnalysis(
        cohortId: cohortId,
        sessionId: sessionId,
        cohort: cohort,
        messages: messages,
      );
    }
    
    await updateSessionStatus(cohortId, sessionId, SessionStatus.ended);
    
    // Sonraki oturum zamanını ayarla (24 saat sonra)
    await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .update({
      'nextSessionTime': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
      'totalSessions': FieldValue.increment(1),
    });
  }

  // ==================== MESAJ İŞLEMLERİ ====================

  /// Mesaj gönder
  static Future<void> sendMessage({
    required String cohortId,
    required String sessionId,
    required CampfireMessage message,
  }) async {
    await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .add(message.toFirestore());
  }

  /// Kullanıcı mesajı gönder
  static Future<void> sendUserMessage({
    required String cohortId,
    required String sessionId,
    required String content,
  }) async {
    final userId = AuthService.userId;
    final profile = await AuthService.getProfile();
    
    final message = CampfireMessage(
      id: '',
      senderId: userId ?? 'anonymous',
      senderName: profile?['name'] ?? 'Anonim',
      content: content,
      timestamp: DateTime.now(),
      type: MessageType.message,
    );

    await sendMessage(
      cohortId: cohortId,
      sessionId: sessionId,
      message: message,
    );
  }

  /// Mesajları dinle (realtime)
  static Stream<List<CampfireMessage>> watchMessages(
    String cohortId,
    String sessionId,
  ) {
    return _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CampfireMessage.fromFirestore(doc))
            .toList());
  }

  /// Session'daki toplam mesaj sayısı
  static Future<int> getMessageCount(String cohortId, String sessionId) async {
    final snapshot = await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Session mesajlarını getir (one-time fetch)
  static Future<List<CampfireMessage>> getSessionMessages(
    String cohortId,
    String sessionId,
  ) async {
    final snapshot = await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => CampfireMessage.fromFirestore(doc))
        .toList();
  }

  // ==================== LOBBY İŞLEMLERİ ====================

  /// Lobiye katıl (participant count artır)
  static Future<void> joinLobby(String cohortId, String sessionId) async {
    await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .update({
      'participantCount': FieldValue.increment(1),
    });
  }

  /// Aktif oturuma katıl (geç gelen için hoş geldin mesajı)
  static Future<void> joinActiveSession({
    required String cohortId,
    required String sessionId,
    required String participantName,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return;
    
    // Kullanıcının daha önce bu session'a mesaj gönderip göndermediğini kontrol et
    final userMessagesSnapshot = await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .where('senderId', isEqualTo: userId)
        .limit(1)
        .get();
    
    // Eğer kullanıcı daha önce mesaj göndermişse, hoş geldin mesajı gönderme
    if (userMessagesSnapshot.docs.isNotEmpty) {
      return; // Zaten katılmış, hoş geldin mesajı gönderme
    }
    
    // Cohort ve mesajları al
    final cohortDoc = await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .get();
    
    if (cohortDoc.exists) {
      final cohort = CohortModel.fromFirestore(cohortDoc);
      
      final messagesSnapshot = await _firestore
          .collection(_cohortsCollection)
          .doc(cohortId)
          .collection('sessions')
          .doc(sessionId)
          .collection('messages')
          .orderBy('timestamp')
          .limit(50)
          .get();
      
      final messages = messagesSnapshot.docs
          .map((doc) => CampfireMessage.fromFirestore(doc))
          .toList();
      
      // AI hoş geldin mesajı (sadece ilk kez katılanlar için)
      await CampfireAIService.welcomeNewParticipant(
        cohortId: cohortId,
        sessionId: sessionId,
        cohort: cohort,
        participantName: participantName,
        messages: messages,
      );
    }
  }

  /// Lobiden ayrıl
  static Future<void> leaveLobby(String cohortId, String sessionId) async {
    await _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .update({
      'participantCount': FieldValue.increment(-1),
    });
  }

  /// Lobby etkileşimi gönder (selam, odun)
  static Future<void> sendLobbyInteraction({
    required String cohortId,
    required String sessionId,
    required String type,
  }) async {
    final userId = AuthService.userId;
    final profile = await AuthService.getProfile();
    final userName = profile?['name'] ?? 'Biri';
    
    final interactionRef = _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .collection('lobby_interactions');
    
    // Etkileşimi kaydet
    await interactionRef.add({
      'userId': userId,
      'userName': userName,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    // Odun sayısını güncelle
    if (type == 'wood') {
      await _firestore
          .collection(_cohortsCollection)
          .doc(cohortId)
          .collection('sessions')
          .doc(sessionId)
          .update({
        'woodCount': FieldValue.increment(1),
      });
    }
  }

  /// Lobby etkileşimlerini dinle
  static Stream<Map<String, dynamic>> watchLobbyInteractions(
    String cohortId,
    String sessionId,
  ) {
    // Session'dan odun sayısını al
    final sessionStream = _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .snapshots();
    
    // Son 5 etkileşimi al
    final interactionsStream = _firestore
        .collection(_cohortsCollection)
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .collection('lobby_interactions')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots();
    
    // İki stream'i birleştir
    return sessionStream.asyncMap((sessionDoc) async {
      final woodCount = sessionDoc.data()?['woodCount'] ?? 0;
      
      final interactionsSnapshot = await _firestore
          .collection(_cohortsCollection)
          .doc(cohortId)
          .collection('sessions')
          .doc(sessionId)
          .collection('lobby_interactions')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
      
      final recentInteractions = interactionsSnapshot.docs.map((doc) {
        final data = doc.data();
        final userName = data['userName'] ?? 'Biri';
        final type = data['type'];
        if (type == 'selam') {
          return '$userName selam verdi 👋';
        } else if (type == 'wood') {
          return '$userName odun attı 🪵';
        }
        return '';
      }).where((s) => s.isNotEmpty).toList();
      
      return {
        'woodCount': woodCount,
        'recent': recentInteractions,
      };
    });
  }

  // ==================== KONU LİSTESİ ====================

  /// Mevcut konu listesi
  static List<Map<String, String>> get availableTopics => [
    {'id': 'anksiyete', 'name': 'Anksiyete', 'icon': '😰'},
    {'id': 'yas', 'name': 'Yas ve Kayıp', 'icon': '🕯️'},
    {'id': 'kumar', 'name': 'Kumar Bağımlılığı', 'icon': '🎰'},
    {'id': 'ayrilik', 'name': 'Ayrılık / İlişki', 'icon': '💔'},
    {'id': 'sosyal_anksiyete', 'name': 'Sosyal Anksiyete', 'icon': '🫥'},
    {'id': 'bagimlilik', 'name': 'Madde Bağımlılığı', 'icon': '⛓️'},
    {'id': 'depresyon', 'name': 'Depresyon', 'icon': '🌧️'},
    {'id': 'ofke', 'name': 'Öfke Kontrolü', 'icon': '😤'},
  ];
}
