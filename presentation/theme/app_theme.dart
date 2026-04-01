// lib/presentation/theme/app_theme.dart
// ─────────────────────────────────────────────────────────────────────────────
// Medical-grade theme.
//
// Design principles:
//   1. High contrast — WCAG AA minimum (4.5:1) enforced on all text
//   2. Large, readable numbers — glucose and dose values use 2× scale
//   3. Semantic colour coding:
//        Green  → safe / normal range
//        Amber  → warning / borderline
//        Red    → danger / critical action required
//        Blue   → informational / action
//   4. Arabic-optimised typeface (Cairo) with English fallback
//   5. Sufficient touch target sizes (≥ 48 × 48 dp) for all interactive items
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

abstract final class AppTheme {
  // ── Brand Colours ─────────────────────────────────────────────────────────
  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _primaryBlueLight = Color(0xFF1E88E5);
  static const Color _primaryBlueDark = Color(0xFF0D47A1);

  // ── Semantic Safety Colours ───────────────────────────────────────────────

  /// Safe / in-range glucose value
  static const Color safeGreen = Color(0xFF2E7D32);
  static const Color safeGreenLight = Color(0xFF81C784);
  static const Color safeGreenSurface = Color(0xFFE8F5E9);

  /// Warning / borderline — BG 70-80 or approaching limits
  static const Color warningAmber = Color(0xFFE65100);
  static const Color warningAmberLight = Color(0xFFFFB74D);
  static const Color warningAmberSurface = Color(0xFFFFF3E0);

  /// Danger — hypoglycaemia or dose ceiling
  static const Color dangerRed = Color(0xFFC62828);
  static const Color dangerRedLight = Color(0xFFEF9A9A);
  static const Color dangerRedSurface = Color(0xFFFFEBEE);

  /// Informational / prediction
  static const Color infoPurple = Color(0xFF4527A0);
  static const Color infoPurpleLight = Color(0xFFB39DDB);
  static const Color infoPurpleSurface = Color(0xFFEDE7F6);

  // ── Neutral ───────────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFF8F9FA);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF5C6068);
  static const Color textDisabled = Color(0xFF9E9E9E);

  // ── Typography ────────────────────────────────────────────────────────────
  static const _fontFamily = 'Cairo';

  static const TextTheme _textTheme = TextTheme(
    // Medical display numbers (BG, dose) — must be visible at arm's length
    displayLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 57,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      letterSpacing: -0.25,
    ),
    displayMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 45,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    displaySmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),

    // Section headings
    headlineLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),

    // Card titles, labels
    titleLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: textPrimary,
      letterSpacing: 0.15,
    ),
    titleSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textSecondary,
      letterSpacing: 0.1,
    ),

    // Body text
    bodyLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: textPrimary,
      letterSpacing: 0.15,
    ),
    bodyMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: textPrimary,
      letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: textSecondary,
      letterSpacing: 0.4,
    ),

    // Buttons & labels
    labelLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
  );

  // ── Light Theme ───────────────────────────────────────────────────────────

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: _fontFamily,
    textTheme: _textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryBlue,
      brightness: Brightness.light,
      primary: _primaryBlue,
      primaryContainer: const Color(0xFFD6E4FF),
      secondary: safeGreen,
      secondaryContainer: safeGreenSurface,
      error: dangerRed,
      errorContainer: dangerRedSurface,
      surface: surface,
    ),
    scaffoldBackgroundColor: surface,

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: cardSurface,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    ),

    // ── Cards ───────────────────────────────────────────────────────────────
    cardTheme: CardTheme(
      color: cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: divider),
      ),
    ),

    // ── Elevated Buttons ─────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── Outlined Buttons ────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryBlue,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: _primaryBlue, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── Input Fields ────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: dangerRed, width: 2),
      ),
      labelStyle: const TextStyle(
        fontFamily: _fontFamily,
        color: textSecondary,
      ),
      hintStyle: const TextStyle(
        fontFamily: _fontFamily,
        color: textDisabled,
      ),
    ),

    // ── Bottom Nav ───────────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardSurface,
      elevation: 8,
      indicatorColor: const Color(0xFFD6E4FF),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // ── Dividers ─────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: divider,
      thickness: 1,
      space: 1,
    ),

    // ── Chips ────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );

  // ── Dark Theme ────────────────────────────────────────────────────────────
  // Maintained for low-light / nighttime hypoglycaemia mode.

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    fontFamily: _fontFamily,
    textTheme: _textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryBlueLight,
      brightness: Brightness.dark,
      primary: _primaryBlueLight,
      primaryContainer: _primaryBlueDark,
      secondary: safeGreenLight,
      error: dangerRedLight,
      surface: const Color(0xFF121212),
    ),
    scaffoldBackgroundColor: const Color(0xFF0A0A0A),
    cardTheme: CardTheme(
      color: const Color(0xFF1E1E1E),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2C2C2C)),
      ),
    ),
  );
}

/// Extension to access semantic colours consistently across the widget tree.
extension AppColours on BuildContext {
  Color get bgSafeColor => AppTheme.safeGreen;
  Color get bgWarnColor => AppTheme.warningAmber;
  Color get bgDangerColor => AppTheme.dangerRed;
  Color get bgInfoColor => AppTheme.infoPurple;

  Color bgStatusColor(double bgValue) {
    if (bgValue < 70) return AppTheme.dangerRed;
    if (bgValue < 80) return AppTheme.warningAmber;
    if (bgValue <= 140) return AppTheme.safeGreen;
    if (bgValue <= 180) return AppTheme.warningAmber;
    return AppTheme.dangerRed;
  }
}
