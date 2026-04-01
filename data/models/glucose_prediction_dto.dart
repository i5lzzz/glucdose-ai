// lib/data/models/glucose_prediction_dto.dart
// ─────────────────────────────────────────────────────────────────────────────
// GlucosePredictionDTO — maps to the `predictions` table.
//
// Predictions are stored to:
//   1. Build the training dataset for Phase 2 TFLite model
//   2. Track model accuracy by comparing predictions to actual readings
//   3. Generate insights about prediction patterns
//
// The full prediction JSON (including all contributions and explanations)
// is stored encrypted as a single blob.  Key scalar fields are indexed.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/data/models/base_dto.dart';

final class GlucosePredictionDTO implements BaseDTO {
  const GlucosePredictionDTO({
    required this.id,
    required this.userId,
    required this.generatedAt,
    required this.predictionJsonEnc,
    required this.modelVersion,
    required this.linkedTraceId,
    required this.hasHypoRisk,
    required this.hasCriticalHypoRisk,
    required this.hasHyperRisk,
    this.actualBg30MinEnc,
    this.actualBg60MinEnc,
    this.actualBg120MinEnc,
  });

  @override
  final String id;
  final String userId;
  final String generatedAt;           // UTC ISO-8601 — indexed
  final String predictionJsonEnc;     // full PredictionOutput JSON — encrypted
  final String modelVersion;          // plaintext — for model tracking
  final String? linkedTraceId;
  final int hasHypoRisk;              // 0/1 — for fast filter queries
  final int hasCriticalHypoRisk;
  final int hasHyperRisk;
  // Actual readings filled in later for accuracy tracking
  final String? actualBg30MinEnc;
  final String? actualBg60MinEnc;
  final String? actualBg120MinEnc;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'generated_at': generatedAt,
        'prediction_json_enc': predictionJsonEnc,
        'model_version': modelVersion,
        if (linkedTraceId != null) 'linked_trace_id': linkedTraceId,
        'has_hypo_risk': hasHypoRisk,
        'has_critical_hypo_risk': hasCriticalHypoRisk,
        'has_hyper_risk': hasHyperRisk,
        if (actualBg30MinEnc != null) 'actual_bg_30_enc': actualBg30MinEnc,
        if (actualBg60MinEnc != null) 'actual_bg_60_enc': actualBg60MinEnc,
        if (actualBg120MinEnc != null) 'actual_bg_120_enc': actualBg120MinEnc,
      };

  factory GlucosePredictionDTO.fromMap(Map<String, dynamic> map) =>
      GlucosePredictionDTO(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        generatedAt: map['generated_at'] as String,
        predictionJsonEnc: map['prediction_json_enc'] as String,
        modelVersion: map['model_version'] as String? ?? '',
        linkedTraceId: map['linked_trace_id'] as String?,
        hasHypoRisk: map['has_hypo_risk'] as int? ?? 0,
        hasCriticalHypoRisk: map['has_critical_hypo_risk'] as int? ?? 0,
        hasHyperRisk: map['has_hyper_risk'] as int? ?? 0,
        actualBg30MinEnc: map['actual_bg_30_enc'] as String?,
        actualBg60MinEnc: map['actual_bg_60_enc'] as String?,
        actualBg120MinEnc: map['actual_bg_120_enc'] as String?,
      );
}
