import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Static authentication service - NeyBu style
class AuthService {
  // LAZY initialization - only accessed after Firebase.initializeApp()
  static FirebaseAuth? _auth;
  static FirebaseFirestore? _firestore;
  static User? _currentUser;

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
      debugPrint('User already signed in: ${_currentUser?.uid}');
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
      await auth.signOut();
      _currentUser = null;
      debugPrint('Signed out');
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}
