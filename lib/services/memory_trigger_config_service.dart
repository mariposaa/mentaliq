import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'admin_role_service.dart';
import 'auth_service.dart';

class MemoryTriggerConfig {
  final List<String> crisis;
  final List<String> relationship;
  final List<String> addiction;
  final List<String> selfworth;
  final List<String> explicit;

  const MemoryTriggerConfig({
    required this.crisis,
    required this.relationship,
    required this.addiction,
    required this.selfworth,
    required this.explicit,
  });

  static const MemoryTriggerConfig defaults = MemoryTriggerConfig(
    crisis: [
      'panik',
      'kriz',
      'dayanamiyorum',
      'dayanamıyorum',
      'nefes alamiyorum',
      'nefes alamıyorum',
      'çok kötüyüm',
      'cok kotuyum',
      'intihar',
      'urgent',
      'help now',
    ],
    relationship: [
      'ayrildik',
      'ayrıldık',
      'ayrildim',
      'ayrıldım',
      'ghost',
      'aldatti',
      'aldattı',
      'eski sevgili',
      'partnerim',
      'ilişki',
      'iliski',
    ],
    addiction: [
      'bozdum',
      'nuks',
      'nüks',
      'dayanamadim',
      'dayanamadım',
      'tetiklendim',
      'icmek istiyorum',
      'içmek istiyorum',
      'kumar oynadim',
      'sigara ictim',
      'sigara içtim',
    ],
    selfworth: [
      'degersizim',
      'değersizim',
      'yetersizim',
      'ise yaramiyorum',
      'işe yaramıyorum',
      'kendimden nefret',
      'berbatim',
    ],
    explicit: [
      'gecen konusma',
      'geçen konuşma',
      'hatirliyor musun',
      'hatırlıyor musun',
      'once soyledigim',
      'önce söylediğim',
      'bunu hatirlat',
      'bunu hatırlat',
    ],
  );

  factory MemoryTriggerConfig.fromMap(Map<String, dynamic> map) {
    List<String> parseList(String key, List<String> fallback) {
      final raw = map[key];
      if (raw is List) {
        final values = raw
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        if (values.isNotEmpty) return values;
      }
      return fallback;
    }

    return MemoryTriggerConfig(
      crisis: parseList('crisis', defaults.crisis),
      relationship: parseList('relationship', defaults.relationship),
      addiction: parseList('addiction', defaults.addiction),
      selfworth: parseList('selfworth', defaults.selfworth),
      explicit: parseList('explicit', defaults.explicit),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'crisis': crisis,
      'relationship': relationship,
      'addiction': addiction,
      'selfworth': selfworth,
      'explicit': explicit,
    };
  }
}

class MemoryTriggerConfigService {
  static MemoryTriggerConfig? _cached;
  static DateTime? _lastFetchedAt;
  static const Duration _cacheTtl = Duration(minutes: 5);

  static Future<MemoryTriggerConfig> getConfig({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final isFresh = _cached != null &&
        _lastFetchedAt != null &&
        now.difference(_lastFetchedAt!) < _cacheTtl;

    if (!forceRefresh && isFresh) return _cached!;

    try {
      final doc = await AuthService.firestore
          .collection('app_config')
          .doc('memory_triggers')
          .get();

      if (!doc.exists || doc.data() == null) {
        _cached = MemoryTriggerConfig.defaults;
        _lastFetchedAt = now;
        return _cached!;
      }

      _cached = MemoryTriggerConfig.fromMap(doc.data()!);
      _lastFetchedAt = now;
      return _cached!;
    } catch (e) {
      debugPrint('MemoryTriggerConfigService getConfig error: $e');
      return _cached ?? MemoryTriggerConfig.defaults;
    }
  }

  static Future<bool> saveConfig(MemoryTriggerConfig config) async {
    try {
      final isAdmin = await AdminRoleService.isCurrentUserAdmin();
      if (!isAdmin) return false;

      await AuthService.firestore.collection('app_config').doc('memory_triggers').set({
        ...config.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': AuthService.userId,
      }, SetOptions(merge: true));

      _cached = config;
      _lastFetchedAt = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('MemoryTriggerConfigService saveConfig error: $e');
      return false;
    }
  }
}
