// test/algorithms/walsh_iob_model_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit tests for WalshIOBModel.
//
// COVERAGE TARGETS:
//   1. Boundary conditions (t=0, t=DIA, t>DIA)
//   2. Continuity at peak time
//   3. Monotonic decrease (IOB only falls, never rises)
//   4. Activity curve integration equals 1.0 (conservation)
//   5. Specific clinical examples with expected values
//   6. Multiple DIA values
//   7. Edge cases (very short/long elapsed times)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/algorithms/iob/walsh_iob_model.dart';
import 'package:insulin_assistant/algorithms/math/precision_math.dart';

void main() {
  group('WalshIOBModel', () {
    const dia240 = 240.0; // 4-hour DIA — most common case
    const dia300 = 300.0; // 5-hour DIA
    const dia180 = 180.0; // 3-hour DIA

    // ── Boundary conditions ─────────────────────────────────────────────────

    group('boundary conditions', () {
      test('t = 0: 100% IOB remaining', () {
        expect(
          WalshIOBModel.percentRemaining(
            minutesElapsed: 0,
            durationMinutes: dia240,
          ),
          equals(1.0),
        );
      });

      test('t < 0: still 100% (future injection guard)', () {
        expect(
          WalshIOBModel.percentRemaining(
            minutesElapsed: -30,
            durationMinutes: dia240,
          ),
          equals(1.0),
        );
      });

      test('t = DIA: 0% IOB remaining', () {
        expect(
          WalshIOBModel.percentRemaining(
            minutesElapsed: dia240,
            durationMinutes: dia240,
          ),
          equals(0.0),
        );
      });

      test('t > DIA: 0% IOB remaining', () {
        expect(
          WalshIOBModel.percentRemaining(
            minutesElapsed: dia240 + 60,
            durationMinutes: dia240,
          ),
          equals(0.0),
        );
      });
    });

    // ── Continuity at peak time ─────────────────────────────────────────────

    group('continuity at peak time', () {
      test('segment 1 and segment 2 agree at t = DIA/2.8 (DIA=240)', () {
        final peakTime = WalshIOBModel.peakTimeFor(dia240); // ≈ 85.71 min
        final justBefore = WalshIOBModel.percentRemaining(
          minutesElapsed: peakTime - 0.001,
          durationMinutes: dia240,
        );
        final atPeak = WalshIOBModel.percentRemaining(
          minutesElapsed: peakTime,
          durationMinutes: dia240,
        );
        final justAfter = WalshIOBModel.percentRemaining(
          minutesElapsed: peakTime + 0.001,
          durationMinutes: dia240,
        );

        // All three should be within epsilon of each other
        expect((justBefore - atPeak).abs(), lessThan(0.001));
        expect((atPeak - justAfter).abs(), lessThan(0.001));
      });

      test('continuity holds for DIA=300', () {
        final peakTime = WalshIOBModel.peakTimeFor(dia300);
        final seg1 = WalshIOBModel.percentRemaining(
          minutesElapsed: peakTime,
          durationMinutes: dia300,
        );
        // Analytical value: 1 - P/DIA = 1 - (DIA/2.8)/DIA = 1 - 1/2.8
        final expected = 1.0 - 1.0 / 2.8;
        expect(seg1, closeTo(expected, 0.001));
      });
    });

    // ── Monotonic decrease ──────────────────────────────────────────────────

    group('monotonic decrease', () {
      test('IOB only decreases over time for DIA=240', () {
        final times =
            List.generate(25, (i) => i * 10.0); // 0, 10, 20, ... 240
        double previous = 1.0;
        for (final t in times) {
          final current = WalshIOBModel.percentRemaining(
            minutesElapsed: t,
            durationMinutes: dia240,
          );
          expect(
            current,
            lessThanOrEqualTo(previous + PrecisionMath.epsilon),
            reason: 'IOB should not increase at t=$t (was $previous, got $current)',
          );
          previous = current;
        }
      });

      test('IOB only decreases for DIA=180', () {
        double previous = 1.0;
        for (var t = 0.0; t <= dia180; t += 6.0) {
          final current = WalshIOBModel.percentRemaining(
            minutesElapsed: t,
            durationMinutes: dia180,
          );
          expect(current, lessThanOrEqualTo(previous + PrecisionMath.epsilon));
          previous = current;
        }
      });
    });

    // ── Clinical spot checks ────────────────────────────────────────────────

    group('clinical spot checks (DIA=240, P≈85.7 min)', () {
      // At t = 30 min (ascending phase): 1 - 30²/(240 × 85.71) = 1 - 900/20571.4
      //   ≈ 1 - 0.04374 ≈ 0.9563
      test('t=30 min: ~95.6% remaining', () {
        expect(
          WalshIOBModel.percentRemaining(
            minutesElapsed: 30,
            durationMinutes: dia240,
          ),
          closeTo(0.956, 0.005),
        );
      });

      // At t = 60 min (ascending): 1 - 60²/(240 × 85.71) ≈ 1 - 0.175 ≈ 0.825
      test('t=60 min: ~82.5% remaining', () {
        expect(
          WalshIOBModel.percentRemaining(
            minutesElapsed: 60,
            durationMinutes: dia240,
          ),
          closeTo(0.825, 0.005),
        );
      });

      // At peak (t≈85.71): 1 - 1/2.8 ≈ 0.6429
      test('t=peakTime: ~64.3% remaining', () {
        final p = WalshIOBModel.peakTimeFor(dia240);
        expect(
          WalshIOBModel.percentRemaining(
            minutesElapsed: p,
            durationMinutes: dia240,
          ),
          closeTo(1.0 - 1.0 / 2.8, 0.001),
        );
      });

      // At t=120 min (descending): (240-120)²/(240×(240-85.71))
      //   = 14400/(240×154.29) = 14400/37028.6 ≈ 0.389
      test('t=120 min (2h): ~38.9% remaining', () {
        expect(
          WalshIOBModel.percentRemaining(
            minutesElapsed: 120,
            durationMinutes: dia240,
          ),
          closeTo(0.389, 0.005),
        );
      });

      // At t=180 min: (240-180)²/(240×154.29) = 3600/37028.6 ≈ 0.097
      test('t=180 min (3h): ~9.7% remaining', () {
        expect(
          WalshIOBModel.percentRemaining(
            minutesElapsed: 180,
            durationMinutes: dia240,
          ),
          closeTo(0.097, 0.005),
        );
      });
    });

    // ── remainingUnits ──────────────────────────────────────────────────────

    group('remainingUnits', () {
      test('4U dose at t=0 returns 4.0 U', () {
        expect(
          WalshIOBModel.remainingUnits(
            originalDoseUnits: 4.0,
            minutesElapsed: 0,
            durationMinutes: dia240,
          ),
          closeTo(4.0, 0.01),
        );
      });

      test('4U dose at t=DIA returns 0.0 U', () {
        expect(
          WalshIOBModel.remainingUnits(
            originalDoseUnits: 4.0,
            minutesElapsed: dia240,
            durationMinutes: dia240,
          ),
          equals(0.0),
        );
      });

      test('zero dose always returns 0.0', () {
        expect(
          WalshIOBModel.remainingUnits(
            originalDoseUnits: 0.0,
            minutesElapsed: 60,
            durationMinutes: dia240,
          ),
          equals(0.0),
        );
      });

      test('4U dose at t=120 min ≈ 1.56 U', () {
        final remaining = WalshIOBModel.remainingUnits(
          originalDoseUnits: 4.0,
          minutesElapsed: 120,
          durationMinutes: dia240,
        );
        expect(remaining, closeTo(1.556, 0.05));
      });
    });

    // ── Activity curve integration ───────────────────────────────────────────

    group('activity curve', () {
      test('activity at t=0 is zero (no instantaneous effect at injection)', () {
        expect(
          WalshIOBModel.activityAt(
            minutesElapsed: 0,
            durationMinutes: dia240,
          ),
          closeTo(0.0, 0.001),
        );
      });

      test('activity peaks at peak time', () {
        final p = WalshIOBModel.peakTimeFor(dia240);
        final atPeak = WalshIOBModel.activityAt(
          minutesElapsed: p,
          durationMinutes: dia240,
        );
        // Check values around peak are lower
        final before = WalshIOBModel.activityAt(
          minutesElapsed: p - 10,
          durationMinutes: dia240,
        );
        final after = WalshIOBModel.activityAt(
          minutesElapsed: p + 10,
          durationMinutes: dia240,
        );
        expect(atPeak, greaterThan(before));
        expect(atPeak, greaterThan(after));
      });

      test('numerical integration of activity ≈ 1.0 (conservation law)', () {
        // Integrate using trapezoidal rule with 1-minute steps
        const steps = 240;
        var sum = 0.0;
        for (var i = 0; i < steps; i++) {
          final t = i.toDouble();
          final a1 = WalshIOBModel.activityAt(
            minutesElapsed: t,
            durationMinutes: dia240,
          );
          final a2 = WalshIOBModel.activityAt(
            minutesElapsed: t + 1,
            durationMinutes: dia240,
          );
          sum += (a1 + a2) / 2.0; // trapezoid area for 1-minute step
        }
        // Should equal 1.0 within numerical integration tolerance
        expect(sum, closeTo(1.0, 0.01));
      });
    });

    // ── Curve generation ────────────────────────────────────────────────────

    group('curve', () {
      test('generates correct number of points', () {
        final curve = WalshIOBModel.curve(durationMinutes: dia240, count: 25);
        expect(curve.length, equals(25));
      });

      test('first point is t=0, percent=1.0', () {
        final curve = WalshIOBModel.curve(durationMinutes: dia240, count: 25);
        expect(curve.first.minutes, equals(0.0));
        expect(curve.first.percent, equals(1.0));
      });

      test('last point is t=DIA, percent=0.0', () {
        final curve = WalshIOBModel.curve(durationMinutes: dia240, count: 25);
        expect(curve.last.minutes, closeTo(dia240, 0.001));
        expect(curve.last.percent, equals(0.0));
      });
    });

    // ── Peak time ────────────────────────────────────────────────────────────

    group('peakTimeFor', () {
      test('DIA=240 → peak ≈ 85.71 min', () {
        expect(WalshIOBModel.peakTimeFor(240), closeTo(85.714, 0.001));
      });
      test('DIA=300 → peak ≈ 107.14 min', () {
        expect(WalshIOBModel.peakTimeFor(300), closeTo(107.143, 0.001));
      });
      test('DIA=180 → peak ≈ 64.29 min', () {
        expect(WalshIOBModel.peakTimeFor(180), closeTo(64.286, 0.001));
      });
    });
  });
}
