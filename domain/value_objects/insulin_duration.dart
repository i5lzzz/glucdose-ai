// lib/domain/value_objects/insulin_duration.dart
// ─────────────────────────────────────────────────────────────────────────────
// InsulinDuration value object.
//
// Represents the total duration of action (DIA) of a given insulin type
// in minutes.  Used by the Walsh IOB model to compute the decay curve.
//
// Typical values:
//   Rapid analogue (NovoRapid, Humalog, Apidra)  : 180–300 min
//   Short-acting (Regular)                        : 300–420 min
//   NPH                                           : 480+ min
//   Long-acting (Lantus, Tresiba) — NOT used for bolus IOB calculation
//
// INVARIANTS:
//   • value is finite
//   • value >= MIN (120 min) — prevents near-zero IOB decay denominator
//   • value <= MAX (480 min) — out-of-scope for bolus calculator
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/core/value_object.dart';

final class InsulinDuration extends ValueObject<double> {
  const InsulinDuration._(super.value);

  static const double _min = MedicalConstants.minInsulinDurationMinutes;
  static const double _max = MedicalConstants.maxInsulinDurationMinutes;

  // ── Common presets ────────────────────────────────────────────────────────

  /// 3 hours — typical rapid-acting analogue lower bound.
  static final InsulinDuration threeHours = _preset(180.0);

  /// 4 hours — default rapid-acting analogue.
  static final InsulinDuration fourHours = _preset(240.0);

  /// 5 hours — extended rapid-acting or short-acting.
  static final InsulinDuration fiveHours = _preset(300.0);

  static InsulinDuration _preset(double minutes) =>
      InsulinDuration._(minutes); // Safe — bounds already satisfied

  // ── Construction ──────────────────────────────────────────────────────────

  static Result<InsulinDuration> fromMinutes(double minutes) {
    return ValueObject.validate(() {
      assertFinite(minutes, field: 'insulin_duration');
      assertRange(minutes, min: _min, max: _max, field: 'insulin_duration');
      return InsulinDuration._(minutes);
    });
  }

  static Result<InsulinDuration> fromHours(double hours) =>
      fromMinutes(hours * 60.0);

  // ── Accessors ─────────────────────────────────────────────────────────────

  double get minutes => value;
  double get hours => value / 60.0;

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {'minutes': value};

  factory InsulinDuration.fromJson(Map<String, dynamic> json) {
    final r = fromMinutes((json['minutes'] as num).toDouble());
    if (r.isFailure) throw r.failure;
    return r.value;
  }

  @override
  String toString() => 'InsulinDuration(${value.toStringAsFixed(0)} min)';
}
