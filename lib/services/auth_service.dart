import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Static authentication service - NeyBu style
class AuthService {
  // LAZY initialization - only accessed after Firebase.initializeApp()
  static FirebaseAuth? _auth;
  static FirebaseFirestore? _firestore;
  static User? _currentUser;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static FirebaseAuth get auth {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  static FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  /// Get current user (cached)
  static User? get currentUser => _currentUser ?? auth.currentUser;

  /// Get current user ID
  static String? get userId => currentUser?.uid;

  /// Check if user is signed in
  static bool get isSignedIn => currentUser != null;
  static bool get isAnonymous => currentUser?.isAnonymous ?? false;
  static String? get userEmail => currentUser?.email;

  static Stream<User?> get authStateChanges => auth.authStateChanges();

  /// Sign in anonymously
  static Future<User?> signInAnonymously() async {
    try {
      if (auth.currentUser != null) {
        _currentUser = auth.currentUser;
        debugPrint('Already signed in: ${_currentUser?.uid}');
        return _currentUser;
      }

      final userCredential = await auth.signInAnonymously();
      _currentUser = userCredential.user;
      await _ensureUserDocument(_currentUser);
      debugPrint('Signed in anonymously: ${_currentUser?.uid}');
      return _currentUser;
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      return null;
    }
  }

  /// Initialize auth (call at app start AFTER Firebase.initializeApp)
  static Future<void> initialize() async {
    // Listen to auth state changes
    auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      if (user != null) {
        debugPrint('Auth state: User signed in (${user.uid})');
      } else {
        debugPrint('Auth state: User signed out');
      }
    });

    // Auto sign in anonymously if not already signed in
    if (auth.currentUser == null) {
      await signInAnonymously();
    } else {
      _currentUser = auth.currentUser;
      await _ensureUserDocument(_currentUser);
      debugPrint('User already signed in: ${_currentUser?.uid}');
    }
  }

  /// Register with email/password.
  /// If current user is anonymous, links anonymous account to email.
  static Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final anonymousUser = auth.currentUser;
      final credential =
          EmailAuthProvider.credential(email: email, password: password);

      UserCredential result;
      if (anonymousUser != null && anonymousUser.isAnonymous) {
        result = await anonymousUser.linkWithCredential(credential);
      } else {
        result = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      _currentUser = result.user;
      if (displayName != null && displayName.trim().isNotEmpty) {
        await _currentUser?.updateDisplayName(displayName.trim());
      }
      await _ensureUserDocument(_currentUser, displayName: displayName);
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('registerWithEmail error (${e.code}): ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('registerWithEmail error: $e');
      rethrow;
    }
  }

  /// Sign in with email/password.
  /// If signed in anonymously and user signs into existing account, data remains on old anonymous uid.
  /// You can migrate later if needed.
  static Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _currentUser = result.user;
      await _ensureUserDocument(_currentUser);
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('signInWithEmail error (${e.code}): ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('signInWithEmail error: $e');
      rethrow;
    }
  }

  /// Send password reset link.
  static Future<void> sendPasswordReset(String email) async {
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign in with Google.
  /// If current user is anonymous, links anonymous account to Google.
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final activeUser = auth.currentUser;
      UserCredential result;

      if (activeUser != null && activeUser.isAnonymous) {
        try {
          result = await activeUser.linkWithCredential(oauthCredential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            result = await auth.signInWithCredential(oauthCredential);
          } else {
            rethrow;
          }
        }
      } else {
        result = await auth.signInWithCredential(oauthCredential);
      }

      _currentUser = result.user;
      await _ensureUserDocument(
        _currentUser,
        displayName: _currentUser?.displayName ?? googleUser.displayName,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('signInWithGoogle error (${e.code}): ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('signInWithGoogle error: $e');
      rethrow;
    }
  }

  /// Update user profile in Firestore
  static Future<void> updateProfile(Map<String, dynamic> profileData) async {
    final uid = userId;
    if (uid == null) {
      debugPrint('updateProfile: No user ID');
      return;
    }

    try {
      // First get existing profile
      final doc = await firestore.collection('users').doc(uid).get();
      Map<String, dynamic> existingProfile = {};

      if (doc.exists && doc.data()?['profile'] != null) {
        existingProfile = Map<String, dynamic>.from(doc.data()!['profile']);
      }

      // Merge with new data
      existingProfile.addAll(profileData);

      // Save merged profile
      await firestore.collection('users').doc(uid).set({
        'profile': existingProfile,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Profile updated: $existingProfile');
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  /// Get user profile from Firestore
  static Future<Map<String, dynamic>?> getProfile() async {
    final uid = userId;
    if (uid == null) return null;

    try {
      final doc = await firestore.collection('users').doc(uid).get();
      return doc.data()?['profile'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return null;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await auth.signOut();
      _currentUser = null;
      await signInAnonymously();
      debugPrint('Signed out and switched to anonymous session');
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  /// Delete account and wipe user data
  static Future<bool> deleteAccount() async {
    try {
      final user = auth.currentUser;
      if (user != null) {
        // Delete user's document from Firestore
        await firestore.collection('users').doc(user.uid).delete();
        
        // Delete auth account
        await user.delete();
        _currentUser = null;
        
        // Ensure sign out from Google if they used it
        await _googleSignIn.signOut();
        
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return false;
    }
  }

  static Future<void> _ensureUserDocument(User? user,
      {String? displayName}) async {
    if (user == null) return;
    final docRef = firestore.collection('users').doc(user.uid);
    final existingDoc = await docRef.get();
    final name = (displayName ?? user.displayName ?? '').trim();

    if (!existingDoc.exists) {
      await docRef.set({
        'tokens': 100,
        'profile': {
          'name': name.isNotEmpty ? name : 'Misafir',
          'email': user.email,
          'isAnonymous': user.isAnonymous,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final data = <String, dynamic>{
      'lastSeenAt': FieldValue.serverTimestamp(),
      'profile': {
        'email': user.email,
        'isAnonymous': user.isAnonymous,
        if (name.isNotEmpty) 'name': name,
      }
    };
    await docRef.set(data, SetOptions(merge: true));
  }
}
