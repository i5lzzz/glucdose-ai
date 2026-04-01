// lib/domain/value_objects/blood_glucose.dart
// ─────────────────────────────────────────────────────────────────────────────
// BloodGlucose value object.
//
// INVARIANTS (always enforced — no instance exists outside these bounds):
//   • value is finite
//   • value is in physiologically plausible range:
//       min: 20 mg/dL  (below this, glucometer error is assumed)
//       max: 600 mg/dL (above this, DKA / HHS protocol — out of app scope)
//   • internal storage is ALWAYS mg/dL (unit normalisation on construction)
//
// CONSTRUCTION:
//   BloodGlucose.fromMgdl(120.0)           → Result<BloodGlucose>
//   BloodGlucose.fromMmol(6.7)             → Result<BloodGlucose>
//   BloodGlucose.fromValue(6.7, GlucoseUnit.mmolL) → Result<BloodGlucose>
//
// The private constructor prevents any invalid instance from being created
// by any call site — even in tests.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/core/unit_system.dart';
import 'package:insulin_assistant/domain/core/value_object.dart';

/// Physiologically safe blood glucose value, always stored in mg/dL.
final class BloodGlucose extends ValueObject<double> {
  // ── Private constructor — only reachable after validation ──────────────────
  const BloodGlucose._(super.value);

  // ── Physiological bounds ─────────────────────────────────────────────────
  static const double _minMgdl = 20.0;
  static const double _maxMgdl = 600.0;

  // ── Named constructors (all return Result) ────────────────────────────────

  /// Construct from mg/dL value.
  static Result<BloodGlucose> fromMgdl(double mgdl) {
    return ValueObject.validate(() {
      assertRange(mgdl, min: _minMgdl, max: _maxMgdl, field: 'blood_glucose');
      return BloodGlucose._(mgdl);
    });
  }

  /// Construct from mmol/L value (converted internally to mg/dL).
  static Result<BloodGlucose> fromMmol(double mmol) {
    assertRange(
      mmol,
      min: GlucoseUnitConverter.toMmol(_minMgdl),
      max: GlucoseUnitConverter.toMmol(_maxMgdl),
      field: 'blood_glucose',
    );
    return fromMgdl(GlucoseUnitConverter.toMgdl(mmol));
  }

  /// Construct from value + explicit unit.
  static Result<BloodGlucose> fromValue(
    double value,
    GlucoseUnit unit,
  ) =>
      switch (unit) {
        GlucoseUnit.mgdl => fromMgdl(value),
        GlucoseUnit.mmolL => fromMmol(value),
      };

  // ── Accessors ─────────────────────────────────────────────────────────────

  /// Internal value in mg/dL.
  double get mgdl => value;

  /// Value converted to mmol/L (for display only).
  double get mmol => GlucoseUnitConverter.toMmol(value);

  /// Returns display value in [unit].
  double inUnit(GlucoseUnit unit) =>
      GlucoseUnitConverter.fromMgdl(value, unit);

  // ── Clinical classifiers ──────────────────────────────────────────────────

  bool get isLevel2Hypo => value < MedicalConstants.bgLevel2HypoHardBlock;
  bool get isLevel1Hypo => value < MedicalConstants.bgLevel1HypoWarn;
  bool get isHypo => value < MedicalConstants.bgLevel1HypoWarn;
  bool get isInRange =>
      value >= MedicalConstants.bgTargetLow &&
      value <= MedicalConstants.bgTargetHigh;
  bool get isHyper => value > MedicalConstants.bgHyperAlertThreshold;
  bool get isSevereHyper => value > MedicalConstants.bgSevereHyperThreshold;

  /// Clinical classification label.
  BloodGlucoseClassification get classification {
    if (isLevel2Hypo) return BloodGlucoseClassification.level2Hypo;
    if (isLevel1Hypo) return BloodGlucoseClassification.level1Hypo;
    if (isInRange) return BloodGlucoseClassification.inRange;
    if (value <= 180) return BloodGlucoseClassification.mildHyper;
    if (isHyper) return BloodGlucoseClassification.hyper;
    return BloodGlucoseClassification.severeHyper;
  }

  // ── Arithmetic (returns new validated instances) ───────────────────────────

  /// Adds [delta] mg/dL.  The result may fall outside valid range — returns
  /// Result to force the caller to handle out-of-range predictions.
  Result<BloodGlucose> addDelta(double deltaMgdl) =>
      fromMgdl(value + deltaMgdl);

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'value_mgdl': value,
        'classification': classification.name,
      };

  factory BloodGlucose.fromJson(Map<String, dynamic> json) {
    final r = fromMgdl((json['value_mgdl'] as num).toDouble());
    if (r.isFailure) throw r.failure;
    return r.value;
  }

  @override
  String toString() => 'BloodGlucose(${value.toStringAsFixed(0)} mg/dL)';
}

/// Clinical classification of a blood glucose reading.
enum BloodGlucoseClassification {
  level2Hypo,
  level1Hypo,
  inRange,
  mildHyper,
  hyper,
  severeHyper;

  bool get isSafe => this == inRange;
  bool get isAnyHypo =>
      this == level1Hypo || this == level2Hypo;
  bool get isAnyHyper =>
      this == hyper || this == severeHyper || this == mildHyper;
}
