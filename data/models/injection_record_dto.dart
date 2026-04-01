// lib/data/models/injection_record_dto.dart
// ─────────────────────────────────────────────────────────────────────────────
// InjectionRecordDTO — maps to the `injections` table.
//
// ENCRYPTED FIELDS (stored as Base64 AES-256-CBC ciphertext):
//   dose_units_enc        — insulin dose in units (PHI)
//   insulin_type_enc      — insulin brand/type (PHI)
//   bg_at_injection_enc   — blood glucose reading at injection time (PHI)
//   iob_at_injection_enc  — IOB at injection time (PHI)
//   calculation_trace_enc — full trace JSON (PHI + clinical data)
//
// PLAINTEXT FIELDS (non-PHI operational data):
//   id                    — UUID primary key
//   user_id               — foreign key to user_profile
//   injected_at           — UTC ISO-8601 timestamp (indexed)
//   duration_minutes      — numeric device setting (not PHI)
//   status                — enum name (confirmed/pending/cancelled/partial)
//   meal_id               — nullable foreign key to meals
//   confirmed             — boolean integer (0/1)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/data/models/base_dto.dart';

final class InjectionRecordDTO implements BaseDTO {
  const InjectionRecordDTO({
    required this.id,
    required this.userId,
    required this.injectedAt,
    required this.doseUnitsEnc,
    required this.insulinTypeEnc,
    required this.durationMinutes,
    required this.status,
    required this.confirmed,
    this.mealId,
    this.bgAtInjectionEnc,
    this.iobAtInjectionEnc,
    this.calculationTraceIdEnc,
    this.notesEnc,
  });

  @override
  final String id;
  final String userId;
  final String injectedAt;          // UTC ISO-8601
  final String doseUnitsEnc;        // encrypted double as string
  final String insulinTypeEnc;      // encrypted enum name
  final double durationMinutes;     // plaintext (device parameter)
  final String status;              // plaintext enum
  final int confirmed;              // 0 or 1
  final String? mealId;
  final String? bgAtInjectionEnc;
  final String? iobAtInjectionEnc;
  final String? calculationTraceIdEnc;
  final String? notesEnc;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'injected_at': injectedAt,
        'dose_units_enc': doseUnitsEnc,
        'insulin_type_enc': insulinTypeEnc,
        'duration_minutes': durationMinutes,
        'status': status,
        'confirmed': confirmed,
        if (mealId != null) 'meal_id': mealId,
        if (bgAtInjectionEnc != null) 'bg_at_injection_enc': bgAtInjectionEnc,
        if (iobAtInjectionEnc != null) 'iob_at_injection_enc': iobAtInjectionEnc,
        if (calculationTraceIdEnc != null)
          'calculation_trace_enc': calculationTraceIdEnc,
        if (notesEnc != null) 'notes_enc': notesEnc,
      };

  factory InjectionRecordDTO.fromMap(Map<String, dynamic> map) =>
      InjectionRecordDTO(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        injectedAt: map['injected_at'] as String,
        doseUnitsEnc: map['dose_units_enc'] as String,
        insulinTypeEnc: map['insulin_type_enc'] as String,
        durationMinutes: (map['duration_minutes'] as num).toDouble(),
        status: map['status'] as String,
        confirmed: map['confirmed'] as int? ?? 0,
        mealId: map['meal_id'] as String?,
        bgAtInjectionEnc: map['bg_at_injection_enc'] as String?,
        iobAtInjectionEnc: map['iob_at_injection_enc'] as String?,
        calculationTraceIdEnc: map['calculation_trace_enc'] as String?,
        notesEnc: map['notes_enc'] as String?,
      );
}
