import '../l10n/app_translations.dart';

class AppConstants {
  static const String appName = 'mentaliq';
  static const String appVersion = '1.0.0';

  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';

  static const List<String> aiCategories = [
    'iliskiler',
    'anksiyete',
    'ruya_tabiri',
    'kendin_kesfet',
    'stil_danismanligi',
    'duygusal_destek',
    'bagimliliklar',
  ];

  static const Map<String, String> _categoryTranslationKeys = {
    'iliskiler': 'catRelationships',
    'duygusal_destek': 'catCompassionateShadow',
    'stil_danismanligi': 'catMyCloset',
    'anksiyete': 'astrology',
    'ruya_tabiri': 'dreamInterpretation',
    'kendin_kesfet': 'catPersonaPsychology',
    'bagimliliklar': 'catMyAddictions',
  };

  static const Map<String, String> _descriptionTranslationKeys = {
    'iliskiler': 'descRelationships',
    'duygusal_destek': 'descCompassionateShadow',
    'kendin_kesfet': 'descPersonaPsychology',
    'anksiyete': 'descAstrologyDream',
    'ruya_tabiri': 'dreamInterpretation',
    'bagimliliklar': 'descMyAddictions',
    'stil_danismanligi': 'descMyCloset',
  };

  static Map<String, String> get categoryNames => {
        for (final entry in _categoryTranslationKeys.entries)
          entry.key: AppTranslations.get(entry.value),
      };

  static Map<String, String> get categoryDescriptions => {
        for (final entry in _descriptionTranslationKeys.entries)
          entry.key: AppTranslations.get(entry.value),
      };

  static const Map<String, String> categoryIcons = {
    'iliskiler': '💞',
    'duygusal_destek': '🌫️',
    'stil_danismanligi': '🧥',
    'anksiyete': '🌌',
    'ruya_tabiri': '🌙',
    'kendin_kesfet': '🎭',
    'bagimliliklar': '🔗',
  };
}

// =============================================================================
// İLİŞKİ STRATEJİSTİ - DİNAMİK BİLGİ ENJEKSİYONU SİSTEMİ
// =============================================================================

// 1. BURÇ STRATEJİLERİ (Ansiklopedik bilgi değil, YÖNETİM TAKTİĞİ)
const Map<String, String> zodiacStrategies = {
  'koç': "KOÇ BURCU YÖNETİMİ: Asla inatlaşma. Gazla çalışır. Ona 'Bunu yapamazsın' dersen yapar. Emrivaki yapma, seçenek sunuyormuş gibi yönlendir.",
  'boğa': "BOĞA BURCU YÖNETİMİ: Değişimi sevmez, güven ister. Onu acele ettirirsen inatlaşır. Karnı açken veya konforu bozukken ciddi konu konuşma.",
  'ikizler': "İKİZLER BURCU YÖNETİMİ: Sıkılırsa gider. Sürekli aynı şeyleri konuşma. Dedikodu ve zeka oyunlarına bayılır. Duygusal derinlikten kaçabilir.",
  'yengeç': "YENGEÇ BURCU YÖNETİMİ: Kabuğuna çekildiyse üstüne gitme. Duygusal manipülasyona (duygu sömürüsü) meyillidir. Geçmişi asla unutmaz.",
  'aslan': "ASLAN BURCU YÖNETİMİ: Pofpofla. Sürekli övülmek ve ilgi odağı olmak ister. Toplum içinde onu sakın eleştirme, gururunu kırma.",
  'başak': "BAŞAK BURCU YÖNETİMİ: Eleştiriyorsa sevdiğindendir, düzeltmeye çalışıyordur. Pasaklı olma. Detaylara takılır, mantıklı argüman ister.",
  'terazi': "TERAZİ BURCU YÖNETİMİ: Karar vermesini bekleme, sen seç. Kavga sevmez, 'pasif agresif' davranabilir. Estetik ve nezaket onun için her şeydir.",
  'akrep': "AKREP BURCU YÖNETİMİ: Asla yalan söyleme, yakalar. Gizemli ol, her şeyi hemen anlatma. Şüphecidir, güvenini kazanmak zordur.",
  'yay': "YAY BURCU YÖNETİMİ: Özgürlüğünü kısıtlarsan kaçar. 'Neredesin?' diye darlama. Eğlence ve macera vaat etmezsen sıkılır.",
  'oğlak': "OĞLAK BURCU YÖNETİMİ: Ciddiyet sever. Gelecek planın yoksa seninle vakit kaybetmez. Saygı ve başarı onun aşk dilidir.",
  'kova': "KOVA BURCU YÖNETİMİ: Vıcık vıcık romantizmden nefret eder. Önce arkadaş ol. Sıradan olma, marjinal ve zeki olduğunu göster.",
  'balık': "BALIK BURCU YÖNETİMİ: Kurban psikolojisine girebilir. Hayal dünyasında yaşar. Gerçeklerle yüzleştirirken çok nazik ol yoksa kaybolur."
};

// 2. SENARYO KURALLARI (Kelimelere göre devreye girecek)
const Map<String, String> scenarioRules = {
  'aldatma': "SENARYO: GÜVEN KIRILMASI / ALDATMA.\nKural: Aldatan taraf suçluluk psikolojisiyle saldırganlaşabilir (Gaslighting). Kullanıcıyı uyar: 'Seni suçlamasına izin verme'. Asla hemen 'Affet' deme.",
  'ghosting': "SENARYO: GHOSTING (YOK OLMA).\nKural: Asla 'Mesaj atayım mı?' sorusuna evet deme. Taktik 'Ölü Taklidi'dir. Cevap verme, arama, hikaye bile atma. Merak etmesini sağla.",
  'ilk_bulusma': "SENARYO: FIRST DATE (İLK BULUŞMA).\nKural: Çok konuşma, dinle. Gizemli kal. Hesap ödeme konusunda politik ol. Eski sevgiliden asla bahsetme.",
  'eski_sevgili': "SENARYO: EX DÖNÜŞÜ.\nKural: 'Isıtılıp önüne gelen yemekten hayır gelmez' prensibini hatırla. Neden ayrıldıklarını sorgulat. Duygusal tuzağa düşmesini engelle.",
  'cinsellik': "SENARYO: CİNSELLİK VE SINIRLAR.\nKural: Ahlak dersi verme ama stratejik uyar. 'Sorunları yatakta çözmeye çalışmak, sadece sorunları erteler' bakış açısını sun.",
  'para': "SENARYO: MADDİ SORUNLAR.\nKural: İlişkide para dengesi önemlidir. Kullanıcının sömürülmesine (finansal manipülasyon) izin verme."
};
