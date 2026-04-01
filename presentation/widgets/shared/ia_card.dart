// lib/presentation/widgets/shared/ia_card.dart

import 'package:flutter/material.dart';
import 'package:insulin_assistant/presentation/theme/design_tokens.dart';

class IACard extends StatelessWidget {
  const IACard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: DT.fast,
      decoration: BoxDecoration(
        color: color ?? DT.card,
        borderRadius: BorderRadius.circular(DT.rLarge),
        border: border ?? Border.all(color: DT.separator, width: 0.5),
        boxShadow: DT.cardShadow,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(DT.s20),
        child: child,
      ),
    );

    if (onTap == null) return card;

    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}
