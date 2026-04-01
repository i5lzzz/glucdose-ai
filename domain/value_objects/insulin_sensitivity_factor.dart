// lib/domain/value_objects/insulin_sensitivity_factor.dart
// ─────────────────────────────────────────────────────────────────────────────
// InsulinSensitivityFactor (ISF) value object.
//
// Also known as: Correction Factor, Insulin Sensitivity Factor.
// Unit: mg/dL per international unit (IU) of insulin.
//
// Represents: how many mg/dL one unit of insulin will lower BG.
//   e.g. ISF = 50 → 1 U lowers BG by 50 mg/dL.
//
// INVARIANTS:
//   • value is finite
//   • value >= MIN_ISF (prevents near-zero denominator in correction calc)
//   • value <= MAX_ISF (very high ISF = very insulin-sensitive = large effect
//                        per unit — values > 200 are clinically implausible
//                        for typical adult T2D)
//
// NOTE: ISF values vary significantly between individuals and even
//       time-of-day.  The stored value is the user's configured baseline.
//       A future phase may support time-of-day ISF schedules.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/core/value_object.dart';

final class InsulinSensitivityFactor extends ValueObject<double> {
  const InsulinSensitivityFactor._(super.value);

  static const double _min = MedicalConstants.minISF;
  static const double _max = MedicalConstants.maxISF;

  // ── Construction ──────────────────────────────────────────────────────────

  static Result<InsulinSensitivityFactor> fromMgdlPerUnit(double mgdlPerUnit) {
    return ValueObject.validate(() {
      assertFinite(mgdlPerUnit, field: 'isf');
      assertRange(mgdlPerUnit, min: _min, max: _max, field: 'isf');
      return InsulinSensitivityFactor._(mgdlPerUnit);
    });
  }

  /// Convenience for mmol/L ISF input (UK/Canada users).
  /// mmol ISF = mg/dL ISF / 18.01559
  static Result<InsulinSensitivityFactor> fromMmolPerUnit(double mmolPerUnit) {
    return fromMgdlPerUnit(mmolPerUnit * 18.01559);
  }

  // ── Domain logic ──────────────────────────────────────────────────────────

  /// Calculates the correction insulin dose for a given BG delta.
  ///
  ///   correctionDose = (currentBG - targetBG) / ISF
  ///
  /// Returns raw double — caller is responsible for clamping to InsulinUnits.
  /// A negative return value indicates BG is BELOW target and NO correction
  /// insulin is warranted (deducted from total dose instead).
  double correctionDoseFor({
    required double currentBgMgdl,
    required double targetBgMgdl,
  }) {
    return (currentBgMgdl - targetBgMgdl) / value;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {'mgdl_per_unit': value};

  factory InsulinSensitivityFactor.fromJson(Map<String, dynamic> json) {
    final r = fromMgdlPerUnit((json['mgdl_per_unit'] as num).toDouble());
    if (r.isFailure) throw r.failure;
    return r.value;
  }

  @override
  String toString() =>
      'InsulinSensitivityFactor(${value.toStringAsFixed(1)} mg/dL/U)';
}
