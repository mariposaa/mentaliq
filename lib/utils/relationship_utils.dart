// lib/utils/relationship_utils.dart
// İlişki Stratejisti - Dinamik Bilgi Enjeksiyonu Beyin Fonksiyonu

import '../config/app_constants.dart';

/// Kullanıcının mesajını ve partnerinin burcunu alarak
/// uygun strateji kartlarını dinamik olarak oluşturur.
/// 
/// Bu fonksiyon, mesajdaki anahtar kelimeleri tarayarak
/// ilgili burç taktiği ve senaryo kurallarını döndürür.
String buildDynamicContext(String userMessage, String? partnerZodiac) {
  List<String> injections = [];
  String lowerMsg = userMessage.toLowerCase();

  // 1. Burç Kartını Çek (Mistik Derinlik)
  if (partnerZodiac != null && zodiacStrategies.containsKey(partnerZodiac.toLowerCase())) {
    injections.add(zodiacStrategies[partnerZodiac.toLowerCase()]!);
  }

  // 2. Senaryo Kartını Çek (Akıllı Niyet Algılama)
  // Aldatılma niyetini sorgula (Korku mu, niyet mi, geçmiş mi?)
  if ((lowerMsg.contains('aldat') && !lowerMsg.contains('mıydı')) || lowerMsg.contains('ihanet')) {
    if (!lowerMsg.contains('korku') && !lowerMsg.contains('travma')) {
      injections.add(scenarioRules['aldatma']!);
    }
  } 
  
  // Ghosting / İlgisizlik
  if (lowerMsg.contains('yazmıyor') || lowerMsg.contains('cevap vermiyor') || 
      (lowerMsg.contains('görüldü') && lowerMsg.contains('attı'))) {
    injections.add(scenarioRules['ghosting']!);
  }
  
  // İlk Buluşma / Heyecan
  if (lowerMsg.contains('buluş') || lowerMsg.contains('ilk defa') || lowerMsg.contains('date')) {
    injections.add(scenarioRules['ilk_bulusma']!);
  }
  
  // Eski Sevgili / Ex Kavramı
  if ((lowerMsg.contains('eski') && lowerMsg.contains('sevgilim')) || 
      lowerMsg.contains(' ex ') || lowerMsg.contains('döndü')) {
    injections.add(scenarioRules['eski_sevgili']!);
  }
  
  // Cinsellik ve Sınırlar
  if (lowerMsg.contains('seviş') || lowerMsg.contains('öpüş') || 
      lowerMsg.contains('yatak') || lowerMsg.contains('cinsel')) {
    injections.add(scenarioRules['cinsellik']!);
  }

  // Maddi / Finansal Manipülasyon
  if (lowerMsg.contains('para') || lowerMsg.contains('borç') || lowerMsg.contains('hesap')) {
    injections.add(scenarioRules['para']!);
  }

  if (injections.isEmpty) return "";
  
  return "\n### GÜNCEL STRATEJİ VE ANALİZ KARTLARI (BUNLARI BAĞLAMA YEDİR):\n${injections.join('\n\n')}\n";
}

