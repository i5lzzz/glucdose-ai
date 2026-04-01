// lib/algorithms/dose/standard_dose_calculator.dart
// ─────────────────────────────────────────────────────────────────────────────
// StandardDoseCalculator — implements [DoseCalculator].
//
// ═══════════════════════════════════════════════════════════════════════════
// THE CORE DOSE FORMULA
// ═══════════════════════════════════════════════════════════════════════════
//
//   dose = (carbs / ICR) + (BG − target) / ISF − IOB
//
//   Where:
//     carbs    = Carbohydrates.grams
//     ICR      = CarbRatio.value  (g of carbs per 1 U of insulin)
//     BG       = BloodGlucose.mgdl (current reading)
//     target   = BloodGlucose.mgdl (user's target)
//     ISF      = InsulinSensitivityFactor.value (mg/dL per U)
//     IOB      = InsulinUnits.units (active insulin on board)
//
// ═══════════════════════════════════════════════════════════════════════════
// SEQUENCE OF OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════
//
//   Step 1  → mealComponent      = CarbRatio.carbDoseFor(carbs)
//   Step 2  → correctionComponent = ISF.correctionDoseFor(BG, target)
//   Step 3  → iobDeduction       = IOB.units  (positive scalar, subtracted)
//   Step 4  → rawTotal           = meal + correction − IOB
//   Step 5  → clampNegative      = max(0, rawTotal)
//   Step 6  → clampCeiling       = min(clampedValue, effectiveCeiling)
//             where effectiveCeiling = min(userMaxDose, ABSOLUTE_MAX)
//   Step 7  → stepFloor          = DoseStepApplicator.apply(clamped, step)
//   Step 8  → finalDose          = stepFloor.steppedDose
//
// ═══════════════════════════════════════════════════════════════════════════
// PURITY CONTRACT
// ═══════════════════════════════════════════════════════════════════════════
//
//   This class has NO state. The [appVersion] injected at construction is a
//   constant string.  The [calculate] method:
//     - reads only from its argument
//     - writes nothing
//     - calls no external services
//     - generates a deterministic [CalculationTrace]
//     - never throws (returns Result.failure on error)
//
//   Given identical [DoseCalculationInput] objects, [calculate] returns
//   identical [CalculationTrace] objects.  This is verified by the test suite.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:uuid/uuid.dart';

import 'package:insulin_assistant/algorithms/dose/dose_breakdown.dart';
import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/algorithms/math/precision_math.dart';
import 'package:insulin_assistant/algorithms/version.dart';
import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/contracts/dose_calculator.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/entities/calculation_trace.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

/// Production implementation of [DoseCalculator].
///
/// [appVersion] — the current app semver, embedded in every trace.
/// [doseStep]   — the device precision step for the current user.
final class StandardDoseCalculator implements DoseCalculator {
  const StandardDoseCalculator({
    required this.appVersion,
    this.doseStep = DoseStep.half,
  });

  final String appVersion;
  final DoseStep doseStep;

  static const _uuid = Uuid();

  @override
  String get algorithmVersion => AlgorithmVersion.doseCalculator;

  // ── DoseCalculator interface ──────────────────────────────────────────────

  @override
  Result<CalculationTrace> calculate(DoseCalculationInput input) {
    try {
      return _calculate(input);
    } catch (e, st) {
      // Safety net — algorithm must NEVER crash the caller
      return Result.failure(
        UnexpectedFailure(
          '[DoseCalculator] Unhandled exception: $e\n$st',
        ),
      );
    }
  }

  // ── Core calculation (wrapped for safety) ────────────────────────────────

