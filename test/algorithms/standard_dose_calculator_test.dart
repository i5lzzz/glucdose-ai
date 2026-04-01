// test/algorithms/standard_dose_calculator_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Exhaustive tests for StandardDoseCalculator.
//
// MANDATORY EDGE CASES:
//   • BG = 39 (hard-block territory — calculator still runs, safety eval blocks)
//   • carbs = 0 (correction-only dose)
//   • IOB > calculated dose (should clamp to zero)
//   • dose exceeds absolute ceiling (should clamp)
//   • dose exceeds user ceiling (should clamp to user ceiling)
//   • negative correction (BG below target)
//   • zero dose result
//
// REPRODUCIBILITY:
//   Same inputs → identical CalculationTrace.output (determinism proof).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';

import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/algorithms/dose/standard_dose_calculator.dart';
import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/entities/calculation_trace.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/carb_ratio.dart';
import 'package:insulin_assistant/domain/value_objects/carbohydrates.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_sensitivity_factor.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

DoseCalculationInput _input({
  double bgMgdl = 150,
  double carbsG = 60,
  double iobUnits = 0.0,
  double icr = 10.0,
  double isf = 50.0,
  double targetBgMgdl = 100,
  double userMaxDose = 10.0,
}) {
  return DoseCalculationInput(
    currentBG: BloodGlucose.fromMgdl(bgMgdl).value,
    carbohydrates: Carbohydrates.fromGrams(carbsG).value,
    iob: InsulinUnits.fromUnitsUnclamped(iobUnits).value,
    carbRatio: CarbRatio.fromGramsPerUnit(icr).value,
    sensitivityFactor: InsulinSensitivityFactor.fromMgdlPerUnit(isf).value,
    targetBG: BloodGlucose.fromMgdl(targetBgMgdl).value,
    userMaxDose: InsulinUnits.fromUnits(userMaxDose).value,
    timestampUtc: DateTime.utc(2024, 6, 1, 12, 0),
  );
}

StandardDoseCalculator _calc({DoseStep step = DoseStep.half}) =>
    StandardDoseCalculator(appVersion: '1.0.0-test', doseStep: step);

