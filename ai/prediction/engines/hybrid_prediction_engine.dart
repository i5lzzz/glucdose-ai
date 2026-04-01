// lib/ai/prediction/engines/hybrid_prediction_engine.dart
// ─────────────────────────────────────────────────────────────────────────────
// HybridPredictionEngine — Phase 1 deterministic implementation.
//
// ═══════════════════════════════════════════════════════════════════════════
// THE PREDICTION FORMULA
// ═══════════════════════════════════════════════════════════════════════════
//
//   predictedBG(t) = currentBG
//                  + carbImpact(t)         [POSITIVE — raises BG]
//                  − insulinImpact(t)      [NEGATIVE — lowers BG]
//                  − iobImpact(t)          [NEGATIVE — lowers BG]
//                  + trendAdjustment(t)    [SIGNED]
//
// WHERE:
//
//   carbImpact(t) = maxCarbImpact × F(t)
//     maxCarbImpact = carbs × ISF / ICR
//     F(t) = 1 − exp(−ln2 × t / T½)    [carb absorption fraction]
//
//   insulinImpact(t) = dose × ISF × [IOB_pct(t₀) − IOB_pct(t₀ + t)]
//     IOB_pct = Walsh bilinear percentRemaining
//     t₀ = minutesSinceInjection
//
//   iobImpact(t) = iobUnits × ISF × [IOB_pct(0) − IOB_pct(t)]
//     (IOB tracks separately — injected further in the past)
//
//   trendAdjustment(t) = trend × τ × (1 − exp(−t/τ)) × exp(−t/60)
//
// PHYSIOLOGICAL CLAMP:
//   predictedBG is clamped to [20, 600] mg/dL — outside these values the
//   model would be extrapolating past physiological plausibility.
//
// CONFIDENCE SCORES:
//   at 30 min  → 0.85
//   at 60 min  → 0.70
//   at 120 min → 0.50
//   Decreasing with horizon because:
//     1. Carb absorption variability increases over time
//     2. Individual insulin sensitivity varies more at longer horizons
//     3. Physical activity / stress are unmeasured confounders
//
// PURITY:
//   This engine has no state. Given the same [PredictionInput], it always
//   returns the same [PredictionOutput]. Fully deterministic.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:uuid/uuid.dart';

import 'package:insulin_assistant/ai/prediction/core/prediction_contribution.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_engine.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_horizons.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_input.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_output.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_risk.dart';
import 'package:insulin_assistant/ai/prediction/models/carb_absorption_model.dart';
import 'package:insulin_assistant/ai/prediction/models/insulin_activity_model.dart';
import 'package:insulin_assistant/ai/prediction/models/trend_adjustment_model.dart';
import 'package:insulin_assistant/algorithms/math/precision_math.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/core/result.dart';

/// Phase 1 deterministic hybrid prediction engine.
final class HybridPredictionEngine implements GlucosePredictionEngine {
  const HybridPredictionEngine();

  static const _uuid = Uuid();

  // ── Physiological BG bounds ───────────────────────────────────────────────
  static const double _minBGMgdl = 20.0;
  static const double _maxBGMgdl = 600.0;

  // ── Confidence scores per horizon ─────────────────────────────────────────
  static const Map<int, double> _horizonConfidence = {
    30: 0.85,
    60: 0.70,
    120: 0.50,
  };

  @override
  String get modelVersion => 'hybrid-deterministic-v1.0';

  @override
  bool get isDeterministic => true;

  // ── GlucosePredictionEngine interface ────────────────────────────────────

  @override
  Future<Result<PredictionOutput>> predict(PredictionInput input) async {
    try {
      return Result.success(_predict(input));
    } catch (e, st) {
      return Result.failure(
        PredictionFailure('HybridPredictionEngine failed: $e\n$st'),
      );
    }
  }

  // ── Core synchronous prediction ───────────────────────────────────────────

  PredictionOutput _predict(PredictionInput input) {
    final at30 = _predictHorizon(input, PredictionHorizon.thirtyMin);
    final at60 = _predictHorizon(input, PredictionHorizon.sixtyMin);
    final at120 = _predictHorizon(input, PredictionHorizon.twoHours);

    return PredictionOutput(
      id: _uuid.v4(),
      generatedAt: input.snapshotUtc,
      modelVersion: modelVersion,
      isHybridModel: true,
      at30min: at30,
      at60min: at60,
      at120min: at120,
      linkedTraceId: input.linkedTraceId,
    );
  }

