// lib/models/daily_guidance_model.dart
// Günlük astrolojik yönergeler - 15 token ile her istekte üretilir

class DailyGuidanceModel {
  final String date;
  final int overallEnergy; // 0-100
  final String cosmicWeather;
  final List<int> focusHouses; // Most activated houses
  final Map<String, HouseGuidance> houseGuidance; // "1" to "12"
  final String powerHour;
  final String dailyMotto;
  final String? cosmicWarning;
  final LuckyElements? luckyElements;
  final DateTime? generatedAt;

  DailyGuidanceModel({
    required this.date,
    required this.overallEnergy,
    required this.cosmicWeather,
    required this.focusHouses,
    required this.houseGuidance,
    required this.powerHour,
    required this.dailyMotto,
    this.cosmicWarning,
    this.luckyElements,
    this.generatedAt,
  });

  factory DailyGuidanceModel.fromJson(Map<String, dynamic> json) {
    // Parse focus houses
    final focusList = <int>[];
    if (json['focus_houses'] != null) {
      for (var h in (json['focus_houses'] as List)) {
        focusList.add(h is int ? h : int.tryParse(h.toString()) ?? 0);
      }
    }

    // Parse house guidance
    final guidanceMap = <String, HouseGuidance>{};
    if (json['house_guidance'] != null) {
      final rawGuidance = json['house_guidance'] as Map<String, dynamic>;
      rawGuidance.forEach((key, value) {
        guidanceMap[key] = HouseGuidance.fromJson(value as Map<String, dynamic>);
      });
    }

    return DailyGuidanceModel(
      date: json['date'] ?? '',
      overallEnergy: json['overall_energy'] ?? 50,
      cosmicWeather: json['cosmic_weather'] ?? '',
      focusHouses: focusList,
      houseGuidance: guidanceMap,
      powerHour: json['power_hour'] ?? '',
      dailyMotto: json['daily_motto'] ?? '',
      cosmicWarning: json['cosmic_warning'],
      luckyElements: json['lucky_element'] != null 
          ? LuckyElements.fromJson(json['lucky_element']) 
          : null,
      generatedAt: json['generated_at'] != null 
          ? DateTime.tryParse(json['generated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final guidanceJson = <String, dynamic>{};
    houseGuidance.forEach((key, value) {
      guidanceJson[key] = value.toJson();
    });

    return {
      'date': date,
      'overall_energy': overallEnergy,
      'cosmic_weather': cosmicWeather,
      'focus_houses': focusHouses,
      'house_guidance': guidanceJson,
      'power_hour': powerHour,
      'daily_motto': dailyMotto,
      'cosmic_warning': cosmicWarning,
      'lucky_element': luckyElements?.toJson(),
      'generated_at': generatedAt?.toIso8601String(),
    };
  }

  /// Get sorted houses by activation level (high first)
  List<MapEntry<String, HouseGuidance>> getSortedHouses() {
    final entries = houseGuidance.entries.toList();
    entries.sort((a, b) {
      final aLevel = _activationOrder(a.value.activationLevel);
      final bLevel = _activationOrder(b.value.activationLevel);
      return bLevel.compareTo(aLevel); // High first
    });
    return entries;
  }

  int _activationOrder(String level) {
    switch (level.toLowerCase()) {
      case 'high': return 3;
      case 'medium': return 2;
      case 'low': return 1;
      default: return 0;
    }
  }
}

class HouseGuidance {
  final String houseName;
  final String themeIcon;
  final String activationLevel; // "high", "medium", "low"
  final String shortAdvice;
  final String? detailedAction; // null for low activation

  HouseGuidance({
    required this.houseName,
    required this.themeIcon,
    required this.activationLevel,
    required this.shortAdvice,
    this.detailedAction,
  });

  factory HouseGuidance.fromJson(Map<String, dynamic> json) {
    return HouseGuidance(
      houseName: json['house_name'] ?? '',
      themeIcon: json['theme_icon'] ?? '⭐',
      activationLevel: json['activation_level'] ?? 'low',
      shortAdvice: json['short_advice'] ?? '',
      detailedAction: json['detailed_action'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'house_name': houseName,
      'theme_icon': themeIcon,
      'activation_level': activationLevel,
      'short_advice': shortAdvice,
      'detailed_action': detailedAction,
    };
  }

  bool get isHighActivation => activationLevel.toLowerCase() == 'high';
  bool get isMediumActivation => activationLevel.toLowerCase() == 'medium';
  bool get isLowActivation => activationLevel.toLowerCase() == 'low';

  /// Get activation color
  int get activationColorValue {
    switch (activationLevel.toLowerCase()) {
      case 'high': return 0xFFE91E63; // Pink/Red
      case 'medium': return 0xFFFF9800; // Orange
      case 'low': return 0xFF9E9E9E; // Grey
      default: return 0xFF9E9E9E;
    }
  }

  /// Get Turkish house name
  static String getHouseNameTr(int houseNumber) {
    const names = {
      1: 'Benlik & Kimlik',
      2: 'Kaynaklar & Değerler',
      3: 'İletişim & Zihin',
      4: 'Yuva & Kökler',
      5: 'Yaratıcılık & Neşe',
      6: 'Sağlık & Rutinler',
      7: 'İlişkiler & Ortaklık',
      8: 'Dönüşüm & Paylaşım',
      9: 'Keşif & Bilgelik',
      10: 'Kariyer & İtibar',
      11: 'Topluluk & Gelecek',
      12: 'Bilinçaltı & Ruhsallık',
    };
    return names[houseNumber] ?? '$houseNumber. Ev';
  }

  /// Get house theme icon
  static String getHouseIcon(int houseNumber) {
    const icons = {
      1: '🪞',
      2: '💎',
      3: '🗣️',
      4: '🏠',
      5: '🎨',
      6: '⚕️',
      7: '💞',
      8: '🔮',
      9: '🌍',
      10: '🏆',
      11: '🌐',
      12: '🌙',
    };
    return icons[houseNumber] ?? '⭐';
  }
}

class LuckyElements {
  final String color;
  final int number;
  final String direction;

  LuckyElements({
    required this.color,
    required this.number,
    required this.direction,
  });

  factory LuckyElements.fromJson(Map<String, dynamic> json) {
    return LuckyElements(
      color: json['color'] ?? '',
      number: json['number'] ?? 0,
      direction: json['direction'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color,
      'number': number,
      'direction': direction,
    };
  }
}
