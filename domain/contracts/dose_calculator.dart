// lib/domain/contracts/dose_calculator.dart
// ─────────────────────────────────────────────────────────────────────────────
// DoseCalculator — domain-level interface contract.
//
// DESIGN:
//   This interface is the ONLY entry point for dose calculation in the domain.
//   All callers (use-cases, tests) depend on this abstraction — never on a
//   concrete implementation.  This enables:
//     1. Swapping Walsh bilinear for a newer model without touching callers.
//     2. Testing the safety engine against a mock calculator.
//     3. Running regression tests on historical traces.
//
// CONTRACT:
//   calculate() is PURE and DETERMINISTIC:
//     • same inputs → same outputs, always
//     • no side effects (no DB writes, no logging inside the calculator)
//     • returns Result — never throws
//
// EXPLAINABILITY:
//   The returned CalculationTrace contains every intermediate step, satisfying
//   the FDA requirement for SaMD to be explainable to clinical reviewers.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/entities/calculation_trace.dart';

/// Contract for the insulin dose calculation engine.
abstract interface class DoseCalculator {
  /// Calculates an insulin dose given [input].
  ///
  /// Returns a [CalculationTrace] containing the final dose, breakdown steps,
  /// safety flags, and all input values for the audit trail.
  ///
  /// NEVER throws.  All errors are encoded in [Result.failure].
  ///
  /// PURE FUNCTION — no side effects.
  Result<CalculationTrace> calculate(DoseCalculationInput input);

  /// The semver of the algorithm this calculator implements.
  /// Changing any calculation constant or formula bumps this.
  String get algorithmVersion;
}
