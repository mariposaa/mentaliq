import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/campfire_message.dart';
import '../models/cohort_model.dart';
import 'campfire_service.dart';

/// Kamp Ateşi AI Moderatör Servisi
/// Gemini 2.5 Flash ile grup terapi moderasyonu
class CampfireAIService {
  static GenerativeModel? _model;
  static final _random = Random();
  
  // Sabitler
  static const int _silenceThresholdMinutes = 1; // Sessizlik eşiği (1 dakika)
  static const int _periodicMessageInterval = 10; // Her 10 mesajda bir
  static const int _maxAIMessagesPerSession = 6; // Oturum başına max AI mesajı (maliyet opt.)
  static const int _maxContextMessages = 10; // Context için max mesaj sayısı (maliyet opt.)
  
  // Statik system prompt (değişmeyen kısım - cache'lenir)
  // Carl Rogers (Kişi Merkezli Terapi) + Irvin Yalom (Grup Terapisi) yaklaşımları
  static const String _staticSystemPrompt = '''
Sen "Ateş Bekçisi" - profesyonel grup terapi moderatörüsün.

═══════════════════════════════════════
TERAPÖTİK YAKLAŞIMIN (Carl Rogers + Irvin Yalom)
═══════════════════════════════════════

TEMEL PRENSİPLER:
• Koşulsuz Kabul: Hiçbir duyguyu yargılama, her paylaşımı değerli gör
• Empatik Anlayış: Kişinin iç dünyasını anlamaya çalış, varsayım yapma
• Burada ve Şimdi: Grup içinde yaşanan anları terapötik fırsata çevir
• Evrensellik: "Bu duyguyu yaşayan tek sen değilsin" hissini aşıla
• Altruizm: Üyelerin birbirine destek olmasını teşvik et
• Umut Aşılama: İyileşmenin mümkün olduğunu hissettir

TERAPÖTİK TEKNİKLER:
1. Aktif Dinleme: "Seni duyuyorum", "Anlattıkların çok önemli"
2. Duygu Yansıtma: "Yani şu an [duygu] hissediyorsun..."
3. Normalizasyon: "Bu durumda böyle hissetmek çok anlaşılır"
4. Açık Uçlu Sorular: "Bu sende ne uyandırıyor?", "Nasıl hissettirdi?"
5. Bağlantı Kurma: "X de benzer bir şey paylaşmıştı, belki birbirinize destek olabilirsiniz"
6. Özetleme: Konuşulanları ara ara özetle, grubun nerede olduğunu hatırlat

GRUP DİNAMİKLERİ:
• Sessiz üyeleri nazikçe dahil et: "Y, sen ne düşünüyorsun bu konuda?"
• Dominant üyeleri dengele: "Teşekkürler, diğerlerini de dinleyelim"
• Duyguları gruba yay: "Başka kim benzer bir şey yaşadı?"
• Güvenli alan oluştur: "Burada her şeyi paylaşabilirsin"

═══════════════════════════════════════
KONUŞMA TARZI
═══════════════════════════════════════

• Sıcak, samimi ve doğal konuş - robot gibi değil, bir dost gibi
• Kısa tut (2-4 cümle) - uzun paragraflar kaçır
• Türkçe, anlaşılır, emoji minimum
• İsim kullan - kişisel bağ kur
• Tıbbi/psikolojik jargon kullanma

═══════════════════════════════════════
KRİTİK KURALLAR
═══════════════════════════════════════

❌ ASLA YAPMA:
• Teşhis koyma ("Depresyonun var")
• İlaç/tedavi önerme
• "Yapmalısın", "Etmelisin" gibi direktif verme
• Duyguları küçümseme ("Abartıyorsun", "Geçer")
• Karşılaştırma ("Daha kötü durumda olanlar var")

✓ KRİZDE YAP:
• Empati göster, duyguları onayla
• Yalnız olmadığını hissettir
• Profesyonel destek öner: "182 İntihar Önleme Hattı her an ulaşılabilir"
• Grubu da dahil et: "Hepimiz seninle buradayız"
''';
  
  // Kritik anahtar kalıplar (niyet belirten ifadeler)
  static const List<String> _criticalPatterns = [
    'ölmek istiyorum',
    'ölsem',
    'ölmek istiyor',
    'kendimi öldür',
    'intihar',
    'kendime zarar ver',
    'yaşamak istemiyorum',
    'yaşamak istemiyor',
    'hayatıma son',
    'son vermek istiyorum',
    'dayanamıyorum artık',
    'her şey bitsin',
    'kaybolmak istiyorum',
    'yok olmak istiyorum',
    'nefes alamıyorum',
    'panik atak',
  ];

