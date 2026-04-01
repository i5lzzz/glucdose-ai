// lib/data/models/glucose_reading_dto.dart

import 'package:insulin_assistant/data/models/base_dto.dart';

/// Maps to the `glucose_readings` table.
///
/// ENCRYPTED: value_enc (BG reading — core PHI), notes_enc
/// PLAINTEXT: id, user_id, recorded_at (indexed), source, trend
final class GlucoseReadingDTO implements BaseDTO {
  const GlucoseReadingDTO({
    required this.id,
    required this.userId,
    required this.recordedAt,
    required this.valueEnc,
    required this.source,
    this.trend,
    this.notesEnc,
  });

  @override
  final String id;
  final String userId;
  final String recordedAt;   // UTC ISO-8601 — indexed
  final String valueEnc;     // encrypted BG in mg/dL
  final String source;       // 'manual' | 'cgm' | 'bgm'
  final String? trend;       // 'rising' | 'stable' | 'falling' etc.
  final String? notesEnc;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'recorded_at': recordedAt,
        'value_enc': valueEnc,
        'source': source,
        if (trend != null) 'trend': trend,
        if (notesEnc != null) 'notes_enc': notesEnc,
      };

  factory GlucoseReadingDTO.fromMap(Map<String, dynamic> map) =>
      GlucoseReadingDTO(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        recordedAt: map['recorded_at'] as String,
        valueEnc: map['value_enc'] as String,
        source: map['source'] as String? ?? 'manual',
        trend: map['trend'] as String?,
        notesEnc: map['notes_enc'] as String?,
      );
}
