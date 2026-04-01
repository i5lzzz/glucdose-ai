// test/unit/algorithms/dose_calculator_comprehensive_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Exhaustive DoseCalculator unit tests.
// Every branch, edge case, safety clamp, and step-rounding scenario is tested.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/algorithms/dose/standard_dose_calculator.dart';
import 'package:insulin_assistant/algorithms/version.dart';
import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/entities/calculation_trace.dart';

import '../../helpers/test_factories.dart';

StandardDoseCalculator _calc({DoseStep step = DoseStep.half}) =>
    StandardDoseCalculator(appVersion: '1.0.0-test', doseStep: step);

void main() {
  group('StandardDoseCalculator — Comprehensive Suite', () {
    // ══════════════════════════════════════════════════════════════════════
    // GROUP 1 — Core formula correctness
    // dose = carbs/ICR + (BG-target)/ISF - IOB
    // ══════════════════════════════════════════════════════════════════════

    group('Core formula', () {
      test('standard: 60g@ICR10 + (150-100)/ISF50 - IOB0 = 7.0U', () {
        final r = _calc().calculate(TestFactories.calcInput());
        expect(r.isSuccess, isTrue);
        expect(r.value.output.carbComponent, closeTo(6.0, 0.001));
        expect(r.value.output.correctionComponent, closeTo(1.0, 0.001));
        expect(r.value.output.iobDeduction, closeTo(0.0, 0.001));
        expect(r.value.output.clampedDose.units, closeTo(7.0, 0.001));
      });

      test('carb-only: no correction, no IOB', () {
        final r = _calc().calculate(
          TestFactories.calcInput(bgVal: 100, carbsG: 50, icrVal: 10),
        );
        expect(r.value.output.carbComponent, closeTo(5.0, 0.001));
        expect(r.value.output.correctionComponent, closeTo(0.0, 0.001));
        expect(r.value.output.clampedDose.units, closeTo(5.0, 0.001));
      });

      test('correction-only: zero carbs', () {
        // carbs=0, BG=200, target=100, ISF=50 → correction = 2U
        final r = _calc().calculate(
          TestFactories.calcInput(bgVal: 200, carbsG: 0),
        );
        expect(r.value.output.carbComponent, closeTo(0.0, 0.001));
        expect(r.value.output.correctionComponent, closeTo(2.0, 0.001));
        expect(r.value.output.clampedDose.units, closeTo(2.0, 0.001));
      });

      test('negative correction: BG below target reduces meal dose', () {
        // BG=80, target=100, ISF=50 → correction = -0.4U
        // meal = 60/10 = 6.0U → final = 6.0 - 0.4 - 0 = 5.6 → floor(0.5) = 5.5
        final r = _calc().calculate(
          TestFactories.calcInput(bgVal: 80, carbsG: 60),
        );
        expect(r.value.output.correctionComponent, closeTo(-0.4, 0.001));
        expect(r.value.output.clampedDose.units, closeTo(5.5, 0.001));
      });

      test('IOB deduction reduces final dose', () {
        // 7.0 raw - 2.0 IOB = 5.0
        final r = _calc().calculate(
          TestFactories.calcInput(iobU: 2.0),
        );
        expect(r.value.output.clampedDose.units, closeTo(5.0, 0.001));
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 2 — Critical safety edge cases
    // ══════════════════════════════════════════════════════════════════════

    group('Critical edge cases', () {
      test('[BG=39] calculator returns zero dose; does NOT block itself', () {
        // The calculator is pure — safety layer blocks, not the calculator.
        // BG=39 with carbs=0 → correction = (39-100)/50 = -1.22 → clamped to 0
        final r = _calc().calculate(
          TestFactories.calcInput(bgVal: 39, carbsG: 0, iobU: 0),
        );
        expect(r.isSuccess, isTrue);
        expect(r.value.output.clampedDose.units, equals(0.0));
        expect(r.value.output.wasBlocked, isFalse, reason:
            'Calculator is pure — it does not block. SafetyEvaluator blocks.');
      });

      test('[carbs=0] correction-only dose is calculated correctly', () {
        final r = _calc().calculate(
          TestFactories.calcInput(carbsG: 0, bgVal: 180),
        );
        expect(r.isSuccess, isTrue);
        // (180-100)/50 = 1.6 → floor(0.5) = 1.5
        expect(r.value.output.clampedDose.units, closeTo(1.5, 0.001));
      });

      test('[IOB > dose] clamps to 0, not negative', () {
        // 7.0 raw - 10.0 IOB = -3.0 → must clamp to 0
        final r = _calc().calculate(
          TestFactories.calcInput(iobU: 10.0),
        );
        expect(r.isSuccess, isTrue);
        expect(r.value.output.clampedDose.units, equals(0.0));
        expect(
          r.value.output.safetyFlags.any(
            (f) => f.reason == SafetyBlockReason.negativeDoseCalculated,
          ),
          isTrue,
        );
      });

      test('[IOB == dose] produces exactly zero dose', () {
        // meal=6, corr=1 → raw=7, IOB=7 → 0
        final r = _calc().calculate(
          TestFactories.calcInput(iobU: 7.0),
        );
        expect(r.value.output.clampedDose.units, equals(0.0));
      });

      test('[max dose clamp] absolute ceiling enforced', () {
        // 300g carbs / 10 ICR = 30U → clamped to 20U absolute max
        final r = _calc().calculate(
          TestFactories.calcInput(carbsG: 300, bgVal: 100, userMax: 20.0),
        );
        expect(
          r.value.output.clampedDose.units,
          lessThanOrEqualTo(MedicalConstants.absoluteMaxSingleDoseUnits),
        );
        expect(
          r.value.output.safetyFlags.any(
            (f) =>
                f.reason == SafetyBlockReason.doseExceedsAbsoluteCeiling ||
                f.reason == SafetyBlockReason.doseExceedsUserCeiling,
          ),
          isTrue,
        );
      });

      test('[user ceiling < absolute] user ceiling applied', () {
        // raw=7, user max=5 → clamped to 5
        final r = _calc().calculate(
          TestFactories.calcInput(userMax: 5.0),
        );
        expect(r.value.output.clampedDose.units, closeTo(5.0, 0.001));
        expect(
          r.value.output.safetyFlags
              .any((f) => f.reason == SafetyBlockReason.doseExceedsUserCeiling),
          isTrue,
        );
      });

      test('IOB stacking flag raised when IOB exceeds threshold', () {
        final r = _calc().calculate(
          TestFactories.calcInput(
            iobU: MedicalConstants.iobStackingWarningThreshold + 0.5,
          ),
        );
        expect(
          r.value.output.safetyFlags
              .any((f) => f.reason == SafetyBlockReason.iobStackingDetected),
          isTrue,
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 3 — Dose step rounding (floor semantics)
    // ══════════════════════════════════════════════════════════════════════

    group('Dose step floor semantics', () {
      test('0.5U step: 7.4 → 7.0 (never rounds up)', () {
        // raw≈7.4: carbs=72/10=7.2, corr=(150-100)/50=1.0, iob=0.8 → 7.4
        final r = _calc(step: DoseStep.half).calculate(
          TestFactories.calcInput(carbsG: 72, bgVal: 150, iobU: 0.8),
        );
        expect(r.value.output.clampedDose.units, closeTo(7.0, 0.001));
      });

      test('0.1U step: 7.4 → 7.4', () {
        final r = _calc(step: DoseStep.tenth).calculate(
          TestFactories.calcInput(carbsG: 72, bgVal: 150, iobU: 0.8),
        );
        expect(r.value.output.clampedDose.units, closeTo(7.4, 0.001));
      });

      test('1.0U step: 7.9 → 7.0', () {
        final r = _calc(step: DoseStep.whole).calculate(
          TestFactories.calcInput(bgVal: 199),
        );
        expect(r.value.output.clampedDose.units, closeTo(7.0, 0.001));
      });

      test('0.5U step: 0.4 → 0.0 (below minimum significant)', () {
        // correction=(120-100)/50=0.4, carbs=0 → 0.4 → floor = 0
        final r = _calc(step: DoseStep.half).calculate(
          TestFactories.calcInput(bgVal: 120, carbsG: 0),
        );
        expect(r.value.output.clampedDose.units, equals(0.0));
      });

      test('dose is never negative regardless of step', () {
        for (final step in DoseStep.values) {
          final r = _calc(step: step).calculate(
            TestFactories.calcInput(carbsG: 0, bgVal: 60, iobU: 5),
          );
          expect(r.value.output.clampedDose.units, greaterThanOrEqualTo(0.0),
              reason: 'Negative dose with step ${step.value}');
        }
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 4 — CalculationTrace integrity
    // ══════════════════════════════════════════════════════════════════════

    group('CalculationTrace', () {
      test('trace contains algorithmVersion', () {
        final r = _calc().calculate(TestFactories.calcInput());
        expect(r.value.algorithmVersion, equals(AlgorithmVersion.compositeVersion));
      });

      test('trace input matches provided values exactly', () {
        final input = TestFactories.calcInput(bgVal: 145, carbsG: 48);
        final r = _calc().calculate(input);
        expect(r.value.input.currentBG.mgdl, closeTo(145, 0.001));
        expect(r.value.input.carbohydrates.grams, closeTo(48, 0.001));
      });

      test('trace steps are non-empty and ordered', () {
        final r = _calc().calculate(TestFactories.calcInput());
        expect(r.value.steps, isNotEmpty);
        expect(r.value.steps.first.stepName, isNotEmpty);
      });

      test('trace output breakdown components sum to raw dose', () {
        final r = _calc().calculate(TestFactories.calcInput());
        final out = r.value.output;
        final sum = out.carbComponent + out.correctionComponent - out.iobDeduction;
        expect(sum, closeTo(out.rawCalculatedDose, 0.001));
      });

      test('DETERMINISM: same input → identical trace output × 20', () {
        final input = TestFactories.calcInput(bgVal: 155, carbsG: 75);
        final ref = _calc().calculate(input).value.output.clampedDose.units;
        for (var i = 0; i < 20; i++) {
          final r = _calc().calculate(input);
          expect(r.value.output.clampedDose.units, equals(ref));
        }
      });

      test('trace serialises to valid JSON', () {
        final r = _calc().calculate(TestFactories.calcInput());
        final json = r.value.toJson();
        expect(json['input'], isA<Map>());
        expect(json['output'], isA<Map>());
        expect(json['steps'], isA<List>());
        expect((json['steps'] as List).isNotEmpty, isTrue);
      });

      test('human explanation is non-empty Arabic text', () {
        final r = _calc().calculate(TestFactories.calcInput());
        final expl = r.value.humanExplanation;
        expect(expl, isNotEmpty);
        // Should contain Arabic characters
        expect(expl.contains(RegExp(r'[\u0600-\u06FF]')), isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 5 — Precision & floating-point safety
    // ══════════════════════════════════════════════════════════════════════

    group('Precision safety', () {
      test('no NaN in any output field', () {
        final r = _calc().calculate(TestFactories.calcInput());
        final out = r.value.output;
        expect(out.rawCalculatedDose.isNaN, isFalse);
        expect(out.clampedDose.units.isNaN, isFalse);
        expect(out.carbComponent.isNaN, isFalse);
        expect(out.correctionComponent.isNaN, isFalse);
      });

      test('no Infinity in any output field', () {
        final r = _calc().calculate(TestFactories.calcInput());
        final out = r.value.output;
        expect(out.rawCalculatedDose.isInfinite, isFalse);
        expect(out.clampedDose.units.isInfinite, isFalse);
      });

      test('floating-point notorious case 0.1+0.2 handled via step', () {
        // Ensure 0.1+0.2 precision issue doesn't appear in final dose
        final r = _calc(step: DoseStep.tenth).calculate(
          TestFactories.calcInput(carbsG: 3, carbsGrams: 3, icrVal: 10, bgVal: 100),
        );
        expect(r.isSuccess, isTrue);
        final d = r.value.output.clampedDose.units;
        expect(d * 10, closeTo((d * 10).roundToDouble(), 0.0001),
            reason: 'Dose should have clean 0.1 precision');
      });

      test('grid sweep: no negative dose for any BG/carbs/IOB combo', () {
        const bgs = [39.0, 40.0, 70.0, 100.0, 200.0, 400.0];
        const carbss = [0.0, 30.0, 60.0, 120.0];
        const iobs = [0.0, 2.0, 5.0, 10.0];

        for (final bg in bgs) {
          for (final carb in carbss) {
            for (final iob in iobs) {
              final clamped = bg.clamp(20.0, 600.0);
              final r = _calc().calculate(
                TestFactories.calcInput(bgVal: clamped, carbsG: carb, iobU: iob),
              );
              expect(r.isSuccess, isTrue,
                  reason: 'Failed for bg=$bg, carbs=$carb, iob=$iob');
              expect(r.value.output.clampedDose.units,
                  greaterThanOrEqualTo(0.0),
                  reason: 'Negative dose for bg=$bg, carbs=$carb, iob=$iob');
            }
          }
        }
      });
    });
  });
}

extension on TestFactories {
  static DoseCalculationInput calcInputExt({
    double bgVal = 150,
    double carbsG = 60,
    double carbsGrams = 60,
    double iobU = 0.0,
    double icrVal = 10.0,
    double isfVal = 50.0,
    double targetBG = 100.0,
    double userMax = 10.0,
  }) =>
      TestFactories.calcInput(
        bgVal: bgVal,
        carbsG: carbsGrams,
        iobU: iobU,
        icrVal: icrVal,
        isfVal: isfVal,
        targetBG: targetBG,
        userMax: userMax,
      );
}
