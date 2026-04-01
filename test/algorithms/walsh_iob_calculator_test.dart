// test/algorithms/walsh_iob_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/algorithms/iob/walsh_iob_calculator.dart';
import 'package:insulin_assistant/domain/core/clock.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_duration.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

InjectionRecord _makeInjection({
  required DateTime injectedAt,
  required double doseUnits,
  required double durationMinutes,
  InjectionStatus status = InjectionStatus.confirmed,
  InsulinType type = InsulinType.rapidAnalogue,
}) {
  final dose = InsulinUnits.fromUnits(doseUnits).value;
  final duration = InsulinDuration.fromMinutes(durationMinutes).value;
  return InjectionRecord(
    id: 'test-${injectedAt.millisecondsSinceEpoch}',
    userId: 'user-1',
    injectedAt: injectedAt,
    doseUnits: dose,
    insulinType: type,
    duration: duration,
    status: status,
  );
}

void main() {
  late WalshIOBCalculator calc;
  final epoch = DateTime.utc(2024, 6, 1, 12, 0, 0);

  setUp(() {
    calc = const WalshIOBCalculator();
  });

  group('WalshIOBCalculator', () {
    // ── Single IOB ───────────────────────────────────────────────────────────

    group('calculateSingleIOB', () {
      test('returns zero for pending injection', () {
        final clock = FakeClock(epoch.add(const Duration(minutes: 60)));
        final injection = _makeInjection(
          injectedAt: epoch,
          doseUnits: 4.0,
          durationMinutes: 240,
          status: InjectionStatus.pending, // NOT confirmed
        );
        final result = calc.calculateSingleIOB(
          injection: injection,
          clock: clock,
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.units, equals(0.0));
      });

      test('returns zero for long-acting insulin', () {
        final clock = FakeClock(epoch.add(const Duration(minutes: 60)));
        final injection = _makeInjection(
          injectedAt: epoch,
          doseUnits: 10.0,
          durationMinutes: 480,
          type: InsulinType.longActing, // does NOT contribute to bolus IOB
        );
        final result = calc.calculateSingleIOB(
          injection: injection,
          clock: clock,
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.units, equals(0.0));
      });

      test('returns ~3.82 U for 4U at t=30 min (DIA=240)', () {
        final clock = FakeClock(epoch.add(const Duration(minutes: 30)));
        final injection = _makeInjection(
          injectedAt: epoch,
          doseUnits: 4.0,
          durationMinutes: 240,
        );
        final result = calc.calculateSingleIOB(
          injection: injection,
          clock: clock,
        );
        expect(result.isSuccess, isTrue);
        // 4 × 0.956 ≈ 3.82
        expect(result.value.units, closeTo(3.82, 0.05));
      });

      test('returns 0 when past DIA', () {
        final clock = FakeClock(epoch.add(const Duration(minutes: 300)));
        final injection = _makeInjection(
          injectedAt: epoch,
          doseUnits: 4.0,
          durationMinutes: 240,
        );
        final result = calc.calculateSingleIOB(
          injection: injection,
          clock: clock,
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.units, equals(0.0));
      });

      test('returns 4.0 U when elapsed is 0 (just injected)', () {
        final clock = FakeClock(epoch); // same time as injection
        final injection = _makeInjection(
          injectedAt: epoch,
          doseUnits: 4.0,
          durationMinutes: 240,
        );
        final result = calc.calculateSingleIOB(
          injection: injection,
          clock: clock,
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.units, closeTo(4.0, 0.01));
      });
    });

    // ── Total IOB ─────────────────────────────────────────────────────────────

    group('calculateTotalIOB', () {
      test('single injection total equals single IOB', () {
        final clock = FakeClock(epoch.add(const Duration(minutes: 60)));
        final injections = [
          _makeInjection(injectedAt: epoch, doseUnits: 4.0, durationMinutes: 240),
        ];
        final single = calc.calculateSingleIOB(
          injection: injections[0],
          clock: clock,
        );
        final total = calc.calculateTotalIOB(
          injections: injections,
          clock: clock,
        );
        expect(total.isSuccess, isTrue);
        expect(
          total.value.units,
          closeTo(single.value.units, 0.0001),
        );
      });

      test('two stacked injections sum correctly', () {
        // Injection 1: 4U, 90 min ago
        // Injection 2: 2U, 30 min ago
        final clock = FakeClock(epoch);
        final inj1 = _makeInjection(
          injectedAt: epoch.subtract(const Duration(minutes: 90)),
          doseUnits: 4.0,
          durationMinutes: 240,
        );
        final inj2 = _makeInjection(
          injectedAt: epoch.subtract(const Duration(minutes: 30)),
          doseUnits: 2.0,
          durationMinutes: 240,
        );

        final iob1 = calc.calculateSingleIOB(injection: inj1, clock: clock);
        final iob2 = calc.calculateSingleIOB(injection: inj2, clock: clock);
        final total = calc.calculateTotalIOB(
          injections: [inj1, inj2],
          clock: clock,
        );

        expect(total.isSuccess, isTrue);
        expect(
          total.value.units,
          closeTo(iob1.value.units + iob2.value.units, 0.001),
        );
      });

      test('empty injection list returns zero IOB', () {
        final clock = FakeClock(epoch);
        final result = calc.calculateTotalIOB(
          injections: [],
          clock: clock,
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.units, equals(0.0));
      });

      test('fully expired injections contribute zero to total', () {
        final clock = FakeClock(epoch.add(const Duration(minutes: 500)));
        final injections = [
          _makeInjection(
            injectedAt: epoch,
            doseUnits: 4.0,
            durationMinutes: 240,
          ),
          _makeInjection(
            injectedAt: epoch.add(const Duration(minutes: 30)),
            doseUnits: 2.0,
            durationMinutes: 240,
          ),
        ];
        final result = calc.calculateTotalIOB(
          injections: injections,
          clock: clock,
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.units, equals(0.0));
      });

      test('total IOB never exceeds sum of original doses', () {
        final clock = FakeClock(epoch.add(const Duration(minutes: 1)));
        final injections = [
          _makeInjection(injectedAt: epoch, doseUnits: 6.0, durationMinutes: 240),
          _makeInjection(
            injectedAt: epoch.subtract(const Duration(minutes: 1)),
            doseUnits: 4.0,
            durationMinutes: 240,
          ),
        ];
        const totalOriginal = 10.0;
        final result = calc.calculateTotalIOB(
          injections: injections,
          clock: clock,
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.units, lessThanOrEqualTo(totalOriginal));
      });
    });

    // ── Breakdown ─────────────────────────────────────────────────────────────

    group('calculateIOBBreakdown', () {
      test('breakdown has one entry per injection', () {
        final clock = FakeClock(epoch.add(const Duration(minutes: 60)));
        final injections = [
          _makeInjection(
            injectedAt: epoch.subtract(const Duration(minutes: 30)),
            doseUnits: 4.0,
            durationMinutes: 240,
          ),
          _makeInjection(
            injectedAt: epoch,
            doseUnits: 2.0,
            durationMinutes: 240,
          ),
        ];
        final result = calc.calculateIOBBreakdown(
          injections: injections,
          clock: clock,
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.length, equals(2));
      });

      test('breakdown items sum to total IOB', () {
        final clock = FakeClock(epoch.add(const Duration(minutes: 60)));
        final injections = [
          _makeInjection(injectedAt: epoch, doseUnits: 4.0, durationMinutes: 240),
          _makeInjection(
            injectedAt: epoch.subtract(const Duration(minutes: 30)),
            doseUnits: 2.0,
            durationMinutes: 240,
          ),
        ];
        final breakdown = calc.calculateIOBBreakdown(
          injections: injections,
          clock: clock,
        );
        final total = calc.calculateTotalIOB(
          injections: injections,
          clock: clock,
        );
        final sumFromBreakdown = breakdown.value
            .fold<double>(0.0, (s, item) => s + item.remainingIOB.units);
        expect(
          sumFromBreakdown,
          closeTo(total.value.units, 0.001),
        );
      });

      test('percentRemaining is within [0, 1]', () {
        final clock = FakeClock(epoch.add(const Duration(minutes: 60)));
        final injections = [
          _makeInjection(injectedAt: epoch, doseUnits: 4.0, durationMinutes: 240),
        ];
        final result = calc.calculateIOBBreakdown(
          injections: injections,
          clock: clock,
        );
        for (final item in result.value) {
          expect(item.percentRemaining, inInclusiveRange(0.0, 1.0));
        }
      });
    });

    // ── Clock abstraction ─────────────────────────────────────────────────────

    group('Clock abstraction', () {
      test('advancing FakeClock reduces IOB', () {
        final clock = FakeClock(epoch);
        final injection = _makeInjection(
          injectedAt: epoch,
          doseUnits: 4.0,
          durationMinutes: 240,
        );

        clock.advance(const Duration(minutes: 60));
        final iobAt60 = calc.calculateSingleIOB(
          injection: injection,
          clock: clock,
        );

        clock.advance(const Duration(minutes: 60)); // now at 120 min
        final iobAt120 = calc.calculateSingleIOB(
          injection: injection,
          clock: clock,
        );

        expect(iobAt120.value.units, lessThan(iobAt60.value.units));
      });

      test('different clocks at same time produce identical IOB (determinism)', () {
        final clock1 = FakeClock(epoch.add(const Duration(minutes: 90)));
        final clock2 = FakeClock(epoch.add(const Duration(minutes: 90)));
        final injection = _makeInjection(
          injectedAt: epoch,
          doseUnits: 4.0,
          durationMinutes: 240,
        );
        final r1 = calc.calculateSingleIOB(injection: injection, clock: clock1);
        final r2 = calc.calculateSingleIOB(injection: injection, clock: clock2);
        expect(r1.value.units, equals(r2.value.units));
      });
    });
  });
}
