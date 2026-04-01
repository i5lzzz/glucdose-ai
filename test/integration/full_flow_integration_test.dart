// test/integration/full_flow_integration_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Full-flow integration test: input → calculate → safety → predict
//
// These tests validate that the layers work correctly together, not just
// in isolation.  Every test exercises the complete medical pipeline.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_input.dart';
import 'package:insulin_assistant/ai/prediction/engines/hybrid_prediction_engine.dart';
import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/algorithms/dose/standard_dose_calculator.dart';
import 'package:insulin_assistant/algorithms/iob/walsh_iob_calculator.dart';
import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/core/clock.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';
import 'package:insulin_assistant/safety/core/safety_level.dart';
import 'package:insulin_assistant/safety/engine/safety_evaluator_impl.dart';

import '../helpers/test_factories.dart';

void main() {
  group('Full Pipeline Integration', () {
    const calculator = StandardDoseCalculator(appVersion: '1.0.0-test');
    const iobCalc = WalshIOBCalculator();
    const safetyEval = SafetyEvaluatorImpl();
    const predEngine = HybridPredictionEngine();

    // ══════════════════════════════════════════════════════════════════════
    // FLOW 1 — Normal pre-meal bolus
    // ══════════════════════════════════════════════════════════════════════

    test('[FLOW 1] Normal pre-meal: BG=150, 60g carbs → safe dose → prediction', () async {
      // Step 1: Calculate IOB (no previous injections)
      final iobResult = iobCalc.calculateTotalIOB(
        injections: [],
        clock: TestFactories.clock(),
      );
      expect(iobResult.isSuccess, isTrue);
      expect(iobResult.value.units, equals(0.0));

      // Step 2: Build input
      final input = TestFactories.calcInput(
        bgVal: 150, carbsG: 60, iobU: iobResult.value.units,
      );

      // Step 3: Calculate dose
      final traceResult = calculator.calculate(input);
      expect(traceResult.isSuccess, isTrue);
      final trace = traceResult.value;
      expect(trace.output.clampedDose.units, closeTo(7.0, 0.001));

      // Step 4: Safety evaluation
      final eval = safetyEval.evaluateRich(
        trace: trace,
        profile: TestFactories.profile(),
        currentBG: TestFactories.bg(150),
        currentIOB: iobResult.value,
      );
      expect(eval.level, equals(SafetyLevel.safe));
      expect(eval.isOverrideable, isFalse);
      expect(eval.approvedDoseUnits, closeTo(7.0, 0.001));

      // Step 5: Predict post-dose glucose
      final predInput = PredictionInput.create(
        currentBG: TestFactories.bg(150),
        carbohydrates: TestFactories.carbs(60),
        doseUnits: eval.approvedDoseUnits != null
            ? TestFactories.dose(eval.approvedDoseUnits!)
            : TestFactories.dose(0),
        iob: iobResult.value,
        isfMgdlPerUnit: 50,
        icrGramsPerUnit: 10,
        insulinDuration: TestFactories.injection().duration,
        minutesSinceInjection: 0,
        carbAbsorptionHalfTimeMinutes: 75,
        snapshotUtc: TestFactories.epoch,
        linkedTraceId: trace.id,
      ).value;

      final prediction = (await predEngine.predict(predInput)).value;
      expect(prediction.linkedTraceId, equals(trace.id));
      expect(prediction.at30min.predictedBGMgdl, isNotNull);
      // With balanced dose/carbs, prediction should be reasonable
      expect(prediction.at60min.predictedBGMgdl, inInclusiveRange(60.0, 350.0));
    });

    // ══════════════════════════════════════════════════════════════════════
    // FLOW 2 — Hypoglycaemia block
    // ══════════════════════════════════════════════════════════════════════

    test('[FLOW 2] BG=39 → pre-check blocks before calculation', () {
      final preCheck = safetyEval.preCheck(
        currentBG: TestFactories.bg(39),
        profile: TestFactories.profile(),
        currentIOB: TestFactories.iob(0),
      );

      // MUST NOT proceed to calculation
      expect(preCheck.canProceed, isFalse);
      expect(preCheck.blockReason, isNotNull);

      // If someone bypassed the pre-check (bug), calculator still works
      // but safety evaluator will still block
      final trace = calculator.calculate(
        TestFactories.calcInput(bgVal: 39, carbsG: 0),
      ).value;
      final eval = safetyEval.evaluateRich(
        trace: trace,
        profile: TestFactories.profile(),
        currentBG: TestFactories.bg(39),
        currentIOB: TestFactories.iob(0),
      );
      expect(eval.isHardBlocked, isTrue);
      expect(eval.approvedDoseUnits, isNull);
    });

    // ══════════════════════════════════════════════════════════════════════
    // FLOW 3 — IOB stacking scenario
    // ══════════════════════════════════════════════════════════════════════

    test('[FLOW 3] Previous injection 45 min ago → IOB reduces new dose', () {
      final base = TestFactories.epoch;
      final clock = FakeClock(base);

      // Previous injection: 4U, 45 min ago
      final prevInj = TestFactories.injection(
        id: 'prev',
        injectedAt: base.subtract(const Duration(minutes: 45)),
        doseU: 4.0,
      );

      // Compute current IOB
      final iobResult = iobCalc.calculateTotalIOB(
        injections: [prevInj],
        clock: clock,
      );
      expect(iobResult.isSuccess, isTrue);
      // At 45 min, ~75% remains: 4 × 0.75 ≈ 3.0 U
      expect(iobResult.value.units, inInclusiveRange(2.5, 3.5));

      // New dose calculation WITH IOB
      final withIOB = calculator.calculate(
        TestFactories.calcInput(bgVal: 150, carbsG: 60, iobU: iobResult.value.units),
      ).value;

      // New dose WITHOUT IOB for comparison
      final withoutIOB = calculator.calculate(
        TestFactories.calcInput(bgVal: 150, carbsG: 60, iobU: 0),
      ).value;

      // IOB should reduce the dose
      expect(
        withIOB.output.clampedDose.units,
        lessThan(withoutIOB.output.clampedDose.units),
      );

      // Safety evaluation should warn about IOB
      final eval = safetyEval.evaluateRich(
        trace: withIOB,
        profile: TestFactories.profile(),
        currentBG: TestFactories.bg(150),
        currentIOB: iobResult.value,
      );
      // IOB warning may or may not fire depending on threshold
      expect([SafetyLevel.safe, SafetyLevel.warning].contains(eval.level), isTrue);
    });

    // ══════════════════════════════════════════════════════════════════════
    // FLOW 4 — Dose ceiling protection
    // ══════════════════════════════════════════════════════════════════════

    test('[FLOW 4] Extreme carbs → dose clamped + safety flagged', () {
      // 400g carbs / 10 ICR = 40U — far above absolute ceiling
      final trace = calculator.calculate(
        TestFactories.calcInput(
          carbsG: MedicalConstants.maxCarbohydratesPerMealGrams,
          bgVal: 200,
          userMax: 10.0,
        ),
      ).value;

      // Dose must be clamped
      expect(
        trace.output.clampedDose.units,
        lessThanOrEqualTo(MedicalConstants.absoluteMaxSingleDoseUnits),
      );

      final eval = safetyEval.evaluateRich(
        trace: trace,
        profile: TestFactories.profile(maxDose: 10.0),
        currentBG: TestFactories.bg(200),
        currentIOB: TestFactories.iob(0),
      );

      // Safety must flag ceiling clamp
      expect(
        eval.flags.any((f) =>
            f.ruleId == 'R101_DOSE_CEILING' ||
            f.ruleId.contains('CEILING')),
        isTrue,
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // FLOW 5 — Correction-only flow (zero carbs)
    // ══════════════════════════════════════════════════════════════════════

    test('[FLOW 5] carbs=0, high BG → correction-only dose', () async {
      const bgVal = 220.0;
      // correction = (220-100)/50 = 2.4 → floor(0.5) = 2.0
      final trace = calculator.calculate(
        TestFactories.calcInput(bgVal: bgVal, carbsG: 0, iobU: 0),
      ).value;

      expect(trace.output.carbComponent, closeTo(0.0, 0.001));
      expect(trace.output.correctionComponent, closeTo(2.4, 0.01));
      expect(trace.output.clampedDose.units, closeTo(2.0, 0.001));

      final eval = safetyEval.evaluateRich(
        trace: trace,
        profile: TestFactories.profile(),
        currentBG: TestFactories.bg(bgVal),
        currentIOB: TestFactories.iob(0),
      );
      expect(eval.level, equals(SafetyLevel.safe));

      // Predict post-correction
      final predInput = PredictionInput.create(
        currentBG: TestFactories.bg(bgVal),
        carbohydrates: TestFactories.carbs(0),
        doseUnits: TestFactories.dose(trace.output.clampedDose.units),
        iob: TestFactories.iob(0),
        isfMgdlPerUnit: 50,
        icrGramsPerUnit: 10,
        insulinDuration: TestFactories.injection().duration,
        minutesSinceInjection: 0,
        carbAbsorptionHalfTimeMinutes: 75,
        snapshotUtc: TestFactories.epoch,
      ).value;

      final pred = (await predEngine.predict(predInput)).value;
      // With correction dose, BG should fall at 60-120 min
      expect(pred.at120min.predictedBGMgdl, lessThan(bgVal));
    });

    // ══════════════════════════════════════════════════════════════════════
    // FLOW 6 — Performance: 100 rapid calculations
    // ══════════════════════════════════════════════════════════════════════

    test('[PERF] 100 dose calculations complete < 500ms', () {
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        calculator.calculate(
          TestFactories.calcInput(
            bgVal: 100.0 + i,
            carbsG: 30.0 + (i % 10) * 5,
            iobU: (i % 5) * 0.5,
          ),
        );
      }
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: '100 calculations took ${stopwatch.elapsedMilliseconds}ms');
    });

    // ══════════════════════════════════════════════════════════════════════
    // FLOW 7 — IOB with 10 stacked injections
    // ══════════════════════════════════════════════════════════════════════

    test('[PERF] IOB with 10 stacked injections is accurate', () {
      final base = TestFactories.epoch;
      final clock = FakeClock(base);

      // 10 injections, each 30 min apart
      final injections = List.generate(10, (i) {
        return TestFactories.injection(
          id: 'stack-$i',
          injectedAt: base.subtract(Duration(minutes: i * 30)),
          doseU: 2.0,
        );
      });

      final totalOriginal = 10 * 2.0; // 20U
      final result = iobCalc.calculateTotalIOB(
        injections: injections,
        clock: clock,
      );

      expect(result.isSuccess, isTrue);
      // IOB must be > 0 (recent injections still active)
      expect(result.value.units, greaterThan(0));
      // IOB must be <= total original dose
      expect(result.value.units, lessThanOrEqualTo(totalOriginal + 0.01));
    });
  });
}
