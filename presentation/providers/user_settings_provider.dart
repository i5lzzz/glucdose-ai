// lib/presentation/providers/user_settings_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/core/unit_system.dart';

class UserSettings {
  const UserSettings({
    this.unitSystem = const UnitSystem.mgdl(),
    this.doseStep = DoseStep.half,
    this.icr = MedicalConstants.defaultICR,
    this.isf = MedicalConstants.defaultISF,
    this.targetBG = MedicalConstants.bgDefaultTarget,
    this.maxDose = MedicalConstants.defaultUserMaxDoseUnits,
    this.insulinDurationMinutes = MedicalConstants.defaultInsulinDurationMinutes,
    this.locale = 'ar',
    this.displayName = '',
  });

  final UnitSystem unitSystem;
  final DoseStep doseStep;
  final double icr;
  final double isf;
  final double targetBG;
  final double maxDose;
  final double insulinDurationMinutes;
  final String locale;
  final String displayName;

  bool get isArabic => locale == 'ar';

  UserSettings copyWith({
    UnitSystem? unitSystem,
    DoseStep? doseStep,
    double? icr,
    double? isf,
    double? targetBG,
    double? maxDose,
    double? insulinDurationMinutes,
    String? locale,
    String? displayName,
  }) =>
      UserSettings(
        unitSystem: unitSystem ?? this.unitSystem,
        doseStep: doseStep ?? this.doseStep,
        icr: icr ?? this.icr,
        isf: isf ?? this.isf,
        targetBG: targetBG ?? this.targetBG,
        maxDose: maxDose ?? this.maxDose,
        insulinDurationMinutes: insulinDurationMinutes ?? this.insulinDurationMinutes,
        locale: locale ?? this.locale,
        displayName: displayName ?? this.displayName,
      );
}

final userSettingsProvider = StateProvider<UserSettings>((ref) => const UserSettings());
