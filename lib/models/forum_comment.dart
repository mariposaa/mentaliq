import 'package:cloud_firestore/cloud_firestore.dart';

class ForumComment {
  final String id;
  final String postId;
  final String authorId;
  final String? authorName;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool deleted;

  ForumComment({
    required this.id,
    required this.postId,
    required this.authorId,
    this.authorName,
    required this.text,
    required this.createdAt,
    this.updatedAt,
    this.deleted = false,
  });

  factory ForumComment.fromFirestore(DocumentSnapshot doc, {String? postId}) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ForumComment(
      id: doc.id,
      postId: postId ?? d['postId'] as String? ?? '',
      authorId: d['authorId'] as String? ?? '',
      authorName: d['authorName'] as String?,
      text: d['text'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      deleted: d['deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'deleted': deleted,
    };
  }
}
