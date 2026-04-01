// lib/presentation/widgets/safety_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:insulin_assistant/presentation/providers/providers.dart';
import 'package:insulin_assistant/presentation/theme/app_theme.dart';

class SafetyBanner extends StatelessWidget {
  const SafetyBanner({
    super.key,
    required this.message,
    required this.level,
    this.action,
    this.actionLabel,
  });

  final String message;
  final CalculatorSafetyLevel level;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    if (level == CalculatorSafetyLevel.safe) return const SizedBox.shrink();

    final colors = _colors(level);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _icon(level),
                color: colors.icon,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.text,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (action != null && actionLabel != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: action,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.icon,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: -0.08, end: 0, duration: 280.ms, curve: Curves.easeOut);
  }

  _BannerColors _colors(CalculatorSafetyLevel level) => switch (level) {
        CalculatorSafetyLevel.hardBlock => _BannerColors(
            background: AppTheme.dangerRedSurface,
            border: AppTheme.dangerRed.withOpacity(0.3),
            icon: AppTheme.dangerRed,
            text: const Color(0xFF7F1D1D),
          ),
        CalculatorSafetyLevel.softBlock => _BannerColors(
            background: AppTheme.warningAmberSurface,
            border: AppTheme.warningAmber.withOpacity(0.3),
            icon: AppTheme.warningAmber,
            text: const Color(0xFF78350F),
          ),
        CalculatorSafetyLevel.warning => _BannerColors(
            background: const Color(0xFFFFFBEB),
            border: const Color(0xFFFDE68A),
            icon: const Color(0xFFD97706),
            text: const Color(0xFF92400E),
          ),
        CalculatorSafetyLevel.safe => _BannerColors(
            background: AppTheme.safeGreenSurface,
            border: AppTheme.safeGreen.withOpacity(0.2),
            icon: AppTheme.safeGreen,
            text: const Color(0xFF14532D),
          ),
      };

  IconData _icon(CalculatorSafetyLevel level) => switch (level) {
        CalculatorSafetyLevel.hardBlock => Icons.block_rounded,
        CalculatorSafetyLevel.softBlock => Icons.warning_amber_rounded,
        CalculatorSafetyLevel.warning => Icons.info_outline_rounded,
        CalculatorSafetyLevel.safe => Icons.check_circle_outline_rounded,
      };
}

class _BannerColors {
  const _BannerColors({
    required this.background,
    required this.border,
    required this.icon,
    required this.text,
  });
  final Color background;
  final Color border;
  final Color icon;
  final Color text;
}
