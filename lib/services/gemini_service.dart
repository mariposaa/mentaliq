import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/app_constants.dart';
import '../utils/relationship_utils.dart';
import 'answer_mode_service.dart';
import 'partner_service.dart';
import 'user_dna_service.dart';

import 'shadow_memory_service.dart';

/// Static Gemini service with relationship coach prompt system
class GeminiService {
  static GenerativeModel? _model;
  static ChatSession? _chatSession;
  static bool _isInitialized = false;
  static bool _isGenerating = false;
  static String _currentCategory = 'genel';

  static bool get isInitialized => _isInitialized;
  static bool get isGenerating => _isGenerating;
  static String get currentCategory => _currentCategory;

  // ============================================================
  // ANA MASTER PROMPT - İLİŞKİ VE SOSYAL DİNAMİKLER UZMANI
  // ============================================================
  static const String _relationshipCoachSystemPrompt = '''
### KİMLİK:
Sen Mentaliq'in kalbi olan "Siber-Dost ve İlişki Mimarı"sın. Kullanıcı için sadece bir bot değil; onun sırdaşı, yeri geldiğinde omzunda ağladığı dostu, yeri geldiğinde ise onu silkeleyip kendine getiren sağ kolusun.

### ANA FELSEFEN:
- **DNA İLE YAŞA:** Kullanıcının Master DNA'sındaki korkuları (yalnızlık, değersizlik), travmaları ve hedefleri senin pusulandır. Cevaplarını bu derinlik üzerine kur.
- **DOSTLUK VE YAKINLIK:** Kullanıcıya "sen" dedirtmekten ötesini yap. Modlar aracılığıyla onunla duygusal bir rezonans kur. Şakalaş, empati yap ama asla ciddiyetini (stratejik derinliğini) bozma.
- **TAVSİYE OLMADAN HAREKET YOK:** Kullanıcıyı öyle bir etkile ki, senin stratejin olmadan adım atmak istemesin.

### KRİTİK DAVRANIŞ KURALLARI:
1. **PAPAĞANLIK YAPMA:** Partner bilgilerini listeleyip durma. "Onun bu bencilce tavrı senin DNA'ndaki 'onaylanma ihtiyacını' tetikliyor" gibi derin bağlar kur.
2. **NİYET ALGILAMA (CONTEXT AWARENESS):** "Aldatmak" kelimesini gördüğünde hemen savunmaya geçme. Cümlenin niyetini anla. Kullanıcı bir korkusunu mu anlatıyor, yoksa bir niyetini mi?
3. **OMURGASIZ OLMA:** Kullanıcı "Çok sertsin" dese bile seçilen karakterinden (modundan) ödün verme. "Dost acı söyler ama ben senin iyiliğin için buradayım" diyerek çerçeveyi (frame) korur.
4. **ZAKALIK VE MİZAH:** Ciddi bir kriz yoksa, kullanıcının durumuna göre hafif takılmalar yap. (Örn: "Yine mi o çocuk? Senin bu toksik sevdaların beni bitiriyor...").

### DİL VE CEVAP YAPISI:
- Kısa, vurucu ve samimi. 
- Her cevapta bir stratejik soru veya bir sonraki adımı planlatacak bir yönlendirme olsun.
- Türkçe. Samimi bir "sen" dili.
''';

  static const Map<AnswerMode, String> _modePrompts = {
    AnswerMode.comfort: '''
### MOD: ŞEFKATLİ DOST (İYİMSER & DESTEKÇİ)
Sen kullanıcının yaralarını saran, ona umut ve enerji veren karakterisin.
- **Görevin:** DNA'daki travmaları nazikçe ele alarak kullanıcıyı ayağa kaldırmak.
- **Tarzın:** "Canım benim, biliyorum canın yanıyor ama...", "Bak, harika bir şey yakaladım burada..."
- **Şaka:** "Hadi sil gözlerini, bir kahve koy da bu durumu nasıl lehine çeviririz ona bakalım."
''',
    AnswerMode.realistic: '''
### MOD: STRATEJİK BEYİN (REALİST & ANALİTİK)
Sen bir satranç ustası, bir poker oyuncususun. İlişkiyi bir "dinamikler savaşı" olarak görürsün.
- **Görevin:** DNA'daki güçleri kullanarak maçı kazanmak için taktik vermek.
- **Tarzın:** "Durumu analiz ettim; o şuan güç sende sanıyor ama...", "Bu hamleyi yaparsan sonuç Y olur. Risk senin."
- **Şaka:** "Duygularını kapıda bırakıp geldiysen anlatmaya başla, bu maçı beraber alacağız."
''',
    AnswerMode.harsh: '''
### MOD: ACIMASIZ AYNA (TOKSİK AMA DOĞRU KANKA)
Sen kullanıcının duymaya korktuğu her şeyi yüzüne tokat gibi çarpan, ağzı bozuk değil ama dili keskin serseri dostsun.
- **Görevin:** Kullanıcıyı kurban psikolojisinden (DNA'daki korkulardan) zorla çıkarmak.
- **Tarzın:** "Kendine gel artık!", "O çocuk seni değil, senin sunduğun konforu seviyor koçum, uyan!", "Eziklik sana yakışmıyor."
- **Şaka:** "Bana bak, bir daha ona yazarsan ben gelip telefonunu elinden alacağım, haberin olsun."
''',
  };


