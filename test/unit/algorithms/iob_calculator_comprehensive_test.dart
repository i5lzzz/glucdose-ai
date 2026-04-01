// test/unit/algorithms/iob_calculator_comprehensive_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/algorithms/iob/walsh_iob_calculator.dart';
import 'package:insulin_assistant/algorithms/iob/walsh_iob_model.dart';
import 'package:insulin_assistant/algorithms/math/precision_math.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';

import '../../helpers/test_factories.dart';

void main() {
  const calc = WalshIOBCalculator();

  group('WalshIOBModel — Mathematical proofs', () {
    group('Boundary conditions', () {
      for (final dia in [180.0, 240.0, 300.0, 360.0]) {
        test('t=0: 100% remaining (DIA=$dia)', () {
          expect(
            WalshIOBModel.percentRemaining(minutesElapsed: 0, durationMinutes: dia),
            equals(1.0),
          );
        });
        test('t=DIA: 0% remaining (DIA=$dia)', () {
          expect(
            WalshIOBModel.percentRemaining(minutesElapsed: dia, durationMinutes: dia),
            equals(0.0),
          );
        });
        test('t>DIA: 0% (DIA=$dia)', () {
          expect(
            WalshIOBModel.percentRemaining(
              minutesElapsed: dia + 60, durationMinutes: dia),
            equals(0.0),
          );
        });
        test('t<0: 100% (guard)', () {
          expect(
            WalshIOBModel.percentRemaining(minutesElapsed: -30, durationMinutes: dia),
            equals(1.0),
          );
        });
      }
    });

    test('Continuity at peak time DIA=240', () {
      const dia = 240.0;
      final p = WalshIOBModel.peakTimeFor(dia);
      final before = WalshIOBModel.percentRemaining(minutesElapsed: p - 0.01, durationMinutes: dia);
      final at     = WalshIOBModel.percentRemaining(minutesElapsed: p,        durationMinutes: dia);
      final after  = WalshIOBModel.percentRemaining(minutesElapsed: p + 0.01, durationMinutes: dia);
      expect((before - at).abs(), lessThan(0.001));
      expect((at - after).abs(), lessThan(0.001));
    });

    test('At peak: IOB = 1 - 1/2.8 ≈ 0.6429', () {
      const dia = 240.0;
      final p = WalshIOBModel.peakTimeFor(dia);
      expect(
        WalshIOBModel.percentRemaining(minutesElapsed: p, durationMinutes: dia),
        closeTo(1.0 - 1.0 / 2.8, 0.001),
      );
    });

    test('Monotonic decrease for DIA=240', () {
      double prev = 1.0;
      for (var t = 0.0; t <= 240.0; t += 1.0) {
        final curr = WalshIOBModel.percentRemaining(minutesElapsed: t, durationMinutes: 240);
        expect(curr, lessThanOrEqualTo(prev + PrecisionMath.epsilon),
            reason: 'Non-monotonic at t=$t');
        prev = curr;
      }
    });

    test('Activity integrates to 1.0 (conservation law)', () {
      var sum = 0.0;
      for (var i = 0; i < 240; i++) {
        final a1 = WalshIOBModel.activityAt(minutesElapsed: i.toDouble(), durationMinutes: 240);
        final a2 = WalshIOBModel.activityAt(minutesElapsed: i + 1.0, durationMinutes: 240);
        sum += (a1 + a2) / 2.0;
      }
      expect(sum, closeTo(1.0, 0.01));
    });

    group('Clinical spot checks (DIA=240)', () {
      const dia = 240.0;
      final checks = {
        30.0: 0.956,
        60.0: 0.825,
        120.0: 0.389,
        180.0: 0.097,
      };
      checks.forEach((t, expected) {
        test('t=${t.toInt()} min ≈ ${(expected * 100).toStringAsFixed(0)}%', () {
          expect(
            WalshIOBModel.percentRemaining(minutesElapsed: t, durationMinutes: dia),
            closeTo(expected, 0.005),
          );
        });
      });
    });
  });

  group('WalshIOBCalculator', () {
    group('Single injection', () {
      test('Pending injection → zero IOB', () {
        final clock = TestFactories.clockAt(60);
        final inj = TestFactories.injection(status: InjectionStatus.pending);
        final r = calc.calculateSingleIOB(injection: inj, clock: clock);
        expect(r.isSuccess, isTrue);
        expect(r.value.units, equals(0.0));
      });

      test('Long-acting → zero IOB (not bolus-eligible)', () {
        final clock = TestFactories.clockAt(60);
        final inj = TestFactories.injection(type: InsulinType.longActing);
        final r = calc.calculateSingleIOB(injection: inj, clock: clock);
        expect(r.value.units, equals(0.0));
      });

      test('At injection time → full dose remaining', () {
        final clock = TestFactories.clock(); // epoch == injection time
        final inj = TestFactories.injection(doseU: 4.0);
        final r = calc.calculateSingleIOB(injection: inj, clock: clock);
        expect(r.value.units, closeTo(4.0, 0.01));
      });

      test('At DIA → zero remaining', () {
        final clock = TestFactories.clockAt(240); // exactly DIA
        final inj = TestFactories.injection(doseU: 4.0);
        final r = calc.calculateSingleIOB(injection: inj, clock: clock);
        expect(r.value.units, equals(0.0));
      });

      test('At 60 min → ~3.30 U for 4U dose', () {
        final clock = TestFactories.clockAt(60);
        final inj = TestFactories.injection(doseU: 4.0);
        final r = calc.calculateSingleIOB(injection: inj, clock: clock);
        // 4.0 × 0.825 ≈ 3.30
        expect(r.value.units, closeTo(3.30, 0.1));
      });

      test('At 120 min → ~1.56 U for 4U dose', () {
        final clock = TestFactories.clockAt(120);
        final inj = TestFactories.injection(doseU: 4.0);
        final r = calc.calculateSingleIOB(injection: inj, clock: clock);
        expect(r.value.units, closeTo(1.556, 0.05));
      });
    });

    group('Multiple injections (stacking)', () {
      test('Empty list → zero total IOB', () {
        final clock = TestFactories.clock();
        final r = calc.calculateTotalIOB(injections: [], clock: clock);
        expect(r.isSuccess, isTrue);
        expect(r.value.units, equals(0.0));
      });

      test('Two stacked injections sum correctly', () {
        final base = TestFactories.epoch;
        final clock = TestFactories.clock(base);
        final inj1 = TestFactories.injection(
          id: 'i1', injectedAt: base.subtract(const Duration(minutes: 90)), doseU: 4.0,
        );
        final inj2 = TestFactories.injection(
          id: 'i2', injectedAt: base.subtract(const Duration(minutes: 30)), doseU: 2.0,
        );
        final r1 = calc.calculateSingleIOB(injection: inj1, clock: clock);
        final r2 = calc.calculateSingleIOB(injection: inj2, clock: clock);
        final total = calc.calculateTotalIOB(injections: [inj1, inj2], clock: clock);
        expect(
          total.value.units,
          closeTo(r1.value.units + r2.value.units, 0.001),
        );
      });

      test('Total IOB never exceeds sum of original doses', () {
        final clock = TestFactories.clockAt(1);
        final injections = [
          TestFactories.injection(id: 'a', doseU: 6.0),
          TestFactories.injection(id: 'b', doseU: 4.0,
            injectedAt: TestFactories.epoch.subtract(const Duration(minutes: 1))),
        ];
        const originalTotal = 10.0;
        final r = calc.calculateTotalIOB(injections: injections, clock: clock);
        expect(r.value.units, lessThanOrEqualTo(originalTotal + 0.001));
      });

      test('Expired injections contribute nothing', () {
        final clock = TestFactories.clockAt(500); // past DIA
        final inj = TestFactories.injection(doseU: 4.0);
        final r = calc.calculateTotalIOB(injections: [inj], clock: clock);
        expect(r.value.units, equals(0.0));
      });

      test('IOB decreases over time (Clock advancing)', () {
        final inj = TestFactories.injection(doseU: 4.0);
        final iob60  = calc.calculateSingleIOB(injection: inj, clock: TestFactories.clockAt(60)).value.units;
        final iob120 = calc.calculateSingleIOB(injection: inj, clock: TestFactories.clockAt(120)).value.units;
        final iob180 = calc.calculateSingleIOB(injection: inj, clock: TestFactories.clockAt(180)).value.units;
        expect(iob60, greaterThan(iob120));
        expect(iob120, greaterThan(iob180));
      });
    });

    group('Breakdown', () {
      test('Breakdown items sum equals total IOB', () {
        final clock = TestFactories.clockAt(60);
        final injections = [
          TestFactories.injection(id: 'b1', doseU: 4.0),
          TestFactories.injection(id: 'b2', doseU: 2.0,
            injectedAt: TestFactories.epoch.subtract(const Duration(minutes: 30))),
        ];
        final bd = calc.calculateIOBBreakdown(injections: injections, clock: clock);
        final total = calc.calculateTotalIOB(injections: injections, clock: clock);
        final sumFromBreakdown = bd.value.fold<double>(0.0, (s, i) => s + i.remainingIOB.units);
        expect(sumFromBreakdown, closeTo(total.value.units, 0.001));
      });

      test('percentRemaining is within [0, 1]', () {
        final clock = TestFactories.clockAt(60);
        final bd = calc.calculateIOBBreakdown(
          injections: [TestFactories.injection(doseU: 4.0)],
          clock: clock,
        );
        for (final item in bd.value) {
          expect(item.percentRemaining, inInclusiveRange(0.0, 1.0));
        }
      });
    });

    group('Determinism', () {
      test('Same clock + injections → same result × 10', () {
        final inj = TestFactories.injection(doseU: 4.0);
        final clock = TestFactories.clockAt(90);
        final ref = calc.calculateSingleIOB(injection: inj, clock: clock).value.units;
        for (var i = 0; i < 10; i++) {
          expect(
            calc.calculateSingleIOB(injection: inj, clock: TestFactories.clockAt(90)).value.units,
            equals(ref),
          );
        }
      });
    });
  });
}
