// lib/domain/entities/calculation_trace.dart
// ─────────────────────────────────────────────────────────────────────────────
// CalculationTrace entity — THE most critical audit artifact in the system.
//
// PURPOSE:
//   Records the complete, deterministic state that produced a specific dose
//   recommendation.  Given a CalculationTrace, any reviewer — clinical,
//   regulatory, or engineering — can reproduce the exact calculation.
//
// IMMUTABILITY:
//   Once created, a trace is NEVER modified.  If a dose is overridden by the
//   user, a NEW trace is created for the override; the original is preserved.
//
// COMPLIANCE:
//   This entity directly satisfies:
//     IEC 62304 §9.1     — Problem reporting and traceability
//     FDA SaMD guidance  — Audit trail and documentation
//     ISO 14971 §10      — Risk control effectiveness verification
//
// STRUCTURE:
//   Inputs  → every parameter that entered the calculation
//   Steps   → each computation step with its intermediate result
//   Output  → final clamped dose + all safety flags triggered
//   Meta    → timestamp, app version, algorithm version
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/carb_ratio.dart';
import 'package:insulin_assistant/domain/value_objects/carbohydrates.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_sensitivity_factor.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

// ── Input snapshot ────────────────────────────────────────────────────────────

/// Immutable snapshot of all inputs to a dose calculation.
final class DoseCalculationInput extends Equatable {
  const DoseCalculationInput({
    required this.currentBG,
    required this.carbohydrates,
    required this.iob,
    required this.carbRatio,
    required this.sensitivityFactor,
    required this.targetBG,
    required this.userMaxDose,
    required this.timestampUtc,
    this.mealId,
    this.glucoseTrend,
  });

  final BloodGlucose currentBG;
  final Carbohydrates carbohydrates;
  final InsulinUnits iob;
  final CarbRatio carbRatio;
  final InsulinSensitivityFactor sensitivityFactor;
  final BloodGlucose targetBG;
  final InsulinUnits userMaxDose;
  final DateTime timestampUtc;
  final String? mealId;
  final double? glucoseTrend; // mg/dL per minute — from CGM

  Map<String, dynamic> toJson() => {
        'current_bg_mgdl': currentBG.mgdl,
        'carbohydrates_g': carbohydrates.grams,
        'iob_units': iob.units,
        'carb_ratio': carbRatio.value,
        'isf_mgdl_per_unit': sensitivityFactor.value,
        'target_bg_mgdl': targetBG.mgdl,
        'user_max_dose_units': userMaxDose.units,
        'timestamp_utc': timestampUtc.toIso8601String(),
        if (mealId != null) 'meal_id': mealId,
        if (glucoseTrend != null) 'glucose_trend': glucoseTrend,
      };

  @override
  List<Object?> get props => [
        currentBG,
        carbohydrates,
        iob,
        carbRatio,
        sensitivityFactor,
        targetBG,
        userMaxDose,
        timestampUtc,
      ];
}

// ── Intermediate steps ────────────────────────────────────────────────────────

/// A single labelled step in the calculation, with its intermediate value.
final class CalculationStep extends Equatable {
  const CalculationStep({
    required this.stepName,
    required this.formula,
    required this.result,
    this.notes,
  });

  final String stepName;
  final String formula; // Human-readable formula string
  final double result;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'step': stepName,
        'formula': formula,
        'result': result,
        if (notes != null) 'notes': notes,
      };

  @override
  List<Object?> get props => [stepName, result];
}

// ── Safety flags ──────────────────────────────────────────────────────────────

/// A safety flag raised during calculation or post-calculation evaluation.
final class SafetyFlag extends Equatable {
  const SafetyFlag({
    required this.reason,
    required this.severity,
    required this.description,
    this.wasBlocking = false,
  });

  final SafetyBlockReason reason;
  final SafetyFlagSeverity severity;
  final String description;

  /// True if this flag caused the calculation to be blocked/clamped.
  final bool wasBlocking;

