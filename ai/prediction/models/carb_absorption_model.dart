// lib/ai/prediction/models/carb_absorption_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// CarbAbsorptionModel — pharmacokinetic model of glucose appearance from carbs.
//
// ═══════════════════════════════════════════════════════════════════════════
// MATHEMATICAL MODEL
// ═══════════════════════════════════════════════════════════════════════════
//
// SOURCE: Hovorka R et al. (2004). "Nonlinear model predictive control of
//   glucose concentration in subjects with type 1 diabetes."
//   Physiol Meas 25(4):905-920. — Meal absorption model.
//
// MODEL CHOICE:
//   We use a first-order mono-exponential absorption model:
//
//     Ra(t) = (carbs × k_abs) × exp(−k_abs × t)
//
//   where:
//     Ra(t)   = rate of glucose appearance at time t (g/min)
//     k_abs   = absorption rate constant = ln(2) / T½
//     T½      = absorption half-time (minutes), derived from AbsorptionSpeed
//     t       = time elapsed since meal (minutes)
//
// CUMULATIVE FRACTION ABSORBED by time t:
//
//     F(t) = 1 − exp(−k_abs × t)
//          = 1 − exp(−ln(2) × t / T½)
//
//   PROOF:
//     ∫[0,t] Ra(s) ds = (carbs × k_abs) × ∫[0,t] exp(−k_abs × s) ds
//                     = (carbs × k_abs) × [−(1/k_abs) × exp(−k_abs × s)]₀ᵗ
//                     = carbs × (1 − exp(−k_abs × t))
//                     = carbs × F(t)
//
//   BOUNDARY CONDITIONS:
//     F(0)   = 1 − exp(0) = 0      (nothing absorbed at t=0)     ✓
//     F(∞)   = 1 − 0 = 1           (fully absorbed eventually)   ✓
//     F(T½)  = 1 − exp(−ln2) = 0.5 (half absorbed at T½)        ✓
//
// GLUCOSE IMPACT:
//
//   BG rise from carbs at time t:
//     carbImpact(t) = maxCarbImpact × F(t)
//
//   where:
//     maxCarbImpact = (carbs [g] / ICR [g/U]) × ISF [mg/dL/U]
//                  = carbs × ISF / ICR   (mg/dL units)
//
//   This is the total glucose excursion if ALL carbs were absorbed.
//   F(t) distributes it over time.
//
// HALF-TIME PARAMETERS (from AbsorptionSpeed):
//   fast   → T½ = 35 min   (dates, juice, white bread)
//   medium → T½ = 75 min   (rice, kabsa, pasta)
//   slow   → T½ = 120 min  (legumes, high-fibre foods)
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:insulin_assistant/algorithms/math/precision_math.dart';

/// Pure stateless carbohydrate absorption model.
abstract final class CarbAbsorptionModel {
  // ── k_abs calculation ─────────────────────────────────────────────────────

  /// Absorption rate constant from half-time: k_abs = ln(2) / T½
  static double absorptionRateConstant(double halfTimeMinutes) {
    assert(halfTimeMinutes > 0, 'halfTime must be positive');
    return math.log(2) / halfTimeMinutes;
  }

  // ── Cumulative fraction absorbed F(t) ─────────────────────────────────────

  /// Returns the cumulative fraction of carbohydrates absorbed by time [t].
  ///
  /// F(t) = 1 − exp(−k_abs × t)
  ///
  /// Range: [0, 1]
  /// F(0) = 0, F(T½) = 0.5, F(∞) = 1
  static double fractionAbsorbed({
    required double minutesElapsed,
    required double halfTimeMinutes,
  }) {
    if (minutesElapsed <= 0) return 0.0;
    final k = absorptionRateConstant(halfTimeMinutes);
    final frac = 1.0 - math.exp(-k * minutesElapsed);
    return PrecisionMath.clamp(frac, min: 0.0, max: 1.0);
  }

  // ── BG impact from carbs ──────────────────────────────────────────────────

  /// BG rise (mg/dL) from carbohydrate absorption at [minutesElapsed].
  ///
  ///   carbImpact(t) = maxCarbImpact × F(t)
  ///
  /// where maxCarbImpact = carbs × ISF / ICR
  ///
  /// Returns 0 when [carbsGrams] == 0.
  static double bgImpactAt({
    required double carbsGrams,
    required double isfMgdlPerUnit,
    required double icrGramsPerUnit,
    required double minutesElapsed,
    required double halfTimeMinutes,
  }) {
    if (carbsGrams <= 0) return 0.0;
    final maxImpact = (carbsGrams / icrGramsPerUnit) * isfMgdlPerUnit;
    final frac = fractionAbsorbed(
      minutesElapsed: minutesElapsed,
      halfTimeMinutes: halfTimeMinutes,
    );
    return PrecisionMath.normalise(maxImpact * frac, decimals: 4);
  }

  /// Rate of BG rise (mg/dL per minute) from carbs at [minutesElapsed].
  ///
  ///   dBG/dt = maxCarbImpact × k_abs × exp(−k_abs × t)
  static double bgRateAt({
    required double carbsGrams,
    required double isfMgdlPerUnit,
    required double icrGramsPerUnit,
    required double minutesElapsed,
    required double halfTimeMinutes,
  }) {
    if (carbsGrams <= 0) return 0.0;
    final maxImpact = (carbsGrams / icrGramsPerUnit) * isfMgdlPerUnit;
    final k = absorptionRateConstant(halfTimeMinutes);
    return maxImpact * k * math.exp(-k * minutesElapsed);
  }

  /// Generates a time-series of BG impact values for UI charting.
  static List<({double minutes, double bgImpact, double fractionAbsorbed})>
      timeSeries({
    required double carbsGrams,
    required double isfMgdlPerUnit,
    required double icrGramsPerUnit,
    required double halfTimeMinutes,
    int points = 48,
    double maxMinutes = 240,
  }) {
    final step = maxMinutes / (points - 1);
    return List.generate(points, (i) {
      final t = i * step;
      return (
        minutes: PrecisionMath.normalise(t),
        bgImpact: bgImpactAt(
          carbsGrams: carbsGrams,
          isfMgdlPerUnit: isfMgdlPerUnit,
          icrGramsPerUnit: icrGramsPerUnit,
          minutesElapsed: t,
          halfTimeMinutes: halfTimeMinutes,
        ),
        fractionAbsorbed: fractionAbsorbed(
          minutesElapsed: t,
          halfTimeMinutes: halfTimeMinutes,
        ),
      );
    });
  }
}
