// lib/models/user_dna_model.dart
// Kullanıcının Dijital Kimliği - Tüm kategorilerde kullanılır

class UserDNAModel {
  final int? age;
  final String? zodiac;
  final String? profession;
  final String? mbti;
  final List<String>? personalityTraits;
  final List<String>? coreValues;
  final List<String>? fears;
  final List<String>? hobbies;
  final String? lifeStage;
  final String? relationshipStatus;
  final String? birthDate; // format: DD.MM.YYYY
  final String? birthTime; // format: HH:mm
  final String? birthLocation; // city name
  final List<String>? traumas;
  final List<String>? triggers;
  final List<String>? strengths;
  final List<String>? goals;
  final Map<String, dynamic>? dynamicRelationships;
  final DateTime? lastUpdated;
  final double? willpowerIndex; // Global willpower
  final List<AddictionDna>? activeAddictions; // The new main list
  final List<InterventionLog>? recentInterventions;
  final String? language; // tr, en, de, es, ar - uygulama dili (UserDNA'da kayıtlı)

  UserDNAModel({
    this.age,
    this.zodiac,
    this.profession,
    this.mbti,
    this.personalityTraits,
    this.coreValues,
    this.fears,
    this.hobbies,
    this.lifeStage,
    this.relationshipStatus,
    this.birthDate,
    this.birthTime,
    this.birthLocation,
    this.traumas,
    this.triggers,
    this.strengths,
    this.goals,
    this.dynamicRelationships,
    this.lastUpdated,
    this.willpowerIndex,
    this.activeAddictions,
    this.recentInterventions,
    this.language,
  });

  /// Firebase'den parse et
  factory UserDNAModel.fromFirestore(Map<String, dynamic> data) {
    return UserDNAModel(
      age: data['age'] as int?,
      zodiac: data['zodiac'] as String?,
      profession: data['profession'] as String?,
      mbti: data['mbti'] as String?,
      personalityTraits: _parseList(data['personality_traits']),
      coreValues: _parseList(data['core_values']),
      fears: _parseList(data['fears']),
      hobbies: _parseList(data['hobbies']),
      lifeStage: data['life_stage'] as String?,
      relationshipStatus: data['relationship_status'] as String?,
      birthDate: data['birth_date'] as String?,
      birthTime: data['birth_time'] as String?,
      birthLocation: data['birth_location'] as String?,
      traumas: _parseList(data['traumas']),
      triggers: _parseList(data['triggers']),
      strengths: _parseList(data['strengths']),
      goals: _parseList(data['goals']),
      dynamicRelationships: data['dynamic_relationships'] != null 
          ? Map<String, dynamic>.from(data['dynamic_relationships']) 
          : null,
      lastUpdated: data['last_updated'] != null
          ? DateTime.parse(data['last_updated'] as String)
          : null,
      willpowerIndex: (data['willpower_index'] as num?)?.toDouble(),
      activeAddictions: data['active_addictions'] != null
          ? (data['active_addictions'] as List).map((e) => AddictionDna.fromMap(e)).toList()
          : null,
      recentInterventions: data['recent_interventions'] != null
          ? (data['recent_interventions'] as List).map((e) => InterventionLog.fromMap(e)).toList()
          : null,
      language: data['language'] as String?,
    );
  }

  static List<String>? _parseList(dynamic list) {
    if (list == null) return null;
    return (list as List<dynamic>).map((e) => e.toString()).toList();
  }

