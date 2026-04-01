// lib/presentation/widgets/ia_card.dart

import 'package:flutter/material.dart';

/// Minimal card — no decoration overload.
class IACard extends StatelessWidget {
  const IACard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.margin,
    this.borderRadius,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? BorderRadius.circular(20);

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: radius,
        border: border ??
            Border.all(
              color: theme.colorScheme.outline.withOpacity(0.10),
              width: 1,
            ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );

    if (onTap != null) {
      card = GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Full-width separator with label.
class IASectionLabel extends StatelessWidget {
  const IASectionLabel(this.text, {super.key, this.padding});
  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
