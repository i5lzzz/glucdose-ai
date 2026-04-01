// lib/ai/prediction/engines/tflite_prediction_engine.dart
// ─────────────────────────────────────────────────────────────────────────────
// TFLitePredictionEngine — Phase 2 ML-based glucose prediction stub.
//
// PHASE 2 DESIGN:
//   When a TFLite model is available, this class replaces [HybridPredictionEngine]
//   in the DI container without any change to callers.
//
// FEATURE VECTOR (9 inputs, must match TFLite model input tensor):
//   [0]  currentBGMgdl                      (normalised ÷ 400)
//   [1]  carbsGrams                          (normalised ÷ 200)
//   [2]  doseUnits                           (normalised ÷ 20)
//   [3]  iobUnits                            (normalised ÷ 20)
//   [4]  isfMgdlPerUnit                      (normalised ÷ 200)
//   [5]  icrGramsPerUnit                     (normalised ÷ 50)
//   [6]  minutesSinceInjection               (normalised ÷ 480)
//   [7]  carbAbsorptionHalfTimeMinutes       (normalised ÷ 180)
//   [8]  glucoseTrendMgdlPerMin              (normalised ÷ 3, clipped to [−1,1])
//
// OUTPUT TENSOR (3 outputs):
//   [0]  predicted BG at 30 min (mg/dL, denormalised × 400)
//   [1]  predicted BG at 60 min
//   [2]  predicted BG at 120 min
//
// SAFETY GUARANTEE:
//   Even with an ML model, predicted BGs are always:
//     1. Clamped to [20, 600] mg/dL physiological range
//     2. Passed through the same risk classifier and safety hooks
//     3. Accompanied by the deterministic hybrid prediction as a
//        secondary reference (dual-model validation)
//
// FALLBACK:
//   If model loading fails, the engine transparently falls back to
//   [HybridPredictionEngine].  Callers never know the difference.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/ai/prediction/core/prediction_engine.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_input.dart';
import 'package:insulin_assistant/ai/prediction/core/prediction_output.dart';
import 'package:insulin_assistant/ai/prediction/engines/hybrid_prediction_engine.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/core/result.dart';

/// Phase 2 TFLite-based glucose prediction engine.
///
/// STATUS: Stub — model file not yet trained. Falls back to HybridEngine.
/// To activate: supply a trained .tflite model at [tfliteModelPath] and
/// replace [_stub] with real tflite_flutter inference code.
final class TFLitePredictionEngine implements GlucosePredictionEngine {
  TFLitePredictionEngine({
    required this.tfliteModelPath,
    HybridPredictionEngine? fallback,
  }) : _fallback = fallback ?? const HybridPredictionEngine();

  final String tfliteModelPath;
  final HybridPredictionEngine _fallback;

  bool _modelLoaded = false;

  @override
  String get modelVersion => _modelLoaded
      ? 'tflite-regression-v1.0'
      : 'hybrid-deterministic-v1.0-fallback';

  @override
  bool get isDeterministic => !_modelLoaded;

  /// Attempts to load the TFLite model.  Call once at startup.
  Future<void> loadModel() async {
    // TODO Phase 2: Replace stub with:
    // _interpreter = await Interpreter.fromAsset(tfliteModelPath);
    // _modelLoaded = true;
    //
    // Feature normalisation constants must match training pipeline exactly.
    _modelLoaded = false; // Stub: always falls back
  }

  @override
  Future<Result<PredictionOutput>> predict(PredictionInput input) async {
    if (!_modelLoaded) {
      // Transparent fallback to deterministic model
      return _fallback.predict(input);
    }

    try {
      return _runInference(input);
    } catch (e) {
      // Any inference error → fallback (never crash on prediction)
      return _fallback.predict(input);
    }
  }

  // ── TFLite inference (Phase 2 implementation placeholder) ─────────────────

  Future<Result<PredictionOutput>> _runInference(PredictionInput input) async {
    // ── Feature vector construction ──────────────────────────────────────────
    final features = _buildFeatureVector(input);

    // TODO Phase 2 — replace with actual tflite_flutter calls:
    //
    // final inputTensor = [features];
    // final outputTensor = List.filled(3, 0.0);
    // _interpreter.run(inputTensor, [outputTensor]);
    //
    // final bg30 = (outputTensor[0] * 400.0).clamp(20.0, 600.0);
    // final bg60 = (outputTensor[1] * 400.0).clamp(20.0, 600.0);
    // final bg120= (outputTensor[2] * 400.0).clamp(20.0, 600.0);
    //
    // Then wrap in PredictionOutput using the same risk classifier and
    // explainability structures as HybridPredictionEngine.

    return Result.failure(
      const ModelLoadFailure('TFLite model not yet trained — stub only'),
    );
  }

  // ── Feature engineering ───────────────────────────────────────────────────

  /// Builds the 9-element normalised feature vector for the TFLite model.
  ///
  /// NORMALISATION MUST match the training pipeline exactly.
  /// All features are normalised to [0, 1] range using domain-knowledge bounds.
  List<double> _buildFeatureVector(PredictionInput input) {
    return [
      _norm(input.currentBGMgdl, 20.0, 400.0),
      _norm(input.carbsGrams, 0.0, 200.0),
      _norm(input.doseU, 0.0, 20.0),
      _norm(input.iobU, 0.0, 20.0),
      _norm(input.isfMgdlPerUnit, 5.0, 200.0),
      _norm(input.icrGramsPerUnit, 3.0, 50.0),
      _norm(input.minutesSinceInjection, 0.0, 480.0),
      _norm(input.carbAbsorptionHalfTimeMinutes, 20.0, 180.0),
      input.glucoseTrendMgdlPerMin.clamp(-1.0, 1.0), // trend already normalised by range
    ];
  }

  /// Min-max normalisation to [0, 1].
  double _norm(double value, double min, double max) =>
      ((value - min) / (max - min)).clamp(0.0, 1.0);

  // ── Feature schema (for training pipeline documentation) ─────────────────

  /// Returns the feature schema as a JSON-serialisable map.
  /// Used to document the training pipeline and validate model compatibility.
  static Map<String, dynamic> featureSchema() => {
        'version': '1.0',
        'n_features': 9,
        'features': [
          {'index': 0, 'name': 'current_bg_mgdl', 'min': 20, 'max': 400},
          {'index': 1, 'name': 'carbs_grams', 'min': 0, 'max': 200},
          {'index': 2, 'name': 'dose_units', 'min': 0, 'max': 20},
          {'index': 3, 'name': 'iob_units', 'min': 0, 'max': 20},
          {'index': 4, 'name': 'isf_mgdl_per_unit', 'min': 5, 'max': 200},
          {'index': 5, 'name': 'icr_grams_per_unit', 'min': 3, 'max': 50},
          {'index': 6, 'name': 'minutes_since_injection', 'min': 0, 'max': 480},
          {'index': 7, 'name': 'carb_absorption_half_time', 'min': 20, 'max': 180},
          {'index': 8, 'name': 'glucose_trend_mgdl_per_min', 'min': -1, 'max': 1},
        ],
        'outputs': [
          {'index': 0, 'name': 'predicted_bg_30min_mgdl'},
          {'index': 1, 'name': 'predicted_bg_60min_mgdl'},
          {'index': 2, 'name': 'predicted_bg_120min_mgdl'},
        ],
        'normalisation': 'min_max',
        'output_denorm_factor': 400.0,
      };
}
