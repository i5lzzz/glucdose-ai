// test/helpers/test_factories.dart
// ─────────────────────────────────────────────────────────────────────────────
// Shared test factories.
// Central source of truth for test data — prevents each test file from
// duplicating construction logic and ensures consistency across suites.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/algorithms/dose/standard_dose_calculator.dart';
import 'package:insulin_assistant/domain/core/clock.dart';
import 'package:insulin_assistant/domain/core/unit_system.dart';
import 'package:insulin_assistant/domain/entities/calculation_trace.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';
import 'package:insulin_assistant/domain/entities/user_profile.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/carb_ratio.dart';
import 'package:insulin_assistant/domain/value_objects/carbohydrates.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_duration.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_sensitivity_factor.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

abstract final class TestFactories {
  // ── Fixed test epoch ──────────────────────────────────────────────────────
  static final DateTime epoch = DateTime.utc(2024, 6, 1, 12, 0, 0);

  // ── Value Objects ─────────────────────────────────────────────────────────

  static BloodGlucose bg(double mgdl) =>
      BloodGlucose.fromMgdl(mgdl).value;

  static InsulinUnits dose(double u) =>
      InsulinUnits.fromUnits(u).value;

  static InsulinUnits iob(double u) =>
      InsulinUnits.fromUnitsUnclamped(u).value;

  static Carbohydrates carbs(double g) =>
      Carbohydrates.fromGrams(g).value;

  static CarbRatio icr(double g) =>
      CarbRatio.fromGramsPerUnit(g).value;

  static InsulinSensitivityFactor isf(double v) =>
      InsulinSensitivityFactor.fromMgdlPerUnit(v).value;

  // ── Domain objects ────────────────────────────────────────────────────────

  static UserProfile profile({
    double icrVal = 10.0,
    double isfVal = 50.0,
    double targetBG = 100.0,
    double maxDose = 10.0,
    bool complete = true,
  }) {
    return UserProfile(
      id: 'test-user',
      createdAt: epoch,
      updatedAt: epoch,
      displayName: complete ? 'Test User' : '',
      diabetesType: DiabetesType.type2,
      carbRatio: icr(icrVal),
      sensitivityFactor: isf(isfVal),
      targetBloodGlucose: bg(targetBG),
      maxDoseUnits: dose(maxDose),
      insulinDuration: InsulinDuration.fourHours,
      unitSystem: const UnitSystem.mgdl(),
    );
  }

  static DoseCalculationInput calcInput({
    double bgVal = 150,
    double carbsG = 60,
    double iobU = 0.0,
    double icrVal = 10.0,
    double isfVal = 50.0,
    double targetBG = 100.0,
    double userMax = 10.0,
    DateTime? timestamp,
  }) =>
      DoseCalculationInput(
        currentBG: bg(bgVal),
        carbohydrates: carbs(carbsG),
        iob: iob(iobU),
        carbRatio: icr(icrVal),
        sensitivityFactor: isf(isfVal),
        targetBG: bg(targetBG),
        userMaxDose: dose(userMax),
        timestampUtc: timestamp ?? epoch,
      );

  static CalculationTrace trace({
    double bgVal = 150,
    double carbsG = 60,
    double iobU = 0.0,
    DoseStep step = DoseStep.half,
    String appVersion = '1.0.0-test',
  }) {
    final calc = StandardDoseCalculator(
      appVersion: appVersion,
      doseStep: step,
    );
    return calc.calculate(calcInput(bgVal: bgVal, carbsG: carbsG, iobU: iobU)).value;
  }

  static InjectionRecord injection({
    String id = 'inj-001',
    String userId = 'user-001',
    DateTime? injectedAt,
    double doseU = 4.0,
    double durationMin = 240.0,
    InjectionStatus status = InjectionStatus.confirmed,
    InsulinType type = InsulinType.rapidAnalogue,
  }) =>
      InjectionRecord(
        id: id,
        userId: userId,
        injectedAt: injectedAt ?? epoch,
        doseUnits: dose(doseU),
        insulinType: type,
        duration: InsulinDuration.fromMinutes(durationMin).value,
        status: status,
      );

  /// Clock fixed at [epoch] — no time passes unless explicitly advanced.
  static FakeClock clock([DateTime? at]) => FakeClock(at ?? epoch);

  /// Clock positioned [minutesAfterEpoch] ahead of epoch.
  static FakeClock clockAt(double minutesAfterEpoch) =>
      FakeClock(epoch.add(Duration(
        seconds: (minutesAfterEpoch * 60).round(),
      )));
}
