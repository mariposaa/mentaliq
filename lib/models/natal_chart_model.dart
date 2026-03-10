// lib/models/natal_chart_model.dart
// Kullanıcının doğum haritası - bir kez hesaplanır, UserDNA'da saklanır

class NatalChartModel {
  final String sunSign;
  final String moonSign;
  final String risingSign;
  final Map<String, HouseCusp> houses; // "1" to "12"
  final Map<String, PlanetPosition> planets;
  final DateTime? calculatedAt;

  NatalChartModel({
    required this.sunSign,
    required this.moonSign,
    required this.risingSign,
    required this.houses,
    required this.planets,
    this.calculatedAt,
  });

  factory NatalChartModel.fromJson(Map<String, dynamic> json) {
    // Parse houses
    final housesMap = <String, HouseCusp>{};
    if (json['houses'] != null) {
      final rawHouses = (json['houses'] as Map).cast<dynamic, dynamic>();
      rawHouses.forEach((key, value) {
        if (value is Map) {
          housesMap['$key'] = HouseCusp.fromJson(value.cast<String, dynamic>());
        }
      });
    }

    // Parse planets
    final planetsMap = <String, PlanetPosition>{};
    if (json['planets'] != null) {
      final rawPlanets = (json['planets'] as Map).cast<dynamic, dynamic>();
      rawPlanets.forEach((key, value) {
        if (value is Map) {
          planetsMap['$key'] = PlanetPosition.fromJson(value.cast<String, dynamic>());
        }
      });
    }

    return NatalChartModel(
      sunSign: json['sun_sign'] ?? '',
      moonSign: json['moon_sign'] ?? '',
      risingSign: json['rising_sign'] ?? '',
      houses: housesMap,
      planets: planetsMap,
      calculatedAt: json['calculated_at'] != null 
          ? DateTime.tryParse(json['calculated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final housesJson = <String, dynamic>{};
    houses.forEach((key, value) {
      housesJson[key] = value.toJson();
    });

    final planetsJson = <String, dynamic>{};
    planets.forEach((key, value) {
      planetsJson[key] = value.toJson();
    });

    return {
      'sun_sign': sunSign,
      'moon_sign': moonSign,
      'rising_sign': risingSign,
      'houses': housesJson,
      'planets': planetsJson,
      'calculated_at': calculatedAt?.toIso8601String(),
    };
  }

  bool get isValid => sunSign.isNotEmpty && moonSign.isNotEmpty && risingSign.isNotEmpty;

  /// Get zodiac emoji for a sign
  static String getZodiacEmoji(String sign) {
    const emojis = {
      'Aries': '♈',
      'Taurus': '♉',
      'Gemini': '♊',
      'Cancer': '♋',
      'Leo': '♌',
      'Virgo': '♍',
      'Libra': '♎',
      'Scorpio': '♏',
      'Sagittarius': '♐',
      'Capricorn': '♑',
      'Aquarius': '♒',
      'Pisces': '♓',
    };
    return emojis[sign] ?? '⭐';
  }

  /// Get Turkish name for a sign
  static String getZodiacNameTr(String sign) {
    const names = {
      'Aries': 'Koç',
      'Taurus': 'Boğa',
      'Gemini': 'İkizler',
      'Cancer': 'Yengeç',
      'Leo': 'Aslan',
      'Virgo': 'Başak',
      'Libra': 'Terazi',
      'Scorpio': 'Akrep',
      'Sagittarius': 'Yay',
      'Capricorn': 'Oğlak',
      'Aquarius': 'Kova',
      'Pisces': 'Balık',
    };
    return names[sign] ?? sign;
  }
}

class HouseCusp {
  final String sign;
  final int degree;

  HouseCusp({
    required this.sign,
    required this.degree,
  });

  factory HouseCusp.fromJson(Map<String, dynamic> json) {
    return HouseCusp(
      sign: json['sign'] ?? '',
      degree: _toInt(json['degree']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'sign': sign,
      'degree': degree,
    };
  }
}

class PlanetPosition {
  final String sign;
  final int house;
  final int degree;

  PlanetPosition({
    required this.sign,
    required this.house,
    required this.degree,
  });

  factory PlanetPosition.fromJson(Map<String, dynamic> json) {
    return PlanetPosition(
      sign: json['sign'] ?? '',
      house: _toInt(json['house']),
      degree: _toInt(json['degree']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'sign': sign,
      'house': house,
      'degree': degree,
    };
  }

  /// Get planet emoji
  static String getPlanetEmoji(String planet) {
    const emojis = {
      'sun': '☀️',
      'moon': '🌙',
      'mercury': '☿️',
      'venus': '♀️',
      'mars': '♂️',
      'jupiter': '♃',
      'saturn': '♄',
      'uranus': '⛢',
      'neptune': '♆',
      'pluto': '♇',
    };
    return emojis[planet.toLowerCase()] ?? '⭐';
  }

  /// Get planet Turkish name
  static String getPlanetNameTr(String planet) {
    const names = {
      'sun': 'Güneş',
      'moon': 'Ay',
      'mercury': 'Merkür',
      'venus': 'Venüs',
      'mars': 'Mars',
      'jupiter': 'Jüpiter',
      'saturn': 'Satürn',
      'uranus': 'Uranüs',
      'neptune': 'Neptün',
      'pluto': 'Plüton',
    };
    return names[planet.toLowerCase()] ?? planet;
  }
}
