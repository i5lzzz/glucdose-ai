// lib/presentation/widgets/bg_value_display.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/entities/glucose_reading.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/presentation/theme/app_theme.dart';

/// Hero widget showing the current BG value in large type.
/// Color shifts based on clinical classification.
class BGValueDisplay extends StatelessWidget {
  const BGValueDisplay({
    super.key,
    required this.bg,
    this.trend = GlucoseTrend.unknown,
    this.unit = 'مغ/دل',
    this.size = BGDisplaySize.large,
    this.animate = true,
  });

  final BloodGlucose? bg;
  final GlucoseTrend trend;
  final String unit;
  final BGDisplaySize size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context, bg);

    final valueText = bg != null
        ? bg!.mgdl.toStringAsFixed(0)
        : '---';

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Value
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              valueText,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: size.valueFontSize,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
            if (bg != null && trend != GlucoseTrend.unknown) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  trend.arrowSymbol,
                  style: TextStyle(
                    fontSize: size.valueFontSize * 0.35,
                    color: color.withOpacity(0.7),
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Unit label
        Text(
          unit,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: size.unitFontSize,
            fontWeight: FontWeight.w400,
            color: color.withOpacity(0.6),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    if (animate && bg != null) {
      content = content
          .animate(key: ValueKey(bg!.mgdl))
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.92, 0.92), duration: 300.ms, curve: Curves.easeOut);
    }

    return content;
  }

  Color _colorFor(BuildContext context, BloodGlucose? bg) {
    if (bg == null) return Theme.of(context).colorScheme.outline;
    if (bg.mgdl < MedicalConstants.bgLevel2HypoHardBlock) {
      return AppTheme.dangerRed;
    }
    if (bg.mgdl < MedicalConstants.bgLevel1HypoWarn) {
      return AppTheme.warningAmber;
    }
    if (bg.isInRange) return AppTheme.safeGreen;
    if (bg.mgdl <= 180) return AppTheme.warningAmber;
    return AppTheme.dangerRed;
  }
}

enum BGDisplaySize {
  small(valueFontSize: 36, unitFontSize: 13),
  medium(valueFontSize: 52, unitFontSize: 15),
  large(valueFontSize: 88, unitFontSize: 18);

  const BGDisplaySize({required this.valueFontSize, required this.unitFontSize});
  final double valueFontSize;
  final double unitFontSize;
}
