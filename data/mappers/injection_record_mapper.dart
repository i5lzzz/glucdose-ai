// lib/data/mappers/injection_record_mapper.dart

import 'package:insulin_assistant/data/mappers/encryption_mapper.dart';
import 'package:insulin_assistant/data/models/injection_record_dto.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_duration.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/core/result.dart';

final class InjectionRecordMapper {
  const InjectionRecordMapper(this._enc);

  final EncryptionMapper _enc;

  // ── Domain → DTO (for storage) ────────────────────────────────────────────

  Future<InjectionRecordDTO> toDTO(InjectionRecord entity) async {
    return InjectionRecordDTO(
      id: entity.id,
      userId: entity.userId,
      injectedAt: entity.injectedAt.toUtc().toIso8601String(),
      doseUnitsEnc: await _enc.encryptDouble(entity.doseUnits.units),
      insulinTypeEnc: await _enc.encryptString(entity.insulinType.name),
      durationMinutes: entity.duration.minutes,
      status: entity.status.name,
      confirmed: entity.status == InjectionStatus.confirmed ? 1 : 0,
      mealId: entity.mealId,
      bgAtInjectionEnc: entity.bgAtInjection != null
          ? await _enc.encryptDouble(entity.bgAtInjection!.mgdl)
          : null,
      iobAtInjectionEnc: entity.iobAtInjection != null
          ? await _enc.encryptDouble(entity.iobAtInjection!.units)
          : null,
      calculationTraceIdEnc: entity.calculationTraceId != null
          ? await _enc.encryptString(entity.calculationTraceId!)
          : null,
      notesEnc: entity.notes != null
          ? await _enc.encryptString(entity.notes!)
          : null,
    );
  }

  // ── DTO → Domain (on retrieval) ───────────────────────────────────────────

  Future<Result<InjectionRecord>> toDomain(InjectionRecordDTO dto) async {
    try {
      final doseUnits = await _enc.decryptDouble(dto.doseUnitsEnc);
      final insulinTypeName = await _enc.decryptString(dto.insulinTypeEnc);

      final doseResult = InsulinUnits.fromUnits(doseUnits);
      if (doseResult.isFailure) return Result.failure(doseResult.failure);

      final durationResult = InsulinDuration.fromMinutes(dto.durationMinutes);
      if (durationResult.isFailure) {
        return Result.failure(durationResult.failure);
      }

      final insulinType = InsulinType.values.byName(insulinTypeName);
      final status = InjectionStatus.values.byName(dto.status);

      // Optional encrypted fields
      BloodGlucose? bgAtInjection;
      if (dto.bgAtInjectionEnc != null) {
        final bgVal = await _enc.decryptDouble(dto.bgAtInjectionEnc!);
        final bgResult = BloodGlucose.fromMgdl(bgVal);
        if (bgResult.isSuccess) bgAtInjection = bgResult.value;
      }

      InsulinUnits? iobAtInjection;
      if (dto.iobAtInjectionEnc != null) {
        final iobVal = await _enc.decryptDouble(dto.iobAtInjectionEnc!);
        final iobResult = InsulinUnits.fromUnitsUnclamped(iobVal);
        if (iobResult.isSuccess) iobAtInjection = iobResult.value;
      }

      final traceId = dto.calculationTraceIdEnc != null
          ? await _enc.decryptOptionalString(dto.calculationTraceIdEnc)
          : null;
      final notes = dto.notesEnc != null
          ? await _enc.decryptOptionalString(dto.notesEnc)
          : null;

      return Result.success(
        InjectionRecord(
          id: dto.id,
          userId: dto.userId,
          injectedAt: DateTime.parse(dto.injectedAt),
          doseUnits: doseResult.value,
          insulinType: insulinType,
          duration: durationResult.value,
          status: status,
          mealId: dto.mealId,
          bgAtInjection: bgAtInjection,
          iobAtInjection: iobAtInjection,
          calculationTraceId: traceId,
          notes: notes,
        ),
      );
    } catch (e) {
      return Result.failure(
        DatabaseFailure('InjectionRecord decryption failed for id=${dto.id}: $e'),
      );
    }
  }
}
