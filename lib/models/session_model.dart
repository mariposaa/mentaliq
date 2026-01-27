import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus {
  waiting,  // Lobi - bekleme
  active,   // 10 dk açık kapı süreci
  locked,   // Kapı kilitlendi
  ended,    // Oturum bitti
}

class SessionModel {
  final String id;
  final String cohortId;
  final SessionStatus status;
  final DateTime? startedAt;
  final DateTime? lockedAt;
  final DateTime? endedAt;
  final int participantCount;

  SessionModel({
    required this.id,
    required this.cohortId,
    required this.status,
    this.startedAt,
    this.lockedAt,
    this.endedAt,
    this.participantCount = 0,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc, String cohortId) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionModel(
      id: doc.id,
      cohortId: cohortId,
      status: _parseStatus(data['status']),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      lockedAt: (data['lockedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      participantCount: data['participantCount'] ?? 0,
    );
  }

  static SessionStatus _parseStatus(String? status) {
    switch (status) {
      case 'WAITING':
        return SessionStatus.waiting;
      case 'ACTIVE':
        return SessionStatus.active;
      case 'LOCKED':
        return SessionStatus.locked;
      case 'ENDED':
        return SessionStatus.ended;
      default:
        return SessionStatus.waiting;
    }
  }

  static String _statusToString(SessionStatus status) {
    switch (status) {
      case SessionStatus.waiting:
        return 'WAITING';
      case SessionStatus.active:
        return 'ACTIVE';
      case SessionStatus.locked:
        return 'LOCKED';
      case SessionStatus.ended:
        return 'ENDED';
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'status': _statusToString(status),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'lockedAt': lockedAt != null ? Timestamp.fromDate(lockedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'participantCount': participantCount,
    };
  }

  SessionModel copyWith({
    String? id,
    String? cohortId,
    SessionStatus? status,
    DateTime? startedAt,
    DateTime? lockedAt,
    DateTime? endedAt,
    int? participantCount,
  }) {
    return SessionModel(
      id: id ?? this.id,
      cohortId: cohortId ?? this.cohortId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      lockedAt: lockedAt ?? this.lockedAt,
      endedAt: endedAt ?? this.endedAt,
      participantCount: participantCount ?? this.participantCount,
    );
  }

  /// Oturumun kilitlenip kilitlenmediğini kontrol et
  bool get isLocked => status == SessionStatus.locked || status == SessionStatus.ended;

  /// 10 dakikalık açık kapı süresi doldu mu?
  bool get shouldLock {
    if (status != SessionStatus.active || startedAt == null) return false;
    final elapsed = DateTime.now().difference(startedAt!);
    return elapsed.inMinutes >= 10;
  }
}
