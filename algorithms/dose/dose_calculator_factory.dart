// lib/algorithms/dose/dose_calculator_factory.dart
// ─────────────────────────────────────────────────────────────────────────────
// DoseCalculatorFactory — assembles a configured [DoseCalculator] from a
// user profile, keeping DI simple and calculators stateless.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/algorithms/dose/standard_dose_calculator.dart';
import 'package:insulin_assistant/core/constants/app_constants.dart';
import 'package:insulin_assistant/domain/contracts/dose_calculator.dart';

abstract final class DoseCalculatorFactory {
  /// Creates a [DoseCalculator] configured for [step] and [appVersion].
  static DoseCalculator create({
    required DoseStep step,
    String? appVersion,
  }) =>
      StandardDoseCalculator(
        appVersion: appVersion ?? AppConstants.appVersion,
        doseStep: step,
      );

  /// Creates using the default dose step (0.5 U).
  static DoseCalculator createDefault() =>
      create(step: DoseStep.defaultStep);
}
