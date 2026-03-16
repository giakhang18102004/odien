import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  static const Color canvas = Color(0xFFF6E7D8);
  static const Color paper = Color(0xFFFFF8F1);
  static const Color ink = Color(0xFF1E2A39);
  static const Color mist = Color(0xFFF4F0E8);
  static const Color coral = Color(0xFFD6674F);
  static const Color teal = Color(0xFF176B61);
  static const Color gold = Color(0xFFE2A83B);
  static const Color slate = Color(0xFF536274);
  static const Color line = Color(0x1F1E2A39);
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.teal,
      brightness: Brightness.light,
      surface: AppPalette.paper,
      primary: AppPalette.teal,
      secondary: AppPalette.gold,
      error: AppPalette.coral,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.canvas,
    );

    return base.copyWith(
      textTheme: GoogleFonts.soraTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.sora(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: AppPalette.ink,
        ),
        headlineMedium: GoogleFonts.sora(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppPalette.ink,
        ),
        titleLarge: GoogleFonts.sora(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppPalette.ink,
        ),
        titleMedium: GoogleFonts.sora(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppPalette.ink,
        ),
        bodyLarge: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppPalette.ink,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppPalette.slate,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppPalette.line),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: const BorderSide(color: AppPalette.line),
        selectedColor: AppPalette.gold.withValues(alpha: 0.18),
        backgroundColor: Colors.white.withValues(alpha: 0.72),
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          color: AppPalette.ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        indicatorColor: AppPalette.gold.withValues(alpha: 0.22),
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.6),
        indicatorColor: AppPalette.gold.withValues(alpha: 0.22),
        selectedLabelTextStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.86),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppPalette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppPalette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppPalette.teal, width: 1.4),
        ),
      ),
    );
  }
}