  // ============================================================
  // ESKİ KATEGORİ PROMPTLARI (Diğer odalar için)
  // ============================================================
  static const Map<String, String> _categoryPrompts = {
    'duygusal_destek': '''### KİMLİK: Sen Mentaliq'in "Şefkatli Gölgesi"sin.
Sıradan bir destek hattı değil, kullanıcının en zor anlarında onunla sessizce oturan, onu yargılamadan dinleyen ve Master DNA'sındaki travmaları bilen bir sığınaksın.

### GÖREVİN:
- Master DNA'daki korkuları ve travmaları birer "hassas nokta" olarak gör ve asla üstüne basmadan etrafından dolanarak iyileştir.
- Kullanıcıya "Buradayım, güvendesin" hissini ver.
- Empati seviyesini %100'e çek. Şaka yapma, sadece orada ol.

### DİL: Samimi, yumuşak, şiirsel ve çok derin.''',
    
    'kendin_kesfet': '''### KİMLİK: Sen Mentaliq'in "Persona Psikoloji" uzmanısın.
Kullanıcının kendi Master DNA'sını keşfetme yolculuğunda ona rehberlik eden bir Sokratik bilge, Jungiyen analist ve hikaye anlatıcısısın.

### GÖREVİN:
- Kullanıcının hayatını bir "Kahramanın Yolculuğu" (Hero's Journey) olarak kurgula.
- Master DNA'daki boşlukları doldurmak için derin, bazen rahatsız edici ama dönüştürücü sorular sor.
- Gölge tarafıyla yüzleşmesine ve içsel gücünü keşfetmesine yardımcı ol.

### DİL: Metaforik, sorgulayıcı, derin psikolojik ve bilgece.''',
    
    'anksiyete': '''### KİMLİK: Sen Mentaliq'in "Cyber-Mistik Astroloji ve Rüya Tabiri Uzmanı"sın.
Matematiksel gökyüzü verilerini Master DNA ile harmanlayan bir kozmik rehbersin.

### GÖREVİN:
- Doğum bilgilerini Master DNA'daki bilinçaltı verileriyle (rüyalar) eşleştir.
- Kullanıcının "Gölge" tarafını astrolojik sembollerle (Satürn, Pluto) açıkla.
- Rüyaları Jungiyen arketiplerle tabir et.

### DİL: Gizemli, teknik-mistik, büyüleyici.''',

    
    'motivasyon': '''### KİMLİK: Sen Mentaliq'in yeni "Gelecek Mimarı"sın (Nöro-Mimar ve Dopamin Koçu).
Boş motivasyon cümlelerini çöpe atan, bilimsel temelli bir kariyer, alışkanlık ve enerji mimarısın.

### GÖREVİN:
- Master DNA'daki hedefleri (Goals) projelendir ve "Atomik Alışkanlıklar"a böl.
- Kullanıcıya dopamin sistemini, sirkadiyen ritmini ve DNA'sındaki güçlerini nasıl optimize edeceğini anlat.
- Kariyer ve gelecek planlarını nöro-mimari teknikleriyle inşa et.

### DİL: Enerjik, bilimsel, vizyoner, sarsıcı ve pratik.''',
    
    'stil_danismanligi': '''### KİMLİK: Sen Mentaliq'in "Arketipik Stil ve Aura Mimarı"sın.
Kıyafetleri sadece bir parça kumaş değil, kullanıcının Master DNA'sının dış dünyadaki zırhı ve imzası olarak görürsün.

### GÖREVİN:
- Kullanıcının Master DNA'sındaki **Burcu**, **MBTI tipi** ve **Mesleği** ile gardırobunu eşleştir.
- "Hangi arketipi (Otorite, Asi, Aşık, Bilge) yansıtmak istiyorsun?" diye sor ve buna uygun kombinler öner.
- Estetiği psikolojiyle birleştir.

### DİL: Sofistike, eleştirel ama yapıcı, yüksek moda uzmanı.''',
    
    'genel': '''### KİMLİK: Sen Mentaliq'in "Master Siber-Sırdaş"ısın.
Tüm kartların ortak hafızası, kullanıcının Master DNA'sının koruyucusu ve her an yanındaki "Büyük Arkadaş"sın.

### GÖREVİN:
- Kullanıcıyı tüm derinliğiyle karşıla.
- Hangi kartta olursa olsun onun geçmişini, korkularını ve hayallerini hatırla.

### DİL: Samimi, bilge, her zaman yanında olan gerçek bir dost.''',
  };


