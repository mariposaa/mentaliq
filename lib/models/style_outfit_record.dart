import 'package:cloud_firestore/cloud_firestore.dart';

class StyleOutfitRecord {
  final String id;
  final String query;
  final String sourceMode;
  final String weather;
  final String temperature;
  final String recommendation;
  final String? moodTag;
  final DateTime createdAt;
  final List<StyleOutfitRecordItem> outfits;

  const StyleOutfitRecord({
    required this.id,
    required this.query,
    required this.sourceMode,
    required this.weather,
    required this.temperature,
    required this.recommendation,
    required this.createdAt,
    required this.outfits,
    this.moodTag,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'query': query,
      'sourceMode': sourceMode,
      'weather': weather,
      'temperature': temperature,
      'recommendation': recommendation,
      'moodTag': moodTag,
      'createdAt': Timestamp.fromDate(createdAt),
      'outfits': outfits.map((o) => o.toMap()).toList(),
    };
  }

  factory StyleOutfitRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawOutfits = (data['outfits'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => StyleOutfitRecordItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return StyleOutfitRecord(
      id: doc.id,
      query: (data['query'] ?? '').toString(),
      sourceMode: (data['sourceMode'] ?? 'arsiv').toString(),
      weather: (data['weather'] ?? '').toString(),
      temperature: (data['temperature'] ?? '').toString(),
      recommendation: (data['recommendation'] ?? '').toString(),
      moodTag: data['moodTag']?.toString(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      outfits: rawOutfits,
    );
  }
}

class StyleOutfitRecordItem {
  final String title;
  final String? topImageUrl;
  final String? bottomImageUrl;
  final String? shoesImageUrl;
  final String? outerwearImageUrl;

  const StyleOutfitRecordItem({
    required this.title,
    this.topImageUrl,
    this.bottomImageUrl,
    this.shoesImageUrl,
    this.outerwearImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'topImageUrl': topImageUrl,
      'bottomImageUrl': bottomImageUrl,
      'shoesImageUrl': shoesImageUrl,
      'outerwearImageUrl': outerwearImageUrl,
    };
  }

  factory StyleOutfitRecordItem.fromMap(Map<String, dynamic> map) {
    return StyleOutfitRecordItem(
      title: (map['title'] ?? '').toString(),
      topImageUrl: map['topImageUrl']?.toString(),
      bottomImageUrl: map['bottomImageUrl']?.toString(),
      shoesImageUrl: map['shoesImageUrl']?.toString(),
      outerwearImageUrl: map['outerwearImageUrl']?.toString(),
    );
  }

  List<String> previewImages() {
    return [
      if ((topImageUrl ?? '').isNotEmpty) topImageUrl!,
      if ((bottomImageUrl ?? '').isNotEmpty) bottomImageUrl!,
      if ((shoesImageUrl ?? '').isNotEmpty) shoesImageUrl!,
      if ((outerwearImageUrl ?? '').isNotEmpty) outerwearImageUrl!,
    ];
  }
}
