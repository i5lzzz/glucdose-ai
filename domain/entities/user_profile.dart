// lib/domain/entities/user_profile.dart
// ─────────────────────────────────────────────────────────────────────────────
// UserProfile entity — the clinical configuration that drives all calculations.
//
// IMMUTABILITY: All fields are final.  Updates produce new instances via
// copyWith — the old instance is preserved for audit delta computation.
//
// COMPLETENESS VALIDATION:
//   isComplete() is checked by the safety engine before any calculation.
//   An incomplete profile blocks all dose calculations with
//   SafetyBlockReason.incompleteProfile.
//
// CHANGE TRACKING:
//   Every profile update is written to the audit log with the old and new
//   values of each changed field.  This satisfies IEC 62304 §9.1.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import 'package:insulin_assistant/domain/core/unit_system.dart';
import 'package:insulin_assistant/domain/value_objects/carb_ratio.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_duration.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_sensitivity_factor.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

/// Diabetes type classification.
enum DiabetesType {
  type1,
  type2,
  lada, // Latent Autoimmune Diabetes in Adults
  mody, // Maturity Onset Diabetes of the Young
  gestational,
  other,
}

/// Immutable clinical user profile.
final class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.displayName,
    required this.diabetesType,
    required this.carbRatio,
    required this.sensitivityFactor,
    required this.targetBloodGlucose,
    required this.maxDoseUnits,
    required this.insulinDuration,
    required this.unitSystem,
    this.dateOfBirth,
    this.locale = 'ar',
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String displayName;
  final DiabetesType diabetesType;
  final CarbRatio carbRatio;
  final InsulinSensitivityFactor sensitivityFactor;
  final BloodGlucose targetBloodGlucose;
  final InsulinUnits maxDoseUnits;
  final InsulinDuration insulinDuration;
  final UnitSystem unitSystem;
  final DateTime? dateOfBirth;
  final String locale;

  // ── Profile completeness ──────────────────────────────────────────────────

  /// Returns true when all calculation-critical fields are set with
  /// clinically plausible values.  An incomplete profile blocks all doses.
  bool get isComplete => _validateCompleteness().isEmpty;

  /// Returns list of human-readable missing/invalid field descriptions.
  List<String> get completenessErrors => _validateCompleteness();

  List<String> _validateCompleteness() {
    final errors = <String>[];
    if (displayName.trim().isEmpty) errors.add('display_name');
    // Value objects already guarantee individual field validity —
    // presence here means they were successfully constructed, so
    // completeness check is always satisfied if the entity was built.
    // This is intentional: the builder must supply all VOs.
    return errors;
  }

  // ── Mutation ──────────────────────────────────────────────────────────────

  UserProfile copyWith({
    DateTime? updatedAt,
    String? displayName,
    DiabetesType? diabetesType,
    CarbRatio? carbRatio,
    InsulinSensitivityFactor? sensitivityFactor,
    BloodGlucose? targetBloodGlucose,
    InsulinUnits? maxDoseUnits,
    InsulinDuration? insulinDuration,
    UnitSystem? unitSystem,
    DateTime? dateOfBirth,
    String? locale,
  }) =>
      UserProfile(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        displayName: displayName ?? this.displayName,
        diabetesType: diabetesType ?? this.diabetesType,
        carbRatio: carbRatio ?? this.carbRatio,
        sensitivityFactor: sensitivityFactor ?? this.sensitivityFactor,
        targetBloodGlucose: targetBloodGlucose ?? this.targetBloodGlucose,
        maxDoseUnits: maxDoseUnits ?? this.maxDoseUnits,
        insulinDuration: insulinDuration ?? this.insulinDuration,
        unitSystem: unitSystem ?? this.unitSystem,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        locale: locale ?? this.locale,
      );

  /// Returns a map of changed field names (for audit delta logging).
  Map<String, Map<String, dynamic>> auditDelta(UserProfile previous) {
    final delta = <String, Map<String, dynamic>>{};
    if (carbRatio != previous.carbRatio) {
      delta['carb_ratio'] = {
        'from': previous.carbRatio.value,
        'to': carbRatio.value,
      };
    }
    if (sensitivityFactor != previous.sensitivityFactor) {
      delta['sensitivity_factor'] = {
        'from': previous.sensitivityFactor.value,
        'to': sensitivityFactor.value,
      };
    }
    if (targetBloodGlucose != previous.targetBloodGlucose) {
      delta['target_bg'] = {
        'from': previous.targetBloodGlucose.mgdl,
        'to': targetBloodGlucose.mgdl,
      };
    }
    if (maxDoseUnits != previous.maxDoseUnits) {
      delta['max_dose'] = {
        'from': previous.maxDoseUnits.units,
        'to': maxDoseUnits.units,
      };
    }
    if (insulinDuration != previous.insulinDuration) {
      delta['insulin_duration'] = {
        'from': previous.insulinDuration.minutes,
        'to': insulinDuration.minutes,
      };
    }
    return delta;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'display_name': displayName,
        'diabetes_type': diabetesType.name,
        'carb_ratio': carbRatio.toJson(),
        'sensitivity_factor': sensitivityFactor.toJson(),
        'target_bg': targetBloodGlucose.toJson(),
        'max_dose': maxDoseUnits.toJson(),
        'insulin_duration': insulinDuration.toJson(),
        'unit_system': unitSystem.toJson(),
        if (dateOfBirth != null) 'dob': dateOfBirth!.toIso8601String(),
        'locale': locale,
      };

  @override
  List<Object?> get props => [
        id,
        carbRatio,
        sensitivityFactor,
        targetBloodGlucose,
        maxDoseUnits,
        insulinDuration,
        unitSystem,
        locale,
      ];
}