  Result<CalculationTrace> _calculate(DoseCalculationInput input) {
    // ── Validate that we have legal values to operate on ──────────────────
    final validationResult = _validateInputs(input);
    if (validationResult != null) return Result.failure(validationResult);

    // ── Step 1: Meal (carbohydrate) component ────────────────────────────
    //   mealComponent = carbs / ICR
    final mealComponent = PrecisionMath.safeDivide(
      input.carbohydrates.grams,
      input.carbRatio.value,
    );

    // ── Step 2: Correction component ─────────────────────────────────────
    //   correctionComponent = (currentBG − targetBG) / ISF
    //   May be negative if BG is below target.
    final correctionComponent = input.sensitivityFactor.correctionDoseFor(
      currentBgMgdl: input.currentBG.mgdl,
      targetBgMgdl: input.targetBG.mgdl,
    );

    // ── Step 3: IOB deduction ────────────────────────────────────────────
    //   The full IOB is deducted.
    //   IOB cannot logically exceed (meal + correction), but we allow it —
    //   the clampToZero step handles the resulting negative value safely.
    final iobDeduction = input.iob.units;

    // ── Step 4: Raw total ─────────────────────────────────────────────────
    //   rawTotal = meal + correction − IOB
    final rawTotal = PrecisionMath.normalise(
      mealComponent + correctionComponent - iobDeduction,
      decimals: 6, // retain precision for intermediate step
    );

    // ── Step 5: Clamp to zero ─────────────────────────────────────────────
    //   A negative total means IOB alone covers the need — no new insulin.
    final wasClampedToZero = PrecisionMath.lessThan(rawTotal, 0.0);
    final afterZeroClamp = wasClampedToZero ? 0.0 : rawTotal;

    // ── Step 6: Ceiling clamp ─────────────────────────────────────────────
    //   Effective ceiling = min(userMax, absolute ceiling)
    final absoluteCeiling = MedicalConstants.absoluteMaxSingleDoseUnits;
    final effectiveCeiling = afterZeroClamp > 0
        ? _effectiveCeiling(input.userMaxDose.units, absoluteCeiling)
        : 0.0;
    final wasClampedByCeiling = afterZeroClamp > effectiveCeiling;
    final afterCeilingClamp = wasClampedByCeiling ? effectiveCeiling : afterZeroClamp;

    // ── Step 7: Dose step (floor to device precision) ─────────────────────
    final stepResult = DoseStepApplicator.apply(afterCeilingClamp, doseStep);
    final finalDose = stepResult.steppedDose;

    // ── Step 8: Build DoseBreakdown ───────────────────────────────────────
    final breakdown = DoseBreakdown(
      carbsGrams: input.carbohydrates.grams,
      carbRatioGramsPerUnit: input.carbRatio.value,
      currentBGMgdl: input.currentBG.mgdl,
      targetBGMgdl: input.targetBG.mgdl,
      isfMgdlPerUnit: input.sensitivityFactor.value,
      iobUnits: iobDeduction,
      userMaxDoseUnits: input.userMaxDose.units,
      doseStep: doseStep,
      mealComponent: PrecisionMath.normalise(mealComponent),
      correctionComponent: PrecisionMath.normalise(correctionComponent),
      iobDeduction: iobDeduction,
      rawTotal: rawTotal,
      clampedTotal: afterCeilingClamp,
      stepResult: stepResult,
      finalDoseUnits: finalDose,
      wasClampedToZero: wasClampedToZero,
      wasClampedByCeiling: wasClampedByCeiling,
      appliedCeilingUnits: effectiveCeiling,
    );

    // ── Step 9: Wrap in InsulinUnits ───────────────────────────────────────
    final finalUnitsResult = InsulinUnits.fromUnits(finalDose);
    if (finalUnitsResult.isFailure) {
      return Result.failure(
        ImplausibleDoseFailure(
          'Computed dose $finalDose is outside InsulinUnits range',
          calculatedDose: finalDose,
        ),
      );
    }

    // ── Step 10: Build safety flags from breakdown ─────────────────────────
    final flags = _deriveSafetyFlags(breakdown, input);

    // ── Step 11: Build output ──────────────────────────────────────────────
    final output = DoseCalculationOutput(
      rawCalculatedDose: rawTotal,
      clampedDose: finalUnitsResult.value,
      carbComponent: breakdown.mealComponent,
      correctionComponent: breakdown.correctionComponent,
      iobDeduction: breakdown.iobDeduction,
      safetyFlags: flags,
      wasBlocked: false, // blocking is the SafetyEvaluator's role, not ours
      blockReason: null,
    );

    // ── Step 12: Assemble CalculationTrace ────────────────────────────────
    final trace = CalculationTrace(
      id: _uuid.v4(),
      userId: _userIdFromInput(input),
      input: input,
      steps: _toTraceSteps(breakdown.steps),
      output: output,
      algorithmVersion: AlgorithmVersion.compositeVersion,
      appVersion: appVersion,
      createdAt: input.timestampUtc,
    );

    return Result.success(trace);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Validates all numeric inputs are within plausible ranges before starting.
  /// These are defence-in-depth checks — value objects should have already
  /// caught most of these.
  Failure? _validateInputs(DoseCalculationInput input) {
    if (!input.currentBG.mgdl.isFinite) {
      return const MedicalValidationFailure(
        'currentBG is not finite',
        field: 'current_bg',
      );
    }
    if (!input.carbohydrates.grams.isFinite) {
      return const MedicalValidationFailure(
        'carbohydrates is not finite',
        field: 'carbohydrates',
      );
    }
    if (!input.iob.units.isFinite) {
      return const MedicalValidationFailure(
        'iob is not finite',
        field: 'iob',
      );
    }
    if (input.carbRatio.value <= 0) {
      return const MedicalValidationFailure(
        'CarbRatio must be positive (used as divisor)',
        field: 'carb_ratio',
      );
    }
    if (input.sensitivityFactor.value <= 0) {
      return const MedicalValidationFailure(
        'ISF must be positive (used as divisor)',
        field: 'isf',
      );
    }
    return null;
  }

  double _effectiveCeiling(double userMax, double absoluteMax) {
    // Absolute max is non-negotiable; user max is advisory but enforced
    return userMax < absoluteMax ? userMax : absoluteMax;
  }

  List<SafetyFlag> _deriveSafetyFlags(
    DoseBreakdown breakdown,
    DoseCalculationInput input,
  ) {
    final flags = <SafetyFlag>[];

    if (breakdown.wasClampedToZero) {
      flags.add(
        const SafetyFlag(
          reason: SafetyBlockReason.negativeDoseCalculated,
          severity: SafetyFlagSeverity.info,
          description: 'IOB covers the full calculated dose — no injection needed',
          wasBlocking: false,
        ),
      );
    }

    if (breakdown.wasClampedByCeiling) {
      final isAbsoluteCeiling = breakdown.appliedCeilingUnits ==
          MedicalConstants.absoluteMaxSingleDoseUnits;
      flags.add(
        SafetyFlag(
          reason: isAbsoluteCeiling
              ? SafetyBlockReason.doseExceedsAbsoluteCeiling
              : SafetyBlockReason.doseExceedsUserCeiling,
          severity: SafetyFlagSeverity.warning,
          description: isAbsoluteCeiling
              ? 'Dose was clamped to absolute safety ceiling '
                  '(${breakdown.appliedCeilingUnits} U)'
              : 'Dose was clamped to your configured maximum '
                  '(${breakdown.appliedCeilingUnits} U)',
          wasBlocking: true,
        ),
      );
    }

    if (PrecisionMath.greaterThan(
      input.iob.units,
      MedicalConstants.iobStackingWarningThreshold,
    )) {
      flags.add(
        SafetyFlag(
          reason: SafetyBlockReason.iobStackingDetected,
          severity: SafetyFlagSeverity.warning,
          description:
              'High IOB detected (${input.iob.units.toStringAsFixed(1)} U) — '
              'stacking risk',
          wasBlocking: false,
        ),
      );
    }

    return flags;
  }

  List<CalculationStep> _toTraceSteps(
    List<CalculationStepSnapshot> snapshots,
  ) =>
      snapshots
          .map(
            (s) => CalculationStep(
              stepName: s.name,
              formula: s.formulaAr, // Primary language is Arabic
              result: s.value,
              notes: s.note,
            ),
          )
          .toList();

  String _userIdFromInput(DoseCalculationInput input) =>
      input.mealId ?? 'unknown';
}
