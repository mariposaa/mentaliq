import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'user_dna_service.dart';
import '../models/astro_model.dart';


class AstroService {
  final GenerativeModel _model;

  AstroService(String apiKey)
      : _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);

  Future<AstroData> getDailyAstro(String userSign) async {
    final date = DateFormat('dd MMMM yyyy').format(DateTime.now());
    
    final dnaContext = await UserDNAService.getDNAForAI();

    // Prompt Hazırlığı
    final prompt = '''
GÖREV: Sen Mentaliq uygulamasının "Siber-Mistik Kozmik Veri Motoru"sun.
KULLANICI BURCU: $userSign
TARİH: $date

### KODLANMIŞ MASTER DNA:
$dnaContext

ANALİZ:
Bugünün gezegen transitlerine bakarak, kullanıcının Master DNA'sındaki korku, hedef ve güçleri ile gökyüzü verilerini birleştir. Aşağıdaki JSON verisini üret.
TON: Mistik, vurucu, psikolojik derinliği olan modern bir dil.

ÇIKTI FORMATI (SADECE JSON):
{
  "battery_level": 85,
  "traffic_lights": {
    "love": "GREEN", 
    "career": "YELLOW",
    "energy": "RED"
  },
  "traffic_comments": {
    "love": "DNA'ndaki özgürlük arayışın bugün gökyüzüyle uyumlu.",
    "career": "Korkuların üzerine gitme vakti, Merkür seni destekliyor.",
    "energy": "Satürn kare açısı DNA'ndaki yorgunluğu tetikleyebilir, dinlen."
  },
  "power_hour": "14:30 - 16:00",
  "totem_emoji": "🦅",
  "totem_name": "Yüksekten Uçan Kartal",
  "motto": "DNA'ndaki gücü serbest bırak.",
  "mission": "Bugün DNA'ndaki o en büyük korkunla yüzleşecek küçük bir adım at."
}
''';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    
    // JSON Temizliği (Markdown ```json taglerini silmek için)
    String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
    
    final Map<String, dynamic> data = jsonDecode(cleanJson);
    return AstroData.fromJson(data);
  }

  /// Save daily astro to firestore
  Future<void> saveDailyAstro(AstroData data) async {
    final userId = AuthService.userId;
    if (userId == null) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    await FirebaseFirestore.instance
        .collection('astro_results')
        .doc(userId)
        .collection('daily')
        .doc(dateKey)
        .set({
          ...data.toJson(),
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  /// Get saved daily astro from firestore
  Future<AstroData?> getSavedDailyAstro() async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final doc = await FirebaseFirestore.instance
        .collection('astro_results')
        .doc(userId)
        .collection('daily')
        .doc(dateKey)
        .get();

    if (doc.exists && doc.data() != null) {
      return AstroData.fromJson(doc.data()!);
    }
    return null;
  }

  /// Mark the card as generated for today to avoid multiple charges
  Future<void> markCardAsGenerated() async {
    final userId = AuthService.userId;
    if (userId == null) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    await FirebaseFirestore.instance
        .collection('astro_results')
        .doc(userId)
        .collection('daily')
        .doc(dateKey)
        .set({'card_generated': true}, SetOptions(merge: true));
  }

  /// Check if card was already generated today
  Future<bool> isCardGeneratedToday() async {
    final userId = AuthService.userId;
    if (userId == null) return false;

    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final doc = await FirebaseFirestore.instance
        .collection('astro_results')
        .doc(userId)
        .collection('daily')
        .doc(dateKey)
        .get();

    return doc.exists && (doc.data()?['card_generated'] == true);
  }
}