  /// Firebase'e kaydet
  Map<String, dynamic> toFirestore() {
    return {
      if (age != null) 'age': age,
      if (zodiac != null) 'zodiac': zodiac,
      if (profession != null) 'profession': profession,
      if (mbti != null) 'mbti': mbti,
      if (personalityTraits != null && personalityTraits!.isNotEmpty)
        'personality_traits': personalityTraits,
      if (coreValues != null && coreValues!.isNotEmpty)
        'core_values': coreValues,
      if (fears != null && fears!.isNotEmpty) 'fears': fears,
      if (hobbies != null && hobbies!.isNotEmpty) 'hobbies': hobbies,
      if (lifeStage != null) 'life_stage': lifeStage,
      if (relationshipStatus != null) 'relationship_status': relationshipStatus,
      if (birthDate != null) 'birth_date': birthDate,
      if (birthTime != null) 'birth_time': birthTime,
      if (birthLocation != null) 'birth_location': birthLocation,
      if (traumas != null && traumas!.isNotEmpty) 'traumas': traumas,
      if (triggers != null && triggers!.isNotEmpty) 'triggers': triggers,
      if (strengths != null && strengths!.isNotEmpty) 'strengths': strengths,
      if (goals != null && goals!.isNotEmpty) 'goals': goals,
      if (dynamicRelationships != null && dynamicRelationships!.isNotEmpty)
        'dynamic_relationships': dynamicRelationships,
      if (willpowerIndex != null) 'willpower_index': willpowerIndex,
      if (activeAddictions != null) 'active_addictions': activeAddictions!.map((e) => e.toMap()).toList(),
      if (recentInterventions != null) 'recent_interventions': recentInterventions!.map((e) => e.toMap()).toList(),
      if (language != null && language!.isNotEmpty) 'language': language,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  /// Merge with new data
  UserDNAModel merge(UserDNAModel updates) {
    return UserDNAModel(
      age: updates.age ?? age,
      zodiac: updates.zodiac ?? zodiac,
      profession: updates.profession ?? profession,
      mbti: updates.mbti ?? mbti,
      personalityTraits: _mergeList(personalityTraits, updates.personalityTraits),
      coreValues: _mergeList(coreValues, updates.coreValues),
      fears: _mergeList(fears, updates.fears),
      hobbies: _mergeList(hobbies, updates.hobbies),
      lifeStage: updates.lifeStage ?? lifeStage,
      relationshipStatus: updates.relationshipStatus ?? relationshipStatus,
      birthDate: updates.birthDate ?? birthDate,
      birthTime: updates.birthTime ?? birthTime,
      birthLocation: updates.birthLocation ?? birthLocation,
      traumas: _mergeList(traumas, updates.traumas),
      triggers: _mergeList(triggers, updates.triggers),
      strengths: _mergeList(strengths, updates.strengths),
      goals: _mergeList(goals, updates.goals),
      dynamicRelationships: updates.dynamicRelationships != null
          ? {...?dynamicRelationships, ...updates.dynamicRelationships!}
          : dynamicRelationships,
      lastUpdated: DateTime.now(),
      willpowerIndex: updates.willpowerIndex ?? willpowerIndex,
      activeAddictions: updates.activeAddictions ?? activeAddictions,
      recentInterventions: updates.recentInterventions ?? recentInterventions,
      language: updates.language ?? language,
    );
  }

  List<String>? _mergeList(List<String>? existing, List<String>? updates) {
    if (updates == null || updates.isEmpty) return existing;
    if (existing == null || existing.isEmpty) return updates;
    
    final merged = <String>{...existing, ...updates};
    return merged.toList();
  }

  /// AI Prompt için formatla
  String toPromptContext() {
    if (_isEmpty()) return '';

    final parts = <String>[];
    
    // Temel Bilgiler
    final baseInfo = <String>[];
    if (age != null) baseInfo.add('$age yaşında');
    if (zodiac != null) baseInfo.add('$zodiac burcu');
    if (profession != null) baseInfo.add('Meslek: $profession');
    if (willpowerIndex != null) baseInfo.add('Global İrade Gücü: ${(willpowerIndex! * 100).toInt()}%');
    if (baseInfo.isNotEmpty) parts.add('[KİMLİK]: ${baseInfo.join(" | ")}');

    // Bağımlılık Profili (General & Gambling)
    if (activeAddictions != null && activeAddictions!.isNotEmpty) {
      for (var a in activeAddictions!) {
        parts.add('[MÜCADELE: ${a.id.toUpperCase()}]');
        parts.add(' - Temiz Gün: ${a.streakDays}');
        parts.add(' - İrade Puanı: ${a.willpowerIndex}');
        if (a.id == 'gambling') {
             parts.add(' - KAYIP / RİSK VERİLERİ (AUDITOR İÇİN):');
             parts.add('   * Toplam Kayıp: ${a.totalLostCapital}');
             parts.add('   * Günlük Ortalama Bahis: ${a.averageDailyBet}');
        }
        if (a.currentMission.isNotEmpty) {
           parts.add(' - Aktif Görev: ${a.currentMission} (Tamamlandı mı: ${a.isMissionCompleted})');
        }
      }
    }

    // Psikolojik Derinlik
    if (personalityTraits != null && personalityTraits!.isNotEmpty) {
      parts.add('[ÖZELLİKLER]: ${personalityTraits!.join(", ")}');
    }
    if (traumas != null && traumas!.isNotEmpty) {
      parts.add('[TRAVMALAR]: ${traumas!.join(", ")}');
    }
    if (triggers != null && triggers!.isNotEmpty) {
      parts.add('[TETİKLEYİCİLER]: ${triggers!.join(", ")}');
    }
    if (strengths != null && strengths!.isNotEmpty) {
      parts.add('[GÜÇLER]: ${strengths!.join(", ")}');
    }
    if (coreValues != null && coreValues!.isNotEmpty) {
      parts.add('[DEĞERLER]: ${coreValues!.join(", ")}');
    }

    if (parts.isEmpty) return '';
    
    return '''
### KULLANICI MASTER DNA (BU BİLGİLERİ BAĞLAMDA KULLAN, YÜZÜNE VURMA):
${parts.join('\n')}
-----------------------------------
''';
  }

  bool _isEmpty() {
    return age == null &&
        zodiac == null &&
        profession == null &&
        mbti == null &&
        (personalityTraits == null || personalityTraits!.isEmpty) &&
        (activeAddictions == null || activeAddictions!.isEmpty);
  }
}



class InterventionLog {
  final DateTime timestamp;
  final String addictionType;
  final String trigger;
  final String outcome;

  InterventionLog({
    required this.timestamp,
    required this.addictionType,
    required this.trigger,
    required this.outcome,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'addiction_type': addictionType,
      'trigger': trigger,
      'outcome': outcome,
    };
  }

  factory InterventionLog.fromMap(Map<String, dynamic> map) {
    return InterventionLog(
      timestamp: DateTime.parse(map['timestamp']),
      addictionType: map['addiction_type'] ?? '',
      trigger: map['trigger'] ?? '',
      outcome: map['outcome'] ?? '',
    );
  }
}

class AddictionDna {
  final String id; // 'gambling', 'smoking', etc.
  final String type; // 'behavioral', 'substance'
  final double willpowerIndex;
  
  // KUMAR ÖZEL (The Auditor Verileri)
  final double totalLostCapital; 
  final double averageDailyBet; 
  final List<DateTime> highRiskDays; 
  
  // GENEL / DİĞER (Bio-Hacker/Architect Verileri)
  final int streakDays;
  final List<String> triggers;
  final DateTime? lastRelapse;
  final String currentMission;
  final bool isMissionCompleted;

  AddictionDna({
    required this.id,
    required this.type,
    this.willpowerIndex = 0.5,
    this.totalLostCapital = 0.0,
    this.averageDailyBet = 0.0,
    this.highRiskDays = const [],
    this.streakDays = 0,
    this.triggers = const [],
    this.lastRelapse,
    this.currentMission = '',
    this.isMissionCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'willpower_index': willpowerIndex,
      'total_lost_capital': totalLostCapital,
      'average_daily_bet': averageDailyBet,
      'high_risk_days': highRiskDays.map((d) => d.toIso8601String()).toList(),
      'streak_days': streakDays,
      'triggers': triggers,
      'last_relapse': lastRelapse?.toIso8601String(),
      'current_mission': currentMission,
      'is_mission_completed': isMissionCompleted,
    };
  }

  factory AddictionDna.fromMap(Map<String, dynamic> map) {
    return AddictionDna(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      willpowerIndex: (map['willpower_index'] as num?)?.toDouble() ?? 0.5,
      totalLostCapital: (map['total_lost_capital'] as num?)?.toDouble() ?? 0.0,
      averageDailyBet: (map['average_daily_bet'] as num?)?.toDouble() ?? 0.0,
      highRiskDays: map['high_risk_days'] != null 
          ? (map['high_risk_days'] as List).map((e) => DateTime.parse(e)).toList() 
          : [],
      streakDays: map['streak_days'] ?? 0,
      triggers: List<String>.from(map['triggers'] ?? []),
      lastRelapse: map['last_relapse'] != null ? DateTime.parse(map['last_relapse']) : null,
      currentMission: map['current_mission'] ?? '',
      isMissionCompleted: map['is_mission_completed'] ?? false,
    );
  }
}
