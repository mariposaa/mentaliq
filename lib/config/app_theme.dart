import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mentaliq Theme - Calming Wellness Design
/// 
/// Inspired by Headspace/Calm but with an analytical edge.
/// "Seni yargılamıyoruz, seni anlıyoruz ve iyileştiriyoruz."
class AppTheme {
  // ═══════════════════════════════════════════════════════════════════
  // COLOR PALETTE - Healing & Balance
  // ═══════════════════════════════════════════════════════════════════
  
  /// Zemin - Warm sand/beige for human touch
  static const Color sandBeige = Color(0xFFFAF6F0);
  
  /// İkincil Zemin - Soft cream for cards
  static const Color warmCream = Color(0xFFFFFDF9);
  
  /// Ana Marka - Sage Green (Adaçayı Yeşili)
  /// Büyüme, iyileşme ve denge
  static const Color sageGreen = Color(0xFF8BA888);
  
  /// Deeper sage for emphasis
  static const Color deepSage = Color(0xFF6B8B6A);
  
  /// Aksiyon Rengi - Terracotta (Toprak Turuncusu)
  /// Sıcak ama bağırmayan, CTA için
  static const Color terracotta = Color(0xFFD4836D);
  
  /// Ana Metin - Orman yeşili tonunda koyu gri
  static const Color forestCharcoal = Color(0xFF3D4A40);
  
  /// Yardımcı Metin - Soft sage grey
  static const Color mutedSage = Color(0xFF8B9A8E);
  
  /// Border - Very subtle sage tint
  static const Color softBorder = Color(0xFFE8EDE8);

  // ═══════════════════════════════════════════════════════════════════
  // SHADOWS - Soft, Dreamy
  // ═══════════════════════════════════════════════════════════════════
  
  /// Premium soft shadow - cards float gently
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: sageGreen.withOpacity(0.08),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
  ];

  /// Subtle card shadow
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: forestCharcoal.withOpacity(0.04),
      blurRadius: 12,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════
  // BORDER RADIUS - Soft, Rounded (Pill shapes for buttons)
  // ═══════════════════════════════════════════════════════════════════
  
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 20.0;
  static const double radiusLarge = 28.0;
  static const double radiusPill = 50.0;  // For pill-shaped buttons

  // ═══════════════════════════════════════════════════════════════════
  // THEME DATA
  // ═══════════════════════════════════════════════════════════════════
  
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: sageGreen,
      scaffoldBackgroundColor: sandBeige,
      colorScheme: const ColorScheme.light(
        primary: sageGreen,
        secondary: terracotta,
        surface: warmCream,
        background: sandBeige,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: forestCharcoal,
        onBackground: forestCharcoal,
      ),
      
      // Typography - Poppins: Rounded, friendly, approachable
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        // Hero titles
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: forestCharcoal,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        // Section headers
        headlineMedium: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: forestCharcoal,
          letterSpacing: -0.3,
        ),
        // Card titles
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: forestCharcoal,
        ),
        // Subtitles
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: forestCharcoal,
        ),
        // Body text
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: forestCharcoal,
          height: 1.6,
        ),
        // Secondary body
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: mutedSage,
          height: 1.5,
        ),
        // Small labels
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: mutedSage,
          letterSpacing: 0.3,
        ),
        // Button text
        labelLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      
      // AppBar - Clean, minimal
      appBarTheme: AppBarTheme(
        backgroundColor: sandBeige,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          color: forestCharcoal,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: forestCharcoal),
      ),
      
      // Cards - Soft, floating
      cardTheme: CardTheme(
        color: warmCream,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      
      // Primary Button - Pill shaped Terracotta
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: terracotta,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      
      // Outlined Button - Sage border
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: sageGreen,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          side: const BorderSide(color: sageGreen, width: 1.5),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: sageGreen,
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // Input fields - Soft, rounded
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: warmCream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: softBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: sageGreen, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(
          color: mutedSage,
          fontSize: 15,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: terracotta,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      
      // Divider
      dividerTheme: const DividerThemeData(
        color: softBorder,
        thickness: 1,
        space: 1,
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: warmCream,
        selectedItemColor: sageGreen,
        unselectedItemColor: mutedSage,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  // Backwards compatibility
  static ThemeData get lightTheme => themeData;
  static ThemeData get darkTheme => themeData;  // TODO: Create dark variant

  // ═══════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Gradient for special sections
  static LinearGradient get calmingGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      sageGreen.withOpacity(0.15),
      terracotta.withOpacity(0.08),
    ],
  );

  /// Card decoration with shadow
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: warmCream,
    borderRadius: BorderRadius.circular(radiusMedium),
    boxShadow: cardShadow,
  );

  /// Pill button decoration (alternative to ElevatedButton)
  static BoxDecoration get pillButtonDecoration => BoxDecoration(
    color: terracotta,
    borderRadius: BorderRadius.circular(radiusPill),
    boxShadow: [
      BoxShadow(
        color: terracotta.withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}
