// lib/ai/prediction/core/prediction_horizons.dart
// ─────────────────────────────────────────────────────────────────────────────
// PredictionHorizon — typed representation of the three forecast windows.
//
// Using an enum (not bare ints) ensures callers cannot accidentally pass
// an arbitrary minute value where a clinical horizon is expected.
// ─────────────────────────────────────────────────────────────────────────────

/// The three clinical glucose prediction horizons.
enum PredictionHorizon {
  /// 30 minutes — covers the immediate post-bolus glucose nadir risk.
  thirtyMin(minutes: 30, labelAr: '٣٠ دقيقة', labelEn: '30 min'),

  /// 60 minutes — peak carb absorption for medium-GI foods.
  sixtyMin(minutes: 60, labelAr: 'ساعة', labelEn: '1 hour'),

  /// 120 minutes — tail of rapid-acting insulin activity + carb absorption.
  twoHours(minutes: 120, labelAr: 'ساعتان', labelEn: '2 hours');

  const PredictionHorizon({
    required this.minutes,
    required this.labelAr,
    required this.labelEn,
  });

  final int minutes;
  final String labelAr;
  final String labelEn;

  static const List<PredictionHorizon> all = [thirtyMin, sixtyMin, twoHours];
}
