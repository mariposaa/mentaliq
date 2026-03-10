import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'user_dna_service.dart';

class CrisisHotlineEntry {
  final String region;
  final String title;
  final String phone;
  final String? website;

  const CrisisHotlineEntry({
    required this.region,
    required this.title,
    required this.phone,
    this.website,
  });
}

class CrisisHotlineService {
  static const Map<String, CrisisHotlineEntry> _byCountry = {
    'TR': CrisisHotlineEntry(
      region: 'TR',
      title: 'Turkey Emergency',
      phone: '112',
      website: 'https://www.112.gov.tr/',
    ),
    'US': CrisisHotlineEntry(
      region: 'US',
      title: '988 Suicide & Crisis Lifeline',
      phone: '988',
      website: 'https://988lifeline.org/',
    ),
    'GB': CrisisHotlineEntry(
      region: 'GB',
      title: 'Samaritans',
      phone: '116123',
      website: 'https://www.samaritans.org/',
    ),
    'DE': CrisisHotlineEntry(
      region: 'DE',
      title: 'TelefonSeelsorge',
      phone: '08001110111',
      website: 'https://www.telefonseelsorge.de/',
    ),
    'ES': CrisisHotlineEntry(
      region: 'ES',
      title: 'Línea 024',
      phone: '024',
      website: 'https://www.sanidad.gob.es/',
    ),
    'SA': CrisisHotlineEntry(
      region: 'SA',
      title: 'Saudi Emergency',
      phone: '999',
      website: null,
    ),
    'FR': CrisisHotlineEntry(
      region: 'FR',
      title: 'France Emergency',
      phone: '3114',
      website: 'https://3114.fr/',
    ),
    'IT': CrisisHotlineEntry(
      region: 'IT',
      title: 'Telefono Amico Italia',
      phone: '0223272327',
      website: 'https://www.telefonoamico.it/',
    ),
    'NL': CrisisHotlineEntry(
      region: 'NL',
      title: '113 Suicide Prevention',
      phone: '113',
      website: 'https://www.113.nl/',
    ),
    'SE': CrisisHotlineEntry(
      region: 'SE',
      title: 'Mind Självmordslinjen',
      phone: '90101',
      website: 'https://mind.se/',
    ),
    'NO': CrisisHotlineEntry(
      region: 'NO',
      title: 'Mental Helse',
      phone: '116123',
      website: 'https://mentalhelse.no/',
    ),
    'CA': CrisisHotlineEntry(
      region: 'CA',
      title: 'Talk Suicide Canada',
      phone: '988',
      website: 'https://talksuicide.ca/',
    ),
    'AU': CrisisHotlineEntry(
      region: 'AU',
      title: 'Lifeline Australia',
      phone: '131114',
      website: 'https://www.lifeline.org.au/',
    ),
    'IN': CrisisHotlineEntry(
      region: 'IN',
      title: 'Tele-MANAS',
      phone: '14416',
      website: 'https://telemanas.mohfw.gov.in/',
    ),
    'BR': CrisisHotlineEntry(
      region: 'BR',
      title: 'CVV',
      phone: '188',
      website: 'https://www.cvv.org.br/',
    ),
    'MX': CrisisHotlineEntry(
      region: 'MX',
      title: 'Línea de la Vida',
      phone: '8009112000',
      website: 'https://www.gob.mx/salud/lineadelavida',
    ),
  };

  static const Map<String, String> _languageDefaultCountry = {
    'tr': 'TR',
    'en': 'US',
    'de': 'DE',
    'es': 'ES',
    'ar': 'SA',
  };

  static const Map<String, String> countryNames = {
    'TR': 'Turkey',
    'US': 'United States',
    'GB': 'United Kingdom',
    'DE': 'Germany',
    'ES': 'Spain',
    'SA': 'Saudi Arabia',
    'FR': 'France',
    'IT': 'Italy',
    'NL': 'Netherlands',
    'SE': 'Sweden',
    'NO': 'Norway',
    'CA': 'Canada',
    'AU': 'Australia',
    'IN': 'India',
    'BR': 'Brazil',
    'MX': 'Mexico',
  };

  static List<String> get supportedCountryCodes => _byCountry.keys.toList()..sort();

  static Future<String> _resolveCountryCode() async {
    try {
      final profile = await AuthService.getProfile();
      final profileCode = (profile?['countryCode'] as String?)?.toUpperCase();
      if (profileCode != null && profileCode.length == 2) return profileCode;
    } catch (_) {}

    final lang = (UserDNAService.currentDNA?.language ?? 'en').toLowerCase();
    return _languageDefaultCountry[lang] ?? 'US';
  }

  static Future<String> getCurrentCountryCode() async {
    return _resolveCountryCode();
  }

  static Future<void> setCurrentUserCountryCode(String countryCode) async {
    final code = countryCode.trim().toUpperCase();
    if (!_byCountry.containsKey(code)) return;
    await AuthService.updateProfile({'countryCode': code});
  }

  static Future<List<CrisisHotlineEntry>> getHotlinesForCurrentUser() async {
    final country = await _resolveCountryCode();
    final primary = _byCountry[country] ?? _byCountry['US']!;
    const globalFallback = CrisisHotlineEntry(
      region: 'GLOBAL',
      title: 'Find A Helpline',
      phone: 'N/A',
      website: 'https://findahelpline.com/',
    );
    return [primary, globalFallback];
  }

  static Future<bool> callHotline(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) return false;
    final uri = Uri.parse('tel:$normalized');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('CrisisHotlineService call error: $e');
      return false;
    }
  }

  static Future<bool> openWebsite(String url) async {
    final uri = Uri.parse(url);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('CrisisHotlineService website error: $e');
      return false;
    }
  }
}
