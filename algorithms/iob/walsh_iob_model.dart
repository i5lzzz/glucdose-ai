// lib/algorithms/iob/walsh_iob_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Walsh Bilinear IOB Decay Model.
//
// ═══════════════════════════════════════════════════════════════════════════
// MATHEMATICAL DERIVATION
// ═══════════════════════════════════════════════════════════════════════════
//
// SOURCE: Walsh J, Roberts R, Bailey T. (2011). "Guidelines for Optimal
//   Bolus Calculator Settings in Adults." JDST 5(1):129-135.
//
// The model treats the insulin ACTIVITY curve a(t) as a symmetric triangle
// with peak at time P and total area 1 (normalised to 1 unit of insulin):
//
//     Activity
//     │        /\
//     │       /  \
//     │      /    \
//     │     /      \
//     └────/────────\────── t
//         0    P    DIA
//
//   Peak activity = 2/DIA  (so the triangle area = 1/2 × DIA × 2/DIA = 1 ✓)
//   Peak time     P = DIA / 2.8  (bilinear parameter, from Walsh Table 3)
//
// ACTIVITY FUNCTION:
//   a(t) = (2t)/(DIA×P)          for 0 ≤ t ≤ P    (ascending)
//   a(t) = 2(DIA−t)/(DIA×(DIA−P)) for P < t ≤ DIA  (descending)
//   a(t) = 0                      for t > DIA
//
// IOB(t) = ∫[t,DIA] a(s) ds  =  fraction of insulin remaining at time t
//
// ═══ SEGMENT 1: 0 ≤ t ≤ P ═══════════════════════════════════════════════
//
//   IOB(t) = ∫[t,P] (2s)/(DIA×P) ds + ∫[P,DIA] 2(DIA−s)/(DIA×(DIA−P)) ds
//
//   Part 1: ∫[t,P] (2s)/(DIA×P) ds
//         = [s²/(DIA×P)] from t to P
//         = (P² − t²) / (DIA × P)
//
//   Part 2: ∫[P,DIA] 2(DIA−s)/(DIA×(DIA−P)) ds
//           Let u = DIA − s  →  du = −ds
//         = ∫[DIA−P,0] 2u/(DIA×(DIA−P)) × (−du)
//         = ∫[0,DIA−P] 2u/(DIA×(DIA−P)) du
//         = [u²/(DIA×(DIA−P))] from 0 to (DIA−P)
//         = (DIA−P)² / (DIA×(DIA−P))
//         = (DIA−P) / DIA
//
//   IOB(t) = (P² − t²)/(DIA×P) + (DIA−P)/DIA
//           = P/DIA − t²/(DIA×P) + 1 − P/DIA
//           = 1 − t²/(DIA×P)                                ← SEGMENT 1
//
// ═══ SEGMENT 2: P < t ≤ DIA ══════════════════════════════════════════════
//
//   IOB(t) = ∫[t,DIA] 2(DIA−s)/(DIA×(DIA−P)) ds
//           = (DIA−t)² / (DIA×(DIA−P))                     ← SEGMENT 2
//
// ═══ CONTINUITY PROOF at t = P ═══════════════════════════════════════════
//
//   Seg1(P) = 1 − P²/(DIA×P) = 1 − P/DIA
//   Seg2(P) = (DIA−P)²/(DIA×(DIA−P)) = (DIA−P)/DIA = 1 − P/DIA  ✓ CONTINUOUS
//
// ═══ BOUNDARY CONDITIONS ═════════════════════════════════════════════════
//
//   IOB(0)   = 1 − 0 = 1     (100% remaining immediately after injection)   ✓
//   IOB(DIA) = (DIA−DIA)²/(…) = 0   (fully absorbed at DIA)                ✓
//
// ═══ SUMMARY FORMULAS ════════════════════════════════════════════════════
//
//   P   = DIA / 2.8
//
//   IOB(t) =
//     1 − t²/(DIA×P)              if  0 ≤ t ≤ P
//     (DIA−t)²/(DIA×(DIA−P))      if  P < t ≤ DIA
//     0                            if  t > DIA
//
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/algorithms/math/precision_math.dart';

/// The Walsh Bilinear IOB decay model.
///
/// This is a PURE STATELESS calculation object — no state, no clock access.
/// The [minutesElapsed] must be provided by the caller (from Clock).
///
/// Algorithms here can be unit-tested with arbitrary time values
/// without any DI or mocking.
abstract final class WalshIOBModel {
  /// The bilinear peak-time factor from Walsh et al. (2011), Table 3.
  static const double _peakTimeDivisor = 2.8;

