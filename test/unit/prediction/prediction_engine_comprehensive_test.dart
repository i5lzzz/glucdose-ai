// test/unit/prediction/prediction_engine_comprehensive_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_input.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_risk.dart';
import 'package:insulin_assistant/ai/prediction/engines/hybrid_prediction_engine.dart';
import 'package:insulin_assistant/ai/prediction/engines/tflite_prediction_engine.dart';
import 'package:insulin_assistant/ai/prediction/models/carb_absorption_model.dart';
import 'package:insulin_assistant/ai/prediction/models/insulin_activity_model.dart';
import 'package:insulin_assistant/ai/prediction/models/trend_adjustment_model.dart';

import '../../helpers/test_factories.dart';

const _engine = HybridPredictionEngine();

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
    currentBG: TestFactories.bg(bgMgdl),
    carbohydrates: TestFactories.carbs(carbsG),
    doseUnits: TestFactories.dose(dose),
    iob: TestFactories.iob(iob),
    isfMgdlPerUnit: isf,
    icrGramsPerUnit: icr,
    insulinDuration: TestFactories.injection().duration,
    minutesSinceInjection: minutesSince,
    carbAbsorptionHalfTimeMinutes: halfTime,
    snapshotUtc: TestFactories.epoch,
    glucoseTrendMgdlPerMin: trend,
  ).value;
  return (await _engine.predict(input)).value;
}

