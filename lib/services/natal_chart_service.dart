import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/natal_chart_model.dart';
import 'auth_service.dart';

class NatalChartService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static final String _weatherApiKey =
      dotenv.env['OPENWEATHER_API_KEY'] ?? '8569c7625881c15f94b3010b99818acc';
  static final _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _tzReady = false;

  static String? lastError;

  static Future<NatalChartModel?> calculateNatalChart({
    required String birthDate,
    required String birthTime,
    required String birthLocation,
  }) async {
    lastError = null;
    try {
      final prompt = _buildNatalChartPrompt(
        birthDate: birthDate,
        birthTime: birthTime,
        birthLocation: birthLocation,
      );

      final response = await _model.generateContent([Content.text(prompt)]);
      if (response.text == null || response.text!.isEmpty) {
        lastError = 'Gemini yaniti bos.';
        return null;
      }

      final text = response.text!;
      final firstOpen = text.indexOf('{');
      final lastClose = text.lastIndexOf('}');
      if (firstOpen == -1 || lastClose == -1 || lastClose <= firstOpen) {
        lastError = 'JSON blogu bulunamadi.';
        return null;
      }

      final jsonStr = text.substring(firstOpen, lastClose + 1);
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      data['calculated_at'] = DateTime.now().toIso8601String();
      final rawChart = NatalChartModel.fromJson(data);

      final det = await _calculateDeterministicCore(
        birthDate: birthDate,
        birthTime: birthTime,
        birthLocation: birthLocation,
      );
      return _mergeWithDeterministicCore(rawChart, det);
    } catch (e) {
      lastError = 'Hesaplama hatasi: $e';
      debugPrint('NatalChartService error: $e');
      return null;
    }
  }

  static Future<bool> saveNatalChart(NatalChartModel chart) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        lastError = 'Kullanici oturumu bulunamadi.';
        return false;
      }

      await _firestore.collection('user_dna').doc(userId).set({
        'natal_chart': chart.toJson(),
        'natal_chart_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      lastError = 'Kaydetme hatasi: $e';
      return false;
    }
  }

  static Future<NatalChartModel?> getSavedNatalChart() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return null;
      final doc = await _firestore.collection('user_dna').doc(userId).get();
      if (doc.exists && doc.data()?['natal_chart'] != null) {
        return NatalChartModel.fromJson(doc.data()!['natal_chart']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasValidNatalChart() async {
    final chart = await getSavedNatalChart();
    return chart != null && chart.isValid;
  }

  static NatalChartModel _mergeWithDeterministicCore(
    NatalChartModel raw,
    _DeterministicCore det,
  ) {
    final planets = <String, PlanetPosition>{...raw.planets};
    if (planets['sun'] != null) {
      final p = planets['sun']!;
      planets['sun'] = PlanetPosition(sign: det.sunSign, house: p.house, degree: p.degree);
    }
    if (planets['moon'] != null) {
      final p = planets['moon']!;
      planets['moon'] = PlanetPosition(sign: det.moonSign, house: p.house, degree: p.degree);
    }

    return NatalChartModel(
      sunSign: det.sunSign,
      moonSign: det.moonSign,
      risingSign: det.risingSign,
      houses: det.houses,
      planets: planets,
      calculatedAt: raw.calculatedAt ?? DateTime.now(),
    );
  }

  static Future<_DeterministicCore> _calculateDeterministicCore({
    required String birthDate,
    required String birthTime,
    required String birthLocation,
  }) async {
    final dt = _parseBirthDateTimeToUtc(
      birthDate: birthDate,
      birthTime: birthTime,
      birthLocation: birthLocation,
    );
    final coords = await _getCoordinatesFromCity(birthLocation);
    final sunLon = _solarLongitude(dt);
    final moonLon = _lunarLongitude(dt);
    final ascLon = _ascendantLongitude(
      utc: dt,
      latitude: coords.lat,
      longitude: coords.lon,
    );
    final risingSign = _signFromLongitude(ascLon);
    return _DeterministicCore(
      sunSign: _signFromLongitude(sunLon),
      moonSign: _signFromLongitude(moonLon),
      risingSign: risingSign,
      houses: _buildEqualHouses(risingSign),
    );
  }

  static void _ensureTimeZones() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    _tzReady = true;
  }

  static DateTime _parseBirthDateTimeToUtc({
    required String birthDate,
    required String birthTime,
    required String birthLocation,
  }) {
    _ensureTimeZones();
    final date = birthDate;
    final time = birthTime;
    final d = date.split('.');
    final t = time.split(':');
    if (d.length != 3 || t.length != 2) return DateTime.now();
    final year = int.tryParse(d[2]) ?? 2000;
    final month = int.tryParse(d[1]) ?? 1;
    final day = int.tryParse(d[0]) ?? 1;
    final hour = int.tryParse(t[0]) ?? 12;
    final minute = int.tryParse(t[1]) ?? 0;

    final tzId = _resolveTimeZoneIdForCity(birthLocation);
    try {
      final location = tz.getLocation(tzId);
      final local = tz.TZDateTime(location, year, month, day, hour, minute);
      return local.toUtc();
    } catch (_) {
      // Last-resort fallback: keep current behavior if timezone id is unknown.
      return DateTime(year, month, day, hour, minute).toUtc();
    }
  }

  static String _resolveTimeZoneIdForCity(String city) {
    final c = _normalizeCityText(city);
    // Turkey-focused mapping; can be expanded with global timezone API later.
    const turkishCities = [
      'istanbul',
      'ankara',
      'izmir',
      'adana',
      'bursa',
      'antalya',
      'konya',
      'mersin',
      'ermenek',
      'karaman',
      'gaziantep',
      'kayseri',
      'samsun',
      'trabzon',
      'eskisehir',
      'diyarbakir',
      'malatya',
      'erzurum',
      'van',
      'mugla',
    ];
    if (turkishCities.any((x) => c.contains(x))) return 'Europe/Istanbul';
    return 'UTC';
  }

  static String _normalizeCityText(String input) {
    var s = input.toLowerCase().trim();

    // Turkish characters -> ASCII for robust matching.
    const trMap = {
      'ı': 'i',
      'i̇': 'i',
      'ğ': 'g',
      'ü': 'u',
      'ş': 's',
      'ö': 'o',
      'ç': 'c',
    };
    trMap.forEach((k, v) => s = s.replaceAll(k, v));

    // Keep only letters/numbers/spaces to handle formats like:
    // "Kadıköy / İstanbul, Türkiye"
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static Future<_GeoPoint> _getCoordinatesFromCity(String city) async {
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/geo/1.0/direct?q=${Uri.encodeComponent(city)}&limit=1&appid=$_weatherApiKey',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && decoded.isNotEmpty) {
          final m = decoded.first as Map<String, dynamic>;
          final lat = (m['lat'] as num?)?.toDouble();
          final lon = (m['lon'] as num?)?.toDouble();
          if (lat != null && lon != null) return _GeoPoint(lat, lon);
        }
      }
    } catch (_) {}
    return const _GeoPoint(37.0, 33.2);
  }

  static double _julianDay(DateTime utc) {
    var y = utc.year;
    var m = utc.month;
    final d = utc.day + (utc.hour / 24.0) + (utc.minute / 1440.0) + (utc.second / 86400.0);
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floorToDouble() +
        (30.6001 * (m + 1)).floorToDouble() +
        d +
        b -
        1524.5;
  }

  static double _normDeg(double x) {
    var v = x % 360.0;
    if (v < 0) v += 360.0;
    return v;
  }

  static double _degToRad(double d) => d * math.pi / 180.0;
  static double _radToDeg(double r) => r * 180.0 / math.pi;

  static double _solarLongitude(DateTime utc) {
    final jd = _julianDay(utc);
    final t = (jd - 2451545.0) / 36525.0;
    final l0 = _normDeg(280.46646 + 36000.76983 * t + 0.0003032 * t * t);
    final m = _normDeg(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
    final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(_degToRad(m)) +
        (0.019993 - 0.000101 * t) * math.sin(_degToRad(2 * m)) +
        0.000289 * math.sin(_degToRad(3 * m));
    return _normDeg(l0 + c);
  }

  static double _lunarLongitude(DateTime utc) {
    final jd = _julianDay(utc);
    final d = jd - 2451545.0;
    final l0 = _normDeg(218.316 + 13.176396 * d);
    final mMoon = _normDeg(134.963 + 13.064993 * d);
    final mSun = _normDeg(357.529 + 0.98560028 * d);
    final dMoon = _normDeg(297.850 + 12.190749 * d);
    final lon = l0 +
        6.289 * math.sin(_degToRad(mMoon)) +
        1.274 * math.sin(_degToRad(2 * dMoon - mMoon)) +
        0.658 * math.sin(_degToRad(2 * dMoon)) +
        0.214 * math.sin(_degToRad(2 * mMoon)) -
        0.186 * math.sin(_degToRad(mSun));
    return _normDeg(lon);
  }

  static double _ascendantLongitude({
    required DateTime utc,
    required double latitude,
    required double longitude,
  }) {
    final jd = _julianDay(utc);
    final t = (jd - 2451545.0) / 36525.0;
    final gmst = _normDeg(
      280.46061837 +
          360.98564736629 * (jd - 2451545.0) +
          0.000387933 * t * t -
          (t * t * t) / 38710000.0,
    );
    final lst = _normDeg(gmst + longitude);
    const eps = 23.439291;
    final phi = _degToRad(latitude);
    final theta = _degToRad(lst);
    final e = _degToRad(eps);
    final numerator = -math.cos(theta);
    final denominator = math.sin(theta) * math.cos(e) + math.tan(phi) * math.sin(e);
    final raw = _normDeg(_radToDeg(math.atan2(numerator, denominator)));
    // atan2-based form above can resolve to Descendant (opposite point) depending
    // on branch selection; Ascendant is the eastern intersection => +180 correction.
    return _normDeg(raw + 180.0);
  }

  static String _signFromLongitude(double lon) {
    const signs = [
      'Aries',
      'Taurus',
      'Gemini',
      'Cancer',
      'Leo',
      'Virgo',
      'Libra',
      'Scorpio',
      'Sagittarius',
      'Capricorn',
      'Aquarius',
      'Pisces',
    ];
    return signs[(lon / 30).floor() % 12];
  }

  static Map<String, HouseCusp> _buildEqualHouses(String risingSign) {
    const signs = [
      'Aries',
      'Taurus',
      'Gemini',
      'Cancer',
      'Leo',
      'Virgo',
      'Libra',
      'Scorpio',
      'Sagittarius',
      'Capricorn',
      'Aquarius',
      'Pisces',
    ];
    final start = signs.indexOf(risingSign);
    final houses = <String, HouseCusp>{};
    for (int i = 0; i < 12; i++) {
      houses['${i + 1}'] = HouseCusp(sign: signs[(start + i) % 12], degree: 0);
    }
    return houses;
  }

  static String _buildNatalChartPrompt({
    required String birthDate,
    required String birthTime,
    required String birthLocation,
  }) {
    return '''
You are a professional astrologer AI with deep knowledge of Western tropical astrology.
TASK: Calculate the complete natal chart for the following birth data.
BIRTH DATA:
- Date: $birthDate (DD.MM.YYYY)
- Time: $birthTime (HH:mm)
- Location: $birthLocation
Return ONLY valid JSON:
{
  "sun_sign": "Leo",
  "moon_sign": "Pisces",
  "rising_sign": "Scorpio",
  "houses": { "1": { "sign": "Scorpio", "degree": 15 } },
  "planets": { "sun": { "sign": "Leo", "house": 10, "degree": 22 } }
}
''';
  }
}

class _DeterministicCore {
  final String sunSign;
  final String moonSign;
  final String risingSign;
  final Map<String, HouseCusp> houses;
  _DeterministicCore({
    required this.sunSign,
    required this.moonSign,
    required this.risingSign,
    required this.houses,
  });
}

class _GeoPoint {
  final double lat;
  final double lon;
  const _GeoPoint(this.lat, this.lon);
}
