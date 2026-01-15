import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../config/app_constants.dart';

/// Manages chat history persistence in Firestore
class ChatHistoryService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  
  String? _currentSessionId;
  String? _currentUserId;
  String? _currentCategory;
  
  String? get currentSessionId => _currentSessionId;

  /// Initialize a new chat session
  String startNewSession(String userId, String category) {
    _currentUserId = userId;
    _currentCategory = category;
    _currentSessionId = _uuid.v4();
    
    // Create session document
    _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.chatsCollection)
        .doc(_currentSessionId)
        .set({
          'category': category,
          'createdAt': Timestamp.now(),
          'lastMessageAt': Timestamp.now(),
          'messageCount': 0,
        });
    
    debugPrint('New chat session started: $_currentSessionId');
    return _currentSessionId!;
  }

  /// Resume an existing session
  void resumeSession(String userId, String sessionId, String category) {
    _currentUserId = userId;
    _currentSessionId = sessionId;
    _currentCategory = category;
  }

  /// Save a message to Firestore
  Future<void> saveMessage({
    required String content,
    required bool isUser,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentUserId == null || _currentSessionId == null) {
      debugPrint('Cannot save message: no active session');
      return;
    }

    try {
      final messageId = _uuid.v4();
      final message = ChatMessage(
        id: messageId,
        content: content,
        isUser: isUser,
        category: _currentCategory ?? 'genel',
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      // Save message
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(_currentUserId)
          .collection(AppConstants.chatsCollection)
          .doc(_currentSessionId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .set(message.toFirestore());

      // Update session metadata
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(_currentUserId)
          .collection(AppConstants.chatsCollection)
          .doc(_currentSessionId)
          .update({
            'lastMessageAt': Timestamp.now(),
            'messageCount': FieldValue.increment(1),
          });

      debugPrint('Message saved: $messageId');
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  /// Get all messages for a session
  Future<List<ChatMessage>> getSessionMessages(String userId, String sessionId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.chatsCollection)
          .doc(sessionId)
          .collection(AppConstants.messagesCollection)
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  /// Get all chat sessions for a user
  Future<List<Map<String, dynamic>>> getUserSessions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.chatsCollection)
          .orderBy('lastMessageAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'category': data['category'],
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
          'lastMessageAt': (data['lastMessageAt'] as Timestamp).toDate(),
          'messageCount': data['messageCount'] ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting sessions: $e');
      return [];
    }
  }

  /// Delete a chat session
  Future<void> deleteSession(String userId, String sessionId) async {
    try {
      // Delete all messages first
      final messagesSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.chatsCollection)
          .doc(sessionId)
          .collection(AppConstants.messagesCollection)
          .get();

      for (var doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete session document
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.chatsCollection)
          .doc(sessionId)
          .delete();

      debugPrint('Session deleted: $sessionId');
    } catch (e) {
      debugPrint('Error deleting session: $e');
    }
  }

  /// Clear current session
  void endSession() {
    _currentSessionId = null;
    _currentCategory = null;
  }
}
