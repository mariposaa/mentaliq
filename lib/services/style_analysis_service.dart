import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';
import 'user_dna_service.dart';
import 'style_service.dart';
import 'style_inspiration_pool_service.dart';
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
    final rawAdvice = (json['shopping_advice'] ?? '').toString().trim();
    return StyleAnalysisResult(
      styleArchetypes: Map<String, double>.from(json['style_dna'] ?? {}),
      primaryColors: List<String>.from(json['colors']['primary'] ?? []),
      complementaryColors:
          List<String>.from(json['colors']['complementary'] ?? []),
      shoppingAdvice: rawAdvice,
      analyzedAt: DateTime.now(),
    );
  }
}

class StyleOutfitSuggestion {
  final String title;
  final String reason;
  final StyleItem? top;
  final StyleItem? bottom;
  final StyleItem? shoes;
  final StyleItem? outerwear;
  final String? missingNote;

  const StyleOutfitSuggestion({
    required this.title,
    required this.reason,
    this.top,
    this.bottom,
    this.shoes,
    this.outerwear,
    this.missingNote,
  });
}

enum _StylePieceType { top, bottom, shoes, outerwear, other }

class StyleAnalysisService {
  /// Tüm gardırobu ve User DNA'yı analiz ederek kapsamlı rapor oluşturur
  static Future<StyleAnalysisResult?> performFullAnalysis() async {
    try {
      final items = await StyleService.getClosetItems();
      final dnaContext = await UserDNAService.getDNAForAI();

      if (items.isEmpty) return null;

      final inventoryText = items
          .map((i) => '${i.category}: ${i.tags.join(", ")} (${i.season})')
          .join('\n');

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

      final response =
          await GeminiService.generateResponse(prompt, 'stil_danismanligi');
      final cleanJson =
          response.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(cleanJson);

      final parsed = StyleAnalysisResult.fromJson(data);
      final finalAdvice = parsed.shoppingAdvice.isNotEmpty
          ? parsed.shoppingAdvice
          : _buildFallbackShoppingAdvice(items);
      final result = StyleAnalysisResult(
        styleArchetypes: parsed.styleArchetypes,
        primaryColors: parsed.primaryColors,
        complementaryColors: parsed.complementaryColors,
        shoppingAdvice: finalAdvice,
        analyzedAt: parsed.analyzedAt,
      );

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
      final inspirations = isHybrid
          ? await StyleInspirationPoolService.getLatest(limit: 12)
          : <StyleInspirationItem>[];

      // Gardırop kontrolü (Hibrit modda esnetildi)
      if (items.isEmpty && !isHybrid) {
        return 'Gardırobun boş, elindeki parçalarla bir kombin yapabilmem için önce birkaç parça eklemelisin.';
      }

      final inventoryText = items.isEmpty
          ? "Gardırop şu an boş. Kullanıcının Master DNA'sına ve bağlamına göre genel öneriler yap."
          : items
              .map((i) => 'ID: ${i.id} - ${i.category}: ${i.tags.join(", ")}')
              .join('\n');
      final inspirationText = inspirations.isEmpty
          ? 'Ilham havuzunda parca yok.'
          : inspirations
              .map(
                (i) =>
                    '- ${i.title} | ${i.category} | Etiket:${i.tags.join(", ")} | Mevsim:${i.seasons.join(", ")}',
              )
              .join('\n');

      const personaRules = '''
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
MOD: ${isHybrid ? "Gardrop Disi Oneri (Arsiv + Disaridan Tamamlama)" : "Sadece Arsivim (Eldekilerle En Iyisi)"}
Kullanıcı Bağlamı (DNA): $dnaContext

GARDIROP ENVANTERİ:
$inventoryText

HIBRIT ILHAM HAVUZU:
$inspirationText

GÖREV:
1. Kullanıcının komutuna ve User DNA'sındaki proaktif bilgilere (Örn: Ayrılık sonrası güce ihtiyaç duyma, profesyonel kariyer vb.) göre bir strateji belirle.
2. Gardıroptaki parçaları acımasızca ama profesyonelce değerlendir. "Mavi tişörtün bu ortam için çok feminen/maskülen/basit kalıyor" gibi yorumlar yapmaktan çekinme.
3. Hibrid modda, gerekiyorsa "Ilham Havuzundan Oneri" basligi ile havuzdan 1-3 parca oner.
4. ÇIKTI: Önce dürüst stil yorumunu yap, sonra parçaları seç, en son nedenini DNA verilerine atıf yaparak (Örn: "Şu anki bağımsız ruh halini yansıtmak için...") açıkla.

Yanıtını bir moda ikonu gibi, iddialı ve nokta atışı bir dille yaz.
''';

      return await GeminiService.generateResponse(prompt, 'stil_danismanligi');
    } catch (e) {
      debugPrint('Custom Recommendation Error: $e');
      return 'İstediğin kombini şu an oluşturamadım, lütfen tekrar dene.';
    }
  }

