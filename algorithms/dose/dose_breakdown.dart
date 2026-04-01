// lib/algorithms/dose/dose_breakdown.dart
// ─────────────────────────────────────────────────────────────────────────────
// DoseBreakdown — the full arithmetic decomposition of a calculated dose.
//
// COMPONENTS OF THE DOSE FORMULA:
//
//   dose = mealComponent + correctionComponent - iobDeduction
//
//   where:
//     mealComponent      = carbs (g) / ICR (g/U)
//     correctionComponent = (currentBG - targetBG) / ISF
//     iobDeduction       = current IOB (U)
//
//   After summation:
//     rawTotal           = mealComponent + correctionComponent - iobDeduction
//     clampedToZero      = max(0, rawTotal)     ← no negative doses
//     steppedDose        = floor(clampedToZero, doseStep)  ← device precision
//
// EXPLAINABILITY REQUIREMENT:
//   Every component, intermediate value, and safety clamp is recorded so that
//   the CalculationTrace can reproduce or explain the result to a reviewer.
//
// IMMUTABILITY:
//   DoseBreakdown is immutable and equality-comparable.
//   The CalculationTrace holds a DoseBreakdown as its canonical output summary.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/algorithms/math/precision_math.dart';

/// Complete arithmetic decomposition of a single dose calculation.
final class DoseBreakdown extends Equatable {
  const DoseBreakdown({
    // ── Inputs ───────────────────────────────────────────────────────────────
    required this.carbsGrams,
    required this.carbRatioGramsPerUnit,
    required this.currentBGMgdl,
    required this.targetBGMgdl,
    required this.isfMgdlPerUnit,
    required this.iobUnits,
    required this.userMaxDoseUnits,
    required this.doseStep,
    // ── Component results ─────────────────────────────────────────────────
    required this.mealComponent,
    required this.correctionComponent,
    required this.iobDeduction,
    // ── Totals ────────────────────────────────────────────────────────────
    required this.rawTotal,
    required this.clampedTotal,
    required this.stepResult,
    required this.finalDoseUnits,
    // ── Clamp metadata ────────────────────────────────────────────────────
    required this.wasClampedToZero,
    required this.wasClampedByCeiling,
    required this.appliedCeilingUnits,
  });

  // ── Inputs recorded verbatim ──────────────────────────────────────────────
  final double carbsGrams;
  final double carbRatioGramsPerUnit;
  final double currentBGMgdl;
  final double targetBGMgdl;
  final double isfMgdlPerUnit;
  final double iobUnits;
  final double userMaxDoseUnits;
  final DoseStep doseStep;

  // ── Per-component results ─────────────────────────────────────────────────

  /// carbs / ICR
  final double mealComponent;

  /// (currentBG - targetBG) / ISF  — may be negative (BG below target)
  final double correctionComponent;

  /// Active IOB deducted from the total (always positive)
  final double iobDeduction;

  // ── Aggregated totals ─────────────────────────────────────────────────────

  /// mealComponent + correctionComponent - iobDeduction
  /// May be negative — clamped before delivery.
  final double rawTotal;

  /// max(0, min(rawTotal, ceiling))  — before step application
  final double clampedTotal;

  /// Result of applying the dose step to clampedTotal.
  final DoseStepResult stepResult;

  /// The final deliverable dose in insulin units.
  final double finalDoseUnits;

  // ── Clamp metadata ────────────────────────────────────────────────────────

  /// True when rawTotal was negative (IOB exceeded calculated need).
  final bool wasClampedToZero;

  /// True when rawTotal exceeded the user or absolute ceiling.
  final bool wasClampedByCeiling;

  /// The ceiling value applied (user max or absolute max, whichever was lower).
  final double appliedCeilingUnits;

  // ── Derived helpers ───────────────────────────────────────────────────────

  bool get hasMealComponent =>
      !PrecisionMath.nearZero(mealComponent);

  bool get hasCorrectionComponent =>
      !PrecisionMath.nearZero(correctionComponent);

  bool get hasPositiveCorrection =>
      PrecisionMath.greaterThan(correctionComponent, 0);

  bool get hasNegativeCorrection =>
      PrecisionMath.lessThan(correctionComponent, 0);

  bool get hasIOBDeduction =>
      !PrecisionMath.nearZero(iobDeduction);

  bool get isZeroDose =>
      PrecisionMath.nearZero(finalDoseUnits);

  /// IOB covered ALL of the calculated need — no injection warranted.
  bool get iobFullyCovered =>
      wasClampedToZero && !PrecisionMath.nearZero(iobUnits);

