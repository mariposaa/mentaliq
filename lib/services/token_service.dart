import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

enum TokenConsumeResult { successPaid, successFree, insufficient, error }

/// Static token service - NeyBu style
class TokenService {
  static const int _initialTokens = 100;
  static const int _messageTokenCost = 5;
  static const int _analysisTokenCost = 15; // İlişki analizi bedeli
  static const int _relationshipAnalysisTokenCost = 30; // Derin ilişki analizi bedeli
  static const int _astroHudTokenCost = 10; // Astroloji HUD bedeli
  static const int _astroCardTokenCost = 10; // Paylaşım kartı bedeli
  static const int _styleStrategyTokenCost = 10; // Stil stratejisi bedeli
  static const int _dreamTokenCost = 20; // Rüya analizi bedeli
  static const int _campfireJoinTokenCost = 10; // Kamp atesi giris bedeli
  static const int _campfireSessionTokenCost = 20; // Kamp atesi oturum bedeli
  static const int _astroGuidanceTokenCost = 15; // Günlük astroloji yönerge bedeli
  static const int _adRewardTokens = 30;
  static const int _addictionUseTokenCost = 5;
  static const String _addictionFirstUseField = 'addictionFirstUseConsumed';

  /// Get current token balance
  static Future<int> getBalance() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        debugPrint('TokenService: userId null - returning initial');
        return _initialTokens;
      }

      final doc = await AuthService.firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!doc.exists || doc.data()?['tokens'] == null) {
        // New user - initialize tokens
        await _initializeTokens(userId);
        return _initialTokens;
      }

      final balance = doc.data()?['tokens'];
      if (balance is int) return balance;
      if (balance is double) return balance.toInt();
      return _initialTokens;
    } catch (e) {
      debugPrint('TokenService error: $e');
      return _initialTokens;  // Return default on error
    }
  }

  /// Initialize tokens for new user
  static Future<void> _initializeTokens(String userId) async {
    try {
      await AuthService.firestore.collection('users').doc(userId).set({
        'tokens': _initialTokens,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Token initialized for user: $userId');
    } catch (e) {
      debugPrint('Error initializing tokens: $e');
    }
  }

  /// Initialize on app start
  static Future<void> initialize() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return;

      final doc = await AuthService.firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!doc.exists || doc.data()?['tokens'] == null) {
        await _initializeTokens(userId);
      }
      
      final balance = await getBalance();
      debugPrint('Token service ready: $balance tokens');
    } catch (e) {
      debugPrint('Error in token initialization: $e');
    }
  }

  /// Use tokens for message (returns true if successful)
  static Future<bool> useTokensForMessage() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      final balance = await getBalance();
      if (balance < _messageTokenCost) {
        debugPrint('Insufficient tokens: $balance < $_messageTokenCost');
        return false;
      }

      await AuthService.firestore.collection('users').doc(userId).set({
        'tokens': FieldValue.increment(-_messageTokenCost),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Tokens used: -$_messageTokenCost');
      return true;
    } catch (e) {
      debugPrint('Error using tokens: $e');
      return false;
    }
  }

  /// Add tokens (e.g., from ad reward)
  static Future<bool> addTokens(int amount) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      await AuthService.firestore.collection('users').doc(userId).set({
        'tokens': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      debugPrint('Tokens added: +$amount');
      return true;
    } catch (e) {
      debugPrint('Error adding tokens: $e');
      return false;
    }
  }

  /// Check if has enough tokens
  static Future<bool> hasEnoughTokens() async {
    final balance = await getBalance();
    return balance >= _messageTokenCost;
  }

  /// Check if has enough tokens for analysis (15 tokens)
  static Future<bool> hasEnoughTokensForAnalysis() async {
    final balance = await getBalance();
    return balance >= _analysisTokenCost;
  }

  /// Use tokens for analysis (15 tokens)
  static Future<bool> useTokensForAnalysis() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      final balance = await getBalance();
      if (balance < _analysisTokenCost) {
        debugPrint('Insufficient tokens for analysis: $balance < $_analysisTokenCost');
        return false;
      }

      await AuthService.firestore.collection('users').doc(userId).set({
        'tokens': FieldValue.increment(-_analysisTokenCost),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Tokens used for analysis: -$_analysisTokenCost');
      return true;
    } catch (e) {
      debugPrint('Error using tokens for analysis: $e');
      return false;
    }
  }

  /// Check if has enough tokens for relationship deep analysis (30 tokens)
  static Future<bool> hasEnoughTokensForRelationshipAnalysis() async {
    final balance = await getBalance();
    return balance >= _relationshipAnalysisTokenCost;
  }

  /// Use tokens for relationship deep analysis (30 tokens)
  static Future<bool> useTokensForRelationshipAnalysis() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      final balance = await getBalance();
      if (balance < _relationshipAnalysisTokenCost) {
        debugPrint('Insufficient tokens for relationship analysis: $balance < $_relationshipAnalysisTokenCost');
        return false;
      }

      await AuthService.firestore.collection('users').doc(userId).set({
        'tokens': FieldValue.increment(-_relationshipAnalysisTokenCost),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Tokens used for relationship analysis: -$_relationshipAnalysisTokenCost');
      return true;
    } catch (e) {
      debugPrint('Error using tokens for relationship analysis: $e');
      return false;
    }
  }

  /// Check if has enough tokens for Astro HUD (10 tokens)
  static Future<bool> hasEnoughTokensForAstroHud() async {
    final balance = await getBalance();
    return balance >= _astroHudTokenCost;
  }

  /// Use tokens for Astro HUD (10 tokens)
  static Future<bool> useTokensForAstroHud() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      final balance = await getBalance();
      if (balance < _astroHudTokenCost) {
        debugPrint('Insufficient tokens for Astro HUD: $balance < $_astroHudTokenCost');
        return false;
      }

      await AuthService.firestore.collection('users').doc(userId).set({
        'tokens': FieldValue.increment(-_astroHudTokenCost),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Tokens used for Astro HUD: -$_astroHudTokenCost');
      return true;
    } catch (e) {
      debugPrint('Error using tokens for Astro HUD: $e');
      return false;
    }
  }

  /// Check if has enough tokens for Astro Card (10 tokens)
  static Future<bool> hasEnoughTokensForAstroCard() async {
    final balance = await getBalance();
    return balance >= _astroCardTokenCost;
  }

  /// Use tokens for Astro Card (10 tokens)
  static Future<bool> useTokensForAstroCard() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      final balance = await getBalance();
      if (balance < _astroCardTokenCost) {
        debugPrint('Insufficient tokens for Astro Card: $balance < $_astroCardTokenCost');
        return false;
      }

      await AuthService.firestore.collection('users').doc(userId).set({
        'tokens': FieldValue.increment(-_astroCardTokenCost),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Tokens used for Astro Card: -$_astroCardTokenCost');
      return true;
    } catch (e) {
      debugPrint('Error using tokens for Astro Card: $e');
      return false;
    }
  }

  /// Check if has enough tokens for Dream (10 tokens)
  static Future<bool> hasEnoughTokensForDream() async {
    final balance = await getBalance();
    return balance >= _dreamTokenCost;
  }

  /// Use tokens for Dream (10 tokens)
  static Future<bool> useTokensForDream() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      final balance = await getBalance();
      if (balance < _dreamTokenCost) {
        debugPrint('Insufficient tokens for Dream: $balance < $_dreamTokenCost');
        return false;
      }

      await AuthService.firestore.collection('users').doc(userId).set({
        'tokens': FieldValue.increment(-_dreamTokenCost),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Tokens used for Dream: -$_dreamTokenCost');
      return true;
    } catch (e) {
      debugPrint('Error using tokens for Dream: $e');
      return false;
    }
  }

  /// Check if has enough tokens for Style Strategy (10 tokens)
  static Future<bool> hasEnoughTokensForStyleStrategy() async {
    final balance = await getBalance();
    return balance >= _styleStrategyTokenCost;
  }

  /// Use tokens for Style Strategy (10 tokens)
  static Future<bool> useTokensForStyleStrategy() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      final balance = await getBalance();
      if (balance < _styleStrategyTokenCost) {
        debugPrint('Insufficient tokens for Style Strategy: $balance < $_styleStrategyTokenCost');
        return false;
      }

      await AuthService.firestore.collection('users').doc(userId).set({
        'tokens': FieldValue.increment(-_styleStrategyTokenCost),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Tokens used for Style Strategy: -$_styleStrategyTokenCost');
      return true;
    } catch (e) {
      debugPrint('Error using tokens for Style Strategy: $e');
      return false;
    }
  }

  /// Check if has enough tokens for Astro Guidance (15 tokens)
  static Future<bool> hasEnoughTokensForAstroGuidance() async {
    final balance = await getBalance();
    return balance >= _astroGuidanceTokenCost;
  }

  /// Check if has enough tokens for Campfire join (10 tokens)
  static Future<bool> hasEnoughTokensForCampfireJoin() async {
    final balance = await getBalance();
    return balance >= _campfireJoinTokenCost;
  }

  /// Check if has enough tokens for Campfire session (20 tokens)
  static Future<bool> hasEnoughTokensForCampfireSession() async {
    final balance = await getBalance();
    return balance >= _campfireSessionTokenCost;
  }

  /// Use tokens for Astro Guidance (15 tokens)
  static Future<bool> useTokensForAstroGuidance() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      final balance = await getBalance();
      if (balance < _astroGuidanceTokenCost) {
        debugPrint('Insufficient tokens for Astro Guidance: $balance < $_astroGuidanceTokenCost');
        return false;
      }

      await AuthService.firestore.collection('users').doc(userId).set({
        'tokens': FieldValue.increment(-_astroGuidanceTokenCost),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Tokens used for Astro Guidance: -$_astroGuidanceTokenCost');
      return true;
    } catch (e) {
      debugPrint('Error using tokens for Astro Guidance: $e');
      return false;
    }
  }

  /// Use tokens for Campfire join (10 tokens)
  static Future<bool> useTokensForCampfireJoin() async {
    return useTokensForTest(_campfireJoinTokenCost);
  }

  /// Use tokens for Campfire session (20 tokens)
  static Future<bool> useTokensForCampfireSession() async {
    return useTokensForTest(_campfireSessionTokenCost);
  }

  /// Use dynamic tokens for tests
  static Future<bool> useTokensForTest(int amount) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      final balance = await getBalance();
      if (balance < amount) {
        debugPrint('Insufficient tokens for test: $balance < $amount');
        return false;
      }

      await AuthService.firestore.collection('users').doc(userId).set({
        'tokens': FieldValue.increment(-amount),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Tokens used for test: -$amount');
      return true;
    } catch (e) {
      debugPrint('Error using tokens for test: $e');
      return false;
    }
  }

  // Getters
  static int get messageTokenCost => _messageTokenCost;
  static int get analysisTokenCost => _analysisTokenCost;
  static int get relationshipAnalysisTokenCost => _relationshipAnalysisTokenCost;
  static int get adRewardTokens => _adRewardTokens;
  static int get initialTokens => _initialTokens;
  static int get styleStrategyTokenCost => _styleStrategyTokenCost;
  static int get astroGuidanceTokenCost => _astroGuidanceTokenCost;
  static int get campfireJoinCost => _campfireJoinTokenCost;
  static int get campfireSessionCost => _campfireSessionTokenCost;
  static int get addictionUseTokenCost => _addictionUseTokenCost;

  static Future<TokenConsumeResult> consumeAddictionUsage() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return TokenConsumeResult.error;
      final docRef = AuthService.firestore.collection('users').doc(userId);
      final doc = await docRef.get();
      final data = doc.data() ?? const <String, dynamic>{};
      final firstUseConsumed = data[_addictionFirstUseField] == true;

      if (!firstUseConsumed) {
        await docRef.set({
          _addictionFirstUseField: true,
          'lastUsedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return TokenConsumeResult.successFree;
      }

      final balance = await getBalance();
      if (balance < _addictionUseTokenCost) {
        return TokenConsumeResult.insufficient;
      }

      await docRef.set({
        'tokens': FieldValue.increment(-_addictionUseTokenCost),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return TokenConsumeResult.successPaid;
    } catch (e) {
      debugPrint('Error consuming addiction usage tokens: $e');
      return TokenConsumeResult.error;
    }
  }
}
