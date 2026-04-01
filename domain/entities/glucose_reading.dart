// lib/domain/entities/glucose_reading.dart

import 'package:equatable/equatable.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';

/// Source of a blood glucose measurement.
enum GlucoseSource {
  manual, // User typed reading
  cgm, // Continuous Glucose Monitor (future)
  bgm, // Blood Glucose Meter via Bluetooth (future)
}

/// Trend direction from CGM or manual sequence.
enum GlucoseTrend {
  risingRapid, // > +3 mg/dL/min
  rising, // +1 to +3 mg/dL/min
  stable, // ±1 mg/dL/min
  falling, // -1 to -3 mg/dL/min
  fallingRapid, // < -3 mg/dL/min
  unknown,
}

extension GlucoseTrendX on GlucoseTrend {
  String get arrowSymbol => switch (this) {
        GlucoseTrend.risingRapid => '↑↑',
        GlucoseTrend.rising => '↑',
        GlucoseTrend.stable => '→',
        GlucoseTrend.falling => '↓',
        GlucoseTrend.fallingRapid => '↓↓',
        GlucoseTrend.unknown => '—',
      };

  /// Approximate mg/dL per minute for trend-aware prediction.
  double get rateOfChangeMgdlPerMin => switch (this) {
        GlucoseTrend.risingRapid => 3.5,
        GlucoseTrend.rising => 1.5,
        GlucoseTrend.stable => 0.0,
        GlucoseTrend.falling => -1.5,
        GlucoseTrend.fallingRapid => -3.5,
        GlucoseTrend.unknown => 0.0,
      };
}

/// Immutable blood glucose reading.
final class GlucoseReading extends Equatable {
  const GlucoseReading({
    required this.id,
    required this.userId,
    required this.recordedAt,
    required this.value,
    required this.source,
    this.trend = GlucoseTrend.unknown,
    this.notes,
  });

  final String id;
  final String userId;
  final DateTime recordedAt;
  final BloodGlucose value;
  final GlucoseSource source;
  final GlucoseTrend trend;
  final String? notes;

  // ── Convenience classifiers ───────────────────────────────────────────────

  BloodGlucoseClassification get classification => value.classification;
  bool get isHypo => value.isHypo;
  bool get isHyper => value.isHyper;
  bool get isCritical => value.isLevel2Hypo || value.isSevereHyper;

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'recorded_at': recordedAt.toIso8601String(),
        'value': value.toJson(),
        'source': source.name,
        'trend': trend.name,
        if (notes != null) 'notes': notes,
      };

  @override
  List<Object?> get props => [id, userId, recordedAt, value];
}
