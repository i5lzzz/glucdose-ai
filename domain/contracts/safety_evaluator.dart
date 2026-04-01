// lib/domain/contracts/safety_evaluator.dart
// ─────────────────────────────────────────────────────────────────────────────
// SafetyEvaluator — domain-level interface contract.
//
// THE MOST CRITICAL INTERFACE IN THE SYSTEM.
//
// Every dose calculation result passes through the SafetyEvaluator before
// being shown to the user.  The evaluator is:
//   1. The LAST LINE OF DEFENCE before a dose recommendation reaches the user.
//   2. Independently testable — pure function, no side effects.
//   3. Versioned — changes to safety rules require version bump + audit entry.
//
// CONTRACT:
//   evaluate() returns SafetyEvaluation — never throws.
//   It operates on the OUTPUT of a dose calculation (CalculationTrace) and
//   performs additional checks that the calculator itself doesn't know about:
//     • User's personal ceiling
//     • IOB stacking threshold
//     • Current BG hypoglycaemia check (independent of the calculation)
//     • Prediction-based pre-emption (if prediction engine is available)
//
// BLOCKING vs WARN:
//   BLOCK  — dose recommendation is suppressed entirely; user cannot proceed
//   WARN   — dose recommendation is shown with a mandatory warning banner;
//             user must acknowledge before seeing the dose
//
// OVERRIDE:
//   Level 1 hypo and IOB stacking WARN blocks may be overridden by the user
//   after acknowledging the specific risk.  Level 2 hypo is NEVER overrideable.
//
// RULE: No UI code evaluates safety conditions independently.
//       ALL safety logic lives here.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/entities/calculation_trace.dart';
import 'package:insulin_assistant/domain/entities/user_profile.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

// ── Safety evaluation result ─────────────────────────────────────────────────

/// The complete safety assessment of a dose recommendation.
final class SafetyEvaluation {
  const SafetyEvaluation({
    required this.trace,
    required this.decision,
    required this.flags,
    required this.isOverrideable,
    required this.evaluatorVersion,
  });

  /// The trace being evaluated.
  final CalculationTrace trace;

  /// Final safety decision.
  final SafetyDecision decision;

  /// All flags raised during evaluation (may be empty).
  final List<SafetyFlag> flags;

  /// Whether the user may override this block (e.g., Level 1 hypo).
  /// Always false for Level 2 hypo.
  final bool isOverrideable;

  /// Version of the safety evaluator that produced this result.
  final String evaluatorVersion;

  // ── Convenience getters ───────────────────────────────────────────────────

  bool get isApproved => decision == SafetyDecision.approved;
  bool get isWarned => decision == SafetyDecision.warnRequired;
  bool get isBlocked => decision == SafetyDecision.hardBlocked;

  /// The approved dose (clamped, safety-adjusted).
  /// Null if [isBlocked].
  InsulinUnits? get approvedDose =>
      isBlocked ? null : trace.output.clampedDose;

  /// The primary blocking reason (null if approved).
  SafetyBlockReason? get primaryBlockReason =>
      flags.where((f) => f.wasBlocking).map((f) => f.reason).firstOrNull;

  /// All raised flag reasons.
  List<SafetyBlockReason> get allFlagReasons =>
      flags.map((f) => f.reason).toList();
}

/// The safety system's verdict on a dose recommendation.
enum SafetyDecision {
  /// Dose is safe to administer — no flags raised.
  approved,

  /// One or more warning-level flags — must be acknowledged before proceeding.
  warnRequired,

  /// Calculation is blocked — dose must NOT be administered.
  hardBlocked,
}

// ── Pre-calculation safety check ─────────────────────────────────────────────

/// Result of a pre-calculation safety screen (before the calculation runs).
final class PreCalculationCheck {
  const PreCalculationCheck({
    required this.canProceed,
    this.blockReason,
    this.warningReasons = const [],
  });

  final bool canProceed;
  final SafetyBlockReason? blockReason;
  final List<SafetyBlockReason> warningReasons;

  bool get hasWarnings => warningReasons.isNotEmpty;
}

// ── Interface ─────────────────────────────────────────────────────────────────

/// Contract for the safety evaluation engine.
abstract interface class SafetyEvaluator {
  /// Pre-calculation screen: can we even start calculating?
  ///
  /// Called BEFORE [DoseCalculator.calculate()] to catch hard-block
  /// conditions early (e.g., BG < 40) without wasting computation.
  ///
  /// PURE FUNCTION — no side effects.
  PreCalculationCheck preCheck({
    required BloodGlucose currentBG,
    required UserProfile profile,
    required InsulinUnits currentIOB,
  });

  /// Post-calculation evaluation of a completed [CalculationTrace].
  ///
  /// Applies all safety rules to the trace and returns a [SafetyEvaluation]
  /// with the final [SafetyDecision].
  ///
  /// PURE FUNCTION — no side effects.
  SafetyEvaluation evaluate({
    required CalculationTrace trace,
    required UserProfile profile,
    required BloodGlucose currentBG,
    required InsulinUnits currentIOB,
  });

  /// Version string for the rules set this evaluator implements.
  String get evaluatorVersion;
}
