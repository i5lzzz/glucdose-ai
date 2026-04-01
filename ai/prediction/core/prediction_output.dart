// lib/ai/prediction/core/prediction_output.dart
// ─────────────────────────────────────────────────────────────────────────────
// PredictionOutput — complete, immutable prediction result.
//
// Contains a [HorizonPrediction] for each of the three clinical horizons
// (30, 60, 120 min), each with:
//   • predictedBGMgdl       — the forecast BG value
//   • riskLevel             — clinical risk classification
//   • recommendedAction     — bilingual action text
//   • contribution          — full explainability breakdown
//
// Plus top-level accessors:
//   • hasHypoRisk           — any horizon predicts BG < 70
//   • hasCriticalHypoRisk   — any horizon predicts BG < 55
//   • hasHyperRisk          — any horizon predicts BG > 250
//   • earliestHypoMinutes   — first horizon at which hypo is predicted
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import 'package:insulin_assistant/ai/prediction/core/prediction_contribution.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_horizons.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_risk.dart';

/// Prediction result at a single horizon.
final class HorizonPrediction extends Equatable {
  const HorizonPrediction({
    required this.horizon,
    required this.predictedBGMgdl,
    required this.riskLevel,
    required this.recommendedAction,
    required this.contribution,
    required this.confidenceScore,
  });

  final PredictionHorizon horizon;
  final double predictedBGMgdl;
  final PredictionRiskLevel riskLevel;
  final PredictionAction recommendedAction;
  final PredictionContribution contribution;

  /// Confidence 0.0–1.0.  Decreases with horizon: 30min=0.85, 60min=0.70, 120min=0.50.
  final double confidenceScore;

  int get horizonMinutes => horizon.minutes;

  Map<String, dynamic> toJson() => {
        'horizon_min': horizonMinutes,
        'predicted_bg_mgdl': predictedBGMgdl,
        'risk': riskLevel.name,
        'risk_ar': riskLevel.nameAr,
        'action_ar': recommendedAction.ar,
        'action_en': recommendedAction.en,
        'confidence': confidenceScore,
        'contribution': contribution.toJson(),
      };

  @override
  List<Object?> get props => [horizon, predictedBGMgdl, riskLevel];
}

/// Complete prediction output for all three horizons.
final class PredictionOutput extends Equatable {
  const PredictionOutput({
    required this.id,
    required this.generatedAt,
    required this.modelVersion,
    required this.isHybridModel,
    required this.at30min,
    required this.at60min,
    required this.at120min,
    required this.linkedTraceId,
  });

  final String id;
  final DateTime generatedAt;
  final String modelVersion;
  final bool isHybridModel;
  final HorizonPrediction at30min;
  final HorizonPrediction at60min;
  final HorizonPrediction at120min;
  final String? linkedTraceId;

  // ── Convenience accessors ─────────────────────────────────────────────────

  List<HorizonPrediction> get all => [at30min, at60min, at120min];

  HorizonPrediction atHorizon(PredictionHorizon h) => switch (h) {
        PredictionHorizon.thirtyMin => at30min,
        PredictionHorizon.sixtyMin => at60min,
        PredictionHorizon.twoHours => at120min,
      };

  // ── Risk aggregators ──────────────────────────────────────────────────────

  bool get hasCriticalHypoRisk =>
      all.any((h) => h.riskLevel == PredictionRiskLevel.criticalHypo);

  bool get hasHypoRisk =>
      all.any((h) => h.riskLevel.isAnyHypo);

  bool get hasHyperRisk =>
      all.any((h) => h.riskLevel == PredictionRiskLevel.severeHyper);

  bool get hasAnyHyperRisk =>
      all.any((h) => h.riskLevel.isAnyHyper);

  bool get allInRange => all.every((h) => h.riskLevel.isSafe);

  /// Minutes to first predicted hypo (null if no hypo predicted).
  int? get earliestHypoMinutes {
    for (final h in all) {
      if (h.riskLevel.isAnyHypo) return h.horizonMinutes;
    }
    return null;
  }

  /// Recommended carbs from the most urgent hypo action.
  double? get recommendedCarbsGrams => all
      .where((h) => h.recommendedAction.recommendedCarbsGrams != null)
      .map((h) => h.recommendedAction.recommendedCarbsGrams!)
      .fold<double?>(null, (max, v) => max == null || v > max ? v : max);

  /// Highest risk level across all horizons.
  PredictionRiskLevel get maxRiskLevel => all
      .map((h) => h.riskLevel)
      .reduce((a, b) => a.index > b.index ? a : b);

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'generated_at': generatedAt.toIso8601String(),
        'model_version': modelVersion,
        'is_hybrid': isHybridModel,
        'at_30min': at30min.toJson(),
        'at_60min': at60min.toJson(),
        'at_120min': at120min.toJson(),
        'has_hypo_risk': hasHypoRisk,
        'has_critical_hypo': hasCriticalHypoRisk,
        'has_hyper_risk': hasHyperRisk,
        if (linkedTraceId != null) 'trace_id': linkedTraceId,
      };

  @override
  List<Object?> get props => [id, generatedAt, at30min, at60min, at120min];
}
