import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  
  // -- User Provided Colors --
  // Light
  static const Color _lightBg = Color(0xFFF3F4F6); // --background
  static const Color _lightCard = Color(0xFFFFFFFF); // --card
  static const Color _lightCardsBg = Color(0xFFE8E8E8); // --cardsBG
  static const Color _lightFg = Color(0xFF171717); // --fg
  static const Color _lightBorder = Color(0xFFD1D5DB); // --border

  // Dark
  static const Color _darkBg = Color(0xFF0A0A0A); // --background
  static const Color _darkCard = Color(0xFF0F1724); // --card
  static const Color _darkCardsBg = Color(0xFF202020); // --cardsBG
  static const Color _darkFg = Color(0xFFEDEDED); // --fg
  static const Color _darkBorder = Color(0xFF1F2937); // --border

  // -- Brand Colors --
  static const Color metaColor = Color(0xFF2563EB);
  static const Color whatsappColor = Color(0xFF16A34A);
  static const Color websiteColor = Color(0xFF06B6D4);
  static const Color justdialColor = Color(0xFFF59E0B);
  static const Color indiamartColor = Color(0xFF16A34A);
  static const Color sulekhaColor = Color(0xFFA855F7);
  static const Color acres99Color = Color(0xFFEC4899);
  static const Color housingColor = Color(0xFF14B8A6);
  static const Color magicbricksColor = Color(0xFFEF4444);
  
  // -- Misc --
  static const Color cremColor = Color(0xFFEFEAE2); // --crem (Light)
  static const Color cremColorDark = Color(0xFF080D14); // --crem (Dark)
  static const Color chatActiveLight = Color(0xFFE7F3EC); // --chat-active (Light)
  static const Color chatActiveDark = Color(0xFF1B2F26); // --chat-active (Dark)

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightBg,
    cardColor: _lightCard,
    dividerColor: _lightBorder,
    // Use a neutral text theme but keep Inter
    textTheme: _applyLetterSpacing(
      GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: _lightFg,
        displayColor: _lightFg,
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue, // Keep a primary accent
      brightness: Brightness.light,
      surface: _lightCard,
      onSurface: _lightFg,
      outline: _lightBorder,
      surfaceContainerHighest: _lightCardsBg, // Variant bg
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _lightCard, // Modern app bars align with card/surface
      foregroundColor: _lightFg,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: _lightFg),
    ),
    cardTheme: const CardThemeData( // Changed CardTheme to CardThemeData
      color: _lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: _lightBorder, width: 1),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkBg,
    cardColor: _darkCard,
    dividerColor: _darkBorder,
    textTheme: _applyLetterSpacing(
      GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: _darkFg,
        displayColor: _darkFg,
      ),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
      surface: _darkCard,
      onSurface: _darkFg,
      outline: _darkBorder,
      surfaceContainerHighest: _darkCardsBg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _darkCard,
      foregroundColor: _darkFg,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: _darkFg),
    ),
    cardTheme: const CardThemeData( // Changed CardTheme to CardThemeData
      color: _darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: _darkBorder, width: 1),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );

  static TextTheme _applyLetterSpacing(TextTheme baseTheme) {
    return baseTheme.copyWith(
      displayLarge: baseTheme.displayLarge?.copyWith(letterSpacing: -0.5),
      displayMedium: baseTheme.displayMedium?.copyWith(letterSpacing: -0.5),
      displaySmall: baseTheme.displaySmall?.copyWith(letterSpacing: -0.5),
      headlineLarge: baseTheme.headlineLarge?.copyWith(letterSpacing: -0.5),
      headlineMedium: baseTheme.headlineMedium?.copyWith(letterSpacing: -0.5),
      headlineSmall: baseTheme.headlineSmall?.copyWith(letterSpacing: -0.5),
      titleLarge: baseTheme.titleLarge?.copyWith(letterSpacing: -0.5),
      titleMedium: baseTheme.titleMedium?.copyWith(letterSpacing: -0.5),
      titleSmall: baseTheme.titleSmall?.copyWith(letterSpacing: -0.5),
      bodyLarge: baseTheme.bodyLarge?.copyWith(letterSpacing: -0.5),
      bodyMedium: baseTheme.bodyMedium?.copyWith(letterSpacing: -0.5),
      bodySmall: baseTheme.bodySmall?.copyWith(letterSpacing: -0.5),
      labelLarge: baseTheme.labelLarge?.copyWith(letterSpacing: -0.5),
      labelMedium: baseTheme.labelMedium?.copyWith(letterSpacing: -0.5),
      labelSmall: baseTheme.labelSmall?.copyWith(letterSpacing: -0.5),
    );
  }
}