  /// Build concrete "wear this" outfit sets from closet items (non-hybrid flow).
  static Future<List<StyleOutfitSuggestion>> getClosetOutfitSuggestions({
    required String command,
    required String weather,
    required String temperature,
  }) async {
    final items = await StyleService.getClosetItems();
    if (items.isEmpty) return [];

    final fromAi = await _getClosetOutfitsWithAI(
      items: items,
      command: command,
      weather: weather,
      temperature: temperature,
    );
    if (fromAi.isNotEmpty) return fromAi;

    return _buildRuleBasedOutfits(items);
  }

  static Future<List<StyleOutfitSuggestion>> _getClosetOutfitsWithAI({
    required List<StyleItem> items,
    required String command,
    required String weather,
    required String temperature,
  }) async {
    try {
      final inventory = items
          .map(
            (item) =>
                'ID:${item.id} | Kategori:${item.category} | Etiketler:${item.tags.join(", ")} | Mevsim:${item.season}',
          )
          .join('\n');

      final prompt = '''
Sadece kullanıcının dolabındaki parçaları kullanarak net giyilebilir kombin setleri üret.

KOMUT: "$command"
HAVA: $weather
SICAKLIK: $temperature

ENVANTER:
$inventory

Kurallar:
- Maksimum 3 kombin üret.
- Her kombin için mümkünse top_id, bottom_id, shoes_id ver.
- Uygunsa outerwear_id ver; yoksa null.
- ID dışındaki hayali ürünler yasak.
- Sadece aşağıdaki JSON formatını döndür:
{
  "outfits": [
    {
      "title": "Kısa kombin adı",
      "reason": "Neden bu kombin",
      "top_id": "id",
      "bottom_id": "id",
      "shoes_id": "id",
      "outerwear_id": null
    }
  ]
}
''';

      final raw =
          await GeminiService.generateResponse(prompt, 'stil_danismanligi');
      final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(clean) as Map<String, dynamic>;
      final outfits = (decoded['outfits'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (outfits.isEmpty) return [];

      final itemById = {for (final item in items) item.id: item};
      final suggestions = outfits
          .map((o) {
            final top = itemById[o['top_id']];
            final bottom = itemById[o['bottom_id']];
            final shoes = itemById[o['shoes_id']];
            final outerwear = itemById[o['outerwear_id']];
            return StyleOutfitSuggestion(
              title: (o['title'] ?? 'Önerilen Kombin').toString(),
              reason: (o['reason'] ?? '').toString(),
              top: top,
              bottom: bottom,
              shoes: shoes,
              outerwear: outerwear,
            );
          })
          .where((s) => s.top != null && s.bottom != null)
          .toList();

      return suggestions.take(3).toList();
    } catch (e) {
      debugPrint('StyleAnalysisService: AI outfit parse failed: $e');
      return [];
    }
  }

  static List<StyleOutfitSuggestion> _buildRuleBasedOutfits(
      List<StyleItem> items) {
    final tops = <StyleItem>[];
    final bottoms = <StyleItem>[];
    final shoes = <StyleItem>[];
    final outers = <StyleItem>[];

    for (final item in items) {
      switch (_detectPieceType(item)) {
        case _StylePieceType.top:
          tops.add(item);
          break;
        case _StylePieceType.bottom:
          bottoms.add(item);
          break;
        case _StylePieceType.shoes:
          shoes.add(item);
          break;
        case _StylePieceType.outerwear:
          outers.add(item);
          break;
        case _StylePieceType.other:
          break;
      }
    }

    if (tops.isEmpty || bottoms.isEmpty) {
      return [
        StyleOutfitSuggestion(
          title: 'Tam Kombin Uretilemedi',
          reason: '',
          missingNote: tops.isEmpty
              ? 'Dolabinda ust parca olmadigi icin tam kombin oneremiyorum.'
              : 'Dolabinda alt parca olmadigi icin tam kombin oneremiyorum.',
        ),
      ];
    }

    final suggestions = <StyleOutfitSuggestion>[];
    final maxCount =
        tops.length < bottoms.length ? tops.length : bottoms.length;
    final usedTopIds = <String>{};
    final usedBottomIds = <String>{};
    var topIndex = 0;
    var bottomIndex = 0;
    var shoesIndex = 0;
    var outerIndex = 0;

    for (var i = 0; i < maxCount && suggestions.length < 3; i++) {
      StyleItem? top;
      StyleItem? bottom;

      while (top == null && topIndex < tops.length * 2) {
        final candidate = tops[topIndex % tops.length];
        topIndex++;
        if (!usedTopIds.contains(candidate.id)) {
          top = candidate;
          usedTopIds.add(candidate.id);
        } else if (tops.length == 1) {
          top = candidate;
        }
      }

      while (bottom == null && bottomIndex < bottoms.length * 2) {
        final candidate = bottoms[bottomIndex % bottoms.length];
        bottomIndex++;
        if (!usedBottomIds.contains(candidate.id)) {
          bottom = candidate;
          usedBottomIds.add(candidate.id);
        } else if (bottoms.length == 1) {
          bottom = candidate;
        }
      }

      if (top == null || bottom == null) {
        continue;
      }

      final selectedShoes =
          shoes.isEmpty ? null : shoes[shoesIndex % shoes.length];
      shoesIndex++;
      final selectedOuter =
          outers.isEmpty ? null : outers[outerIndex % outers.length];
      outerIndex++;

      suggestions.add(
        StyleOutfitSuggestion(
          title: 'Kombin ${suggestions.length + 1}',
          reason: 'Dolabındaki parçalarla hızlı ve uyumlu bir günlük set.',
          top: top,
          bottom: bottom,
          shoes: selectedShoes,
          outerwear: selectedOuter,
        ),
      );
    }

    return suggestions;
  }

  static String _buildFallbackShoppingAdvice(List<StyleItem> items) {
    int topCount = 0;
    int bottomCount = 0;
    int shoesCount = 0;
    int outerCount = 0;

    for (final item in items) {
      switch (_detectPieceType(item)) {
        case _StylePieceType.top:
          topCount++;
          break;
        case _StylePieceType.bottom:
          bottomCount++;
          break;
        case _StylePieceType.shoes:
          shoesCount++;
          break;
        case _StylePieceType.outerwear:
          outerCount++;
          break;
        case _StylePieceType.other:
          break;
      }
    }

    if (topCount == 0) {
      return 'Dolabinda ust parca eksik. Nötr renkte basic bir gomlek veya kazak eklemeni oneririm.';
    }
    if (bottomCount == 0) {
      return 'Dolabinda alt parca eksik. Kombinleri tamamlamak icin duz kesim bir pantolon ekleyebilirsin.';
    }
    if (shoesCount == 0) {
      return 'Dolabinda ayakkabi tarafi zayif. Siyah veya bej bir gunluk ayakkabi kombin kapasiteni ciddi artirir.';
    }
    if (outerCount == 0) {
      return 'Dis giyim katmani eksik. Mevsime uygun bir ceket veya blazer eklemek kombinleri tamamlar.';
    }

    return 'Dolabin dengeli gorunuyor. Bir sonraki seviye icin aksesuar odakli 1-2 vurucu parca ekleyebilirsin.';
  }

  static _StylePieceType _detectPieceType(StyleItem item) {
    final text = '${item.category} ${item.tags.join(" ")}'.toLowerCase();

    const topKeywords = [
      'top',
      'üst',
      'bluz',
      'gomlek',
      'gömlek',
      'tişört',
      'tisort',
      't-shirt',
      'kazak',
      'sweat'
    ];
    const bottomKeywords = [
      'bottom',
      'alt',
      'pantolon',
      'etek',
      'şort',
      'sort',
      'jean',
      'kot'
    ];
    const shoesKeywords = [
      'shoes',
      'ayakkabı',
      'ayakkabi',
      'sneaker',
      'bot',
      'çizme',
      'cizme',
      'loafer',
      'topuklu'
    ];
    const outerKeywords = [
      'outerwear',
      'dış',
      'dis',
      'ceket',
      'mont',
      'kaban',
      'hırka',
      'hirka',
      'trenç',
      'trenc',
      'blazer'
    ];

    if (shoesKeywords.any(text.contains)) return _StylePieceType.shoes;
    if (bottomKeywords.any(text.contains)) return _StylePieceType.bottom;
    if (outerKeywords.any(text.contains)) return _StylePieceType.outerwear;
    if (topKeywords.any(text.contains)) return _StylePieceType.top;
    return _StylePieceType.other;
  }

  static Future<void> _updateUserDNAWithStyleTraits(
      StyleAnalysisResult result) async {
    // Burada UserDNAService üzerinden DNA'ya "style_traits" gibi alanlar eklenebilir.
    // Şimdilik sadece debug print, UserDNA modeline yeni alanlar ekleyerek genişletebiliriz.
    debugPrint('StyleAnalysisService: Style Traits syncing to DNA...');
  }
}