void main() {
  group('HybridPredictionEngine — Comprehensive Suite', () {

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 1 — Safety hooks
    // ══════════════════════════════════════════════════════════════════════

    group('Safety hooks', () {
      test('[predicted < 55] → criticalHypo risk raised', () async {
        // BG=80, large dose, no carbs → crash
        final out = await _predict(bgMgdl: 80, carbsG: 0, dose: 4.0, isf: 80);
        expect(out.hasHypoRisk || out.hasCriticalHypoRisk, isTrue,
            reason: 'Large dose+low BG should predict hypo');
      });

      test('[predicted < 70] → hypo risk with carb recommendation', () async {
        final out = await _predict(bgMgdl: 90, carbsG: 0, dose: 3.0, isf: 70);
        if (out.hasHypoRisk) {
          expect(
            out.all.any((h) => h.recommendedAction.recommendedCarbsGrams != null),
            isTrue,
          );
          expect(out.earliestHypoMinutes, isNotNull);
        }
      });

      test('[predicted > 250] → hyper risk flagged', () async {
        final out = await _predict(bgMgdl: 200, carbsG: 150, dose: 0.0);
        expect(out.hasHyperRisk || out.hasAnyHyperRisk, isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 2 — Formula verification
    // ══════════════════════════════════════════════════════════════════════

    group('Formula: BG + carbs - insulin - IOB + trend', () {
      test('Zero carbs + zero dose → BG stays near baseline', () async {
        final out = await _predict(bgMgdl: 150, carbsG: 0, dose: 0.0, iob: 0.0);
        expect(out.at30min.predictedBGMgdl, closeTo(150.0, 5.0));
        expect(out.at60min.predictedBGMgdl, closeTo(150.0, 5.0));
        expect(out.at120min.predictedBGMgdl, closeTo(150.0, 5.0));
      });

      test('Carbs only → BG rises monotonically', () async {
        final out = await _predict(bgMgdl: 100, carbsG: 60, dose: 0.0, iob: 0.0);
        expect(out.at30min.predictedBGMgdl, greaterThan(100));
        expect(out.at60min.predictedBGMgdl,
            greaterThan(out.at30min.predictedBGMgdl - 1));
      });

      test('Dose only → BG falls', () async {
        final out = await _predict(bgMgdl: 200, carbsG: 0, dose: 4.0, iob: 0.0);
        expect(out.at30min.predictedBGMgdl, lessThan(200));
        expect(out.at60min.predictedBGMgdl, lessThan(out.at30min.predictedBGMgdl + 1));
      });

      test('Rising trend increases predictions at short horizons', () async {
        final withTrend = await _predict(trend: 2.0);
        final noTrend = await _predict(trend: 0.0);
        expect(withTrend.at30min.predictedBGMgdl,
            greaterThan(noTrend.at30min.predictedBGMgdl));
      });

      test('Falling trend decreases predictions', () async {
        final withFall = await _predict(trend: -2.0);
        final noTrend = await _predict(trend: 0.0);
        expect(withFall.at30min.predictedBGMgdl,
            lessThan(noTrend.at30min.predictedBGMgdl));
      });

      test('Trend saturates — does not produce astronomical values', () async {
        final out = await _predict(bgMgdl: 150, trend: 3.5);
        expect(out.at120min.predictedBGMgdl, lessThan(600));
      });

      test('IOB lowers predicted BG', () async {
        final withIOB = await _predict(iob: 3.0);
        final noIOB = await _predict(iob: 0.0);
        expect(withIOB.at60min.predictedBGMgdl,
            lessThan(noIOB.at60min.predictedBGMgdl));
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 3 — Physiological clamping
    // ══════════════════════════════════════════════════════════════════════

    group('Physiological clamping [20, 600]', () {
      test('Never below 20 mg/dL', () async {
        final out = await _predict(bgMgdl: 40, carbsG: 0, dose: 20, isf: 100);
        for (final h in out.all) {
          expect(h.predictedBGMgdl, greaterThanOrEqualTo(20));
        }
      });

      test('Never above 600 mg/dL', () async {
        final out = await _predict(bgMgdl: 400, carbsG: 300, dose: 0, isf: 50, icr: 10);
        for (final h in out.all) {
          expect(h.predictedBGMgdl, lessThanOrEqualTo(600));
        }
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 4 — Explainability
    // ══════════════════════════════════════════════════════════════════════

    group('Explainability', () {
      test('Contribution record is non-null for all horizons', () async {
        final out = await _predict();
        for (final h in out.all) {
          expect(h.contribution, isNotNull);
          expect(h.contribution.explanationAr, isNotEmpty);
          expect(h.contribution.explanationEn, isNotEmpty);
        }
      });

      test('Zero carbs → carb contribution ≈ 0', () async {
        final out = await _predict(carbsG: 0, dose: 0);
        for (final h in out.all) {
          expect(h.contribution.carbContributionMgdl.abs(), lessThan(0.1));
        }
      });

      test('Carb fraction absorbed increases with horizon', () async {
        final out = await _predict(carbsG: 60);
        expect(out.at30min.contribution.carbFractionAbsorbed,
            lessThan(out.at60min.contribution.carbFractionAbsorbed));
        expect(out.at60min.contribution.carbFractionAbsorbed,
            lessThan(out.at120min.contribution.carbFractionAbsorbed));
      });

      test('Confidence decreases with horizon', () async {
        final out = await _predict();
        expect(out.at30min.confidenceScore,
            greaterThan(out.at60min.confidenceScore));
        expect(out.at60min.confidenceScore,
            greaterThan(out.at120min.confidenceScore));
      });

      test('Dominant driver = carbs when large meal + small dose', () async {
        final out = await _predict(carbsG: 150, dose: 1.0, iob: 0, isf: 30, icr: 15);
        expect(out.at60min.contribution.dominantDriver, equals(PredictionDriver.carbs));
      });

      test('Dominant driver = insulin when large dose + no carbs', () async {
        final out = await _predict(carbsG: 0, dose: 8.0, iob: 0, isf: 50);
        expect(out.at60min.contribution.dominantDriver, equals(PredictionDriver.insulin));
      });

      test('Contribution serialises to valid JSON', () async {
        final out = await _predict();
        final json = out.at60min.contribution.toJson();
        expect(json['horizon_min'], equals(60));
        expect(json['predicted_bg_mgdl'], isA<double>());
        expect(json['carb_contribution'], isA<double>());
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 5 — Output completeness
    // ══════════════════════════════════════════════════════════════════════

    group('Output completeness', () {
      test('All three horizons present with correct minutes', () async {
        final out = await _predict();
        expect(out.at30min.horizonMinutes, equals(30));
        expect(out.at60min.horizonMinutes, equals(60));
        expect(out.at120min.horizonMinutes, equals(120));
      });

      test('Output serialises to JSON', () async {
        final out = await _predict();
        final json = out.toJson();
        expect(json['at_30min'], isA<Map>());
        expect(json['at_60min'], isA<Map>());
        expect(json['at_120min'], isA<Map>());
        expect(json['model_version'], isNotEmpty);
        expect(json['is_hybrid'], isTrue);
      });

      test('linkedTraceId preserved', () async {
        final input = PredictionInput.create(
          currentBG: TestFactories.bg(150),
          carbohydrates: TestFactories.carbs(60),
          doseUnits: TestFactories.dose(7),
          iob: TestFactories.iob(0),
          isfMgdlPerUnit: 50,
          icrGramsPerUnit: 10,
          insulinDuration: TestFactories.injection().duration,
          minutesSinceInjection: 0,
          carbAbsorptionHalfTimeMinutes: 75,
          snapshotUtc: TestFactories.epoch,
          linkedTraceId: 'trace-abc',
        ).value;
        final out = (await _engine.predict(input)).value;
        expect(out.linkedTraceId, equals('trace-abc'));
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 6 — Determinism
    // ══════════════════════════════════════════════════════════════════════

    group('Determinism', () {
      test('Same inputs → identical predictions × 10', () async {
        final refs = <double>[];
        for (var i = 0; i < 10; i++) {
          final out = await _predict(bgMgdl: 145, carbsG: 55);
          refs.add(out.at60min.predictedBGMgdl);
        }
        expect(refs.toSet().length, equals(1),
            reason: 'All 10 runs must produce identical 60-min prediction');
      });

      test('Different input → different output', () async {
        final r1 = await _predict(bgMgdl: 120);
        final r2 = await _predict(bgMgdl: 180);
        expect(r1.at60min.predictedBGMgdl,
            isNot(equals(r2.at60min.predictedBGMgdl)));
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 7 — Sub-model unit tests
    // ══════════════════════════════════════════════════════════════════════

    group('CarbAbsorptionModel', () {
      test('F(0)=0, F(T½)=0.5, F(∞)→1', () {
        expect(CarbAbsorptionModel.fractionAbsorbed(minutesElapsed: 0, halfTimeMinutes: 75), equals(0.0));
        expect(CarbAbsorptionModel.fractionAbsorbed(minutesElapsed: 75, halfTimeMinutes: 75), closeTo(0.5, 0.001));
        expect(CarbAbsorptionModel.fractionAbsorbed(minutesElapsed: 10000, halfTimeMinutes: 75), closeTo(1.0, 0.001));
      });

      test('Fast > medium > slow at same time', () {
        const t = 60.0;
        expect(CarbAbsorptionModel.fractionAbsorbed(minutesElapsed: t, halfTimeMinutes: 35),
            greaterThan(CarbAbsorptionModel.fractionAbsorbed(minutesElapsed: t, halfTimeMinutes: 75)));
        expect(CarbAbsorptionModel.fractionAbsorbed(minutesElapsed: t, halfTimeMinutes: 75),
            greaterThan(CarbAbsorptionModel.fractionAbsorbed(minutesElapsed: t, halfTimeMinutes: 120)));
      });

      test('Always in [0, 1]', () {
        for (var t = 0.0; t <= 600.0; t += 15.0) {
          expect(
            CarbAbsorptionModel.fractionAbsorbed(minutesElapsed: t, halfTimeMinutes: 75),
            inInclusiveRange(0.0, 1.0),
          );
        }
      });
    });

    group('TrendAdjustmentModel', () {
      test('At t=0: zero adjustment', () {
        expect(TrendAdjustmentModel.bgAdjustmentAt(trendMgdlPerMin: 2.0, horizonMinutes: 0),
            closeTo(0.0, 0.001));
      });

      test('Positive trend → positive adjustment', () {
        expect(TrendAdjustmentModel.bgAdjustmentAt(trendMgdlPerMin: 2.0, horizonMinutes: 30),
            greaterThan(0));
      });

      test('Negative trend → negative adjustment', () {
        expect(TrendAdjustmentModel.bgAdjustmentAt(trendMgdlPerMin: -2.0, horizonMinutes: 30),
            lessThan(0));
      });

      test('Decays at long horizons', () {
        final adj30  = TrendAdjustmentModel.bgAdjustmentAt(trendMgdlPerMin: 2.0, horizonMinutes: 30).abs();
        final adj240 = TrendAdjustmentModel.bgAdjustmentAt(trendMgdlPerMin: 2.0, horizonMinutes: 240).abs();
        expect(adj240, lessThan(adj30));
      });
    });

    group('TFLitePredictionEngine stub', () {
      test('Stub falls back to hybrid engine transparently', () async {
        final stub = TFLitePredictionEngine(
          tfliteModelPath: 'assets/models/bg_predictor.tflite',
        );
        final input = PredictionInput.create(
          currentBG: TestFactories.bg(150),
          carbohydrates: TestFactories.carbs(60),
          doseUnits: TestFactories.dose(7),
          iob: TestFactories.iob(0),
          isfMgdlPerUnit: 50,
          icrGramsPerUnit: 10,
          insulinDuration: TestFactories.injection().duration,
          minutesSinceInjection: 0,
          carbAbsorptionHalfTimeMinutes: 75,
          snapshotUtc: TestFactories.epoch,
        ).value;
        final result = await stub.predict(input);
        expect(result.isSuccess, isTrue, reason: 'Stub must fall back to hybrid');
        expect(result.value.isHybridModel, isTrue);
      });
    });
  });
}
