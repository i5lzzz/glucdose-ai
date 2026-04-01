// lib/domain/contracts/iob_calculator.dart
// ─────────────────────────────────────────────────────────────────────────────
// IOBCalculator — domain-level interface contract.
//
// IOB = Insulin On Board = total remaining active insulin from all previous
//   bolus injections at a given point in time.
//
// CONTRACT:
//   calculateIOB() is PURE and DETERMINISTIC given the same injections
//   and the same clock value.  The Clock abstraction is passed in — not
//   accessed via DateTime.now() — ensuring testability.
//
// WALSH BILINEAR MODEL:
//   The production implementation must use the Walsh bilinear model, not
//   a linear decay.  The interface does not mandate this — but the
//   concrete class is tested against the Walsh equations.
//   See: Walsh J et al. (2011) "Using technology to minimize medication
//        error" — Table 3, bilinear IOB model.
//
// STACKING DETECTION:
//   calculateTotalActiveInsulin() returns the summed IOB across ALL
//   recent injections, which is compared to the stacking threshold.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/domain/core/clock.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

/// Contract for the Insulin on Board (IOB) calculation engine.
abstract interface class IOBCalculator {
  /// Calculates the remaining IOB from [injection] at the time reported by
  /// [clock].
  ///
  /// Returns [InsulinUnits.zero] if:
  ///   • The injection is not confirmed
  ///   • The elapsed time exceeds the injection's duration of action
  ///   • The injection type does not contribute to bolus IOB
  ///
  /// PURE FUNCTION — no side effects.
  Result<InsulinUnits> calculateSingleIOB({
    required InjectionRecord injection,
    required Clock clock,
  });

  /// Sums IOB across [injections], returning total active insulin.
  ///
  /// Only injections where [isActiveForIOB] is true are included.
  /// Calls [calculateSingleIOB] for each eligible injection and sums.
  ///
  /// PURE FUNCTION — no side effects.
  Result<InsulinUnits> calculateTotalIOB({
    required List<InjectionRecord> injections,
    required Clock clock,
  });

  /// Returns the per-injection IOB breakdown for transparency.
  /// Used to populate the "Active Insulin" detail view.
  Result<List<IOBBreakdownItem>> calculateIOBBreakdown({
    required List<InjectionRecord> injections,
    required Clock clock,
  });

  /// Name of the decay model implemented (e.g., "Walsh Bilinear v1").
  String get modelName;
}

/// Single injection's contribution to total IOB.
final class IOBBreakdownItem {
  const IOBBreakdownItem({
    required this.injectionId,
    required this.injectedAt,
    required this.originalDose,
    required this.remainingIOB,
    required this.percentRemaining,
    required this.minutesElapsed,
  });

  final String injectionId;
  final DateTime injectedAt;
  final InsulinUnits originalDose;
  final InsulinUnits remainingIOB;
  final double percentRemaining; // 0.0 – 1.0
  final double minutesElapsed;
}
