// lib/ai/prediction/models/trend_adjustment_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// TrendAdjustmentModel — extrapolates BG trend over the prediction horizon.
//
// ═══════════════════════════════════════════════════════════════════════════
// MATHEMATICAL MODEL
// ═══════════════════════════════════════════════════════════════════════════
//
// PROBLEM WITH PURE LINEAR EXTRAPOLATION:
//   If glucose trend is +2 mg/dL/min and we extrapolate linearly for 120 min,
//   the trend alone would predict BG = current + 240 mg/dL — wildly wrong
//   because trends don't persist; they revert as meals absorb and insulin acts.
//
// MODEL: Exponentially Decayed Linear Trend
//
//   trendImpact(t) = trend × τ × (1 − exp(−t / τ))
//
//   where:
//     trend = BG rate of change (mg/dL/min), signed
//     τ     = trend decay time constant (minutes)
//     t     = horizon (minutes)
//
//   INTERPRETATION:
//     At t → 0:  trendImpact ≈ trend × t   (linear, short horizons)
//     At t → ∞:  trendImpact → trend × τ   (saturates at max contribution)
//
//   CHOICE OF τ = 30 min:
//     A typical glucose excursion trend lasts 20–40 minutes before the
//     combined effect of meal absorption and insulin action reverses it.
//     τ = 30 min gives a saturation cap of (trend × 30) mg/dL.
//     For trend = +2 mg/dL/min, this caps at +60 mg/dL — clinically plausible.
//
//   CONTINUITY:
//     trendImpact(0) = trend × τ × (1 − 1) = 0                      ✓
//     dtrendImpact/dt|₀ = trend × τ × (1/τ) = trend  (rate matches)  ✓
//
// CONFIDENCE DECAY:
//   The trend component is also weighted by a confidence factor that
//   decreases with horizon, since trend persistence is uncertain:
//     confidence(t) = exp(−t / 60)   (half-life of confidence ≈ 42 min)
//
//   Final:
//     adjustedTrend(t) = trendImpact(t) × confidence(t)
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:insulin_assistant/algorithms/math/precision_math.dart';

/// Pure stateless trend extrapolation model.
abstract final class TrendAdjustmentModel {
  /// Trend decay time constant (minutes).
  static const double _tauMinutes = 30.0;

  /// Confidence half-life (minutes).
  static const double _confidenceHalfLifeMinutes = 60.0;

  // ── Core calculation ──────────────────────────────────────────────────────

  /// BG adjustment (mg/dL) from trend extrapolation at [horizonMinutes].
  ///
  ///   trendImpact(t) = trend × τ × (1 − exp(−t/τ)) × exp(−t/60)
  ///
  /// [trendMgdlPerMin] is signed:
  ///   positive → BG rising  (trend adds to predicted BG)
  ///   negative → BG falling (trend subtracts from predicted BG)
  ///
  /// Returns 0 when [trendMgdlPerMin] == 0.
  static double bgAdjustmentAt({
    required double trendMgdlPerMin,
    required double horizonMinutes,
  }) {
    if (trendMgdlPerMin == 0.0 || horizonMinutes <= 0) return 0.0;

    // Exponentially decayed linear extrapolation
    final rawImpact =
        trendMgdlPerMin * _tauMinutes * (1.0 - math.exp(-horizonMinutes / _tauMinutes));

    // Confidence weighting (trend persistence decays with horizon)
    final confidence = math.exp(-horizonMinutes / _confidenceHalfLifeMinutes);

    return PrecisionMath.normalise(rawImpact * confidence, decimals: 4);
  }

  /// Confidence score [0,1] for the trend contribution at [horizonMinutes].
  static double confidenceAt(double horizonMinutes) {
    if (horizonMinutes <= 0) return 1.0;
    return PrecisionMath.clamp(
      math.exp(-horizonMinutes / _confidenceHalfLifeMinutes),
      min: 0.0,
      max: 1.0,
    );
  }

  /// Maximum possible trend contribution (saturation value × confidence).
  /// Used for explainability ("trend could contribute up to X mg/dL").
  static double maxContribution(double trendMgdlPerMin) =>
      (trendMgdlPerMin * _tauMinutes).abs();
}
