// lib/domain/value_objects/carb_ratio.dart
// ─────────────────────────────────────────────────────────────────────────────
// CarbRatio (ICR — Insulin-to-Carb Ratio) value object.
//
// Represents: how many grams of carbohydrate one unit of insulin covers.
//   e.g. ICR = 10 → 1 U covers 10 g carbohydrate.
//
// INVARIANTS:
//   • value is finite
//   • value >= MIN_ICR  (prevents astronomically small carb dose)
//   • value <= MAX_ICR  (prevents unrealistically large carb dose)
//   • value > 0         (structural guarantee — used as divisor)
//
// NAMING:
//   Industry uses both ICR (insulin-to-carb ratio) and CR (carb ratio).
//   This type is named CarbRatio for readability but the field name in
//   the profile is 'icr' throughout for consistency with clinical notation.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/core/value_object.dart';

final class CarbRatio extends ValueObject<double> {
  const CarbRatio._(super.value);

  static const double _min = MedicalConstants.minICR;
  static const double _max = MedicalConstants.maxICR;

  // ── Construction ──────────────────────────────────────────────────────────

  /// [gramsPerUnit] — grams of carbohydrate covered by 1 unit of insulin.
  static Result<CarbRatio> fromGramsPerUnit(double gramsPerUnit) {
    return ValueObject.validate(() {
      assertFinite(gramsPerUnit, field: 'carb_ratio');
      assertRange(gramsPerUnit, min: _min, max: _max, field: 'carb_ratio');
      // Extra guard: value used as divisor — must be strictly positive
      assertValid(
        condition: gramsPerUnit > 0,
        message: 'CarbRatio must be strictly positive',
        field: 'carb_ratio',
      );
      return CarbRatio._(gramsPerUnit);
    });
  }

  // ── Domain logic ──────────────────────────────────────────────────────────

  /// Calculates the carbohydrate dose component.
  ///
  ///   carbDose = carbs (g) / ICR (g/U)
  ///
  double carbDoseFor(double carbsGrams) {
    assert(carbsGrams >= 0, 'Carbs cannot be negative');
    return carbsGrams / value;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {'grams_per_unit': value};

  factory CarbRatio.fromJson(Map<String, dynamic> json) {
    final r = fromGramsPerUnit((json['grams_per_unit'] as num).toDouble());
    if (r.isFailure) throw r.failure;
    return r.value;
  }

  @override
  String toString() => 'CarbRatio(1 U : ${value.toStringAsFixed(1)} g)';
}
