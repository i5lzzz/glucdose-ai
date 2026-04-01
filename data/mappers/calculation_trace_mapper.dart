// lib/data/mappers/calculation_trace_mapper.dart
// ─────────────────────────────────────────────────────────────────────────────
// CalculationTraceMapper — domain entity ↔ DTO using encrypted JSON blob.
//
// The full [CalculationTrace] is serialised to JSON, encrypted as a single
// blob, and stored in the `dose_history.carbs_enc` column.
// On retrieval, the blob is decrypted and the JSON is deserialised back.
//
// This is the only correct approach for complex nested entities — attempting
// to map every nested field to separate columns would require 25+ columns
// and make schema migrations extremely fragile.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:insulin_assistant/algorithms/version.dart';
import 'package:insulin_assistant/core/constants/app_constants.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/data/mappers/encryption_mapper.dart';
import 'package:insulin_assistant/data/models/calculation_trace_dto.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/entities/calculation_trace.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/carb_ratio.dart';
import 'package:insulin_assistant/domain/value_objects/carbohydrates.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_sensitivity_factor.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

final class CalculationTraceMapper {
  const CalculationTraceMapper(this._enc);

  final EncryptionMapper _enc;

  // ── Domain → DTO ──────────────────────────────────────────────────────────

  Future<CalculationTraceDTO> toDTO(
    CalculationTrace trace, {
    String outcome = 'pending',
  }) async {
    final traceJson = trace.toJson();
    final traceJsonEnc = await _enc.encryptJson(traceJson);
    final doseEnc =
        await _enc.encryptDouble(trace.output.clampedDose.units);
    final flagsEnc = await _enc.encryptString(
      trace.output.safetyFlags.map((f) => f.reason.name).join(','),
    );

    return CalculationTraceDTO(
      id: trace.id,
      userId: trace.userId,
      calculatedAt: trace.createdAt.toUtc().toIso8601String(),
      traceJsonEnc: traceJsonEnc,
      calculatedDoseEnc: doseEnc,
      safetyFlagsEnc: flagsEnc,
      outcome: outcome,
      algorithmVersion: trace.algorithmVersion,
      appVersion: trace.appVersion,
    );
  }

  // ── DTO → Domain ──────────────────────────────────────────────────────────

  Future<Result<CalculationTrace>> toDomain(CalculationTraceDTO dto) async {
    try {
      final traceJson = await _enc.decryptJson(dto.traceJsonEnc);
      final trace = _fromJson(dto.id, dto.userId, traceJson);
      return Result.success(trace);
    } catch (e) {
      return Result.failure(
        DatabaseFailure(
          'CalculationTrace decryption/deserialisation failed '
          'for id=${dto.id}: $e',
        ),
      );
    }
  }

  // ── JSON reconstruction ───────────────────────────────────────────────────

  CalculationTrace _fromJson(
    String id,
    String userId,
    Map<String, dynamic> json,
  ) {
    final inputJson = json['input'] as Map<String, dynamic>;
    final stepsJson = json['steps'] as List<dynamic>;
    final outputJson = json['output'] as Map<String, dynamic>;

    final input = _inputFromJson(inputJson);
    final steps = stepsJson.map(_stepFromJson).toList();
    final output = _outputFromJson(outputJson);

    return CalculationTrace(
      id: id,
      userId: userId,
      input: input,
      steps: steps,
      output: output,
      algorithmVersion: json['algorithm_version'] as String? ??
          AlgorithmVersion.compositeVersion,
      appVersion:
          json['app_version'] as String? ?? AppConstants.appVersion,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  DoseCalculationInput _inputFromJson(Map<String, dynamic> j) {
    return DoseCalculationInput(
      currentBG: BloodGlucose.fromMgdl(
        (j['current_bg_mgdl'] as num).toDouble(),
      ).value,
      carbohydrates: Carbohydrates.fromGrams(
        (j['carbohydrates_g'] as num).toDouble(),
      ).value,
      iob: InsulinUnits.fromUnitsUnclamped(
        (j['iob_units'] as num).toDouble(),
      ).value,
      carbRatio: CarbRatio.fromGramsPerUnit(
        (j['carb_ratio'] as num).toDouble(),
      ).value,
      sensitivityFactor: InsulinSensitivityFactor.fromMgdlPerUnit(
        (j['isf_mgdl_per_unit'] as num).toDouble(),
      ).value,
      targetBG: BloodGlucose.fromMgdl(
        (j['target_bg_mgdl'] as num).toDouble(),
      ).value,
      userMaxDose: InsulinUnits.fromUnits(
        (j['user_max_dose_units'] as num).toDouble(),
      ).value,
      timestampUtc: DateTime.parse(j['timestamp_utc'] as String),
      mealId: j['meal_id'] as String?,
    );
  }

  CalculationStep _stepFromJson(dynamic s) {
    final step = s as Map<String, dynamic>;
    return CalculationStep(
      stepName: step['name'] as String? ?? step['step'] as String,
      formula: step['formula_ar'] as String? ?? step['formula'] as String,
      result: (step['value'] as num? ?? step['result'] as num).toDouble(),
      notes: step['note'] as String?,
    );
  }

  DoseCalculationOutput _outputFromJson(Map<String, dynamic> j) {
    final flagsJson = j['safety_flags'] as List<dynamic>? ?? [];
    final flags = flagsJson.map((f) {
      final fm = f as Map<String, dynamic>;
      return SafetyFlag(
        reason: SafetyBlockReason.values.byName(
          fm['reason'] as String? ?? 'negativeDoseCalculated',
        ),
        severity: SafetyFlagSeverity.values.byName(
          fm['severity'] as String? ?? 'info',
        ),
        description: fm['description'] as String? ?? '',
        wasBlocking: fm['was_blocking'] as bool? ?? false,
      );
    }).toList();

    return DoseCalculationOutput(
      rawCalculatedDose:
          (j['raw_dose'] as num? ?? j['raw_calculated_dose'] as num? ?? 0)
              .toDouble(),
      clampedDose: InsulinUnits.fromUnits(
        (j['clamped_dose'] as num).toDouble(),
      ).value,
      carbComponent:
          (j['carb_component'] as num? ?? 0).toDouble(),
      correctionComponent:
          (j['correction_component'] as num? ?? 0).toDouble(),
      iobDeduction: (j['iob_deduction'] as num? ?? 0).toDouble(),
      safetyFlags: flags,
      wasBlocked: j['was_blocked'] as bool? ?? false,
      blockReason: j['block_reason'] != null
          ? SafetyBlockReason.values.byName(j['block_reason'] as String)
          : null,
    );
  }
}
