// lib/algorithms/version.dart
// ─────────────────────────────────────────────────────────────────────────────
// Algorithm version registry.
//
// RULE: Any change to a formula, constant, or rounding behaviour in ANY
//       algorithm file MUST bump the corresponding version string here.
//
// VERSION HISTORY is tracked here as a constant comment block so that
// code review, git blame, and the audit log all carry the same changelog.
//
// Each CalculationTrace embeds [AlgorithmVersion.doseCalculator] so that
// a reviewer can know exactly which formula produced a given result, even
// years after the calculation.
//
// SEMVER: MAJOR.MINOR.PATCH
//   MAJOR → formula or model change (recalibration required for historical data)
//   MINOR → new safety flag added (backward compatible)
//   PATCH → precision constant adjusted (no clinical impact)
// ─────────────────────────────────────────────────────────────────────────────

/*
 * ═══════════════════════════════════════════════════════════════
 *  VERSION HISTORY
 * ═══════════════════════════════════════════════════════════════
 *
 * dose_calculator:
 *   1.0.0 (2024-01-01) — Initial release.
 *                         Formula: dose = carbs/ICR + (BG-target)/ISF - IOB
 *                         Rounding: floor to dose step
 *                         IOB: Walsh Bilinear v1.0
 *
 * iob_model:
 *   1.0.0 (2024-01-01) — Walsh bilinear with P = DIA/2.8
 *
 * safety_evaluator:
 *   1.0.0 (2024-01-01) — Initial safety rule set.
 *                         Rules: level2Hypo hardBlock, level1Hypo warn,
 *                                ceiling clamp, IOB stacking warning.
 *
 * ═══════════════════════════════════════════════════════════════
 */

abstract final class AlgorithmVersion {
  /// Version of the dose calculation engine.
  static const String doseCalculator = '1.0.0';

  /// Version of the IOB model.
  static const String iobModel = '1.0.0';

  /// Version of the safety evaluator rule set.
  static const String safetyEvaluator = '1.0.0';

  /// Version of the glucose prediction engine.
  static const String predictionEngine = '1.0.0';

  /// Version of the insight generation engine.
  static const String insightEngine = '1.0.0';

  /// Composite version string embedded in CalculationTrace.
  /// Format: "dose:{d}|iob:{i}|safety:{s}"
  static String get compositeVersion =>
      'dose:$doseCalculator|iob:$iobModel|safety:$safetyEvaluator';
}
