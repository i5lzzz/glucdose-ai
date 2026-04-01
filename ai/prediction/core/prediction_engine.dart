// lib/ai/prediction/core/prediction_engine.dart
// ─────────────────────────────────────────────────────────────────────────────
// GlucosePredictionEngine — domain contract for the prediction layer.
//
// INTERFACE DESIGN:
//   The same interface is implemented by:
//     Phase 1: [HybridPredictionEngine]   — deterministic pharmacokinetics
//     Phase 2: [TFLitePredictionEngine]   — on-device ML regression model
//
//   Callers depend only on this interface, never on a concrete class.
//   Swapping from Phase 1 to Phase 2 requires changing only the DI
//   registration — no use-case or UI code changes.
//
// PURE FUNCTION CONTRACT:
//   predict(input) must:
//     • always return Result (never throw)
//     • be deterministic: same input → same output
//     • have no side effects (no DB writes, no network calls)
//     • complete synchronously or asynchronously as declared
//
// VERSIONING:
//   [modelVersion] is embedded in every [PredictionOutput] so that a clinical
//   reviewer can know which model produced a historical prediction.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/ai/prediction/core/prediction_input.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_output.dart';
import 'package:insulin_assistant/domain/core/result.dart';

/// Abstract prediction engine contract.
abstract interface class GlucosePredictionEngine {
  /// Human-readable model identifier embedded in [PredictionOutput].
  String get modelVersion;

  /// Whether this engine uses a deterministic model (true) or ML (false).
  bool get isDeterministic;

  /// Predicts BG at 30, 60, and 120 minutes from [input].
  ///
  /// PURE — no side effects, no exceptions.  Returns [Result.failure] on error.
  Future<Result<PredictionOutput>> predict(PredictionInput input);
}
