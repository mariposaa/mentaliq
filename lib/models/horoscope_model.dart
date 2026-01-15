class HoroscopeData {
  final String sunSign;
  final String risingSign;
  final String sunInterpretation;
  final String risingInterpretation;
  final String date;
  final String period; // 'daily' or 'weekly'

  HoroscopeData({
    required this.sunSign,
    required this.risingSign,
    required this.sunInterpretation,
    required this.risingInterpretation,
    required this.date,
    required this.period,
  });

  factory HoroscopeData.fromJson(Map<String, dynamic> json) {
    return HoroscopeData(
      sunSign: json['sun_sign'] ?? '',
      risingSign: json['rising_sign'] ?? '',
      sunInterpretation: json['sun_interpretation'] ?? '',
      risingInterpretation: json['rising_interpretation'] ?? '',
      date: json['date'] ?? '',
      period: json['period'] ?? 'daily',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sun_sign': sunSign,
      'rising_sign': risingSign,
      'sun_interpretation': sunInterpretation,
      'rising_interpretation': risingInterpretation,
      'date': date,
      'period': period,
    };
  }
}
