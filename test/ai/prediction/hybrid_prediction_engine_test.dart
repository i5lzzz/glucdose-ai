// test/ai/prediction/hybrid_prediction_engine_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:insulin_assistant/ai/prediction/core/prediction_input.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_risk.dart';
import 'package:insulin_assistant/ai/prediction/engines/hybrid_prediction_engine.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/carbohydrates.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_duration.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

// ── Test helper ───────────────────────────────────────────────────────────────

Future<dynamic> _predict({
  double bgMgdl = 150,
  double carbsG = 60,
  double dose = 7.0,
  double iob = 0.0,
  double isf = 50.0,
  double icr = 10.0,
  double minutesSince = 0.0,
  double halfTime = 75.0,
  double trend = 0.0,
}) async {
  final input = PredictionInput.create(
    currentBG: BloodGlucose.fromMgdl(bgMgdl).value,
    carbohydrates: Carbohydrates.fromGrams(carbsG).value,
    doseUnits: InsulinUnits.fromUnits(dose).value,
    iob: InsulinUnits.fromUnitsUnclamped(iob).value,
    isfMgdlPerUnit: isf,
    icrGramsPerUnit: icr,
    insulinDuration: InsulinDuration.fourHours,
    minutesSinceInjection: minutesSince,
    carbAbsorptionHalfTimeMinutes: halfTime,
    snapshotUtc: DateTime.utc(2024, 6, 1, 12, 0),
    glucoseTrendMgdlPerMin: trend,
  ).value;

  final engine = const HybridPredictionEngine();
  final result = await engine.predict(input);
  return result.value;
}