  HorizonPrediction _predictHorizon(
    PredictionInput input,
    PredictionHorizon horizon,
  ) {
    final t = horizon.minutes.toDouble();

    // ── Step 1: Carb impact ────────────────────────────────────────────────
    final carbFraction = CarbAbsorptionModel.fractionAbsorbed(
      minutesElapsed: t,
      halfTimeMinutes: input.carbAbsorptionHalfTimeMinutes,
    );
    final carbImpact = CarbAbsorptionModel.bgImpactAt(
      carbsGrams: input.carbsGrams,
      isfMgdlPerUnit: input.isfMgdlPerUnit,
      icrGramsPerUnit: input.icrGramsPerUnit,
      minutesElapsed: t,
      halfTimeMinutes: input.carbAbsorptionHalfTimeMinutes,
    );

    // ── Step 2: New dose insulin impact ────────────────────────────────────
    //   The dose is at t₀ = minutesSinceInjection.
    //   At horizon t, elapsed = t₀ + t.
    final insulinFraction = InsulinActivityModel.fractionActiveInWindow(
      durationMinutes: input.diaMinutes,
      minutesSinceInjection: input.minutesSinceInjection,
      horizonMinutes: t,
    );
    final insulinLowering = InsulinActivityModel.bgLoweringAt(
      doseUnits: input.doseU,
      isfMgdlPerUnit: input.isfMgdlPerUnit,
      durationMinutes: input.diaMinutes,
      minutesSinceInjection: input.minutesSinceInjection,
      horizonMinutes: t,
    );

    // ── Step 3: Residual IOB impact ────────────────────────────────────────
    //   IOB is from prior injections, already partially active.
    //   We model IOB as having been injected at t₀ = 0 (its current
    //   remaining effect) and use a weighted fraction of it consumed
    //   during [0, t]. This approximation is conservative.
    //   More accurately: IOB already represents the REMAINING insulin —
    //   we compute how much of that remaining IOB becomes active in [0, t].
    //
    //   Approximation: treat IOB as if injected at t=0 with the same DIA.
    //   The fraction consumed from 0→t is [1 − IOB_pct(t)].
    final iobFraction = InsulinActivityModel.fractionActiveInWindow(
      durationMinutes: input.diaMinutes,
      minutesSinceInjection: 0.0,  // IOB starts "now"
      horizonMinutes: t,
    );
    final iobLowering = InsulinActivityModel.bgLoweringAt(
      doseUnits: input.iobU,
      isfMgdlPerUnit: input.isfMgdlPerUnit,
      durationMinutes: input.diaMinutes,
      minutesSinceInjection: 0.0,
      horizonMinutes: t,
    );

    // ── Step 4: Trend adjustment ───────────────────────────────────────────
    final trendAdj = TrendAdjustmentModel.bgAdjustmentAt(
      trendMgdlPerMin: input.glucoseTrendMgdlPerMin,
      horizonMinutes: t,
    );

    // ── Step 5: Combine ───────────────────────────────────────────────────
    //   predictedBG = currentBG + carbs − insulin − iob + trend
    final rawPredicted = input.currentBGMgdl
        + carbImpact
        - insulinLowering
        - iobLowering
        + trendAdj;

    // ── Step 6: Physiological clamp ───────────────────────────────────────
    final predictedBG = PrecisionMath.clamp(
      rawPredicted,
      min: _minBGMgdl,
      max: _maxBGMgdl,
    );

    // ── Step 7: Risk classification & recommended action ──────────────────
    final risk = PredictionRiskLevel.classify(predictedBG);
    final action = PredictionAction.forRisk(risk);
    final confidence = _horizonConfidence[horizon.minutes] ?? 0.5;

    // ── Step 8: Explainability contribution record ─────────────────────────
    final contribution = PredictionContribution(
      horizonMinutes: horizon.minutes,
      baselineMgdl: input.currentBGMgdl,
      carbContributionMgdl: carbImpact,
      insulinContributionMgdl: -insulinLowering, // signed negative
      iobContributionMgdl: -iobLowering,         // signed negative
      trendContributionMgdl: trendAdj,           // signed
      carbFractionAbsorbed: carbFraction,
      insulinFractionActive: insulinFraction,
      iobFractionActive: iobFraction,
      predictedBGMgdl: predictedBG,
    );

    return HorizonPrediction(
      horizon: horizon,
      predictedBGMgdl: predictedBG,
      riskLevel: risk,
      recommendedAction: action,
      contribution: contribution,
      confidenceScore: confidence,
    );
  }
}
