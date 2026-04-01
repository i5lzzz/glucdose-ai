// lib/ai/prediction/models/insulin_activity_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// InsulinActivityModel — BG-lowering from insulin activity over time.
//
// ═══════════════════════════════════════════════════════════════════════════
// MATHEMATICAL MODEL
// ═══════════════════════════════════════════════════════════════════════════
//
// The cumulative BG-lowering effect of insulin from time t₀ to tₑ is the
// integral of the activity curve over that interval, scaled by dose and ISF.
//
// From Phase 4 (Walsh bilinear model):
//
//   IOB(t) = fraction of insulin remaining at time t
//
//   Insulin activity A(t) = −dIOB/dt  (the derivative of the IOB curve)
//
//   Cumulative BG lowering from time 0 to time t:
//
//     ΔBG_insulin(0→t) = dose × ISF × [IOB(0) − IOB(t)]
//                      = dose × ISF × [1 − IOB(t)]
//
//   This is because IOB starts at 1 (fully on board) and falls to 0 (fully
//   absorbed).  The cumulative BG lowering at time t is proportional to the
//   FRACTION ALREADY CONSUMED, which is 1 − IOB(t).
//
//   PROOF:
//     ΔBG(0→t) = dose × ISF × ∫[0,t] A(s) ds
//              = dose × ISF × ∫[0,t] (−dIOB/ds) ds
//              = dose × ISF × [IOB(0) − IOB(t)]
//              = dose × ISF × [1 − IOB(t)]         ✓
//
//   BOUNDARY CONDITIONS:
//     t = 0   → 1 − IOB(0) = 1 − 1 = 0    (no effect yet)            ✓
//     t = DIA → 1 − IOB(DIA) = 1 − 0 = 1  (full dose absorbed)       ✓
//
// IOB FOR DOSE STARTED [minutesSinceInjection] AGO:
//   The dose was injected at −minutesSinceInjection.
//   At horizon t (from now), elapsed since injection = minutesSinceInjection + t
//
//   cumBGLowering(t) = dose × ISF × [IOB(t₀) − IOB(t₀ + t)]
//
//   where t₀ = minutesSinceInjection
//
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/algorithms/iob/walsh_iob_model.dart';
import 'package:insulin_assistant/algorithms/math/precision_math.dart';

/// Pure stateless insulin activity model for glucose prediction.
abstract final class InsulinActivityModel {
  // ── Cumulative BG lowering ────────────────────────────────────────────────

  /// BG lowering (mg/dL, returned as positive value) attributable to a dose
  /// that was injected [minutesSinceInjection] minutes ago, at [horizonMinutes]
  /// from now.
  ///
  ///   bgLowering = dose × ISF × [IOB(t₀) − IOB(t₀ + horizon)]
  ///
  /// t₀ = minutesSinceInjection
  ///
  /// The return value is POSITIVE (represents a lowering effect — callers
  /// subtract it from the BG prediction).
  static double bgLoweringAt({
    required double doseUnits,
    required double isfMgdlPerUnit,
    required double durationMinutes,
    required double minutesSinceInjection,
    required double horizonMinutes,
  }) {
    if (doseUnits <= 0) return 0.0;

    final t0 = minutesSinceInjection;
    final t1 = minutesSinceInjection + horizonMinutes;

    final iobAtT0 = WalshIOBModel.percentRemaining(
      minutesElapsed: t0,
      durationMinutes: durationMinutes,
    );
    final iobAtT1 = WalshIOBModel.percentRemaining(
      minutesElapsed: t1,
      durationMinutes: durationMinutes,
    );

    // Fraction consumed in the horizon window = iobAtT0 − iobAtT1
    final fractionConsumed = iobAtT0 - iobAtT1;

    // Clamp: fractionConsumed can be slightly negative due to float noise
    // if t0 > DIA (injection already expired)
    final clamped = PrecisionMath.clampToZero(fractionConsumed);
    final lowering = doseUnits * isfMgdlPerUnit * clamped;
    return PrecisionMath.normalise(lowering, decimals: 4);
  }

  /// Fraction of dose that becomes active during [horizonMinutes] from now,
  /// given the dose was injected [minutesSinceInjection] ago.
  ///
  /// Used for the explainability "X% active during this window" display.
  static double fractionActiveInWindow({
    required double durationMinutes,
    required double minutesSinceInjection,
    required double horizonMinutes,
  }) {
    final t0 = minutesSinceInjection;
    final t1 = minutesSinceInjection + horizonMinutes;

    final iobAtT0 = WalshIOBModel.percentRemaining(
      minutesElapsed: t0,
      durationMinutes: durationMinutes,
    );
    final iobAtT1 = WalshIOBModel.percentRemaining(
      minutesElapsed: t1,
      durationMinutes: durationMinutes,
    );

    return PrecisionMath.clamp(iobAtT0 - iobAtT1, min: 0.0, max: 1.0);
  }

  /// Current IOB fraction (at t=0, before any horizon) — used for IOB impact.
  static double currentIobFraction({
    required double minutesSinceInjection,
    required double durationMinutes,
  }) =>
      WalshIOBModel.percentRemaining(
        minutesElapsed: minutesSinceInjection,
        durationMinutes: durationMinutes,
      );

  /// Generates a time-series of cumulative BG-lowering for UI charting.
  static List<({double minutes, double bgLowering, double iobPercent})>
      timeSeries({
    required double doseUnits,
    required double isfMgdlPerUnit,
    required double durationMinutes,
    required double minutesSinceInjection,
    int points = 48,
    double maxHorizonMinutes = 240,
  }) {
    final step = maxHorizonMinutes / (points - 1);
    return List.generate(points, (i) {
      final horizon = i * step;
      final elapsed = minutesSinceInjection + horizon;
      return (
        minutes: PrecisionMath.normalise(horizon),
        bgLowering: bgLoweringAt(
          doseUnits: doseUnits,
          isfMgdlPerUnit: isfMgdlPerUnit,
          durationMinutes: durationMinutes,
          minutesSinceInjection: minutesSinceInjection,
          horizonMinutes: horizon,
        ),
        iobPercent: WalshIOBModel.percentRemaining(
          minutesElapsed: elapsed,
          durationMinutes: durationMinutes,
        ),
      );
    });
  }
}