  /// Calculates the IOB percentage (0.0–1.0) remaining from a single injection
  /// given [minutesElapsed] since the injection and the insulin [durationMinutes].
  ///
  /// Returns 1.0 if [minutesElapsed] ≤ 0 (future or immediate injection).
  /// Returns 0.0 if [minutesElapsed] ≥ [durationMinutes].
  ///
  /// PURE FUNCTION — no side effects, no exceptions.
  static double percentRemaining({
    required double minutesElapsed,
    required double durationMinutes,
  }) {
    assert(durationMinutes > 0, 'durationMinutes must be positive');

    // ── Boundary conditions ────────────────────────────────────────────────
    if (minutesElapsed <= 0) return 1.0;
    if (minutesElapsed >= durationMinutes) return 0.0;

    final D = durationMinutes;
    final t = minutesElapsed;
    final P = _peakTime(D);

    double percent;

    if (t <= P) {
      // ── Segment 1: Ascending phase ────────────────────────────────────
      // IOB(t) = 1 − t² / (D × P)
      percent = 1.0 - PrecisionMath.sq(t) / (D * P);
    } else {
      // ── Segment 2: Descending phase ───────────────────────────────────
      // IOB(t) = (D − t)² / (D × (D − P))
      final dMinusP = D - P;
      percent = PrecisionMath.sq(D - t) / (D * dMinusP);
    }

    // Clamp to [0, 1] — floating-point may produce values like 1.0000000001
    return PrecisionMath.clamp(percent, min: 0.0, max: 1.0);
  }

  /// Calculates the remaining IOB in units for a single injection.
  ///
  /// ```
  /// remainingUnits(
  ///   originalDoseUnits : 4.0,
  ///   minutesElapsed    : 60.0,
  ///   durationMinutes   : 240.0,
  /// ) → ~3.16 U  (≈79% remaining at 60 min with 4h DIA)
  /// ```
  static double remainingUnits({
    required double originalDoseUnits,
    required double minutesElapsed,
    required double durationMinutes,
  }) {
    if (originalDoseUnits <= 0) return 0.0;
    final pct = percentRemaining(
      minutesElapsed: minutesElapsed,
      durationMinutes: durationMinutes,
    );
    return PrecisionMath.normalise(originalDoseUnits * pct);
  }

  /// Returns the peak time for a given insulin duration.
  ///
  ///   P = DIA / 2.8
  ///
  /// For DIA = 240 min: P ≈ 85.7 min
  /// For DIA = 300 min: P ≈ 107.1 min
  static double peakTimeFor(double durationMinutes) =>
      _peakTime(durationMinutes);

  /// The instantaneous insulin ACTIVITY at time t (derivative of -IOB).
  ///
  /// Used by the prediction engine to model glucose lowering over time.
  /// Activity peaks at [peakTimeFor(D)] and is zero outside [0, DIA].
  ///
  /// Units: fraction of dose per minute.
  static double activityAt({
    required double minutesElapsed,
    required double durationMinutes,
  }) {
    if (minutesElapsed <= 0 || minutesElapsed >= durationMinutes) return 0.0;

    final D = durationMinutes;
    final t = minutesElapsed;
    final P = _peakTime(D);

    if (t <= P) {
      // a(t) = 2t / (D × P)
      return (2.0 * t) / (D * P);
    } else {
      // a(t) = 2(D − t) / (D × (D − P))
      return (2.0 * (D - t)) / (D * (D - P));
    }
  }

  /// Generates a time-series of IOB percentages for visualisation.
  ///
  /// Returns list of [count] evenly spaced (time, percent) pairs from
  /// t = 0 to t = durationMinutes.
  static List<({double minutes, double percent})> curve({
    required double durationMinutes,
    int count = 50,
  }) {
    assert(count > 1, 'count must be at least 2');
    final step = durationMinutes / (count - 1);
    return List.generate(
      count,
      (i) {
        final t = i * step;
        return (
          minutes: PrecisionMath.normalise(t),
          percent: percentRemaining(
            minutesElapsed: t,
            durationMinutes: durationMinutes,
          ),
        );
      },
    );
  }

  // ── Private ───────────────────────────────────────────────────────────────

  static double _peakTime(double D) => D / _peakTimeDivisor;
}
