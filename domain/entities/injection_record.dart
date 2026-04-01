// lib/domain/entities/injection_record.dart
// ─────────────────────────────────────────────────────────────────────────────
// InjectionRecord entity — an administered (or pending) insulin dose.
//
// LIFECYCLE:
//   1. PENDING   — calculated dose, user has not yet confirmed injection
//   2. CONFIRMED — user confirmed injection via hold-to-confirm UI
//   3. CANCELLED — user dismissed before confirming
//   4. PARTIAL   — user administered a different dose than calculated
//                   (manually overridden)
//
// Each state transition is written to the audit log.
// Confirmed records are the only ones included in IOB calculations.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_duration.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

enum InjectionStatus { pending, confirmed, cancelled, partial }

enum InsulinType {
  rapidAnalogue, // NovoRapid, Humalog, Apidra
  shortActing, // Regular insulin
  intermediate, // NPH
  longActing, // Lantus, Tresiba — recorded but NOT used in bolus IOB
  other,
}

extension InsulinTypeX on InsulinType {
  String get nameAr => switch (this) {
        InsulinType.rapidAnalogue => 'سريع المفعول',
        InsulinType.shortActing => 'قصير المفعول',
        InsulinType.intermediate => 'متوسط المفعول',
        InsulinType.longActing => 'طويل المفعول',
        InsulinType.other => 'أخرى',
      };

  /// Whether this type contributes to active bolus IOB.
  bool get contributesToBolusIOB =>
      this == InsulinType.rapidAnalogue || this == InsulinType.shortActing;
}

/// Immutable record of a single insulin injection event.
final class InjectionRecord extends Equatable {
  const InjectionRecord({
    required this.id,
    required this.userId,
    required this.injectedAt,
    required this.doseUnits,
    required this.insulinType,
    required this.duration,
    required this.status,
    this.mealId,
    this.bgAtInjection,
    this.iobAtInjection,
    this.calculationTraceId,
    this.notes,
  });

  final String id;
  final String userId;
  final DateTime injectedAt;
  final InsulinUnits doseUnits;
  final InsulinType insulinType;
  final InsulinDuration duration;
  final InjectionStatus status;

  /// Associated meal — null for correction-only doses.
  final String? mealId;

  /// BG reading captured at time of injection (for audit).
  final BloodGlucose? bgAtInjection;

  /// IOB at time of injection (for audit).
  final InsulinUnits? iobAtInjection;

  /// Link to CalculationTrace for full audit trail.
  final String? calculationTraceId;
  final String? notes;

  // ── Business rules ────────────────────────────────────────────────────────

  /// Only confirmed rapid/short-acting injections contribute to IOB.
  bool get isActiveForIOB =>
      status == InjectionStatus.confirmed &&
      insulinType.contributesToBolusIOB;

  InjectionRecord confirm() => _copyWithStatus(InjectionStatus.confirmed);
  InjectionRecord cancel() => _copyWithStatus(InjectionStatus.cancelled);

  InjectionRecord confirmPartial(InsulinUnits actualDose) => InjectionRecord(
        id: id,
        userId: userId,
        injectedAt: injectedAt,
        doseUnits: actualDose,
        insulinType: insulinType,
        duration: duration,
        status: InjectionStatus.partial,
        mealId: mealId,
        bgAtInjection: bgAtInjection,
        iobAtInjection: iobAtInjection,
        calculationTraceId: calculationTraceId,
        notes: notes,
      );

  InjectionRecord _copyWithStatus(InjectionStatus s) => InjectionRecord(
        id: id,
        userId: userId,
        injectedAt: injectedAt,
        doseUnits: doseUnits,
        insulinType: insulinType,
        duration: duration,
        status: s,
        mealId: mealId,
        bgAtInjection: bgAtInjection,
        iobAtInjection: iobAtInjection,
        calculationTraceId: calculationTraceId,
        notes: notes,
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'injected_at': injectedAt.toIso8601String(),
        'dose_units': doseUnits.toJson(),
        'insulin_type': insulinType.name,
        'duration': duration.toJson(),
        'status': status.name,
        if (mealId != null) 'meal_id': mealId,
        if (bgAtInjection != null) 'bg_at_injection': bgAtInjection!.toJson(),
        if (iobAtInjection != null)
          'iob_at_injection': iobAtInjection!.toJson(),
        if (calculationTraceId != null) 'trace_id': calculationTraceId,
        if (notes != null) 'notes': notes,
      };

  @override
  List<Object?> get props => [id, userId, injectedAt, doseUnits, status];
}