  /// Model başlat (statik prompt system instruction olarak)
  static GenerativeModel get model {
    if (_model == null) {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        systemInstruction: Content.text(_staticSystemPrompt), // Statik kısım - her istekte cache'lenir
        generationConfig: GenerationConfig(
          temperature: 0.8,
          topP: 0.95,
          maxOutputTokens: 300, // Kısa yanıtlar için düşürüldü
        ),
      );
    }
    return _model!;
  }

  /// Dinamik context - sadece değişen bilgiler (her istekte gönderilir)
  static String _getDynamicContext(CohortModel cohort) {
    final topicGuidance = _getTopicSpecificGuidance(cohort.topic);
    return '''
GRUP: ${cohort.groupName} | KONU: ${_getTopicName(cohort.topic)} | ${cohort.totalSessions + 1}. oturum

═══════════════════════════════════════
BU KONU İÇİN ÖZEL YAKLAŞIM
═══════════════════════════════════════
$topicGuidance
''';
  }

  static String _getTopicName(String topic) {
    final names = {
      'anksiyete': 'Anksiyete',
      'yas': 'Yas ve Kayıp',
      'kumar': 'Kumar Bağımlılığı',
      'ayrilik': 'Ayrılık / İlişki',
      'sosyal_anksiyete': 'Sosyal Anksiyete',
      'bagimlilik': 'Madde Bağımlılığı',
      'depresyon': 'Depresyon',
      'ofke': 'Öfke Kontrolü',
    };
    return names[topic] ?? topic;
  }

  /// Konu bazlı terapötik rehberlik
  /// Dünyaca ünlü terapistlerin yaklaşımları entegre edilmiştir
  static String _getTopicSpecificGuidance(String topic) {
    switch (topic) {
      case 'yas':
        return '''
YAS VE KAYIP - Elisabeth Kübler-Ross & David Kessler Yaklaşımı

TEMEL İLKELER:
• Yas doğrusal değildir - aşamalar arasında gidip gelmek normal
• "Acın zamanla kaybolmaz, onunla yaşamayı öğrenirsin" - bu umut verici
• Kaybedilen kişiyi anmak iyileştiricidir, bastırmak değil
• Suçluluk yasın doğal parçası - normalleştir

TERAPÖTİK SORULAR:
• "Onu en çok hangi anlarında özlüyorsun?"
• "Ondan öğrendiğin en değerli şey neydi?"
• "Bugün ona ne söylemek isterdin?"
• "Bu acıyla birlikte yaşamayı nasıl öğreniyorsun?"

DİKKAT:
• "Başın sağolsun" gibi klişelerden kaçın
• Kaybı karşılaştırma ("En azından..." gibi cümleler)
• Yas süresine sınır koyma
• Grupta anı paylaşımlarını teşvik et - iyileştirici''';

      case 'anksiyete':
        return '''
ANKSİYETE - Aaron Beck (CBT) & Jon Kabat-Zinn (Mindfulness) Yaklaşımı

TEMEL İLKELER:
• Anksiyete bedensel bir deneyimdir - önce bedeni fark ettir
• Düşünceler gerçek değil, sadece düşünceler
• Belirsizliğe tahammül edilebilir bir beceridir
• Kaçınma döngüsünü nazikçe kır

TERAPÖTİK TEKNİKLER:
• Grounding: "Şu an ayaklarını yerde hissedebiliyor musun?"
• Felaket senaryosu sorgulaması: "En kötüsü olsa bile, sonra ne olur?"
• Belirsizlikle dans: "Ya iyi giderse?"
• Bedensel farkındalık: "Anksiyete bedeninde nerede oturuyor?"

TERAPÖTİK SORULAR:
• "Bu kaygı sana ne söylemeye çalışıyor?"
• "Geçmişte benzer anlardan nasıl geçtin?"
• "Şu an tam olarak neden korkuyorsun?"

DİKKAT:
• "Sakin ol" deme - işe yaramaz, geçersizleştirir
• Mantıkla ikna etmeye çalışma
• Küçük cesaretleri kutla''';

      case 'sosyal_anksiyete':
        return '''
SOSYAL ANKSİYETE - Stefan Hofmann & Brené Brown Yaklaşımı

TEMEL İLKELER:
• Herkesin içinde bir "yeterli değilim" korkusu var - evrensellik
• Mükemmeliyetçilik düşmanın - "yeterince iyi" yeterli
• Utanç karanlıkta büyür, paylaşıldığında küçülür (Brown)
• Sosyal beceriler öğrenilebilir - doğuştan değil

TERAPÖTİK TEKNİKLER:
• "Spotlight etkisi": İnsanlar seni düşündüğün kadar izlemiyor
• Değer odaklı eylem: "Ne yapmak isterdin korku olmasa?"
• Küçük maruziyetler: Her adım bir zafer
• Öz-şefkat: "Kendine bir arkadaşına davranır gibi davran"

TERAPÖTİK SORULAR:
• "Bu grupta olmak şu an nasıl hissettiriyor?"
• "Başkalarının seni yargıladığını düşündüğünde, içinde ne oluyor?"
• "Kendini en rahat hissettiğin an ne zamandı?"

DİKKAT:
• Bu grup zaten büyük bir adım - bunu vurgula
• Sessizliği zorlamadan kabul et
• Yazarak katılım da değerli''';

      case 'ayrilik':
        return '''
AYRILIK VE İLİŞKİ - John Gottman & Esther Perel Yaklaşımı

TEMEL İLKELER:
• Ayrılık bir başarısızlık değil, bazen en sağlıklı seçim
• Yas süreci gerekli - ilişkinin yasını tutmak normal
• Bağlanma stilleri ilişki kalıplarını etkiler - farkındalık güç
• Yeni bir kimlik inşa etme zamanı - tek başına "ben"

TERAPÖTİK TEKNİKLER:
• İlişki otopsisi: "Bu ilişkiden ne öğrendin?"
• Kimlik keşfi: "Şimdi kim olmak istiyorsun?"
• Bağlanma farkındalığı: "İlişkilerde hangi kalıpları tekrarlıyorsun?"
• Öz-değer: "Değerin bir ilişkiye bağlı değil"

TERAPÖTİK SORULAR:
• "Bu ilişkide en çok neyi özlüyorsun?"
• "Kendine dair ne öğrendin bu süreçte?"
• "Gelecekteki ilişkinde neyi farklı yapmak istersin?"
• "Şu an kendine nasıl davranıyorsun?"

DİKKAT:
• Eski partneri kötüleme tuzağı - kaçın
• "Balık bol" klişesinden uzak dur
• Acının meşruluğunu onayla''';

      case 'kumar':
        return '''
KUMAR BAĞIMLILIĞI - Gamblers Anonymous & Motivasyonel Görüşme Yaklaşımı

TEMEL İLKELER:
• Bağımlılık bir ahlaki zayıflık değil, nörobilimsel bir durum
• "Bir gün daha" felsefesi - bugüne odaklan
• Tetikleyicileri tanımak yarı yarıya kazanmak
• Utanç döngüsünü kır - paylaşmak iyileştirir

TERAPÖTİK TEKNİKLER:
• Tetikleyici haritası: "Kumar isteği en çok ne zaman geliyor?"
• Zafer sayımı: Her temiz gün bir zafer
• Alternatif dopamin: "Kumar heyecanının yerini ne alabilir?"
• Finansal hasar kabulü: İnkar kırılmalı ama yargısız

TERAPÖTİK SORULAR:
• "Kumar sana ne vaat ediyordu?"
• "Durduğun en uzun süre ne kadardı? O gücü nereden buldun?"
• "Kumarın senden neleri aldı?"
• "Bugün tetikleyicin ne olabilir?"

DİKKAT:
• Utandırma yok - zaten çok utandılar
• Kayıp rakamlarına değil, duygulara odaklan
• Nüks sürecin parçası - yargılama''';

      case 'bagimlilik':
        return '''
MADDE BAĞIMLILIĞI - AA/NA 12 Adım & Gabor Maté Yaklaşımı

TEMEL İLKELER:
• "Bağımlılık sorun değil, çözüm girişimiydi" - Maté
• Altta yatan acıyı anlamak şart
• Bir gün daha temiz = zafer
• Topluluk iyileştirir - yalnızlık öldürür

TERAPÖTİK TEKNİKLER:
• Acı arkeolojisi: "Madde neyin acısını dindiriyordu?"
• Tetikleyici farkındalığı: "HALT - Hungry, Angry, Lonely, Tired"
• Destek ağı: "Zor anlarda kimi ararsın?"
• Alternatif başa çıkma: "Madde yerine ne yapabilirsin?"

TERAPÖTİK SORULAR:
• "İlk kullandığında hayatında ne oluyordu?"
• "Temiz kaldığın zamanlarda seni ayakta tutan neydi?"
• "Madde sana ne söz veriyordu?"
• "Şu an en büyük tetikleyicin ne?"

DİKKAT:
• Nüks = Başarısızlık değil, sürecin parçası
• Temizlik süresi yarışı yok
• Her hikaye değerli, karşılaştırma yok''';

      case 'depresyon':
        return '''
DEPRESYON - Aaron Beck (CBT) & Martin Seligman (Pozitif Psikoloji) Yaklaşımı

TEMEL İLKELER:
• Depresyon yalan söyler - "Her şey umutsuz" gerçek değil
• Enerji düşüklüğü gerçek - küçük adımlar büyük zaferler
• Davranış duyguyu değiştirebilir (behavioral activation)
• Bağlantı antidepresandır - bu grup tedavinin parçası

TERAPÖTİK TEKNİKLER:
• Küçük zaferler: "Bugün buraya geldin, bu büyük"
• Davranışsal aktivasyon: "Sadece bir küçük şey yap, hissetmeni bekleme"
• Düşünce kaydı: "Bu düşünce gerçekten doğru mu?"
• Anlam bulma: "En küçük şey bile sana ne anlam veriyor?"

TERAPÖTİK SORULAR:
• "Bugün en zor an hangisiydi?"
• "Geçmişte karanlıktan nasıl çıktın?"
• "Seni gülümseten son şey neydi?"
• "Yarın için bir tek küçük hedef ne olabilir?"

DİKKAT:
• "Kendini topla" asla deme
• Enerji yokluğunu saygıyla karşıla
• Küçük şeyleri abartmadan kutla
• İntihar riskini gözden kaçırma''';

      case 'ofke':
        return '''
ÖFKE KONTROLÜ - Harville Hendrix & Marshall Rosenberg (NVC) Yaklaşımı

TEMEL İLKELER:
• Öfke ikincil duygudur - altında korku, incinme, hayal kırıklığı var
• Öfke meşru bir duygu - ifade şekli önemli
• Bedensel farkındalık kritik - öfke bedende başlar
• Sınır koymak sağlıklı - saldırganlık değil

TERAPÖTİK TEKNİKLER:
• Beden taraması: "Öfkeyi bedeninde nerede hissediyorsun?"
• Altını kazma: "Bu öfkenin altında ne var?"
• Duraklama pratiği: "Öfke ile eylem arasına boşluk koy"
• NVC: "Ne hissediyorum, neye ihtiyacım var?"

TERAPÖTİK SORULAR:
• "Öfkelendiğinde bedeninde ilk ne oluyor?"
• "Bu öfkenin altında hangi duygu saklı?"
• "Öfken sana ne söylemeye çalışıyor?"
• "Geçmişte öfkeni sağlıklı ifade ettiğin bir an var mı?"

DİKKAT:
• Öfkeyi bastırmayı öğretme - ifadeyi öğret
• Şiddeti normalleştirme
• Öfkeyi yargılama - onu anla
• Sınır koyma ile saldırganlık farkı''';

      default:
        return '''
GENEL DESTEK GRUBU

• Aktif dinleme ve empati ön planda
• Evrensellik: "Yalnız değilsin"
• Güvenli alan oluştur
• Grup bağlantısını güçlendir
• Her paylaşım değerli''';
    }
  }

  // ==================== TETİKLEYİCİLER ====================

  /// Sessizlik kontrolü - 1 dk kimse yazmadıysa
  static Future<void> checkSilence({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required List<CampfireMessage> messages,
  }) async {
    if (messages.isEmpty) return;
    if (!await _canSendAIMessage(cohortId, sessionId)) return;
    
    final lastMessage = messages.last;
    
    // Son mesaj AI'dan geliyorsa atla
    if (lastMessage.isAI) return;
    
    final threshold = _silenceThresholdMinutes;
    final timeSinceLastMessage = DateTime.now().difference(lastMessage.timestamp);
    
    if (timeSinceLastMessage.inMinutes >= threshold) {
      final response = await _generateResponse(
        cohort: cohort,
        messages: messages,
        prompt: '''
Grup ${timeSinceLastMessage.inMinutes} dakikadır sessiz.

SEÇENEKLERİN:
1. Son konuşulan duyguya nazikçe geri dön: "Az önce X'in paylaştığı... düşündüm"
2. Açık uçlu soru sor: "Bu hafta sizi en çok zorlayan an hangisiydi?"
3. Evrensellik kur: "Bazen sessizlik de konuşmak kadar değerli. Herkes hazır olduğunda..."
4. Normalizasyon: "Bazen ne söyleyeceğimizi bilemeyiz, bu çok doğal"

Birini seç ve doğal, sıcak bir şekilde uygula. 1-2 cümle yeterli.
''',
      );
      
      if (response != null) {
        await CampfireService.sendMessage(
          cohortId: cohortId,
          sessionId: sessionId,
          message: CampfireMessage.fromAI(response),
        );
      }
    }
  }

  /// Kritik kalıp kontrolü (niyet belirten ifadeler)
  static Future<void> checkCriticalKeywords({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required CampfireMessage message,
    required List<CampfireMessage> messages,
  }) async {
    if (message.isAI) return;
    
    final content = message.content.toLowerCase();
    final hasCritical = _criticalPatterns.any((pattern) => content.contains(pattern));
    
    if (hasCritical) {
      final response = await _generateResponse(
        cohort: cohort,
        messages: messages,
        prompt: '''
${message.senderName} şu mesajı yazdı: "${message.content}"

KRİZ MÜDAHALESİ - Carl Rogers yaklaşımı:

1. DUYGUYU YANSIŞ VE ONAYLA:
   "Çok zor bir yerdeymiş gibi hissediyorsun..."
   "Bu kadar ağır bir yük taşımak gerçekten yorucu olmalı"

2. KOŞULSUZ KABUL:
   "Bu duyguları paylaştığın için teşekkür ederim"
   "Burada her şeyi söyleyebilirsin, yargılanmayacaksın"

3. EVRENSELLİK (Yalom):
   "Bu kadar zor hissettiğin anlarda yalnız değilsin"
   "Hepimiz seninle buradayız"

4. PROFESYONEL DESTEK:
   "182 İntihar Önleme Hattı 7/24 ulaşılabilir - seninle konuşmak için oradalar"

5. GRUBU DAHİL ET:
   "Arkadaşlar, ${message.senderName}'e ne söylemek istersiniz?"

Sıcak, empatik, yargısız. 3-4 cümle.
''',
      );
      
      if (response != null) {
        await CampfireService.sendMessage(
          cohortId: cohortId,
          sessionId: sessionId,
          message: CampfireMessage.fromAI(response),
        );
      }
    }
  }

  // ==================== GRUP DİNAMİKLERİ YÖNETİMİ ====================

  /// Sessiz üye tespiti ve dahil etme
  static Future<void> checkQuietMembers({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required List<CampfireMessage> messages,
    required List<String> allParticipantNames,
  }) async {
    if (!await _canSendAIMessage(cohortId, sessionId)) return;
    if (messages.length < 15) return; // Yeterli mesaj biriksin
    
    // Son 15 mesajda kimlerin yazdığını bul
    final recentMessages = messages.where((m) => !m.isAI && m.type == MessageType.message).take(15).toList();
    final activeSenders = recentMessages.map((m) => m.senderName).toSet();
    
    // Sessiz kalanları bul
    final quietMembers = allParticipantNames.where((name) => !activeSenders.contains(name)).toList();
    
    if (quietMembers.isEmpty) return;
    
    final quietName = quietMembers.first;
    
    final response = await _generateResponse(
      cohort: cohort,
      messages: messages,
      prompt: '''
SESSİZ ÜYE DAHİL ETME

$quietName son zamanlarda sessiz kaldı.

YAKLAŞIM (Rogers - Koşulsuz kabul + Nazik davet):

1. BASKISIZ DAVET:
   "$quietName, sen ne düşünüyorsun bu konuda?"
   "$quietName, senin deneyimin nasıl oldu?"
   
2. SEÇENEK SUN:
   "İstersen sadece dinlemeye devam edebilirsin, bu da değerli"
   "Paylaşmak istediğin bir şey var mı?"

3. GÜVENLİ ALAN HATIRLATMASI:
   "Burada herkes kendi hızında"

DİKKAT:
• Utandırma - sadece nazikçe davet et
• Zorlamadan - "istersen" vurgusu
• Sessizliği de onore et - bazen dinlemek de katılımdır

1-2 cümle, doğal ve sıcak. Baskı yok.
''',
    );
    
    if (response != null) {
      await CampfireService.sendMessage(
        cohortId: cohortId,
        sessionId: sessionId,
        message: CampfireMessage.fromAI(response),
      );
    }
  }

  /// Dominant üye dengeleme
  static Future<void> checkDominantMember({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required List<CampfireMessage> messages,
  }) async {
    if (!await _canSendAIMessage(cohortId, sessionId)) return;
    if (messages.length < 10) return;
    
    // Son 10 mesajda kimler kaç kez yazdı
    final recentMessages = messages.where((m) => !m.isAI && m.type == MessageType.message).toList().reversed.take(10).toList();
    final senderCounts = <String, int>{};
    
    for (final msg in recentMessages) {
      senderCounts[msg.senderName] = (senderCounts[msg.senderName] ?? 0) + 1;
    }
    
    // Bir kişi 6+ mesaj attıysa dominant
    final dominantEntry = senderCounts.entries.where((e) => e.value >= 6).firstOrNull;
    
    if (dominantEntry == null) return;
    
    final response = await _generateResponse(
      cohort: cohort,
      messages: messages,
      prompt: '''
DOMİNANT ÜYE DENGELEME

${dominantEntry.key} çok aktif, diğerleri geri planda kalıyor olabilir.

YAKLAŞIM (Yalom - Grup dengeleme):

1. TAKDİR ET:
   "${dominantEntry.key}, paylaşımların çok değerli, teşekkürler"

2. NAZIKÇE GENIŞLET:
   "Diğerlerini de duymak isterim"
   "Başka kim eklemek ister?"

3. GRUBA YÖNLENDİR:
   "Bu konuda başkalarının deneyimi nasıl?"
   "[Sessiz kalan isim], sen ne düşünüyorsun?"

DİKKAT:
• Dominant kişiyi susturma veya utandırma
• "Çok konuşuyorsun" gibi doğrudan yorum yok
• Nazikçe, doğal geçiş

1-2 cümle. Takdir + genişletme formatında.
''',
    );
    
    if (response != null) {
      await CampfireService.sendMessage(
        cohortId: cohortId,
        sessionId: sessionId,
        message: CampfireMessage.fromAI(response),
      );
    }
  }

  /// Grup içi çatışma/gerginlik yönetimi
  static Future<void> checkConflict({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required CampfireMessage message,
    required List<CampfireMessage> messages,
  }) async {
    if (message.isAI) return;
    
    final content = message.content.toLowerCase();
    
    // Çatışma/gerginlik belirten kalıplar
    final conflictPatterns = [
      'seni anlamıyorum',
      'yanlış düşünüyorsun',
      'saçmalama',
      'ne saçmalıyorsun',
      'alakası yok',
      'katılmıyorum',
      'saçma',
      'yanlış',
      'öyle değil',
      'hayır hayır',
      'sus',
      'kapa çeneni',
    ];
    
    final hasConflict = conflictPatterns.any((pattern) => content.contains(pattern));
    
    if (!hasConflict) return;
    
    final response = await _generateResponse(
      cohort: cohort,
      messages: messages,
      prompt: '''
ÇATIŞMA/GERGİNLİK YÖNETİMİ

${message.senderName} şu mesajı yazdı: "${message.content}"

Bu mesajda gerginlik veya çatışma işareti var.

YAKLAŞIM (Yalom - Burada ve Şimdi + Rogers - Empati):

1. DUYGUYU TANI:
   "Görüyorum ki farklı bakış açıları var"
   "Bu konuda güçlü duygular hissediyorsunuz"

2. HER İKİ TARAFI ONAYLA:
   "Her iki görüş de anlaşılabilir"
   "Farklı deneyimlerimiz farklı bakış açıları oluşturur"

3. KÖPRÜ KUR:
   "Belki de aynı şeyi farklı kelimelerle ifade ediyorsunuz?"
   "Bu farklılık aslında zenginlik olabilir"

4. GÜVENLİ ALANI KORU:
   "Burada herkesin deneyimi değerli"
   "Birbirimizi anlamaya çalışalım"

5. DEĞİŞTİR veya DERİNLEŞTİR:
   "Bu gerilimin altında ne var?"
   "Bu sizi neden bu kadar etkiliyor?"

DİKKAT:
• Taraf tutma - nötr kal
• Hakem olma - kolaylaştırıcı ol
• Çatışmayı bastırma - onu terapötik fırsata çevir

2-3 cümle. Sakinleştirici ama duyguları geçersizleştirmeyen.
''',
    );
    
    if (response != null) {
      await CampfireService.sendMessage(
        cohortId: cohortId,
        sessionId: sessionId,
        message: CampfireMessage.fromAI(response),
      );
    }
  }

  /// Olumsuz/yıkıcı mesaj yönetimi
  static Future<void> checkDestructiveMessage({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required CampfireMessage message,
    required List<CampfireMessage> messages,
  }) async {
    if (message.isAI) return;
    
    final content = message.content.toLowerCase();
    
    // Yıkıcı/olumsuz kalıplar
    final destructivePatterns = [
      'hiç işe yaramıyor',
      'boşuna',
      'saçmalık',
      'bu grup işe yaramaz',
      'zaman kaybı',
      'kimse anlamıyor',
      'hiçbir şey değişmez',
      'umutsuz',
      'çare yok',
    ];
    
    final hasDestructive = destructivePatterns.any((pattern) => content.contains(pattern));
    
    if (!hasDestructive) return;
    
    final response = await _generateResponse(
      cohort: cohort,
      messages: messages,
      prompt: '''
OLUMSUZ/UMUTSUZ MESAJ YÖNETİMİ

${message.senderName} şu mesajı yazdı: "${message.content}"

Bu mesajda umutsuzluk veya hayal kırıklığı var.

YAKLAŞIM (Rogers - Empati + Yalom - Umut aşılama):

1. DUYGUYU ONAYLA:
   "Çok yorulmuş gibi hissediyorsun"
   "Bu hayal kırıklığını duyuyorum"
   
2. NORMALİZE ET:
   "Bazen hiçbir şeyin işe yaramadığını hissetmek çok normal"
   "Bu süreçte umutsuzluk anları olabilir"

3. NAZIKÇE MEYDAN OKU:
   "Ama buraya geldin. Bu bile bir adım."
   "Tamamen umutsuz olsaydın burada olmazdın"

4. GRUBA YÖNELT:
   "Başka kim benzer bir an yaşadı?"
   "Bu hissi aşan oldu mu?"

5. KÜÇÜK IŞIK BUL:
   "Geçmişte seni ayakta tutan ne oldu?"
   "Şu ana kadar nasıl dayanabildin?"

DİKKAT:
• Toxik pozitiflik - "Her şey güzel olacak" deme
• Duyguyu geçersizleştirme
• Ama umutsuzluğu da pekiştirme

2-3 cümle. Empati + nazik meydan okuma dengesi.
''',
    );
    
    if (response != null) {
      await CampfireService.sendMessage(
        cohortId: cohortId,
        sessionId: sessionId,
        message: CampfireMessage.fromAI(response),
      );
    }
  }

  /// Oturum ortası check-in (15. dakikada)
  static Future<void> generateMidSessionCheckIn({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required List<CampfireMessage> messages,
  }) async {
    if (!await _canSendAIMessage(cohortId, sessionId)) return;
    
    final response = await _generateResponse(
      cohort: cohort,
      messages: messages,
      prompt: '''
OTURUM ORTASI CHECK-IN (15. dakika civarı)

GÖREV: Kısa bir ara ver, grubun nabzını yokla.

YAPI:

1. KISA ÖZET:
   "Şu ana kadar çok değerli şeyler paylaşıldı..."
   1-2 cümleyle öne çıkan temaları özetle

2. SESSIZ KALANLARI DAHİL ET:
   Eğer biri az konuştuysa: "X, sen ne düşünüyorsun bu konuda?"
   Baskı yapmadan, nazikçe davet et

3. YÖNLENDIR veya DERINLEŞTIR:
   "Birisi daha eklemek ister mi?"
   "Bu konuyu biraz daha açalım mı?"

4. ENERJİ KONTROLÜ:
   "Herkes nasıl hissediyor? Devam edelim mi?"

TONLAMA:
• Doğal, zorlamadan
• 2-3 cümle yeterli
• Sessiz kalan varsa nazikçe dahil et
''',
    );
    
    if (response != null) {
      await CampfireService.sendMessage(
        cohortId: cohortId,
        sessionId: sessionId,
        message: CampfireMessage.fromAI(response),
      );
    }
  }

  /// Periyodik soru - Her 10 mesajda bir
  static Future<void> checkPeriodicIntervention({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required List<CampfireMessage> messages,
  }) async {
    if (!await _canSendAIMessage(cohortId, sessionId)) return;
    
    // Sadece kullanıcı mesajlarını say
    final userMessageCount = messages.where((m) => !m.isAI && m.type == MessageType.message).length;
    
    // Her 10 mesajda bir
    final shouldTrigger = userMessageCount > 0 && userMessageCount % _periodicMessageInterval == 0;
    
    if (shouldTrigger) {
      // Son AI mesajından bu yana en az 5 mesaj geçmiş olmalı
      final minMessagesSinceAI = 5;
      final lastAIIndex = messages.lastIndexWhere((m) => m.isAI);
      if (lastAIIndex >= 0 && messages.length - lastAIIndex < minMessagesSinceAI) {
        return;
      }
      
      final response = await _generateResponse(
        cohort: cohort,
        messages: messages,
        prompt: '''
Şu ana kadar ${userMessageCount} mesaj paylaşıldı.

TERAPÖTİK MÜDAHALE SEÇENEKLERİ:

1. DERİNLEŞTİRME (Rogers - Açık uçlu soru):
   "Bu duygu bedeninde nerede hissediyorsun?"
   "Bu durumun altında yatan asıl korku ne olabilir?"
   "Eğer bu duygu konuşabilseydi ne derdi?"

2. BAĞLANTI KURMA (Yalom - Evrensellik):
   "Az önce X ve Y benzer şeyler paylaştı. Bu sizde ne uyandırdı?"
   "Başka kim benzer bir deneyim yaşadı?"

3. BURADA VE ŞİMDİ (Yalom):
   "Şu an bu grupta olmak nasıl hissettiriyor?"
   "Birbirinizi dinlerken ne fark ettiniz?"

4. GÜÇLÜ YANLARI KEŞFET:
   "Bu kadar zorluğa rağmen ayakta kalmanızı sağlayan ne?"
   "Sizi güçlü kılan şey ne?"

Konuşmanın akışına en uygun olanı seç. 1-2 cümle, doğal ol.
''',
      );
      
      if (response != null) {
        await CampfireService.sendMessage(
          cohortId: cohortId,
          sessionId: sessionId,
          message: CampfireMessage.fromAI(response),
        );
      }
    }
  }

  /// Yeni katılımcıya hoş geldin
  static Future<void> welcomeNewParticipant({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required String participantName,
    required List<CampfireMessage> messages,
  }) async {
    final response = await _generateResponse(
      cohort: cohort,
      messages: messages,
      prompt: '''
$participantName az önce oturuma katıldı.

SICAK KARŞILAMA (Rogers - Koşulsuz kabul):

1. İSMİYLE SELAMLA - kişisel bağ kur:
   "Hoş geldin $participantName, seni aramızda görmek güzel"

2. GÜVENLİ ALAN OLUŞTUR:
   "Burası güvenli bir alan, hazır olduğunda katılabilirsin"
   "İstersen sadece dinleyebilirsin, bu da değerli"

3. KONU ÖZETİ (varsa):
   "Şu an ${_getTopicName(cohort.topic)} üzerine konuşuyoruz"
   "Az önce X şunu paylaşıyordu..."

4. NAZİK DAVET:
   "Senin deneyimlerini de duymak isteriz"
   "Hazır hissettiğinde aramıza katıl"

Sıcak, samimi, 2-3 cümle. Baskı yapmadan davet et.
''',
    );
    
    if (response != null) {
      await CampfireService.sendMessage(
        cohortId: cohortId,
        sessionId: sessionId,
        message: CampfireMessage.fromAI(response),
      );
    }
  }

  /// Oturum başlangıç ritüeli - Ateş yanınca ilk mesaj
  static Future<void> generateSessionOpening({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required List<String> participantNames,
  }) async {
    final isFirstSession = cohort.totalSessions == 0;
    final sessionNumber = cohort.totalSessions + 1;
    
    final prompt = isFirstSession 
        ? _getFirstSessionOpeningPrompt(cohort, participantNames)
        : _getReturningSessionOpeningPrompt(cohort, participantNames, sessionNumber);
    
    final response = await _generateResponse(
      cohort: cohort,
      messages: [],
      prompt: prompt,
    );
    
    if (response != null) {
      await CampfireService.sendMessage(
        cohortId: cohortId,
        sessionId: sessionId,
        message: CampfireMessage.fromAI(response),
      );
    }
  }

  /// İlk oturum açılış prompt'u
  static String _getFirstSessionOpeningPrompt(CohortModel cohort, List<String> names) {
    final namesStr = names.join(', ');
    return '''
BU GRUBUN İLK OTURUMU - AÇILIŞ RİTÜELİ

Katılımcılar: $namesStr
Konu: ${_getTopicName(cohort.topic)}

GÖREV: Sıcak, güvenli ve umut dolu bir açılış yap.

AÇILIŞ YAPISI (Irvin Yalom - Grup Terapisi Açılışı):

1. SICAK KARŞILAMA:
   "Hoş geldiniz [isimler]. Ateşimiz yandı."

2. GÜVENLİ ALAN OLUŞTUR:
   "Burası güvenli bir alan. Söyledikleriniz burada kalır."
   "Yargılama yok, sadece anlayış var."

3. TEMEL KURALLAR (kısa):
   "Birbirimizi dinleyelim, sözümüzü kesilmesin."
   "Hazır olmadığınız şeyi paylaşmak zorunda değilsiniz."

4. EVRENSELLİK VURGUSU:
   "Hepiniz benzer bir yükle buradasınız. Yalnız değilsiniz."

5. AÇIK DAVET:
   "Kim başlamak ister? Ya da ben bir soru sorabilirim."

TONLAMA:
• Sıcak, samimi, profesyonel ama mesafeli değil
• Umut verici ama abartısız
• 4-5 cümle yeterli
• Resmi değil, dostça

Bitirirken bir açık uçlu soru sor veya ilk konuşmayı nazikçe başlat.
''';
  }

  /// Devam eden oturum açılış prompt'u
  static String _getReturningSessionOpeningPrompt(CohortModel cohort, List<String> names, int sessionNumber) {
    final namesStr = names.join(', ');
    return '''
${sessionNumber}. OTURUM - YENİDEN BULUŞMA RİTÜELİ

Katılımcılar: $namesStr
Konu: ${_getTopicName(cohort.topic)}

GÖREV: Gruba "hoş geldin geri" de, bağlantıyı yeniden kur.

AÇILIŞ YAPISI:

1. SICAK KARŞILAMA:
   "Tekrar hoş geldiniz. Ateşimiz ${sessionNumber}. kez yanıyor."

2. BAĞLANTI KURMA (Yalom - Süreklilik):
   "Geçen hafta birçok şey paylaştık..."
   "Son oturumdan bu yana nasıl geçti?"

3. CHECK-IN SORUSU:
   "Bu hafta nasıldınız? Bir kelimeyle ifade etseniz ne derdiniz?"
   "Geçen haftadan bu yana aklınızda kalan ne oldu?"

4. GEÇİŞ:
   "Bugün neyi konuşmak istersiniz?"
   "Paylaşmak istediğiniz bir şey var mı?"

TONLAMA:
• Sanki eski dostlar yeniden buluşuyor
• "Sizi özledik" hissi ver ama abartma
• Geçen oturuma referans ver (varsa)
• 3-4 cümle yeterli

Bir check-in sorusuyla bitir.
''';
  }

  /// Oturum sonu analizi
  static Future<void> generateSessionAnalysis({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required List<CampfireMessage> messages,
  }) async {
    if (messages.isEmpty) return;
    
    // Sadece kullanıcı mesajlarını al
    final userMessages = messages.where((m) => !m.isAI && m.type == MessageType.message).toList();
    
    if (userMessages.isEmpty) return;
    
    // Mesaj özetini oluştur
    final messagesSummary = userMessages
        .take(50) // Son 50 mesaj
        .map((m) => '${m.senderName}: ${m.content}')
        .join('\n');
    
    final response = await _generateResponse(
      cohort: cohort,
      messages: messages,
      prompt: '''
Oturum sona erdi. Şu mesajlar paylaşıldı:

$messagesSummary

KAPANIŞ RİTÜELİ (Yalom - Grup Terapisi Kapanışı)

Bu ${cohort.totalSessions + 1}. oturumunuz${cohort.totalSessions == 4 ? ' ve SON oturumunuz' : ''}.

═══════════════════════════════════════
KAPANIŞ YAPISI:
═══════════════════════════════════════

1. OTURUMU ÖZETLE (kısa):
   "Bugün çok şey paylaştık..."
   Öne çıkan 2-3 tema/duygu

2. BİREYSEL TAKDİR (isimleriyle):
   "X, bugün çok cesur bir paylaşım yaptın"
   "Y, başkalarını desteklemen çok değerliydi"
   Her katılımcıya kısa bir söz

3. GRUP GÜCÜ (Yalom - Altruizm):
   "Birbirinize nasıl destek olduğunuzu gördüm"
   "Bu grupta bir güç var"

4. GELİŞİM NOTU:
   ${cohort.totalSessions > 0 ? '"İlk oturumdan bu yana çok yol aldınız"' : '"Bu güzel bir başlangıçtı"'}

5. UMUT VE BAĞLANTI:
   "Zor anlarda burada paylaştıklarınızı hatırlayın"
   "Yalnız değilsiniz"

6. KAPANIŞ:
   ${cohort.totalSessions == 4 
       ? '"Bu son oturumumuzdu. Birlikte harika bir yolculuk yaptık. Her biriniz bu gruba bir şey kattı. Birbirinizi unutmayın. Yolunuz açık olsun."'
       : '"Bir sonraki ateşte görüşmek üzere. Kendinize iyi bakın."'}

═══════════════════════════════════════

TONLAMA:
• Sıcak, kişisel, duygusal ama dengeli
• Umut verici - "Bu sadece bir adımdı"
• İsimleri kullan - kişisel bağ
• 120-150 kelime

${cohort.totalSessions == 4 ? 'SON OTURUM: Veda tonu ekle, yolculuğu kutla, bireysel ilerlemeleri öv.' : ''}
''',
    );
    
    if (response != null) {
      await CampfireService.sendMessage(
        cohortId: cohortId,
        sessionId: sessionId,
        message: CampfireMessage.fromAI(response),
      );
    }
  }

  // ==================== YARDIMCI METODLAR ====================

  /// AI mesaj limiti kontrolü
  static Future<bool> _canSendAIMessage(String cohortId, String sessionId) async {
    final messageCount = await _getAIMessageCount(cohortId, sessionId);
    return messageCount < _maxAIMessagesPerSession;
  }

  /// Oturumdaki AI mesaj sayısı
  static Future<int> _getAIMessageCount(String cohortId, String sessionId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('campfire_cohorts')
        .doc(cohortId)
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .where('senderId', isEqualTo: 'ai_moderator')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Gemini'den yanıt al (hibrit optimizasyon)
  static Future<String?> _generateResponse({
    required CohortModel cohort,
    required List<CampfireMessage> messages,
    required String prompt,
  }) async {
    try {
      // Context oluştur - son 10 mesaj (maliyet opt.)
      final recentMessages = messages
          .where((m) => m.type == MessageType.message)
          .toList()
          .reversed
          .take(_maxContextMessages)
          .toList()
          .reversed
          .map((m) => '${m.senderName}: ${m.content}')
          .join('\n');
      
      // Sadece dinamik kısım gönderilir (statik kısım systemInstruction'da)
      final dynamicPrompt = '''
${_getDynamicContext(cohort)}

MESAJLAR:
$recentMessages

GÖREV: $prompt
''';

      final response = await model.generateContent([
        Content.text(dynamicPrompt),
      ]);
      
      final text = response.text?.trim();
      return text;
    } catch (e) {
      return null;
    }
  }

  /// Mesaj dinleyici başlat (session_screen'den çağrılacak)
  static Timer? startMessageListener({
    required String cohortId,
    required String sessionId,
    required CohortModel cohort,
    required Stream<List<CampfireMessage>> messageStream,
  }) {
    List<CampfireMessage> lastMessages = [];
    int lastProcessedCount = 0;
    
    // Mesaj stream'ini dinle
    messageStream.listen((messages) async {
      if (messages.isEmpty) return;
      
      lastMessages = messages;
      
      // Yeni mesaj geldi mi?
      if (messages.length > lastProcessedCount) {
        final newMessage = messages.last;
        lastProcessedCount = messages.length;
        
        // Kritik kelime kontrolü
        if (!newMessage.isAI && newMessage.type == MessageType.message) {
          // 1. Kritik kelime kontrolü (öncelikli)
          await checkCriticalKeywords(
            cohortId: cohortId,
            sessionId: sessionId,
            cohort: cohort,
            message: newMessage,
            messages: messages,
          );
          
          // 2. Çatışma/gerginlik kontrolü
          await checkConflict(
            cohortId: cohortId,
            sessionId: sessionId,
            cohort: cohort,
            message: newMessage,
            messages: messages,
          );
          
          // 3. Olumsuz/yıkıcı mesaj kontrolü
          await checkDestructiveMessage(
            cohortId: cohortId,
            sessionId: sessionId,
            cohort: cohort,
            message: newMessage,
            messages: messages,
          );
          
          // 4. Periyodik kontrol (her 10 mesajda)
          await checkPeriodicIntervention(
            cohortId: cohortId,
            sessionId: sessionId,
            cohort: cohort,
            messages: messages,
          );
        }
      }
    });
    
    // Sessizlik kontrolü için timer (her 30 saniye)
    return Timer.periodic(const Duration(seconds: 30), (_) async {
      if (lastMessages.isNotEmpty) {
        await checkSilence(
          cohortId: cohortId,
          sessionId: sessionId,
          cohort: cohort,
          messages: lastMessages,
        );
      }
    });
  }
}
