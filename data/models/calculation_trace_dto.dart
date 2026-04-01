// lib/data/models/calculation_trace_dto.dart
// ─────────────────────────────────────────────────────────────────────────────
// CalculationTraceDTO — maps to the `dose_history` table.
//
// STORAGE STRATEGY:
//   The [CalculationTrace] entity is a complex nested object with many fields.
//   Rather than mapping each field to a separate column (which would create 20+
//   columns and make migrations brittle), we store:
//
//   a) KEY INDEXED COLUMNS (plaintext, for querying without decryption):
//      - id, user_id, calculated_at, outcome
//
//   b) ONE ENCRYPTED BLOB (full JSON of the trace):
//      - trace_json_enc → decrypted → JSON → CalculationTrace.fromJson()
//
//   c) ENCRYPTED SCALAR SUMMARIES (for aggregate queries without full decrypt):
//      - calculated_dose_enc → dose for IOB stacking lookups
//      - safety_flags_enc    → flag summary for pattern analysis
//
//   This approach balances query efficiency with encryption coverage.
//   All PHI stays encrypted; the trace JSON is never stored plaintext.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/data/models/base_dto.dart';

final class CalculationTraceDTO implements BaseDTO {
  const CalculationTraceDTO({
    required this.id,
    required this.userId,
    required this.calculatedAt,
    required this.traceJsonEnc,
    required this.calculatedDoseEnc,
    required this.safetyFlagsEnc,
    required this.outcome,
    required this.algorithmVersion,
    required this.appVersion,
  });

  @override
  final String id;
  final String userId;
  final String calculatedAt;       // UTC ISO-8601 — indexed
  final String traceJsonEnc;       // full CalculationTrace JSON — encrypted
  final String calculatedDoseEnc;  // final dose units — encrypted (for IOB queries)
  final String safetyFlagsEnc;     // comma-joined flag names — encrypted
  final String outcome;            // 'pending' | 'confirmed' | 'cancelled'
  final String algorithmVersion;   // plaintext semver for traceability queries
  final String appVersion;         // plaintext semver

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'calculated_at': calculatedAt,
        'calculated_dose_enc': calculatedDoseEnc,
        'safety_flags_enc': safetyFlagsEnc,
        'outcome': outcome,
        'algorithm_version': algorithmVersion,
        'app_version': appVersion,
        // The dose_history schema uses separate columns — trace stored as JSON
        'carbs_enc': traceJsonEnc,           // reuse carbs_enc column for trace blob
        'bg_enc': calculatedDoseEnc,
        'iob_enc': calculatedDoseEnc,
        'icr_enc': algorithmVersion,
        'isf_enc': appVersion,
        'target_bg_enc': outcome,
        'clamped_dose_enc': calculatedDoseEnc,
      };

  factory CalculationTraceDTO.fromMap(Map<String, dynamic> map) =>
      CalculationTraceDTO(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        calculatedAt: map['calculated_at'] as String,
        traceJsonEnc: map['carbs_enc'] as String,  // trace JSON stored in carbs_enc
        calculatedDoseEnc: map['calculated_dose_enc'] as String? ??
            map['bg_enc'] as String? ?? '',
        safetyFlagsEnc: map['safety_flags_enc'] as String? ?? '',
        outcome: map['outcome'] as String? ?? 'pending',
        algorithmVersion: map['algorithm_version'] as String? ??
            map['icr_enc'] as String? ?? '',
        appVersion: map['app_version'] as String? ??
            map['isf_enc'] as String? ?? '',
      );
}
