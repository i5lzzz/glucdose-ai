// lib/ai/prediction/core/prediction_risk.dart
// ─────────────────────────────────────────────────────────────────────────────
// PredictionRisk — clinical risk classification of a predicted BG value.
//
// THRESHOLDS (mg/dL):
//   < 55             → criticalHypo    (Level 2 — imminent seizure risk)
//   55 – 69          → hypo            (Level 1 — symptomatic)
//   70 – 79          → lowNormal       (approaching boundary)
//   80 – 140         → inRange         (target)
//   141 – 180        → elevated        (mildly above target)
//   181 – 250        → hyper           (correction may be needed)
//   > 250            → severeHyper     (urgent)
//
// RECOMMENDED ACTIONS:
//   criticalHypo → alert + 20 g fast carbs immediately
//   hypo         → alert + 15 g fast carbs
//   severeHyper  → correction warning + physician advice
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Clinical risk classification for a single predicted BG point.
enum PredictionRiskLevel {
  criticalHypo, // < 55
  hypo,         // 55–69
  lowNormal,    // 70–79
  inRange,      // 80–140
  elevated,     // 141–180
  hyper,        // 181–250
  severeHyper;  // > 250

  // ── Thresholds ─────────────────────────────────────────────────────────────
  static const double _criticalHypoThreshold = 55.0;
  static const double _hypoThreshold = 70.0;
  static const double _lowNormalThreshold = 80.0;
  static const double _targetHigh = 140.0;
  static const double _mildHyperHigh = 180.0;
  static const double _hyperHigh = 250.0;

  /// Classifies [bgMgdl] into the appropriate risk level.
  static PredictionRiskLevel classify(double bgMgdl) {
    if (bgMgdl < _criticalHypoThreshold) return criticalHypo;
    if (bgMgdl < _hypoThreshold) return hypo;
    if (bgMgdl < _lowNormalThreshold) return lowNormal;
    if (bgMgdl <= _targetHigh) return inRange;
    if (bgMgdl <= _mildHyperHigh) return elevated;
    if (bgMgdl <= _hyperHigh) return hyper;
    return severeHyper;
  }

  // ── Clinical properties ───────────────────────────────────────────────────

  bool get requiresImmediateAction =>
      this == criticalHypo || this == hypo;

  bool get isAnyHypo =>
      this == criticalHypo || this == hypo || this == lowNormal;

  bool get isAnyHyper =>
      this == elevated || this == hyper || this == severeHyper;

  bool get isSafe => this == inRange;

  bool get isCritical =>
      this == criticalHypo || this == severeHyper;

  String get nameAr => switch (this) {
        PredictionRiskLevel.criticalHypo => 'انخفاض حرج',
        PredictionRiskLevel.hypo => 'انخفاض',
        PredictionRiskLevel.lowNormal => 'طبيعي منخفض',
        PredictionRiskLevel.inRange => 'مثالي',
        PredictionRiskLevel.elevated => 'مرتفع قليلاً',
        PredictionRiskLevel.hyper => 'مرتفع',
        PredictionRiskLevel.severeHyper => 'مرتفع جداً',
      };

  String get nameEn => switch (this) {
        PredictionRiskLevel.criticalHypo => 'Critical Hypo',
        PredictionRiskLevel.hypo => 'Hypoglycaemia',
        PredictionRiskLevel.lowNormal => 'Low Normal',
        PredictionRiskLevel.inRange => 'In Range',
        PredictionRiskLevel.elevated => 'Elevated',
        PredictionRiskLevel.hyper => 'Hyperglycaemia',
        PredictionRiskLevel.severeHyper => 'Severe Hyper',
      };
}

/// A recommended action associated with a prediction risk.
final class PredictionAction extends Equatable {
  const PredictionAction({
    required this.ar,
    required this.en,
    required this.urgency,
    this.recommendedCarbsGrams,
  });

  final String ar;
  final String en;
  final ActionUrgency urgency;
  final double? recommendedCarbsGrams;

  static const PredictionAction none = PredictionAction(
    ar: '',
    en: '',
    urgency: ActionUrgency.none,
  );

  static PredictionAction forRisk(PredictionRiskLevel risk) => switch (risk) {
        PredictionRiskLevel.criticalHypo => const PredictionAction(
            ar: '🚨 تناول ٢٠ جرام جلوكوز فوراً — خطر انخفاض حرج متوقع',
            en: '🚨 Consume 20 g fast glucose immediately — critical hypo predicted',
            urgency: ActionUrgency.critical,
            recommendedCarbsGrams: 20,
          ),
        PredictionRiskLevel.hypo => const PredictionAction(
            ar: '⚠️ تناول ١٥ جرام كربوهيدرات سريعة — انخفاض متوقع',
            en: '⚠️ Consume 15 g fast carbs — hypoglycaemia predicted',
            urgency: ActionUrgency.urgent,
            recommendedCarbsGrams: 15,
          ),
        PredictionRiskLevel.lowNormal => const PredictionAction(
            ar: 'راقب سكر الدم عن كثب في الدقائق القادمة',
            en: 'Monitor blood glucose closely over the next few minutes',
            urgency: ActionUrgency.monitor,
          ),
        PredictionRiskLevel.severeHyper => const PredictionAction(
            ar: '⚠️ ارتفاع شديد متوقع — استشر طبيبك',
            en: '⚠️ Severe hyperglycaemia predicted — consult physician',
            urgency: ActionUrgency.urgent,
          ),
        PredictionRiskLevel.hyper => const PredictionAction(
            ar: 'ارتفاع متوقع — قد تحتاج جرعة تصحيح لاحقاً',
            en: 'Hyperglycaemia predicted — correction dose may be needed later',
            urgency: ActionUrgency.monitor,
          ),
        _ => PredictionAction.none,
      };

  @override
  List<Object?> get props => [ar, urgency, recommendedCarbsGrams];
}

enum ActionUrgency { none, monitor, urgent, critical }
