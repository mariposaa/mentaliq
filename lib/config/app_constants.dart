// Mentaliq App Constants

class AppConstants {
  // App Info
  static const String appName = 'mentaliq';
  static const String appVersion = '1.0.0';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  
  // AI Categories - Wellness & Support focused
  static const List<String> aiCategories = [
    'iliskiler',
    'anksiyete', // Astroloji ve Rüya
    'kendin_kesfet', // Persona Psikoloji
    'stil_danismanligi',
    'motivasyon', // Gelecek Mimarı
    'duygusal_destek', // Şefkatli Gölge
    'bagimliliklar',
  ];

  
  // Category Display Names (Turkish - Friendly)
  static const Map<String, String> categoryNames = {
    'iliskiler': 'Siber-Dost ve İlişki Mimarı',
    'duygusal_destek': 'Şefkatli Gölge',
    'stil_danismanligi': 'Dolabım',
    'anksiyete': 'Astroloji ve Rüya (Cyber-Mistik)',
    'kendin_kesfet': 'Persona Psikoloji',
    'bagimliliklar': 'Bağımlılıklarım',
    'motivasyon': 'Gelecek Mimarı',
  };

  
  // Category Icons (Calming emojis)
  static const Map<String, String> categoryIcons = {
    'iliskiler': '💞',
    'duygusal_destek': '🌫️',
    'stil_danismanligi': '🧥',
    'anksiyete': '🌌',
    'kendin_kesfet': '🎭',
    'bagimliliklar': '🔗',
    'motivasyon': '🗺️',
  };

  
  // Category Descriptions (for tooltips/details)
  static const Map<String, String> categoryDescriptions = {
    'iliskiler': 'Romantik bağlar ve stratejik ilişki yönetimi',
    'duygusal_destek': 'Derin empati ve travma duyarlı destek',
    'kendin_kesfet': 'Kahramanın Yolculuğu ve psikolojik derinlik',
    'anksiyete': 'Doğum haritası ve rüya tabiri analizi',
    'bagimliliklar': 'Dijital ve davranışsal bağımlılık yönetimi',
    'stil_danismanligi': 'Kimlik ve arketip odaklı stil mimarlığı',
    'motivasyon': 'Kariyer, dopamin ve gelecek stratejisti',
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