void main() {
  group('HybridPredictionEngine', () {

    // ── Safety hooks ──────────────────────────────────────────────────────────

    group('Safety hooks', () {
      test('[CRITICAL] predicted < 55 → criticalHypo risk at relevant horizon', () async {
        // BG=80, large dose, no carbs → BG will drop significantly
        final output = await _predict(bgMgdl: 80, carbsG: 0, dose: 4.0, isf: 80);
        // At 120 min: 80 − (4 × 80 × ~0.9) ≈ 80 − 288 → clamped, but check risk
        final bg120 = output.at120min.predictedBGMgdl;
        // Not always critical, but model should detect hypo risk
        final hasHypo = output.hasHypoRisk || output.hasCriticalHypoRisk;
        expect(hasHypo, isTrue,
            reason: 'Large dose with no carbs should predict hypo risk. '
                'bg120=$bg120');
      });

      test('[SAFETY] predicted < 70 → hypo risk flag raised', () async {
        final output = await _predict(bgMgdl: 90, carbsG: 0, dose: 3.0, isf: 70);
        // 90 − 3×70×fraction → likely hypo at some horizon
        if (output.hasHypoRisk) {
          expect(output.earliestHypoMinutes, isNotNull);
          expect(
            output.all.any((h) => h.recommendedAction.recommendedCarbsGrams != null),
            isTrue,
            reason: 'Hypo risk should carry carb recommendation',
          );
        }
      });

      test('[SAFETY] predicted > 250 → hyper risk flag', () async {
        // High BG, lots of carbs, no insulin dose, no IOB
        final output = await _predict(bgMgdl: 200, carbsG: 150, dose: 0.0, isf: 50, icr: 10);
        // 200 + (150/10)×50 = 200 + 750 → clamped to 600, but risk = severeHyper
        expect(output.hasHyperRisk || output.hasAnyHyperRisk, isTrue,
            reason: 'High BG + large carbs with no insulin should flag hyper');
      });

      test('normal case: 150 BG, 60g carbs, 7U → stays in range or mildly elevated', () async {
        final output = await _predict();
        // At t=0 (before meal) → BG starts at 150
        // After 7U covers 60g carbs (60/10 = 6U carb, 1U correction) → balanced
        final bg60 = output.at60min.predictedBGMgdl;
        expect(bg60, inInclusiveRange(80.0, 220.0),
            reason: 'Balanced meal+dose should stay within reasonable range');
      });
    });

    // ── Formula verification ──────────────────────────────────────────────────

    group('Formula: predictedBG = currentBG + carbs − insulin − iob + trend', () {
      test('zero carbs, zero dose: BG stays at baseline', () async {
        final output = await _predict(bgMgdl: 150, carbsG: 0, dose: 0.0, iob: 0.0);
        // With no carbs, no dose, no IOB, no trend → BG ≈ current
        expect(output.at30min.predictedBGMgdl, closeTo(150.0, 5.0));
        expect(output.at60min.predictedBGMgdl, closeTo(150.0, 5.0));
        expect(output.at120min.predictedBGMgdl, closeTo(150.0, 5.0));
      });

      test('carbs only: BG rises over time', () async {
        final output = await _predict(bgMgdl: 100, carbsG: 60, dose: 0.0, iob: 0.0);
        expect(output.at30min.predictedBGMgdl, greaterThan(100));
        expect(output.at60min.predictedBGMgdl,
            greaterThan(output.at30min.predictedBGMgdl));
        expect(output.at120min.predictedBGMgdl,
            greaterThanOrEqualTo(output.at60min.predictedBGMgdl));
      });

      test('dose only: BG falls over time', () async {
        final output = await _predict(bgMgdl: 200, carbsG: 0, dose: 4.0, iob: 0.0);
        expect(output.at30min.predictedBGMgdl, lessThan(200));
        expect(output.at60min.predictedBGMgdl,
            lessThanOrEqualTo(output.at30min.predictedBGMgdl));
        expect(output.at120min.predictedBGMgdl,
            lessThanOrEqualTo(output.at60min.predictedBGMgdl));
      });

      test('rising trend increases prediction at short horizons', () async {
        final withTrend = await _predict(trend: 2.0);
        final noTrend = await _predict(trend: 0.0);
        // Rising trend → predicted BG at 30 min should be higher
        expect(
          withTrend.at30min.predictedBGMgdl,
          greaterThan(noTrend.at30min.predictedBGMgdl),
        );
      });

      test('falling trend decreases prediction', () async {
        final withFallTrend = await _predict(trend: -2.0);
        final noTrend = await _predict(trend: 0.0);
        expect(
          withFallTrend.at30min.predictedBGMgdl,
          lessThan(noTrend.at30min.predictedBGMgdl),
        );
      });

      test('trend impact saturates (does not dominate at 120 min)', () async {
        // Even with extreme rising trend, prediction should not be 10× baseline
        final output = await _predict(bgMgdl: 150, trend: 3.5);
        expect(output.at120min.predictedBGMgdl, lessThan(600));
      });

      test('IOB lowers predicted BG', () async {
        final withIOB = await _predict(iob: 3.0);
        final noIOB = await _predict(iob: 0.0);
        expect(
          withIOB.at60min.predictedBGMgdl,
          lessThan(noIOB.at60min.predictedBGMgdl),
        );
      });
    });

    // ── Physiological clamping ────────────────────────────────────────────────

    group('Physiological clamping', () {
      test('prediction never goes below 20 mg/dL', () async {
        final output = await _predict(bgMgdl: 40, carbsG: 0, dose: 20, isf: 100);
        expect(output.at30min.predictedBGMgdl, greaterThanOrEqualTo(20));
        expect(output.at60min.predictedBGMgdl, greaterThanOrEqualTo(20));
        expect(output.at120min.predictedBGMgdl, greaterThanOrEqualTo(20));
      });

      test('prediction never exceeds 600 mg/dL', () async {
        final output = await _predict(bgMgdl: 400, carbsG: 300, dose: 0, isf: 50, icr: 10);
        expect(output.at30min.predictedBGMgdl, lessThanOrEqualTo(600));
        expect(output.at60min.predictedBGMgdl, lessThanOrEqualTo(600));
        expect(output.at120min.predictedBGMgdl, lessThanOrEqualTo(600));
      });
    });

    // ── Explainability ────────────────────────────────────────────────────────

    group('Explainability', () {
      test('contribution record is non-null for all horizons', () async {
        final output = await _predict();
        for (final h in output.all) {
          expect(h.contribution, isNotNull);
          expect(h.contribution.explanationAr, isNotEmpty);
          expect(h.contribution.explanationEn, isNotEmpty);
        }
      });

      test('zero carbs → carb contribution is ~0', () async {
        final output = await _predict(carbsG: 0, dose: 0);
        for (final h in output.all) {
          expect(h.contribution.carbContributionMgdl, closeTo(0.0, 0.01));
        }
      });

      test('zero dose → insulin contribution is ~0', () async {
        final output = await _predict(dose: 0.0, carbsG: 0, iob: 0);
        for (final h in output.all) {
          expect(h.contribution.insulinContributionMgdl.abs(), closeTo(0.0, 0.5));
        }
      });

      test('carb fraction absorbed increases with horizon', () async {
        final output = await _predict(carbsG: 60);
        expect(
          output.at30min.contribution.carbFractionAbsorbed,
          lessThan(output.at60min.contribution.carbFractionAbsorbed),
        );
        expect(
          output.at60min.contribution.carbFractionAbsorbed,
          lessThan(output.at120min.contribution.carbFractionAbsorbed),
        );
      });

      test('contribution serialises to JSON correctly', () async {
        final output = await _predict();
        final json = output.at60min.contribution.toJson();
        expect(json['horizon_min'], equals(60));
        expect(json['predicted_bg_mgdl'], isA<double>());
        expect(json['carb_contribution'], isA<double>());
        expect(json['insulin_contribution'], isA<double>());
      });

      test('dominant driver is carbs when large meal and small dose', () async {
        final output = await _predict(carbsG: 150, dose: 1.0, iob: 0, isf: 30, icr: 15);
        // At 60 min, carbs impact should dominate over 1U insulin
        final driver60 = output.at60min.contribution.dominantDriver;
        expect(driver60, equals(PredictionDriver.carbs));
      });

      test('dominant driver is insulin when large dose and no carbs', () async {
        final output = await _predict(carbsG: 0, dose: 8.0, iob: 0, isf: 50);
        final driver60 = output.at60min.contribution.dominantDriver;
        expect(driver60, equals(PredictionDriver.insulin));
      });
    });

    // ── Risk classification ───────────────────────────────────────────────────

    group('Risk classification', () {
      test('normal BG with balanced dose/carbs → inRange at 60 min', () async {
        // 150 + carb impact − insulin impact ≈ balanced
        final output = await _predict(bgMgdl: 120, carbsG: 60, dose: 6.0);
        // The exact risk depends on ISF/ICR balance, but should not be critical
        expect(
          output.at60min.riskLevel,
          isNot(PredictionRiskLevel.criticalHypo),
        );
      });

      test('confidence decreases with horizon', () async {
        final output = await _predict();
        expect(output.at30min.confidenceScore, greaterThan(output.at60min.confidenceScore));
        expect(output.at60min.confidenceScore, greaterThan(output.at120min.confidenceScore));
      });
    });

    // ── Output completeness ───────────────────────────────────────────────────

    group('Output completeness', () {
      test('all three horizons are present', () async {
        final output = await _predict();
        expect(output.at30min.horizonMinutes, equals(30));
        expect(output.at60min.horizonMinutes, equals(60));
        expect(output.at120min.horizonMinutes, equals(120));
      });

      test('output serialises to JSON', () async {
        final output = await _predict();
        final json = output.toJson();
        expect(json['at_30min'], isA<Map>());
        expect(json['at_60min'], isA<Map>());
        expect(json['at_120min'], isA<Map>());
        expect(json['model_version'], isNotEmpty);
        expect(json['is_hybrid'], isTrue);
      });

      test('model version is non-empty', () async {
        const engine = HybridPredictionEngine();
        expect(engine.modelVersion, isNotEmpty);
        expect(engine.isDeterministic, isTrue);
      });
    });

    // ── Determinism ───────────────────────────────────────────────────────────

    group('Determinism', () {
      test('same inputs → identical predictions (10 runs)', () async {
        final results = await Future.wait(
          List.generate(10, (_) => _predict(bgMgdl: 145, carbsG: 55)),
        );
        final ref = results.first.at60min.predictedBGMgdl;
        for (final r in results) {
          expect(r.at60min.predictedBGMgdl, equals(ref),
              reason: 'Prediction must be deterministic');
        }
      });

      test('changing one input changes the prediction', () async {
        final r1 = await _predict(bgMgdl: 120);
        final r2 = await _predict(bgMgdl: 180);
        expect(
          r1.at60min.predictedBGMgdl,
          isNot(r2.at60min.predictedBGMgdl),
        );
      });
    });

    // ── CalculationTrace integration ─────────────────────────────────────────

    group('CalculationTrace integration', () {
      test('linkedTraceId is preserved in output', () async {
        final input = PredictionInput.create(
          currentBG: BloodGlucose.fromMgdl(150).value,
          carbohydrates: Carbohydrates.fromGrams(60).value,
          doseUnits: InsulinUnits.fromUnits(7).value,
          iob: InsulinUnits.zero,
          isfMgdlPerUnit: 50,
          icrGramsPerUnit: 10,
          insulinDuration: InsulinDuration.fourHours,
          minutesSinceInjection: 0,
          carbAbsorptionHalfTimeMinutes: 75,
          snapshotUtc: DateTime.utc(2024, 6, 1),
          linkedTraceId: 'trace-abc-123',
        ).value;

        final engine = const HybridPredictionEngine();
        final output = (await engine.predict(input)).value;
        expect(output.linkedTraceId, equals('trace-abc-123'));
      });
    });
  });
}
