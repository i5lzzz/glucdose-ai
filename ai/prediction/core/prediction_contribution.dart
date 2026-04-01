// lib/ai/prediction/core/prediction_contribution.dart
// ─────────────────────────────────────────────────────────────────────────────
// PredictionContribution — explainability record for one prediction horizon.
//
// MEDICAL EXPLAINABILITY REQUIREMENT:
//   FDA SaMD guidance and ISO 14971 both require that a SaMD producing a
//   clinical recommendation be explainable to the patient and clinician.
//   For glucose prediction, this means:
//     "Your predicted BG of 145 mg/dL in 60 min is composed of:
//      current 150 mg/dL
//      + 45 mg/dL from 60g carbohydrates (46% absorbed at 60 min)
//      − 52 mg/dL from 7 U dose (63% active at 60 min)
//      − 3 mg/dL from IOB (0.3 U residual)
//      + 5 mg/dL trend adjustment (↑ trend)"
//
// Each [PredictionContribution] records exactly these values for one horizon.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Signed contribution of each component to the predicted BG delta.
///
/// SIGN CONVENTION:
///   Positive → raises BG (carbs, rising trend, baseline)
///   Negative → lowers BG (insulin, IOB, falling trend)
final class PredictionContribution extends Equatable {
  const PredictionContribution({
    required this.horizonMinutes,
    required this.baselineMgdl,
    required this.carbContributionMgdl,
    required this.insulinContributionMgdl,
    required this.iobContributionMgdl,
    required this.trendContributionMgdl,
    required this.carbFractionAbsorbed,
    required this.insulinFractionActive,
    required this.iobFractionActive,
    required this.predictedBGMgdl,
  });

  final int horizonMinutes;

  /// Current BG — the starting point (always positive).
  final double baselineMgdl;

  /// BG change attributable to carbohydrate absorption (positive).
  final double carbContributionMgdl;

  /// BG change attributable to the new dose insulin activity (negative).
  final double insulinContributionMgdl;

  /// BG change attributable to residual IOB activity (negative).
  final double iobContributionMgdl;

  /// BG change from extrapolated CGM/manual trend (signed).
  final double trendContributionMgdl;

  /// Fraction of carbs absorbed at [horizonMinutes] (0.0–1.0).
  final double carbFractionAbsorbed;

  /// Fraction of new dose still active at [horizonMinutes] (0.0–1.0).
  final double insulinFractionActive;

  /// Fraction of IOB still active at [horizonMinutes] (0.0–1.0).
  final double iobFractionActive;

  /// Final predicted BG (clamped to physiological range).
  final double predictedBGMgdl;

  // ── Derived ───────────────────────────────────────────────────────────────

  /// Net change from baseline (signed sum of all components).
  double get netDeltaMgdl =>
      carbContributionMgdl +
      insulinContributionMgdl +
      iobContributionMgdl +
      trendContributionMgdl;

  /// Dominant driver of BG change at this horizon.
  PredictionDriver get dominantDriver {
    final abs = {
      PredictionDriver.carbs: carbContributionMgdl.abs(),
      PredictionDriver.insulin: insulinContributionMgdl.abs(),
      PredictionDriver.iob: iobContributionMgdl.abs(),
      PredictionDriver.trend: trendContributionMgdl.abs(),
    };
    return abs.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ── Human-readable explanation ────────────────────────────────────────────

  String get explanationAr {
    final sb = StringBuffer();
    sb.writeln('التوقع عند ${horizonMinutes} دقيقة: '
        '${predictedBGMgdl.toStringAsFixed(0)} مغ/دل');
    sb.writeln('  • الأساس: ${baselineMgdl.toStringAsFixed(0)} مغ/دل');
    if (carbContributionMgdl.abs() > 0.5) {
      sb.writeln(
        '  • الكربوهيدرات: +${carbContributionMgdl.toStringAsFixed(1)} مغ/دل'
        ' (${(carbFractionAbsorbed * 100).toStringAsFixed(0)}٪ امتُصَّ)',
      );
    }
    if (insulinContributionMgdl.abs() > 0.5) {
      sb.writeln(
        '  • الأنسولين الجديد: '
        '${insulinContributionMgdl.toStringAsFixed(1)} مغ/دل'
        ' (${(insulinFractionActive * 100).toStringAsFixed(0)}٪ فعّال)',
      );
    }
    if (iobContributionMgdl.abs() > 0.5) {
      sb.writeln(
        '  • الأنسولين الفعّال: '
        '${iobContributionMgdl.toStringAsFixed(1)} مغ/دل'
        ' (${(iobFractionActive * 100).toStringAsFixed(0)}٪ متبقٍّ)',
      );
    }
    if (trendContributionMgdl.abs() > 0.5) {
      final sign = trendContributionMgdl > 0 ? '+' : '';
      sb.writeln('  • الاتجاه: $sign${trendContributionMgdl.toStringAsFixed(1)} مغ/دل');
    }
    return sb.toString().trim();
  }

  String get explanationEn {
    final sb = StringBuffer();
    sb.writeln('Prediction at ${horizonMinutes} min: '
        '${predictedBGMgdl.toStringAsFixed(0)} mg/dL');
    sb.writeln('  • Baseline: ${baselineMgdl.toStringAsFixed(0)} mg/dL');
    if (carbContributionMgdl.abs() > 0.5) {
      sb.writeln(
        '  • Carbs: +${carbContributionMgdl.toStringAsFixed(1)} mg/dL'
        ' (${(carbFractionAbsorbed * 100).toStringAsFixed(0)}% absorbed)',
      );
    }
    if (insulinContributionMgdl.abs() > 0.5) {
      sb.writeln(
        '  • New dose: ${insulinContributionMgdl.toStringAsFixed(1)} mg/dL'
        ' (${(insulinFractionActive * 100).toStringAsFixed(0)}% active)',
      );
    }
    if (iobContributionMgdl.abs() > 0.5) {
      sb.writeln(
        '  • IOB: ${iobContributionMgdl.toStringAsFixed(1)} mg/dL'
        ' (${(iobFractionActive * 100).toStringAsFixed(0)}% remaining)',
      );
    }
    if (trendContributionMgdl.abs() > 0.5) {
      final sign = trendContributionMgdl > 0 ? '+' : '';
      sb.writeln('  • Trend: $sign${trendContributionMgdl.toStringAsFixed(1)} mg/dL');
    }
    return sb.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'horizon_min': horizonMinutes,
        'baseline_mgdl': baselineMgdl,
        'carb_contribution': carbContributionMgdl,
        'insulin_contribution': insulinContributionMgdl,
        'iob_contribution': iobContributionMgdl,
        'trend_contribution': trendContributionMgdl,
        'carb_fraction_absorbed': carbFractionAbsorbed,
        'insulin_fraction_active': insulinFractionActive,
        'iob_fraction_active': iobFractionActive,
        'predicted_bg_mgdl': predictedBGMgdl,
        'net_delta': netDeltaMgdl,
        'dominant_driver': dominantDriver.name,
      };

  @override
  List<Object?> get props => [horizonMinutes, predictedBGMgdl, netDeltaMgdl];
}

/// The component that has the largest absolute impact on BG at a horizon.
enum PredictionDriver {
  carbs,
  insulin,
  iob,
  trend;

  String get nameAr => switch (this) {
        PredictionDriver.carbs => 'الكربوهيدرات',
        PredictionDriver.insulin => 'الأنسولين',
        PredictionDriver.iob => 'الأنسولين الفعّال',
        PredictionDriver.trend => 'الاتجاه',
      };
}
