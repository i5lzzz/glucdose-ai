// lib/algorithms/dose/dose_step.dart
// ─────────────────────────────────────────────────────────────────────────────
// DoseStep — insulin delivery device precision.
//
// CLINICAL RATIONALE:
//   Insulin delivery devices (pens, pumps) have physical minimum increments:
//     • Older vial+syringe : 1.0 U minimum increment
//     • Standard pen       : 0.5 U minimum increment (most common in KSA)
//     • Precision pen      : 0.1 U minimum increment (NovoPen Echo, etc.)
//
//   The calculator MUST floor to the step — not round.
//   If calculated dose = 3.7 U and step = 0.5 U:
//     round → 4.0 U  ← patient gets 0.3 U MORE than calculated → hypo risk
//     floor → 3.5 U  ← patient gets 0.2 U LESS → mild under-correction
//   The latter is the safer clinical choice.
//
// DISPLAY:
//   The step also drives the decimal precision shown in the UI.
//   step=0.1 → show 1 decimal place; step=1.0 → show 0 decimal places.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';
import 'package:insulin_assistant/algorithms/math/precision_math.dart';

/// Represents the minimum dose increment of the user's insulin delivery device.
enum DoseStep {
  /// 0.1 U — precision pens (NovoPen Echo, HumaPen Savvio).
  tenth(value: 0.1, decimalPlaces: 1, labelAr: '٠.١ وحدة', labelEn: '0.1 U'),

  /// 0.5 U — standard disposable pens (most common in Saudi Arabia).
  half(value: 0.5, decimalPlaces: 1, labelAr: '٠.٥ وحدة', labelEn: '0.5 U'),

  /// 1.0 U — standard syringes or older pens.
  whole(value: 1.0, decimalPlaces: 0, labelAr: '١ وحدة', labelEn: '1 U');

  const DoseStep({
    required this.value,
    required this.decimalPlaces,
    required this.labelAr,
    required this.labelEn,
  });

  final double value;
  final int decimalPlaces;
  final String labelAr;
  final String labelEn;

  /// Default step — used when the user has not selected a device precision.
  static const DoseStep defaultStep = DoseStep.half;

  // ── Core operation ────────────────────────────────────────────────────────

  /// Floors [rawDose] DOWN to the nearest multiple of this step.
  ///
  /// Enforces the clinical safety rule: always give less, never more.
  ///
  /// ```
  /// DoseStep.half.floor(3.74)  → 3.5
  /// DoseStep.half.floor(3.5)   → 3.5
  /// DoseStep.tenth.floor(3.74) → 3.7
  /// DoseStep.whole.floor(3.9)  → 3.0
  /// ```
  double floor(double rawDose) {
    if (rawDose <= 0) return 0.0;
    return PrecisionMath.floorToStep(rawDose, value);
  }

  /// Returns a display string for [dose] at this step's precision.
  String format(double dose) => dose.toStringAsFixed(decimalPlaces);

  /// Returns the minimum clinically meaningful dose for this step.
  /// Doses below this threshold should be displayed as "< {value}" not "0".
  double get minimumSignificant => value;
}

// ── DoseStepResult ────────────────────────────────────────────────────────────

/// Result of applying a dose step to a raw calculated dose.
final class DoseStepResult extends Equatable {
  const DoseStepResult({
    required this.rawDose,
    required this.steppedDose,
    required this.step,
    required this.truncatedAmount,
  });

  /// Raw double from the calculation (before step application).
  final double rawDose;

  /// Final deliverable dose, floored to [step].
  final double steppedDose;

  final DoseStep step;

  /// Amount truncated by flooring (rawDose - steppedDose).
  /// Should always be in [0, step.value).
  final double truncatedAmount;

  bool get wasTruncated =>
      !PrecisionMath.nearZero(truncatedAmount);

  String get displayString => step.format(steppedDose);

  @override
  List<Object?> get props => [rawDose, steppedDose, step];

  @override
  String toString() =>
      'DoseStepResult(raw=$rawDose, stepped=$steppedDose, step=${step.value})';
}

// ── DoseStepApplicator ────────────────────────────────────────────────────────

/// Stateless service that applies a [DoseStep] to a raw dose.
abstract final class DoseStepApplicator {
  /// Applies [step] to [rawDose], returning a full [DoseStepResult].
  static DoseStepResult apply(double rawDose, DoseStep step) {
    final clamped = PrecisionMath.clampToZero(rawDose);
    final stepped = step.floor(clamped);
    final truncated = PrecisionMath.normalise(clamped - stepped);
    return DoseStepResult(
      rawDose: rawDose,
      steppedDose: stepped,
      step: step,
      truncatedAmount: truncated,
    );
  }
}
