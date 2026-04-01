// lib/domain/value_objects/carbohydrates.dart
// ─────────────────────────────────────────────────────────────────────────────
// Carbohydrates value object.
//
// Represents a carbohydrate quantity in grams.
//
// INVARIANTS:
//   • value is finite
//   • value >= 0.0  (zero is valid — correction-only dose with no meal)
//   • value <= MAX_PER_MEAL (guard against data-entry errors like 3000 g)
//
// GLYCAEMIC IMPACT:
//   CarbohydrateQuality (GI + absorption speed) is not part of this VO —
//   it belongs to the FoodItem entity.  The VO only holds the gram count.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/core/value_object.dart';

final class Carbohydrates extends ValueObject<double> {
  const Carbohydrates._(super.value);

  /// Zero carbs — correction-only dose with no food intake.
  static const Carbohydrates zero = Carbohydrates._(0.0);

  static const double _minGrams = 0.0;
  static const double _maxGrams = MedicalConstants.maxCarbohydratesPerMealGrams;

  // ── Construction ──────────────────────────────────────────────────────────

  static Result<Carbohydrates> fromGrams(double grams) {
    return ValueObject.validate(() {
      assertFinite(grams, field: 'carbohydrates');
      assertRange(grams, min: _minGrams, max: _maxGrams, field: 'carbohydrates');
      return Carbohydrates._(grams);
    });
  }

  // ── Accessors ─────────────────────────────────────────────────────────────

  double get grams => value;
  bool get isZero => value == 0.0;
  bool get isPositive => value > 0.0;

  // ── Arithmetic ────────────────────────────────────────────────────────────

  /// Adds two carbohydrate quantities (combining meal items).
  Result<Carbohydrates> add(Carbohydrates other) =>
      fromGrams(value + other.value);

  /// Calculates the bolus component for [icr] (grams per unit).
  /// Returns raw double — caller wraps in InsulinUnits.
  double carbDoseFor(double icr) {
    assert(icr > 0, 'ICR must be positive');
    return value / icr;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {'grams': value};

  factory Carbohydrates.fromJson(Map<String, dynamic> json) {
    final r = fromGrams((json['grams'] as num).toDouble());
    if (r.isFailure) throw r.failure;
    return r.value;
  }

  @override
  String toString() => 'Carbohydrates(${value.toStringAsFixed(1)} g)';
}