  Map<String, dynamic> toJson() => {
        'reason': reason.name,
        'severity': severity.name,
        'description': description,
        'was_blocking': wasBlocking,
      };

  @override
  List<Object?> get props => [reason, severity, wasBlocking];
}

enum SafetyFlagSeverity { info, warning, critical }

// ── Output ────────────────────────────────────────────────────────────────────

/// The complete output of a dose calculation.
final class DoseCalculationOutput extends Equatable {
  const DoseCalculationOutput({
    required this.rawCalculatedDose,
    required this.clampedDose,
    required this.carbComponent,
    required this.correctionComponent,
    required this.iobDeduction,
    required this.safetyFlags,
    required this.wasBlocked,
    required this.blockReason,
  });

  /// Dose before any clamping or safety intervention.
  final double rawCalculatedDose;

  /// Final dose after clamping to ceiling and applying safety rules.
  final InsulinUnits clampedDose;

  // ── Breakdown components ─────────────────────────────────────────────────

  /// Dose component from carbohydrate coverage: carbs / ICR
  final double carbComponent;

  /// Dose component from BG correction: (BG - target) / ISF
  final double correctionComponent;

  /// Deduction from active IOB.
  final double iobDeduction;

  // ── Safety ───────────────────────────────────────────────────────────────

  final List<SafetyFlag> safetyFlags;
  final bool wasBlocked;
  final SafetyBlockReason? blockReason;

  bool get hasCriticalFlags =>
      safetyFlags.any((f) => f.severity == SafetyFlagSeverity.critical);

  Map<String, dynamic> toJson() => {
        'raw_dose': rawCalculatedDose,
        'clamped_dose': clampedDose.units,
        'carb_component': carbComponent,
        'correction_component': correctionComponent,
        'iob_deduction': iobDeduction,
        'safety_flags': safetyFlags.map((f) => f.toJson()).toList(),
        'was_blocked': wasBlocked,
        if (blockReason != null) 'block_reason': blockReason!.name,
      };

  @override
  List<Object?> get props => [rawCalculatedDose, clampedDose, wasBlocked];
}

// ── CalculationTrace (root entity) ───────────────────────────────────────────

/// Complete, immutable audit record of a single dose calculation.
final class CalculationTrace extends Equatable {
  const CalculationTrace({
    required this.id,
    required this.userId,
    required this.input,
    required this.steps,
    required this.output,
    required this.algorithmVersion,
    required this.appVersion,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final DoseCalculationInput input;
  final List<CalculationStep> steps;
  final DoseCalculationOutput output;

  /// Semver of the dose algorithm (e.g. "1.0.0").
  /// Changing any calculation constant bumps this version.
  final String algorithmVersion;

  /// Semver of the app build.
  final String appVersion;
  final DateTime createdAt;

  // ── Human-readable explanation ────────────────────────────────────────────

  /// Generates a formatted explanation string suitable for display in the
  /// "Calculation Breakdown" sheet.
  String get humanExplanation {
    final sb = StringBuffer();
    sb.writeln('الجرعة = (الكربوهيدرات ÷ ICR) + (السكر - الهدف) ÷ ISF - IOB');
    sb.writeln();
    for (final step in steps) {
      sb.writeln('${step.stepName}: ${step.formula} = ${step.result.toStringAsFixed(2)}');
    }
    sb.writeln();
    sb.writeln('الجرعة المحسوبة: ${output.rawCalculatedDose.toStringAsFixed(2)} وحدة');
    sb.writeln('الجرعة النهائية: ${output.clampedDose.display()} وحدة');
    if (output.safetyFlags.isNotEmpty) {
      sb.writeln();
      sb.writeln('تنبيهات الأمان:');
      for (final flag in output.safetyFlags) {
        sb.writeln('  • ${flag.description}');
      }
    }
    return sb.toString();
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'input': input.toJson(),
        'steps': steps.map((s) => s.toJson()).toList(),
        'output': output.toJson(),
        'algorithm_version': algorithmVersion,
        'app_version': appVersion,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, userId, createdAt, output];
}