  /// The effective BG delta this dose is expected to correct.
  double get bgDelta => currentBGMgdl - targetBGMgdl;

  // ── Human-readable step list ─────────────────────────────────────────────

  /// Returns ordered list of [CalculationStepSnapshot] for the trace.
  List<CalculationStepSnapshot> get steps => [
        CalculationStepSnapshot(
          name: 'meal_component',
          formulaAr: 'جرعة الكربوهيدرات = $carbsGrams ÷ $carbRatioGramsPerUnit',
          formulaEn: 'Meal dose = $carbsGrams g ÷ $carbRatioGramsPerUnit g/U',
          value: mealComponent,
        ),
        CalculationStepSnapshot(
          name: 'correction_component',
          formulaAr:
              'جرعة التصحيح = ($currentBGMgdl − $targetBGMgdl) ÷ $isfMgdlPerUnit',
          formulaEn:
              'Correction = ($currentBGMgdl − $targetBGMgdl) ÷ $isfMgdlPerUnit mg/dL/U',
          value: correctionComponent,
        ),
        CalculationStepSnapshot(
          name: 'iob_deduction',
          formulaAr: 'خصم الأنسولين الفعّال = −$iobUnits',
          formulaEn: 'IOB deduction = −$iobUnits U',
          value: -iobDeduction,
        ),
        CalculationStepSnapshot(
          name: 'raw_total',
          formulaAr:
              'المجموع الخام = $mealComponent + $correctionComponent − $iobUnits',
          formulaEn:
              'Raw total = $mealComponent + $correctionComponent − $iobUnits',
          value: rawTotal,
        ),
        if (wasClampedToZero)
          const CalculationStepSnapshot(
            name: 'clamp_to_zero',
            formulaAr: 'الجرعة سالبة → تُحوَّل إلى صفر (الأنسولين الفعّال يغطي الاحتياج)',
            formulaEn: 'Negative dose → clamped to 0 (IOB covers the need)',
            value: 0,
          ),
        if (wasClampedByCeiling)
          CalculationStepSnapshot(
            name: 'ceiling_clamp',
            formulaAr: 'الجرعة تتجاوز السقف ($appliedCeilingUnits) → تُقيَّد',
            formulaEn: 'Dose exceeds ceiling ($appliedCeilingUnits U) → clamped',
            value: appliedCeilingUnits,
          ),
        CalculationStepSnapshot(
          name: 'dose_step_floor',
          formulaAr:
              'تقريب للجهاز = floor($clampedTotal ÷ ${doseStep.value}) × ${doseStep.value}',
          formulaEn:
              'Device floor = floor($clampedTotal ÷ ${doseStep.value}) × ${doseStep.value}',
          value: finalDoseUnits,
        ),
      ];

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'inputs': {
          'carbs_g': carbsGrams,
          'icr': carbRatioGramsPerUnit,
          'bg_mgdl': currentBGMgdl,
          'target_bg_mgdl': targetBGMgdl,
          'isf': isfMgdlPerUnit,
          'iob_units': iobUnits,
          'user_max_dose': userMaxDoseUnits,
          'dose_step': doseStep.value,
        },
        'components': {
          'meal': mealComponent,
          'correction': correctionComponent,
          'iob_deduction': iobDeduction,
        },
        'totals': {
          'raw': rawTotal,
          'clamped': clampedTotal,
          'stepped': finalDoseUnits,
          'truncated': stepResult.truncatedAmount,
        },
        'clamps': {
          'to_zero': wasClampedToZero,
          'by_ceiling': wasClampedByCeiling,
          'ceiling_used': appliedCeilingUnits,
        },
      };

  @override
  List<Object?> get props => [
        mealComponent,
        correctionComponent,
        iobDeduction,
        rawTotal,
        finalDoseUnits,
      ];

  @override
  String toString() =>
      'DoseBreakdown(meal=$mealComponent, corr=$correctionComponent, '
      'iob=-$iobDeduction, raw=$rawTotal, final=$finalDoseUnits)';
}

/// A single named step in the calculation for display/audit.
final class CalculationStepSnapshot extends Equatable {
  const CalculationStepSnapshot({
    required this.name,
    required this.formulaAr,
    required this.formulaEn,
    required this.value,
    this.note,
  });

  final String name;
  final String formulaAr;
  final String formulaEn;
  final double value;
  final String? note;

  Map<String, dynamic> toJson() => {
        'name': name,
        'formula_ar': formulaAr,
        'formula_en': formulaEn,
        'value': value,
        if (note != null) 'note': note,
      };

  @override
  List<Object?> get props => [name, value];
}
