// lib/domain/value_objects/insulin_units.dart
// ─────────────────────────────────────────────────────────────────────────────
// InsulinUnits value object.
//
// Represents a quantity of insulin in international units (IU).
//
// INVARIANTS:
//   • value is finite
//   • value >= 0.0  (negative insulin is physically impossible)
//   • value <= ABSOLUTE_MAX (hard safety ceiling)
//
// PRECISION:
//   Insulin quantities are clinically significant to 0.05 U (modern pen
//   injectors).  Stored as double, rounded to 2 decimal places on display.
//   DO NOT round the stored value — rounding in intermediate calculations
//   accumulates error in stacked IOB.
//
// SPECIAL VALUES:
//   InsulinUnits.zero — the canonical zero dose (used when IOB deduction
//   results in a zero or negative corrective dose).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/core/value_object.dart';

final class InsulinUnits extends ValueObject<double> {
  const InsulinUnits._(super.value);

  // ── Sentinel values ───────────────────────────────────────────────────────

  /// Canonical zero dose.  Use instead of `InsulinUnits.fromUnits(0)` for
  /// clarity at call sites — zero is a meaningful clinical value (no bolus).
  static const InsulinUnits zero = InsulinUnits._(0.0);

  // ── Bounds ────────────────────────────────────────────────────────────────
  static const double _minUnits = 0.0;
  // Ceiling from MedicalConstants — single source of truth
  static const double _maxUnits = MedicalConstants.absoluteMaxSingleDoseUnits;

  // ── Construction ──────────────────────────────────────────────────────────

  /// Primary factory. Returns [Result.failure] for out-of-range or non-finite
  /// values.
  static Result<InsulinUnits> fromUnits(double units) {
    return ValueObject.validate(() {
      assertFinite(units, field: 'insulin_units');
      assertRange(units, min: _minUnits, max: _maxUnits, field: 'insulin_units');
      return InsulinUnits._(units);
    });
  }

  /// Unclamped constructor used INTERNALLY by the safety engine to represent
  /// calculated values BEFORE clamping — not for use outside safety layer.
  /// Returns failure if negative or non-finite; allows values > ceiling so
  /// the safety engine can compare and decide.
  static Result<InsulinUnits> fromUnitsUnclamped(double units) {
    return ValueObject.validate(() {
      assertFinite(units, field: 'insulin_units_unclamped');
      assertValid(
        condition: units >= _minUnits,
        message: 'Insulin units cannot be negative (got $units)',
        field: 'insulin_units_unclamped',
      );
      return InsulinUnits._(units);
    });
  }

  // ── Accessors ─────────────────────────────────────────────────────────────

  double get units => value;

  bool get isZero => value == 0.0;
  bool get isPositive => value > 0.0;

  /// True if this value exceeds the absolute safety ceiling.
  bool get exceedsAbsoluteCeiling =>
      value > MedicalConstants.absoluteMaxSingleDoseUnits;

  /// True if this value exceeds [userMax] (user-configured ceiling).
  bool exceedsUserCeiling(double userMax) => value > userMax;

  // ── Arithmetic ────────────────────────────────────────────────────────────

  /// Subtracts [other] from this, clamping result to zero minimum.
  /// Used when deducting IOB from calculated bolus.
  Result<InsulinUnits> subtractIOB(InsulinUnits iob) =>
      fromUnitsUnclamped((value - iob.value).clamp(0.0, double.infinity));

  /// Adds two insulin quantities (used for IOB stacking).
  /// Returns unclamped result — IOB total may legitimately exceed single-dose
  /// ceiling.
  Result<InsulinUnits> add(InsulinUnits other) =>
      fromUnitsUnclamped(value + other.value);

  /// Rounds to [decimalPlaces] for display.
  String display({int decimalPlaces = 1}) =>
      value.toStringAsFixed(decimalPlaces);

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {'units': value};

  factory InsulinUnits.fromJson(Map<String, dynamic> json) {
    final r = fromUnits((json['units'] as num).toDouble());
    if (r.isFailure) throw r.failure;
    return r.value;
  }

  @override
  String toString() => 'InsulinUnits(${value.toStringAsFixed(2)} U)';
}
