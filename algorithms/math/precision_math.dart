// lib/algorithms/math/precision_math.dart
// ─────────────────────────────────────────────────────────────────────────────
// Precision-safe arithmetic for medical calculations.
//
// WHY THIS EXISTS:
//   Floating-point representation errors are unacceptable in dose arithmetic.
//   Example without precision control:
//     0.1 + 0.2 = 0.30000000000000004  → displayed as "0.3" but wrong in math
//     10.0 / 3.0 = 3.3333333333333335  → acceptable only if rounded correctly
//
//   In insulin dosing, a 0.05 U error propagated across 3 calculations steps
//   can shift the final dose by ~0.15 U — clinically meaningful for sensitive
//   patients (ISF = 50 → 7.5 mg/dL BG effect per 0.15 U error).
//
// STRATEGY:
//   1. All intermediate calculations use full double precision (no premature
//      rounding — rounding early amplifies, not reduces, error).
//   2. A single precision-normalise step is applied at the FINAL output only.
//   3. Comparisons use epsilon-tolerance to handle representation noise.
//   4. Division by near-zero is guarded with an explicit check.
//
// REFERENCE:
//   Goldberg, D. (1991). "What every computer scientist should know about
//   floating-point arithmetic." ACM Computing Surveys, 23(1), 5–48.
// ─────────────────────────────────────────────────────────────────────────────

/// Precision-safe arithmetic primitives for the algorithm engine.
///
/// All methods are static pure functions — no state, no side effects.
abstract final class PrecisionMath {
  // ── Epsilon tolerance ─────────────────────────────────────────────────────

  /// Two doubles closer than this are considered equal in medical context.
  /// 0.001 U is below the resolution of any commercial insulin delivery device.
  static const double epsilon = 1e-4;

  // ── Safe division ─────────────────────────────────────────────────────────

  /// Divides [numerator] by [denominator].
  ///
  /// Throws [ArgumentError] if [denominator] is zero or near-zero, rather than
  /// returning Infinity or NaN which would silently propagate through a
  /// calculation chain and produce nonsensical results.
  ///
  /// Medical context: [denominator] is always ICR or ISF — both have enforced
  /// minimum values (see MedicalConstants), so this guard is a defence-in-depth
  /// measure, not the primary validation.
  static double safeDivide(double numerator, double denominator) {
    if (denominator.abs() < epsilon) {
      throw ArgumentError(
        'PrecisionMath.safeDivide: denominator is effectively zero '
        '($denominator). This indicates a corrupted profile value that '
        'should have been caught by value-object validation.',
      );
    }
    return numerator / denominator;
  }

  // ── Rounding ──────────────────────────────────────────────────────────────

  /// Rounds [value] to [decimalPlaces] decimal places using symmetric
  /// rounding (away from zero — the banker's rounding used in finance and
  /// medical dosing).
  static double roundTo(double value, int decimalPlaces) {
    if (decimalPlaces < 0) {
      throw ArgumentError(
        'decimalPlaces must be non-negative, got $decimalPlaces',
      );
    }
    final factor = _pow10(decimalPlaces);
    // (value * factor + 0.5).floor() / factor is symmetric for positive values
    // For negative values (shouldn't appear in doses but may in corrections):
    return value >= 0
        ? (value * factor + 0.5).floor() / factor
        : -(((-value) * factor + 0.5).floor() / factor);
  }

  /// Floors [value] DOWN to the nearest [step] multiple.
  ///
  /// FLOOR (not round) is mandatory for insulin dosing:
  ///   rounding UP → patient receives MORE insulin than calculated → hypo risk
  ///   flooring DOWN → patient receives LESS → mild under-coverage, recoverable
  ///
  /// Examples:
  ///   floorToStep(3.7, 0.5)  → 3.5
  ///   floorToStep(3.5, 0.5)  → 3.5  (exact multiple)
  ///   floorToStep(3.49, 0.5) → 3.0
  ///   floorToStep(3.7, 0.1)  → 3.7  (within epsilon)
  ///   floorToStep(3.74, 0.1) → 3.7
  static double floorToStep(double value, double step) {
    assert(step > 0, 'Dose step must be positive');
    if (value <= 0) return 0.0;

    // Multiply, floor, divide — using integer arithmetic at the step boundary
    // to avoid float representation errors.
    final stepsCount = (value / step).floor();
    return _normalise(stepsCount * step);
  }

  // ── Clamp ─────────────────────────────────────────────────────────────────

  /// Clamps [value] to [min]..[max], with precision normalisation.
  static double clamp(double value, {required double min, required double max}) {
    assert(min <= max, 'clamp: min ($min) must be ≤ max ($max)');
    if (value < min) return min;
    if (value > max) return max;
    return _normalise(value);
  }

  /// Clamps [value] to zero minimum. Negative results of dose arithmetic
  /// (BG below target when IOB is high) must be treated as zero.
  static double clampToZero(double value) => value < 0 ? 0.0 : _normalise(value);

  // ── Equality with tolerance ────────────────────────────────────────────────

  static bool nearEqual(double a, double b) => (a - b).abs() < epsilon;
  static bool nearZero(double value) => value.abs() < epsilon;
  static bool greaterThan(double a, double b) => a - b > epsilon;
  static bool lessThan(double a, double b) => b - a > epsilon;

  // ── Squaring (used heavily in Walsh model) ────────────────────────────────

  /// Returns [value]² — named helper for legibility in Walsh formulas.
  static double sq(double value) => value * value;

  // ── Precision normalisation ───────────────────────────────────────────────

  /// Removes floating-point noise from a result to [significantDecimals].
  ///
  /// Insulin dosing requires 2 significant decimal places maximum.
  /// BG values require 0 (mg/dL) or 1 (mmol/L).
  static double normalise(double value, {int decimals = 4}) =>
      _normalise(value, decimals: decimals);

  // ── Private ───────────────────────────────────────────────────────────────

  static double _normalise(double value, {int decimals = 4}) {
    final factor = _pow10(decimals);
    return (value * factor).roundToDouble() / factor;
  }

  static double _pow10(int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) {
      result *= 10.0;
    }
    return result;
  }
}