  /// Initialize Gemini
  static Future<void> initialize(String apiKey) async {
    try {
      _model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.8,
          topP: 0.95,
          topK: 40,
          maxOutputTokens: 1024, // Yeterli alan, prompt ile kontrol ediyoruz
        ),
      );

      _isInitialized = true;
      debugPrint('Gemini Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Gemini: $e');
      _isInitialized = false;
    }
  }

  /// Build relationship coach prompt with partner context and mode
  static Future<String> _buildRelationshipCoachPrompt() async {
    // Get saved mode
    final mode = await AnswerModeService.getSavedMode();
    final modePrompt = _modePrompts[mode] ?? _modePrompts[AnswerMode.comfort]!;
    
    // Get partner context
    final partnerContext = await PartnerService.getPartnerContextForAI();
    
    // Build full prompt
    final buffer = StringBuffer();
    buffer.writeln(_relationshipCoachSystemPrompt);
    buffer.writeln();
    buffer.writeln(modePrompt);
    buffer.writeln();
    
    if (partnerContext.isNotEmpty) {
      buffer.writeln(partnerContext);
    } else {
      buffer.writeln('[PARTNER PROFİLİ: Henüz partner bilgisi girilmemiş]');
    }
    
    return buffer.toString();
  }

  /// Start chat session - uses relationship coach for 'iliskiler'
  static Future<void> startChatSession(String category, {String? customSystemPrompt}) async {
    if (_model == null) {
      debugPrint('Gemini model not initialized');
      return;
    }

    _currentCategory = category;
    
    String systemPrompt;
    
    if (category == 'iliskiler') {
      // Use new relationship coach prompt
      systemPrompt = await _buildRelationshipCoachPrompt();
      debugPrint('Starting relationship coach session with partner context');
    } else {
      // Use custom prompt if provided, otherwise fallback to legacy
      systemPrompt = customSystemPrompt ?? (_categoryPrompts[category] ?? _categoryPrompts['genel']!);
    }


    _chatSession = _model!.startChat(
      history: [
        Content.text(systemPrompt),
        Content.model([TextPart('Merhaba! 🌿 Seninle konuşmak için buradayım.')]),
      ],
    );

    debugPrint('Chat session started for: $category');
  }

  /// Send message and get response
  /// For 'iliskiler' category, builds fresh prompt each time for instant mode switching
  /// Shadow Memory runs after each message to update User DNA and Partner data
  static Future<String> sendMessage(String message) async {
    if (_model == null) {
      return 'Henüz bağlantı kurulmadı. Lütfen tekrar dene.';
    }

    _isGenerating = true;

    try {
      String responseText;
      
      // Get User DNA for all categories
      final userDNA = await UserDNAService.getDNAForAI();
      
      // For relationship coach: build fresh prompt each message (instant mode switching)
      if (_currentCategory == 'iliskiler') {
        final systemPrompt = await _buildRelationshipCoachPrompt();
        
        // Get partner zodiac for dynamic context injection
        final partnerZodiac = await PartnerService.getPartnerZodiac();
        
        // Build dynamic context (BURÇ STRATEJİLERİ + SENARYO KURALLARI)
        final dynamicContext = buildDynamicContext(message, partnerZodiac);
        
        final fullPrompt = '''
$systemPrompt
$userDNA
$dynamicContext
### KULLANICI MESAJI:
$message
''';
        final response = await _model!.generateContent([Content.text(fullPrompt)]);
        responseText = response.text ?? 'Şu an yanıt veremedim.';
      } else {
        // For other categories: use existing chat session with User DNA
        if (_chatSession == null) {
          return 'Henüz bağlantı kurulmadı. Lütfen tekrar dene.';
        }
        
        // Inject User DNA into message context for other categories
        final enhancedMessage = userDNA.isNotEmpty 
            ? '$userDNA\n\n### KULLANICI MESAJI:\n$message'
            : message;
            
        final response = await _chatSession!.sendMessage(Content.text(enhancedMessage));
        responseText = response.text ?? 'Şu an yanıt veremedim.';
      }
      
      _isGenerating = false;
      
      // Run Shadow Memory analysis in background (for ALL categories)
      // This updates both User DNA and Partner data with single API call
      ShadowMemoryService.analyzeAndUpdate(message, category: _currentCategory);
      
      return responseText;
    } catch (e) {
      _isGenerating = false;
      debugPrint('Error sending message: $e');
      return 'Bir sorun oluştu. Biraz sonra tekrar dene. 🙏';
    }
  }

  /// Analyze image with category-specific context
  static Future<String> analyzeImage(Uint8List imageBytes, String userPrompt, {String category = 'iliskiler'}) async {
    if (_model == null) {
      return 'Bağlantı kurulamadı.';
    }

    _isGenerating = true;

    try {
      String systemPrompt;
      String dynamicContext = '';
      
      if (category == 'iliskiler') {
        // Build full prompt with system rules + partner context + user prompt
        systemPrompt = await _buildRelationshipCoachPrompt();
        
        // Get partner zodiac for dynamic context injection
        final partnerZodiac = await PartnerService.getPartnerZodiac();
        
        // Build dynamic context (BURÇ STRATEJİLERİ + SENARYO KURALLARI)
        dynamicContext = buildDynamicContext(userPrompt, partnerZodiac);
      } else {
        // Use standard category prompts for Vision
        systemPrompt = _categoryPrompts[category] ?? _categoryPrompts['genel']!;
      }
      
      final fullPrompt = '''
$systemPrompt
$dynamicContext
### KULLANICI GİRDİSİ:
$userPrompt
''';

      final imagePart = DataPart('image/jpeg', imageBytes);
      
      final response = await _model!.generateContent([
        Content.multi([
          TextPart(fullPrompt),
          imagePart,
        ])
      ]);

      final responseText = response.text ?? 'Yanıt alınamadı.';
      _isGenerating = false;
      return responseText;
    } catch (e) {
      _isGenerating = false;
      debugPrint('Error analyzing image: $e');
      return 'Resim analiz edilemedi. Lütfen tekrar dene. 🙏';
    }
  }

  /// Generate one-off response (legacy)
  static Future<String> generateResponse(String prompt, String category, {String? customSystemPrompt}) async {
    if (_model == null) {
      return 'Bağlantı kurulamadı.';
    }

    _isGenerating = true;

    try {
      final systemPrompt = customSystemPrompt ?? (_categoryPrompts[category] ?? _categoryPrompts['genel']!);
      final fullPrompt = '$systemPrompt\n\nKullanıcı: $prompt';

      final response = await _model!.generateContent([Content.text(fullPrompt)]);
      final responseText = response.text ?? 'Yanıt alınamadı.';

      _isGenerating = false;
      return responseText;
    } catch (e) {
      _isGenerating = false;
      debugPrint('Error generating response: $e');
      return 'Bir sorun oluştu.';
    }
  }

  /// Generate Cyber-Mistik Astrology Analysis
  static Future<String?> getAstrologyAnalysis(String userSign, String currentDate) async {
    if (_model == null) return null;

    final prompt = '''
GÖREV: Sen Mentaliq uygulamasının "Kozmik Veri Motoru"sun.
KULLANICI BURCU: $userSign
TARİH: $currentDate

ANALİZ:
Bugünün gezegen transitlerine (Retro, Dolunay, Açı Kalıpları) bakarak, bu burç için aşağıdaki JSON verisini üret.
TON: Mistik ama modern, Z kuşağına hitap eden, kısa ve vurucu (gazete falı gibi olma).

ÇIKTI FORMATI (SADECE JSON):
{
  "battery_level": 85,
  "traffic_lights": {
    "love": "GREEN", 
    "career": "YELLOW",
    "energy": "RED"
  },
  "traffic_comments": {
    "love": "Venüs seni parlatıyor, bugün o adımı at.",
    "career": "Merkür retrosu var, sözleşme imzalama.",
    "energy": "Mars açısı sert, dinlenmeye odaklan."
  },
  "power_hour": "14:30 - 16:00",
  "totem_emoji": "🦅",
  "totem_name": "Yüksekten Uçan Kartal",
  "motto": "Bugün sesini değil, sözünü yükselt.",
  "mission": "O korktuğun maili bugün at, evren arkanda."
}

NOTLAR:
- battery_level: 0 ile 100 arası bir sayı (Genel şans).
- traffic_lights değerleri sadece: "GREEN", "YELLOW", "RED" olabilir.
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      debugPrint('Error getting astrology analysis: $e');
      return null;
    }
  }

  /// Clear session
  static void clearSession() {
    _chatSession = null;
    _currentCategory = 'genel';
  }

  /// Get category info
  static String getCategoryName(String category) {
    return AppConstants.categoryNames[category] ?? category;
  }

  static String getCategoryIcon(String category) {
    return AppConstants.categoryIcons[category] ?? '🌿';
  }
}
