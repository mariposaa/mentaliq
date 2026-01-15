/// Partner Model - stores relationship partner information
class PartnerModel {
  final String id;
  final String name;
  final String? nickname;          // Takma ad
  final String? relationshipType;  // sevgili, eş, nişanlı, vs
  final String? gender;            // kadın, erkek
  final int? age;
  final DateTime? relationshipStart;  // İlişki başlangıç tarihi
  final String? zodiacSign;        // Burç
  final String? mbtiType;          // MBTI tipi
  final String? loveLanguage;      // Sevgi dili (fiziksel dokunuş, hediye, vs)
  final String? communicationStyle; // pasif, agresif, pasif-agresif, asertif
  final List<String>? positiveTraits; // Olumlu özellikleri
  final List<String>? negativeTraits; // Olumsuz özellikleri
  final List<String>? sharedInterests; // Ortak ilgi alanları
  final List<String>? conflictTopics;  // Sık tartışma konuları
  final String? notes;              // Genel notlar
  final DateTime createdAt;
  final DateTime updatedAt;

  PartnerModel({
    required this.id,
    required this.name,
    this.nickname,
    this.relationshipType,
    this.gender,
    this.age,
    this.relationshipStart,
    this.zodiacSign,
    this.mbtiType,
    this.loveLanguage,
    this.communicationStyle,
    this.positiveTraits,
    this.negativeTraits,
    this.sharedInterests,
    this.conflictTopics,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firebase JSON
  factory PartnerModel.fromJson(Map<String, dynamic> json, String id) {
    return PartnerModel(
      id: id,
      name: json['name'] ?? '',
      nickname: json['nickname'],
      relationshipType: json['relationshipType'],
      gender: json['gender'],
      age: json['age'],
      relationshipStart: json['relationshipStart'] != null 
          ? DateTime.tryParse(json['relationshipStart']) 
          : null,
      zodiacSign: json['zodiacSign'],
      mbtiType: json['mbtiType'],
      loveLanguage: json['loveLanguage'],
      communicationStyle: json['communicationStyle'],
      positiveTraits: json['positiveTraits'] != null 
          ? List<String>.from(json['positiveTraits']) 
          : null,
      negativeTraits: json['negativeTraits'] != null 
          ? List<String>.from(json['negativeTraits']) 
          : null,
      sharedInterests: json['sharedInterests'] != null 
          ? List<String>.from(json['sharedInterests']) 
          : null,
      conflictTopics: json['conflictTopics'] != null 
          ? List<String>.from(json['conflictTopics']) 
          : null,
      notes: json['notes'],
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Convert to Firebase JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (nickname != null) 'nickname': nickname,
      if (relationshipType != null) 'relationshipType': relationshipType,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (relationshipStart != null) 'relationshipStart': relationshipStart!.toIso8601String(),
      if (zodiacSign != null) 'zodiacSign': zodiacSign,
      if (mbtiType != null) 'mbtiType': mbtiType,
      if (loveLanguage != null) 'loveLanguage': loveLanguage,
      if (communicationStyle != null) 'communicationStyle': communicationStyle,
      if (positiveTraits != null && positiveTraits!.isNotEmpty) 'positiveTraits': positiveTraits,
      if (negativeTraits != null && negativeTraits!.isNotEmpty) 'negativeTraits': negativeTraits,
      if (sharedInterests != null && sharedInterests!.isNotEmpty) 'sharedInterests': sharedInterests,
      if (conflictTopics != null && conflictTopics!.isNotEmpty) 'conflictTopics': conflictTopics,
      if (notes != null) 'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create copy with updates
  PartnerModel copyWith({
    String? name,
    String? nickname,
    String? relationshipType,
    String? gender,
    int? age,
    DateTime? relationshipStart,
    String? zodiacSign,
    String? mbtiType,
    String? loveLanguage,
    String? communicationStyle,
    List<String>? positiveTraits,
    List<String>? negativeTraits,
    List<String>? sharedInterests,
    List<String>? conflictTopics,
    String? notes,
  }) {
    return PartnerModel(
      id: id,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      relationshipType: relationshipType ?? this.relationshipType,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      relationshipStart: relationshipStart ?? this.relationshipStart,
      zodiacSign: zodiacSign ?? this.zodiacSign,
      mbtiType: mbtiType ?? this.mbtiType,
      loveLanguage: loveLanguage ?? this.loveLanguage,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      positiveTraits: positiveTraits ?? this.positiveTraits,
      negativeTraits: negativeTraits ?? this.negativeTraits,
      sharedInterests: sharedInterests ?? this.sharedInterests,
      conflictTopics: conflictTopics ?? this.conflictTopics,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Generate AI context string for prompts
  String toAIContext() {
    final parts = <String>[];
    
    parts.add('Partner: $name');
    if (relationshipType != null) parts.add('İlişki: $relationshipType');
    if (gender != null) parts.add('Cinsiyet: $gender');
    if (age != null) parts.add('Yaş: $age');
    if (zodiacSign != null) parts.add('Burç: $zodiacSign');
    if (mbtiType != null) parts.add('MBTI: $mbtiType');
    if (loveLanguage != null) parts.add('Sevgi dili: $loveLanguage');
    if (communicationStyle != null) parts.add('İletişim tarzı: $communicationStyle');
    if (positiveTraits != null && positiveTraits!.isNotEmpty) {
      parts.add('Olumlu özellikleri: ${positiveTraits!.join(", ")}');
    }
    if (negativeTraits != null && negativeTraits!.isNotEmpty) {
      parts.add('Olumsuz özellikleri: ${negativeTraits!.join(", ")}');
    }
    if (conflictTopics != null && conflictTopics!.isNotEmpty) {
      parts.add('Sık tartışma konuları: ${conflictTopics!.join(", ")}');
    }
    
    return parts.join('\n');
  }
}
