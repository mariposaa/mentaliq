import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  message,  // Normal kullanıcı/AI mesajı
  system,   // Sistem bildirimi (kapı kilitlendi vs.)
  emoji,    // Emoji tepkisi
}

class CampfireMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final bool isAI;

  CampfireMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.type = MessageType.message,
    this.isAI = false,
  });

  factory CampfireMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CampfireMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Anonim',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: _parseType(data['type']),
      isAI: data['senderId'] == 'ai_moderator',
    );
  }

  static MessageType _parseType(String? type) {
    switch (type) {
      case 'system':
        return MessageType.system;
      case 'emoji':
        return MessageType.emoji;
      default:
        return MessageType.message;
    }
  }

  static String _typeToString(MessageType type) {
    switch (type) {
      case MessageType.system:
        return 'system';
      case MessageType.emoji:
        return 'emoji';
      case MessageType.message:
        return 'message';
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': _typeToString(type),
    };
  }

  /// AI moderatör mesajı oluştur
  factory CampfireMessage.fromAI(String content, {MessageType type = MessageType.message}) {
    return CampfireMessage(
      id: '',
      senderId: 'ai_moderator',
      senderName: 'Ateş Bekçisi',
      content: content,
      timestamp: DateTime.now(),
      type: type,
      isAI: true,
    );
  }

  /// Sistem mesajı oluştur
  factory CampfireMessage.system(String content) {
    return CampfireMessage(
      id: '',
      senderId: 'system',
      senderName: 'Sistem',
      content: content,
      timestamp: DateTime.now(),
      type: MessageType.system,
      isAI: false,
    );
  }
}
