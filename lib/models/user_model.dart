import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String? deviceId;
  final String? firebaseUid;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? preferences;

  UserModel({
    required this.id,
    this.deviceId,
    this.firebaseUid,
    required this.createdAt,
    required this.lastSeenAt,
    this.profile,
    this.preferences,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      deviceId: data['deviceId'],
      firebaseUid: data['firebaseUid'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastSeenAt: (data['lastSeenAt'] as Timestamp).toDate(),
      profile: data['profile'],
      preferences: data['preferences'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'firebaseUid': firebaseUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'profile': profile,
      'preferences': preferences,
    };
  }

  UserModel copyWith({
    String? id,
    String? deviceId,
    String? firebaseUid,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    Map<String, dynamic>? profile,
    Map<String, dynamic>? preferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      profile: profile ?? this.profile,
      preferences: preferences ?? this.preferences,
    );
  }
}
