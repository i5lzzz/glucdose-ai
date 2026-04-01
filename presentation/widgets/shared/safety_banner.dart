// lib/presentation/widgets/shared/safety_banner.dart

import 'package:flutter/material.dart';
import 'package:insulin_assistant/presentation/theme/design_tokens.dart';

class SafetyBanner extends StatelessWidget {
  const SafetyBanner({
    super.key,
    required this.level,
    required this.messageAr,
  });

  final String level; // 'warning' | 'softBlock' | 'hardBlock'
  final String messageAr;

  Color get _color => switch (level) {
        'hardBlock' => DT.danger,
        'softBlock' => DT.warn,
        _           => DT.warn,
      };

  Color get _surface => switch (level) {
        'hardBlock' => DT.dangerSurface,
        'softBlock' => DT.warnSurface,
        _           => DT.warnSurface,
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: DT.medium,
      curve: DT.spring,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(DT.rMedium),
          border: Border.all(color: _color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DT.s16,
          vertical: DT.s12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                messageAr,
                style: DT.body15.copyWith(
                  color: _color,
                  height: 1.6,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: DT.s8),
            Icon(
              level == 'hardBlock'
                  ? Icons.block_rounded
                  : Icons.warning_amber_rounded,
              color: _color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
