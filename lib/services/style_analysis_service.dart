import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';
import 'user_dna_service.dart';
import 'weather_service.dart';
import 'style_service.dart';
import '../models/style_item.dart';

class StyleAnalysisResult {
  final Map<String, double> styleArchetypes; // %60 Minimalist, %40 Klasik vb.
  final List<String> primaryColors;
  final List<String> complementaryColors;
  final String shoppingAdvice;
  final DateTime analyzedAt;

  StyleAnalysisResult({
    required this.styleArchetypes,
    required this.primaryColors,
    required this.complementaryColors,
    required this.shoppingAdvice,
    required this.analyzedAt,
  });

  factory StyleAnalysisResult.fromJson(Map<String, dynamic> json) {
    return StyleAnalysisResult(
      styleArchetypes: Map<String, double>.from(json['style_dna'] ?? {}),
      primaryColors: List<String>.from(json['colors']['primary'] ?? []),
      complementaryColors: List<String>.from(json['colors']['complementary'] ?? []),
      shoppingAdvice: json['shopping_advice'] ?? '',
      analyzedAt: DateTime.now(),
    );
  }
}

class StyleAnalysisService {
  /// Tüm gardırobu ve User DNA'yı analiz ederek kapsamlı rapor oluşturur
  static Future<StyleAnalysisResult?> performFullAnalysis() async {
    try {
      final items = await StyleService.getClosetItems();
      final dnaContext = await UserDNAService.getDNAForAI();
      
      if (items.isEmpty) return null;

      final inventoryText = items.map((i) => '${i.category}: ${i.tags.join(", ")} (${i.season})').join('\n');

      final prompt = '''
Kullanıcının Gardırop Envanteri:
$inventoryText

Kullanıcı DNA Bağlamı:
$dnaContext

GÖREV:
1. Bu verilere dayanarak kullanıcının Stil DNA'sını (Arketip dağılımı: Minimalist, Klasik, Bohem, Sportif, Avangart vb.) % olarak belirle.
2. Gardırobun dominant renklerini ve eksik olan, kombinleri tamamlayacak 3 tamamlayıcı rengi belirle.
3. Gardıroptaki eksikliği fark et ve nokta atışı bir "Alışveriş Tavsiyesi" ver.

SADECE aşağıdaki JSON formatında yanıt ver:
{
  "style_dna": {"Minimalist": 60, "Klasik": 40},
  "colors": {
    "primary": ["Siyah", "Gri"],
    "complementary": ["Bebek Mavisi", "Taba"]
  },
  "shopping_advice": "Koleksiyonun çok koyu renkli, stilini yumuşatmak için keten bej bir pantolon eklemeni öneririm."
}
''';

      final response = await GeminiService.generateResponse(prompt, 'stil_danismanligi');
      final cleanJson = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(cleanJson);
      
      final result = StyleAnalysisResult.fromJson(data);
      
      // Analiz sonuçlarını User DNA'ya işle (Proaktif veri yazma)
      await _updateUserDNAWithStyleTraits(result);
      
      return result;
    } catch (e) {
      debugPrint('StyleAnalysisService Error: $e');
      return null;
    }
  }

  /// Kullanıcı komutu ve manuel seçimlere göre kombin önerisi
  static Future<String> getCustomRecommendation({
    required String command,
    required String weather,
    required String temperature,
    bool isHybrid = false,
  }) async {
    try {
      final dnaContext = await UserDNAService.getDNAForAI();
      final items = await StyleService.getClosetItems();

      // Gardırop kontrolü (Hibrit modda esnetildi)
      if (items.isEmpty && !isHybrid) {
        return 'Gardırobun boş, elindeki parçalarla bir kombin yapabilmem için önce birkaç parça eklemelisin.';
      }

      final inventoryText = items.isEmpty 
          ? "Gardırop şu an boş. Kullanıcının Master DNA'sına ve bağlamına göre genel öneriler yap."
          : items.map((i) => 'ID: ${i.id} - ${i.category}: ${i.tags.join(", ")}').join('\n');
      
      final personaRules = '''
SENİN KİMLİĞİN:
Sen dünya standartlarında, dürüst ve vizyoner bir Stil Danışmanısın. 
- Sadece "olur" diyen bir asistan değil, yanlış tercihleri eleştiren bir uzmansın.
- Eğer kullanıcının istediği parça rüküşse veya bağlama (iş toplantısı, ayrılık sonrası güç toplama vb.) uymuyorsa bunu şık bir dille yüzüne vur.
- Cinsiyet rolleri, renk uyumu ve mevsim standartları konusunda keskin fikirlerin var.

MOD KURALLARI:
- HİBRİT MOD: Kullanıcının gardırobunu baz al ama eğer gardıroptaki parçalar hedefe (komuta) ulaşmak için ZAYIF kalıyorsa VEYA gardırop boşsa, Master DNA'daki meslek, yaş ve psikolojik duruma göre "Dışarıdan şu parçaları edinmelisin" diyerek yaratıcı öneriler yap.
- SADECE GARDROP: Sadece eldeki parçaları kullan. Eğer eldeki parçalar yetersizse bunu açıkça belirt.
''';


      final prompt = '''
$personaRules

DURUM:
Hava Durumu: $weather ($temperature)
Kullanıcı Komutu: "$command"
MOD: ${isHybrid ? "Hibrit (Yaratıcı ve Sınır Tanımaz)" : "Sadece Arşivim (Eldekilerle En İyisi)"}
Kullanıcı Bağlamı (DNA): $dnaContext

GARDIROP ENVANTERİ:
$inventoryText

GÖREV:
1. Kullanıcının komutuna ve User DNA'sındaki proaktif bilgilere (Örn: Ayrılık sonrası güce ihtiyaç duyma, profesyonel kariyer vb.) göre bir strateji belirle.
2. Gardıroptaki parçaları acımasızca ama profesyonelce değerlendir. "Mavi tişörtün bu ortam için çok feminen/maskülen/basit kalıyor" gibi yorumlar yapmaktan çekinme.
3. ÇIKTI: Önce dürüst stil yorumunu yap, sonra parçaları seç, en son nedenini DNA verilerine atıf yaparak (Örn: "Şu anki bağımsız ruh halini yansıtmak için...") açıkla.

Yanıtını bir moda ikonu gibi, iddialı ve nokta atışı bir dille yaz.
''';

      return await GeminiService.generateResponse(prompt, 'stil_danismanligi');
    } catch (e) {
      debugPrint('Custom Recommendation Error: $e');
      return 'İstediğin kombini şu an oluşturamadım, lütfen tekrar dene.';
    }
  }

  static Future<void> _updateUserDNAWithStyleTraits(StyleAnalysisResult result) async {
    // Burada UserDNAService üzerinden DNA'ya "style_traits" gibi alanlar eklenebilir.
    // Şimdilik sadece debug print, UserDNA modeline yeni alanlar ekleyerek genişletebiliriz.
    debugPrint('StyleAnalysisService: Style Traits syncing to DNA...');
  }
}