void main() {
  group('StandardDoseCalculator', () {
    // ── Core formula verification ─────────────────────────────────────────────

    group('formula: dose = carbs/ICR + (BG-target)/ISF - IOB', () {
      test('standard case: 60g carbs, BG=150, target=100, ISF=50, ICR=10, IOB=0', () {
        // meal      = 60 / 10 = 6.0 U
        // correction = (150 - 100) / 50 = 1.0 U
        // iob       = 0.0 U
        // raw       = 6.0 + 1.0 - 0.0 = 7.0 U
        // stepped (0.5) = 7.0 U
        final result = _calc().calculate(_input());
        expect(result.isSuccess, isTrue);
        final trace = result.value;
        expect(trace.output.carbComponent, closeTo(6.0, 0.001));
        expect(trace.output.correctionComponent, closeTo(1.0, 0.001));
        expect(trace.output.iobDeduction, closeTo(0.0, 0.001));
        expect(trace.output.clampedDose.units, closeTo(7.0, 0.001));
      });

      test('meal only: carbs=45, BG=100 (at target), ICR=15', () {
        // meal      = 45 / 15 = 3.0 U
        // correction = (100 - 100) / 50 = 0.0
        // raw       = 3.0 U → stepped = 3.0
        final result = _calc().calculate(
          _input(carbsG: 45, bgMgdl: 100, icr: 15),
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.output.clampedDose.units, closeTo(3.0, 0.001));
        expect(result.value.output.correctionComponent, closeTo(0.0, 0.001));
      });

      test('correction only: carbs=0, BG=200, target=100, ISF=50', () {
        // meal      = 0 / 10 = 0 U
        // correction = (200 - 100) / 50 = 2.0 U
        // raw       = 2.0 U → stepped = 2.0
        final result = _calc().calculate(
          _input(carbsG: 0, bgMgdl: 200),
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.output.carbComponent, closeTo(0.0, 0.001));
        expect(result.value.output.correctionComponent, closeTo(2.0, 0.001));
        expect(result.value.output.clampedDose.units, closeTo(2.0, 0.001));
      });

      test('IOB deduction reduces dose', () {
        // Without IOB: 6.0 + 1.0 = 7.0 U
        // With IOB=2: 7.0 - 2.0 = 5.0 U
        final result = _calc().calculate(_input(iobUnits: 2.0));
        expect(result.isSuccess, isTrue);
        expect(result.value.output.clampedDose.units, closeTo(5.0, 0.001));
      });

      test('negative correction: BG below target reduces dose', () {
        // BG=80, target=100, ISF=50
        // correction = (80 - 100) / 50 = -0.4 U
        // meal = 60/10 = 6.0 U
        // raw = 6.0 - 0.4 = 5.6 → stepped(0.5) = 5.5
        final result = _calc().calculate(
          _input(bgMgdl: 80, carbsG: 60),
        );
        expect(result.isSuccess, isTrue);
        expect(
          result.value.output.correctionComponent,
          closeTo(-0.4, 0.001),
        );
        expect(result.value.output.clampedDose.units, closeTo(5.5, 0.001));
      });
    });

    // ── Edge cases ────────────────────────────────────────────────────────────

    group('edge cases', () {
      test('[CRITICAL] BG=39 — calculator runs; safety layer (not calculator) blocks', () {
        // The calculator is pure and does NOT enforce hypoglycaemia rules.
        // Blocking is the SafetyEvaluator's responsibility.
        // The result should still be a valid (though clinically wrong) output
        // so the safety layer has something to evaluate.
        final result = _calc().calculate(
          _input(bgMgdl: 39, carbsG: 0, iobUnits: 0),
        );
        // BG=39 can't construct a valid BloodGlucose VO (min=20, valid).
        // correction = (39 - 100) / 50 = -1.22 → clamped to 0
        expect(result.isSuccess, isTrue);
        expect(result.value.output.clampedDose.units, equals(0.0));
        expect(result.value.output.wasBlocked, isFalse); // calculator doesn't block
      });

      test('[CRITICAL] carbs=0: correction-only dose', () {
        final result = _calc().calculate(
          _input(carbsG: 0, bgMgdl: 250),
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.output.carbComponent, closeTo(0.0, 0.001));
        // correction = (250 - 100) / 50 = 3.0
        expect(result.value.output.clampedDose.units, closeTo(3.0, 0.001));
      });

      test('[CRITICAL] IOB > calculated dose → clamp to zero', () {
        // meal=6, correction=1, total=7, IOB=10 → raw = -3 → clamp to 0
        final result = _calc().calculate(_input(iobUnits: 10.0));
        expect(result.isSuccess, isTrue);
        expect(result.value.output.clampedDose.units, equals(0.0));
        // Flag: negativeDoseCalculated
        final flags = result.value.output.safetyFlags;
        expect(
          flags.any((f) => f.reason == SafetyBlockReason.negativeDoseCalculated),
          isTrue,
        );
      });

      test('IOB exactly equals calculated dose → zero dose', () {
        // 60/10 + (150-100)/50 = 7.0, IOB = 7.0 → raw = 0.0
        final result = _calc().calculate(_input(iobUnits: 7.0));
        expect(result.isSuccess, isTrue);
        expect(result.value.output.clampedDose.units, equals(0.0));
      });

      test('[CRITICAL] dose exceeds absolute ceiling → clamped to 20U', () {
        // carbs=300, ICR=10 → meal=30, way above absolute max
        final result = _calc().calculate(
          _input(carbsG: 300, bgMgdl: 100, userMaxDose: 10.0),
        );
        expect(result.isSuccess, isTrue);
        expect(
          result.value.output.clampedDose.units,
          lessThanOrEqualTo(MedicalConstants.absoluteMaxSingleDoseUnits),
        );
        final flags = result.value.output.safetyFlags;
        expect(
          flags.any(
            (f) =>
                f.reason == SafetyBlockReason.doseExceedsAbsoluteCeiling ||
                f.reason == SafetyBlockReason.doseExceedsUserCeiling,
          ),
          isTrue,
        );
      });

      test('dose exceeds user ceiling but not absolute → clamped to user max', () {
        // 60/10 + 1 = 7.0, user max = 5.0
        final result = _calc().calculate(_input(userMaxDose: 5.0));
        expect(result.isSuccess, isTrue);
        expect(result.value.output.clampedDose.units, closeTo(5.0, 0.001));
        expect(
          result.value.output.safetyFlags.any(
            (f) => f.reason == SafetyBlockReason.doseExceedsUserCeiling,
          ),
          isTrue,
        );
      });
    });

    // ── Dose step rounding ────────────────────────────────────────────────────

    group('dose step rounding', () {
      test('0.5U step floors 7.4 → 7.0', () {
        // raw = 7.4 U  →  floor(7.4 / 0.5) × 0.5 = 14 × 0.5 = 7.0
        final calc = _calc(step: DoseStep.half);
        // ISF=50, carbs=72, ICR=10 → meal=7.2, correction=(150-100)/50=1.0
        // IOB=0.8 → raw = 7.2 + 1.0 - 0.8 = 7.4
        final result = calc.calculate(
          _input(carbsG: 72, bgMgdl: 150, iobUnits: 0.8),
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.output.clampedDose.units, closeTo(7.0, 0.001));
      });

      test('0.1U step floors 7.43 → 7.4', () {
        final calc = _calc(step: DoseStep.tenth);
        final result = calc.calculate(
          _input(carbsG: 72, bgMgdl: 150, iobUnits: 0.8),
        );
        expect(result.isSuccess, isTrue);
        expect(result.value.output.clampedDose.units, closeTo(7.4, 0.001));
      });

      test('1.0U step floors 7.9 → 7.0', () {
        final calc = _calc(step: DoseStep.whole);
        // carbs=60/10=6, correction=(199-100)/50=1.98 → raw=7.98 → floor=7
        final result = calc.calculate(_input(bgMgdl: 199));
        expect(result.isSuccess, isTrue);
        expect(result.value.output.clampedDose.units, closeTo(7.0, 0.001));
      });
    });

    // ── CalculationTrace integrity ────────────────────────────────────────────

    group('CalculationTrace', () {
      test('trace contains algorithmVersion', () {
        final result = _calc().calculate(_input());
        expect(result.value.algorithmVersion, isNotEmpty);
      });

      test('trace input matches provided input values', () {
        final input = _input(bgMgdl: 140, carbsG: 45);
        final result = _calc().calculate(input);
        expect(result.value.input.currentBG.mgdl, equals(140));
        expect(result.value.input.carbohydrates.grams, equals(45));
      });

      test('trace steps are non-empty', () {
        final result = _calc().calculate(_input());
        expect(result.value.steps, isNotEmpty);
      });

      test('DETERMINISM: same inputs → identical output', () {
        final input = _input(bgMgdl: 155, carbsG: 75);
        final r1 = _calc().calculate(input);
        final r2 = _calc().calculate(input);
        expect(
          r1.value.output.clampedDose.units,
          equals(r2.value.output.clampedDose.units),
        );
        expect(
          r1.value.output.rawCalculatedDose,
          equals(r2.value.output.rawCalculatedDose),
        );
      });

      test('trace can be serialised to JSON', () {
        final result = _calc().calculate(_input());
        final json = result.value.toJson();
        expect(json['input'], isA<Map>());
        expect(json['output'], isA<Map>());
        expect(json['steps'], isA<List>());
        expect(json['algorithm_version'], isNotEmpty);
      });

      test('human explanation is non-empty', () {
        final result = _calc().calculate(_input());
        expect(result.value.humanExplanation, isNotEmpty);
      });
    });

    // ── IOB stacking warning ──────────────────────────────────────────────────

    group('IOB stacking flag', () {
      test('raised when IOB exceeds stacking threshold', () {
        final result = _calc().calculate(
          _input(iobUnits: MedicalConstants.iobStackingWarningThreshold + 0.1),
        );
        expect(result.isSuccess, isTrue);
        expect(
          result.value.output.safetyFlags.any(
            (f) => f.reason == SafetyBlockReason.iobStackingDetected,
          ),
          isTrue,
        );
      });

      test('not raised when IOB is below threshold', () {
        final result = _calc().calculate(_input(iobUnits: 1.0));
        expect(
          result.value.output.safetyFlags
              .any((f) => f.reason == SafetyBlockReason.iobStackingDetected),
          isFalse,
        );
      });
    });

    // ── Precision safety ──────────────────────────────────────────────────────

    group('precision safety', () {
      test('no NaN in output', () {
        final result = _calc().calculate(_input());
        expect(result.value.output.rawCalculatedDose.isNaN, isFalse);
        expect(result.value.output.clampedDose.units.isNaN, isFalse);
      });

      test('no Infinity in output', () {
        final result = _calc().calculate(_input());
        expect(result.value.output.rawCalculatedDose.isInfinite, isFalse);
        expect(result.value.output.clampedDose.units.isInfinite, isFalse);
      });

      test('final dose is never negative', () {
        // Try every combination of high IOB and low carbs
        for (var iob = 0.0; iob <= 10.0; iob += 2.0) {
          for (var carbs = 0.0; carbs <= 60.0; carbs += 20.0) {
            final r = _calc().calculate(_input(carbsG: carbs, iobUnits: iob));
            expect(
              r.value.output.clampedDose.units,
              greaterThanOrEqualTo(0.0),
              reason: 'Negative dose for carbs=$carbs, iob=$iob',
            );
          }
        }
      });
    });
  });
}
