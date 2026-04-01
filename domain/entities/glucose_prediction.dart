// lib/domain/entities/glucose_prediction.dart

import 'package:equatable/equatable.dart';
import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';

/// Risk level classification for a predicted BG point.
enum PredictionRisk {
  hypo, // < 70 mg/dL — action required
  low, // 70–79 mg/dL — monitor closely
  inRange, // 80–140 mg/dL — target
  elevated, // 141–180 mg/dL — slightly above target
  hyper, // > 180 mg/dL — correction may be needed
  severeHyper, // > 250 mg/dL — urgent
}

extension PredictionRiskX on PredictionRisk {
  bool get requiresAction =>
      this == PredictionRisk.hypo || this == PredictionRisk.severeHyper;

  String get nameAr => switch (this) {
        PredictionRisk.hypo => 'خطر انخفاض',
        PredictionRisk.low => 'منخفض قليلاً',
        PredictionRisk.inRange => 'مستوى مثالي',
        PredictionRisk.elevated => 'مرتفع قليلاً',
        PredictionRisk.hyper => 'مرتفع',
        PredictionRisk.severeHyper => 'مرتفع جداً',
      };

  static PredictionRisk fromBG(double mgdl) {
    if (mgdl < MedicalConstants.bgLevel1HypoWarn) return PredictionRisk.hypo;
    if (mgdl < MedicalConstants.bgTargetLow) return PredictionRisk.low;
    if (mgdl <= MedicalConstants.bgTargetHigh) return PredictionRisk.inRange;
    if (mgdl <= 180) return PredictionRisk.elevated;
    if (mgdl <= MedicalConstants.bgHyperAlertThreshold) {
      return PredictionRisk.hyper;
    }
    return PredictionRisk.severeHyper;
  }
}

/// A single predicted blood glucose point at [minutesAhead] from now.
final class PredictedPoint extends Equatable {
  const PredictedPoint({
    required this.minutesAhead,
    required this.predictedBG,
    required this.risk,
    required this.confidence,
  });

  final int minutesAhead;
  final BloodGlucose predictedBG;
  final PredictionRisk risk;

  /// Confidence in [0.0, 1.0] — lower for longer horizons.
  final double confidence;

  bool get requiresAction => risk.requiresAction;

  Map<String, dynamic> toJson() => {
        'minutes_ahead': minutesAhead,
        'predicted_bg_mgdl': predictedBG.mgdl,
        'risk': risk.name,
        'confidence': confidence,
      };

  @override
  List<Object?> get props => [minutesAhead, predictedBG, risk];
}

/// Complete glucose prediction result from the AI engine.
final class GlucosePrediction extends Equatable {
  const GlucosePrediction({
    required this.id,
    required this.userId,
    required this.generatedAt,
    required this.points,
    required this.modelVersion,
    required this.isHybridModel,
    this.recommendedCarbIntakeGrams,
    this.recommendedCorrectionDose,
  });

  final String id;
  final String userId;
  final DateTime generatedAt;
  final List<PredictedPoint> points;
  final String modelVersion;

  /// True when deterministic hybrid model was used (Phase 1).
  /// False when TFLite model was used (Phase 2).
  final bool isHybridModel;

  /// Suggested carbs if hypo is predicted (grams).
  final double? recommendedCarbIntakeGrams;

  /// Suggested correction dose if severe hyper predicted (units).
  final double? recommendedCorrectionDose;

  // ── Accessors ─────────────────────────────────────────────────────────────

  PredictedPoint? pointAt(int minutesAhead) =>
      points.where((p) => p.minutesAhead == minutesAhead).firstOrNull;

  bool get hasHypoRisk =>
      points.any((p) => p.risk == PredictionRisk.hypo);

  bool get hasHyperRisk => points.any(
        (p) =>
            p.risk == PredictionRisk.hyper ||
            p.risk == PredictionRisk.severeHyper,
      );

  /// Earliest horizon at which hypo risk is predicted (or null).
  int? get firstHypoHorizonMinutes => points
      .where((p) => p.risk == PredictionRisk.hypo)
      .map((p) => p.minutesAhead)
      .fold<int?>(null, (min, v) => min == null || v < min ? v : min);

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'generated_at': generatedAt.toIso8601String(),
        'points': points.map((p) => p.toJson()).toList(),
        'model_version': modelVersion,
        'is_hybrid': isHybridModel,
        if (recommendedCarbIntakeGrams != null)
          'recommended_carbs_g': recommendedCarbIntakeGrams,
        if (recommendedCorrectionDose != null)
          'recommended_correction_u': recommendedCorrectionDose,
      };

  @override
  List<Object?> get props => [id, userId, generatedAt];
}
