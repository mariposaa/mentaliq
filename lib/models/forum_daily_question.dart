import 'package:cloud_firestore/cloud_firestore.dart';

/// Günün sorusu - alan oluşturuldu, kim dolduracak vb. sonra karar verilecek.
class ForumDailyQuestion {
  final String id;
  final String language;
  final String text;
  final DateTime date;
  final DateTime? createdAt;

  ForumDailyQuestion({
    required this.id,
    required this.language,
    required this.text,
    required this.date,
    this.createdAt,
  });

  factory ForumDailyQuestion.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ForumDailyQuestion(
      id: doc.id,
      language: d['language'] as String? ?? 'tr',
      text: d['text'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'language': language,
      'text': text,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }
}
