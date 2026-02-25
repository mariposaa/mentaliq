import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'config/app_locale.dart';
import 'services/auth_service.dart';
import 'services/gemini_service.dart';
import 'services/shadow_memory_service.dart';
import 'services/relationship_analysis_service.dart';
import 'services/roadmap_generator_service.dart';
import 'services/motivation_quote_service.dart';
import 'services/dream_series_service.dart';
import 'services/progress_analysis_service.dart';
import 'services/token_service.dart';
import 'services/user_dna_service.dart';
import 'services/ad_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════════
  // STEP 1: Load environment
  // ═══════════════════════════════════════════════════════════════════
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✓ Environment loaded');
  } catch (e) {
    debugPrint('⚠ Could not load .env: $e');
  }

  // ═══════════════════════════════════════════════════════════════════
  // STEP 2: Initialize Firebase FIRST - before any Firebase usage
  // ═══════════════════════════════════════════════════════════════════
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✓ Firebase initialized');

    // Web platform fix
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    }
  } catch (e) {
    debugPrint('⚠ Firebase error: $e');
  }

  // ═══════════════════════════════════════════════════════════════════
  // STEP 3: Initialize Auth (AFTER Firebase)
  // ═══════════════════════════════════════════════════════════════════
  try {
    await AuthService.initialize();
    debugPrint('✓ Auth initialized: ${AuthService.userId}');
  } catch (e) {
    debugPrint('⚠ Auth error: $e');
  }

  // ═══════════════════════════════════════════════════════════════════
  // STEP 4: Initialize Tokens (AFTER Auth)
  // ═══════════════════════════════════════════════════════════════════
  try {
    await TokenService.initialize();
    await UserDNAService.initialize(); // Load User DNA
    debugPrint('✓ Token & DNA services ready');
  } catch (e) {
    debugPrint('⚠ Token/DNA error: $e');
  }

  // ═══════════════════════════════════════════════════════════════════
  // STEP 5: Initialize Gemini
  // ═══════════════════════════════════════════════════════════════════
  try {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      await GeminiService.initialize(apiKey);
      ShadowMemoryService.initialize(apiKey); // Gölge Hafıza
      RelationshipAnalysisService.initialize(apiKey); // THE AUDITOR
      RoadmapGeneratorService.initialize(apiKey); // Yol Haritası Üretici
      MotivationQuoteService.initialize(apiKey); // Motivasyon Sözleri
      DreamSeriesService.initialize(apiKey); // Gelecek Dizisi
      ProgressAnalysisService.initialize(apiKey); // İlerleme Analizi
      debugPrint('✓ Gemini initialized');
    }
  } catch (e) {
    debugPrint('⚠ Gemini error: $e');
  }

  // ═════════════════════════════════════════════════════════════════════
  // STEP 6: Initialize Ads
  // ═════════════════════════════════════════════════════════════════════
  try {
    await AdService.initialize();
    debugPrint('✓ Ad service initialized');
  } catch (e) {
    debugPrint('⚠ Ad service error: $e');
  }

  debugPrint('════════════════════════════════════════');
  debugPrint('ALL SERVICES READY - STARTING APP');
  debugPrint('════════════════════════════════════════');

  runApp(const MentaliqApp());
}

class MentaliqApp extends StatelessWidget {
  const MentaliqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mentaliq',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: AppLocale.locale,
      supportedLocales: AppLocale.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
