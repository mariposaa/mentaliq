import 'package:cloud_firestore/cloud_firestore.dart';

class StyleItem {
  final String id;
  final String imageUrl;
  final String category; // Üst, Alt, Ayakkabı, Aksesuar vb.
  final List<String> tags; // Mavi, Keten, Slim-fit vb.
  final String season; // Yaz, Kış, Bahar
  final String aiDescription;
  final DateTime createdAt;

  StyleItem({
    required this.id,
    required this.imageUrl,
    required this.category,
    required this.tags,
    required this.season,
    required this.aiDescription,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'category': category,
      'tags': tags,
      'season': season,
      'aiDescription': aiDescription,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory StyleItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StyleItem(
      id: doc.id,
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] ?? 'Diğer',
      tags: List<String>.from(data['tags'] ?? []),
      season: data['season'] ?? 'Her mevsim',
      aiDescription: data['aiDescription'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
