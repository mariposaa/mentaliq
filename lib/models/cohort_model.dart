import 'package:cloud_firestore/cloud_firestore.dart';

/// Cohort durumu
enum CohortStatus { active, dissolved }

class CohortModel {
  final String id;
  final List<String> members;
  final String topic;
  final String groupName;
  final String timezone;
  final String language; // Dil kodu (tr, en, de vs.)
  final DateTime createdAt;
  final DateTime? nextSessionTime;
  final int totalSessions;
  final int memberCount;
  final CohortStatus status;
  final Map<String, int> memberActivity; // userId -> son katıldığı oturum no
  final DateTime? dissolvedAt;

  CohortModel({
    required this.id,
    required this.members,
    required this.topic,
    required this.groupName,
    required this.timezone,
    this.language = 'tr',
    required this.createdAt,
    this.nextSessionTime,
    this.totalSessions = 0,
    required this.memberCount,
    this.status = CohortStatus.active,
    this.memberActivity = const {},
    this.dissolvedAt,
  });

  /// Grup aktif mi?
  bool get isActive => status == CohortStatus.active;

  /// Grup dağılmış mı?
  bool get isDissolved => status == CohortStatus.dissolved;

  /// 5 oturum tamamlandı mı?
  bool get hasReachedSessionLimit => totalSessions >= 5;

  factory CohortModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CohortModel(
      id: doc.id,
      members: List<String>.from(data['members'] ?? []),
      topic: data['topic'] ?? '',
      groupName: data['groupName'] ?? '',
      timezone: data['timezone'] ?? '+3',
      language: data['language'] ?? 'tr',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nextSessionTime: (data['nextSessionTime'] as Timestamp?)?.toDate(),
      totalSessions: data['totalSessions'] ?? 0,
      memberCount: data['memberCount'] ?? 0,
      status: _parseStatus(data['status']),
      memberActivity: Map<String, int>.from(data['memberActivity'] ?? {}),
      dissolvedAt: (data['dissolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  static CohortStatus _parseStatus(String? status) {
    if (status == 'dissolved') return CohortStatus.dissolved;
    return CohortStatus.active;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'members': members,
      'topic': topic,
      'groupName': groupName,
      'timezone': timezone,
      'language': language,
      'createdAt': Timestamp.fromDate(createdAt),
      'nextSessionTime': nextSessionTime != null 
          ? Timestamp.fromDate(nextSessionTime!) 
          : null,
      'totalSessions': totalSessions,
      'memberCount': memberCount,
      'status': status == CohortStatus.dissolved ? 'dissolved' : 'active',
      'memberActivity': memberActivity,
      'dissolvedAt': dissolvedAt != null 
          ? Timestamp.fromDate(dissolvedAt!) 
          : null,
    };
  }

  CohortModel copyWith({
    String? id,
    List<String>? members,
    String? topic,
    String? groupName,
    String? timezone,
    String? language,
    DateTime? createdAt,
    DateTime? nextSessionTime,
    int? totalSessions,
    int? memberCount,
    CohortStatus? status,
    Map<String, int>? memberActivity,
    DateTime? dissolvedAt,
  }) {
    return CohortModel(
      id: id ?? this.id,
      members: members ?? this.members,
      topic: topic ?? this.topic,
      groupName: groupName ?? this.groupName,
      timezone: timezone ?? this.timezone,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      nextSessionTime: nextSessionTime ?? this.nextSessionTime,
      totalSessions: totalSessions ?? this.totalSessions,
      memberCount: memberCount ?? this.memberCount,
      status: status ?? this.status,
      memberActivity: memberActivity ?? this.memberActivity,
      dissolvedAt: dissolvedAt ?? this.dissolvedAt,
    );
  }
}
