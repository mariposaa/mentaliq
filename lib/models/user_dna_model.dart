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
    if (mbti != null) baseInfo.add('Kişilik: $mbti');
    if (relationshipStatus != null) baseInfo.add('İlişki: $relationshipStatus');
    if (lifeStage != null) baseInfo.add('Yaşam evresi: $lifeStage');
    if (baseInfo.isNotEmpty) parts.add('[KİMLİK]: ${baseInfo.join(" | ")}');
    
    // Doğum Bilgileri (Astroloji için)
    final birthInfo = <String>[];
    if (birthDate != null) birthInfo.add('Tarih: $birthDate');
    if (birthTime != null) birthInfo.add('Saat: $birthTime');
    if (birthLocation != null) birthInfo.add('Yer: $birthLocation');
    if (birthInfo.isNotEmpty) parts.add('[DOĞUM]: ${birthInfo.join(" | ")}');

    // Psikolojik Derinlik
    if (personalityTraits != null && personalityTraits!.isNotEmpty) {
      parts.add('[ÖZELLİKLER]: ${personalityTraits!.join(", ")}');
    }
    if (traumas != null && traumas!.isNotEmpty) {
      parts.add('[TRAVMALAR]: ${traumas!.join(", ")}');
    }
    if (fears != null && fears!.isNotEmpty) {
      parts.add('[KORKULAR]: ${fears!.join(", ")}');
    }
    if (triggers != null && triggers!.isNotEmpty) {
      parts.add('[TETİKLEYİCİLER]: ${triggers!.join(", ")}');
    }
    if (strengths != null && strengths!.isNotEmpty) {
      parts.add('[GÜÇLER]: ${strengths!.join(", ")}');
    }
    if (goals != null && goals!.isNotEmpty) {
      parts.add('[HEDEFLER]: ${goals!.join(", ")}');
    }
    if (coreValues != null && coreValues!.isNotEmpty) {
      parts.add('[DEĞERLER]: ${coreValues!.join(", ")}');
    }
    if (hobbies != null && hobbies!.isNotEmpty) {
      parts.add('[HOBİLER]: ${hobbies!.join(", ")}');
    }

    // İlişkisel Detaylar
    if (dynamicRelationships != null && dynamicRelationships!.isNotEmpty) {
      final relStrs = dynamicRelationships!.entries.map((e) => '${e.key}: ${e.value}');
      parts.add('[İlişki Detayları]: ${relStrs.join(", ")}');
    }

    if (parts.isEmpty) return '';
    
    return '''
### KULLANICI MASTER DNA (BU BİLGİLERİ BAĞLAMDA KULLAN AMA YÜZÜNE OKUMA):
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
        (coreValues == null || coreValues!.isEmpty) &&
        (fears == null || fears!.isEmpty) &&
        (hobbies == null || hobbies!.isEmpty) &&
        lifeStage == null &&
        relationshipStatus == null &&
        (traumas == null || traumas!.isEmpty) &&
        (triggers == null || triggers!.isEmpty) &&
        (strengths == null || strengths!.isEmpty) &&
        (goals == null || goals!.isEmpty);
  }
}

