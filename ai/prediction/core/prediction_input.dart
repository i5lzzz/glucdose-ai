// lib/ai/prediction/core/prediction_input.dart
// ─────────────────────────────────────────────────────────────────────────────
// PredictionInput — complete, validated snapshot fed to the prediction engine.
//
// DESIGN RATIONALE:
//   The prediction engine is a pure function: PredictionEngine.predict(input).
//   All time-dependent state (elapsed minutes, IOB fraction already computed)
//   is baked into this snapshot at construction time by the use-case layer.
//   This means the engine itself is fully deterministic and testable without
//   any Clock dependency.
//
// REQUIRED vs OPTIONAL FIELDS:
//   Required: currentBG, carbohydrates, dose, iob, isf, icr, insulinDuration,
//             minutesSinceInjection, carbAbsorptionHalfTime
//   Optional: glucoseTrendMgdlPerMin  (from CGM or manual sequence)
//
// VALIDATION:
//   Each numeric field is checked for finiteness and physiological plausibility.
//   Construction returns a Result<PredictionInput> — no invalid instance exists.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/carbohydrates.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_duration.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

/// Immutable validated snapshot for one prediction run.
final class PredictionInput extends Equatable {
  const PredictionInput._({
    required this.currentBG,
    required this.carbohydrates,
    required this.doseUnits,
    required this.iob,
    required this.isfMgdlPerUnit,
    required this.icrGramsPerUnit,
    required this.insulinDuration,
    required this.minutesSinceInjection,
    required this.carbAbsorptionHalfTimeMinutes,
    required this.snapshotUtc,
    this.glucoseTrendMgdlPerMin = 0.0,
    this.linkedTraceId,
  });

  final BloodGlucose currentBG;
  final Carbohydrates carbohydrates;

  /// Dose just calculated/administered (may be 0 for carb-free correction).
  final InsulinUnits doseUnits;

  /// Active IOB from ALL previous injections (not counting this new dose).
  final InsulinUnits iob;

  /// Patient's insulin sensitivity factor (mg/dL per unit).
  final double isfMgdlPerUnit;

  /// Patient's insulin-to-carb ratio (grams per unit).
  final double icrGramsPerUnit;

  final InsulinDuration insulinDuration;

  /// Minutes since this dose was (or will be) administered.
  /// 0 = just injected, used to compute insulin activity over the horizon.
  final double minutesSinceInjection;

  /// Carbohydrate absorption half-time (minutes).
  /// Derived from the food's [AbsorptionSpeed] by the use-case layer.
  final double carbAbsorptionHalfTimeMinutes;

  /// BG rate of change in mg/dL per minute from CGM trend (0 = unknown/stable).
  final double glucoseTrendMgdlPerMin;

  /// UTC timestamp when this snapshot was created (for trace linkage).
  final DateTime snapshotUtc;

  /// Links this prediction to the [CalculationTrace] that produced [doseUnits].
  final String? linkedTraceId;

  // ── Factory constructor with validation ────────────────────────────────────

  static Result<PredictionInput> create({
    required BloodGlucose currentBG,
    required Carbohydrates carbohydrates,
    required InsulinUnits doseUnits,
    required InsulinUnits iob,
    required double isfMgdlPerUnit,
    required double icrGramsPerUnit,
    required InsulinDuration insulinDuration,
    required double minutesSinceInjection,
    required double carbAbsorptionHalfTimeMinutes,
    required DateTime snapshotUtc,
    double glucoseTrendMgdlPerMin = 0.0,
    String? linkedTraceId,
  }) {
    // Validate numeric parameters
    final errors = <String>[];
    if (!isfMgdlPerUnit.isFinite || isfMgdlPerUnit <= 0) {
      errors.add('ISF must be finite and positive (got $isfMgdlPerUnit)');
    }
    if (!icrGramsPerUnit.isFinite || icrGramsPerUnit <= 0) {
      errors.add('ICR must be finite and positive (got $icrGramsPerUnit)');
    }
    if (!minutesSinceInjection.isFinite || minutesSinceInjection < 0) {
      errors.add('minutesSinceInjection must be ≥ 0 (got $minutesSinceInjection)');
    }
    if (!carbAbsorptionHalfTimeMinutes.isFinite || carbAbsorptionHalfTimeMinutes <= 0) {
      errors.add('carbAbsorptionHalfTime must be positive '
          '(got $carbAbsorptionHalfTimeMinutes)');
    }
    if (!glucoseTrendMgdlPerMin.isFinite) {
      errors.add('glucoseTrend must be finite (got $glucoseTrendMgdlPerMin)');
    }

    if (errors.isNotEmpty) {
      return Result.failure(
        MedicalValidationFailure(errors.join('; '), field: 'prediction_input'),
      );
    }

    return Result.success(
      PredictionInput._(
        currentBG: currentBG,
        carbohydrates: carbohydrates,
        doseUnits: doseUnits,
        iob: iob,
        isfMgdlPerUnit: isfMgdlPerUnit,
        icrGramsPerUnit: icrGramsPerUnit,
        insulinDuration: insulinDuration,
        minutesSinceInjection: minutesSinceInjection,
        carbAbsorptionHalfTimeMinutes: carbAbsorptionHalfTimeMinutes,
        snapshotUtc: snapshotUtc,
        glucoseTrendMgdlPerMin: glucoseTrendMgdlPerMin,
        linkedTraceId: linkedTraceId,
      ),
    );
  }

  // ── Derived helpers ───────────────────────────────────────────────────────

  double get currentBGMgdl => currentBG.mgdl;
  double get carbsGrams => carbohydrates.grams;
  double get doseU => doseUnits.units;
  double get iobU => iob.units;
  double get diaMinutes => insulinDuration.minutes;

  /// Maximum theoretical BG rise from these carbohydrates (mg/dL).
  ///   maxCarbImpact = (carbs / ICR) × ISF
  double get maxCarbImpactMgdl => (carbsGrams / icrGramsPerUnit) * isfMgdlPerUnit;

  /// Maximum theoretical BG lowering from this dose (mg/dL).
  ///   maxInsulinImpact = dose × ISF
  double get maxDoseImpactMgdl => doseU * isfMgdlPerUnit;

  /// Maximum theoretical BG lowering from IOB (mg/dL).
  double get maxIobImpactMgdl => iobU * isfMgdlPerUnit;

  bool get hasTrend => glucoseTrendMgdlPerMin != 0.0;
  bool get hasCarbs => carbsGrams > 0;
  bool get hasDose => doseU > 0;

  @override
  List<Object?> get props => [
        currentBG,
        carbohydrates,
        doseUnits,
        iob,
        isfMgdlPerUnit,
        icrGramsPerUnit,
        insulinDuration,
        minutesSinceInjection,
        carbAbsorptionHalfTimeMinutes,
        glucoseTrendMgdlPerMin,
        snapshotUtc,
      ];
}
