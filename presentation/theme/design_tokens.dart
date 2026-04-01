// lib/presentation/theme/design_tokens.dart

import 'package:flutter/material.dart';

abstract final class DT {
  // ── Spacing ────────────────────────────────────────────────────────────────
  static const double s2  = 2.0;
  static const double s4  = 4.0;
  static const double s8  = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;
  static const double s56 = 56.0;
  static const double s64 = 64.0;

  // ── Radii ─────────────────────────────────────────────────────────────────
  static const double rSmall  = 8.0;
  static const double rMedium = 14.0;
  static const double rLarge  = 20.0;
  static const double rXL     = 28.0;
  static const double rFull   = 999.0;

  // ── Semantic colours (light) ───────────────────────────────────────────────
  static const Color ink       = Color(0xFF0A0A0F); // near-black
  static const Color inkSub    = Color(0xFF6B6B7A); // secondary label
  static const Color inkTert   = Color(0xFFADADB8); // tertiary
  static const Color surface   = Color(0xFFFAFAFC); // page background
  static const Color card      = Color(0xFFFFFFFF);
  static const Color separator = Color(0xFFE5E5EA);
  static const Color fill      = Color(0xFFF2F2F7); // grouped bg

  // ── Status colours ────────────────────────────────────────────────────────
  static const Color safe    = Color(0xFF34C759); // Apple green
  static const Color warn    = Color(0xFFFF9500); // Apple orange
  static const Color danger  = Color(0xFFFF3B30); // Apple red
  static const Color info    = Color(0xFF007AFF); // Apple blue
  static const Color purple  = Color(0xFF5856D6);

  // ── Status surface tints ─────────────────────────────────────────────────
  static const Color safeSurface   = Color(0xFFEAF9EE);
  static const Color warnSurface   = Color(0xFFFFF4E6);
  static const Color dangerSurface = Color(0xFFFFEEED);
  static const Color infoSurface   = Color(0xFFE8F2FF);

  // ── Typography ─────────────────────────────────────────────────────────────
  static const String fontFamily = 'Cairo';

  // Display — BG and dose numbers
  static const TextStyle display96 = TextStyle(
    fontFamily: fontFamily, fontSize: 96,
    fontWeight: FontWeight.w300, color: ink,
    letterSpacing: -4, height: 1.0,
  );
  static const TextStyle display72 = TextStyle(
    fontFamily: fontFamily, fontSize: 72,
    fontWeight: FontWeight.w300, color: ink,
    letterSpacing: -3, height: 1.0,
  );
  static const TextStyle display48 = TextStyle(
    fontFamily: fontFamily, fontSize: 48,
    fontWeight: FontWeight.w300, color: ink,
    letterSpacing: -2, height: 1.05,
  );

  // Title hierarchy
  static const TextStyle title28 = TextStyle(
    fontFamily: fontFamily, fontSize: 28,
    fontWeight: FontWeight.w700, color: ink,
    letterSpacing: -0.5,
  );
  static const TextStyle title22 = TextStyle(
    fontFamily: fontFamily, fontSize: 22,
    fontWeight: FontWeight.w600, color: ink,
    letterSpacing: -0.3,
  );
  static const TextStyle title17 = TextStyle(
    fontFamily: fontFamily, fontSize: 17,
    fontWeight: FontWeight.w600, color: ink,
    letterSpacing: -0.2,
  );

  // Body
  static const TextStyle body17 = TextStyle(
    fontFamily: fontFamily, fontSize: 17,
    fontWeight: FontWeight.w400, color: ink,
    letterSpacing: -0.1, height: 1.5,
  );
  static const TextStyle body15 = TextStyle(
    fontFamily: fontFamily, fontSize: 15,
    fontWeight: FontWeight.w400, color: inkSub,
    height: 1.5,
  );
  static const TextStyle body13 = TextStyle(
    fontFamily: fontFamily, fontSize: 13,
    fontWeight: FontWeight.w400, color: inkTert,
    height: 1.4,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily, fontSize: 12,
    fontWeight: FontWeight.w400, color: inkTert,
    letterSpacing: 0.1,
  );
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily, fontSize: 13,
    fontWeight: FontWeight.w500, color: inkSub,
    letterSpacing: 0.2,
  );

  // ── Shadows ──────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get floatShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];

  // ── Durations ─────────────────────────────────────────────────────────────
  static const Duration fast   = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow   = Duration(milliseconds: 500);

  // ── Curves ───────────────────────────────────────────────────────────────
  static const Curve spring = Curves.easeOutCubic;
  static const Curve ease   = Curves.easeInOut;
}

// ── Status colour helpers ─────────────────────────────────────────────────────

Color bgStatusColor(double bgMgdl) {
  if (bgMgdl < 70)  return DT.danger;
  if (bgMgdl < 80)  return DT.warn;
  if (bgMgdl <= 140) return DT.safe;
  if (bgMgdl <= 180) return DT.warn;
  return DT.danger;
}

Color bgStatusSurface(double bgMgdl) {
  if (bgMgdl < 70)  return DT.dangerSurface;
  if (bgMgdl < 80)  return DT.warnSurface;
  if (bgMgdl <= 140) return DT.safeSurface;
  if (bgMgdl <= 180) return DT.warnSurface;
  return DT.dangerSurface;
}

String bgStatusLabelAr(double bgMgdl) {
  if (bgMgdl < 70)  return 'منخفض';
  if (bgMgdl < 80)  return 'طبيعي منخفض';
  if (bgMgdl <= 140) return 'مثالي';
  if (bgMgdl <= 180) return 'مرتفع قليلاً';
  return 'مرتفع';
}
