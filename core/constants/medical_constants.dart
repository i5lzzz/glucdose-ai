// lib/core/constants/medical_constants.dart
// ─────────────────────────────────────────────────────────────────────────────
// Single source of truth for ALL medical thresholds.
//
// ⚠️  CHANGE-CONTROL REQUIRED:
//     Any modification to this file must be reviewed by a qualified clinician
//     and documented in the risk register (ISO 14971 §10).
//     Changes are audited via git blame + audit_log.
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable medical constants namespace.
///
/// All glucose values are in mg/dL unless explicitly suffixed with `_mmol`.
/// All insulin quantities are in units (U).
/// All times are in minutes unless suffixed otherwise.
abstract final class MedicalConstants {
  // ── Glucose Thresholds (mg/dL) ───────────────────────────────────────────

  /// Level 2 hypoglycaemia — HARD BLOCK all dose calculations.
  /// Clinical basis: ADA Standards of Care 2024, Table 6.2
  static const double bgLevel2HypoHardBlock = 40.0;

  /// Level 1 hypoglycaemia — WARN and require double confirmation.
  static const double bgLevel1HypoWarn = 70.0;

  /// Hyperglycaemia alert threshold (above this, show correction warning).
  static const double bgHyperAlertThreshold = 250.0;

  /// Severe hyperglycaemia — recommend DKA screening protocol.
  static const double bgSevereHyperThreshold = 400.0;

  /// Standard target range lower bound.
  static const double bgTargetLow = 80.0;

  /// Standard target range upper bound.
  static const double bgTargetHigh = 140.0;

  /// Default target BG used in dose calculations when user has not set one.
  static const double bgDefaultTarget = 100.0;

  // ── Dose Safety Ceilings ─────────────────────────────────────────────────

  /// Absolute hard ceiling per single dose — overrides all user settings.
  /// Rationale: prevents accidental 10× entry errors.
  /// Clinical review: doses >20 U as single bolus carry unacceptable risk
  /// in T2D management without direct physician oversight.
  static const double absoluteMaxSingleDoseUnits = 20.0;

  /// Default user-configurable max dose until the user sets their own.
  static const double defaultUserMaxDoseUnits = 10.0;

  /// Minimum calculable dose below which we display "< 0.5 U" and round to 0.
  static const double minClinicallySignificantDose = 0.5;

  // ── Carbohydrate Constraints ─────────────────────────────────────────────

  /// Maximum carbohydrate value accepted in a single meal entry (grams).
  /// Values above this are likely data entry errors.
  static const double maxCarbohydratesPerMealGrams = 400.0;

  // ── Insulin on Board (IOB) ───────────────────────────────────────────────

  /// Maximum credible IOB before stacking warning is mandatory.
  static const double iobStackingWarningThreshold = 5.0;

  /// Walsh model: default insulin duration of action (minutes).
  static const double defaultInsulinDurationMinutes = 240.0; // 4 h

  /// Minimum accepted insulin duration (minutes) — prevents divide-by-zero.
  static const double minInsulinDurationMinutes = 120.0;

  /// Maximum accepted insulin duration (minutes).
  static const double maxInsulinDurationMinutes = 480.0; // 8 h

  // ── Insulin Sensitivity Factor (ISF) ────────────────────────────────────

  /// Minimum ISF accepted (mg/dL per unit) — guards against denominator ≈ 0.
  static const double minISF = 5.0;

  /// Maximum ISF accepted — values above this suggest data entry error.
  static const double maxISF = 200.0;

  /// Default ISF for first-run before user profile is complete.
  static const double defaultISF = 50.0;

  // ── Insulin-to-Carb Ratio (ICR) ─────────────────────────────────────────

  /// Minimum ICR (grams carb per unit) — e.g., 1 U covers only 3 g.
  static const double minICR = 3.0;

  /// Maximum ICR (grams carb per unit) — e.g., 1 U covers 50 g.
  static const double maxICR = 50.0;

  /// Default ICR for first-run.
  static const double defaultICR = 10.0;

  // ── Prediction Engine ────────────────────────────────────────────────────

  /// Prediction horizons (minutes).
  static const List<int> predictionHorizonsMinutes = [30, 60, 120];

  /// Carbohydrate absorption half-time for medium GI foods (minutes).
  static const double carbAbsorptionHalfTimeMinutes = 75.0;

  // ── Meal Timing ──────────────────────────────────────────────────────────

  /// Minutes before meal — pre-meal insulin window.
  static const int preMealWindowMinutes = 30;

  /// Minutes after meal — post-meal correction window.
  static const int postMealWindowMinutes = 120;

  // ── Audit / Traceability ─────────────────────────────────────────────────

  /// Minimum audit record retention (days) — aligns with GDPR Article 5(1)(e).
  static const int auditRetentionDays = 365;

  // ── UI Safety ────────────────────────────────────────────────────────────

  /// Mandatory confirmation delay before recording a dose (seconds).
  /// Prevents accidental taps — mitigates ISO 14971 hazard H-02.
  static const int doseConfirmationDelaySeconds = 3;

  // ── Unit display precision ───────────────────────────────────────────────

  /// Decimal places shown for calculated insulin dose.
  static const int dosePrecisionDecimalPlaces = 1;

  /// Decimal places shown for BG readings.
  static const int bgPrecisionDecimalPlaces = 0;
}
