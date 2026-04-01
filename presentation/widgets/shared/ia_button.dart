// lib/presentation/widgets/shared/ia_button.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:insulin_assistant/presentation/theme/design_tokens.dart';

enum IAButtonVariant { primary, secondary, destructive, ghost }

class IAButton extends StatefulWidget {
  const IAButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = IAButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IAButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;

  @override
  State<IAButton> createState() => _IAButtonState();
}

class _IAButtonState extends State<IAButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _bgColor => switch (widget.variant) {
        IAButtonVariant.primary     => DT.ink,
        IAButtonVariant.secondary   => DT.fill,
        IAButtonVariant.destructive => DT.danger,
        IAButtonVariant.ghost       => Colors.transparent,
      };

  Color get _fgColor => switch (widget.variant) {
        IAButtonVariant.primary     => Colors.white,
        IAButtonVariant.secondary   => DT.ink,
        IAButtonVariant.destructive => Colors.white,
        IAButtonVariant.ghost       => DT.info,
      };

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    return GestureDetector(
      onTapDown: disabled ? null : (_) {
        HapticFeedback.lightImpact();
        _controller.forward();
      },
      onTapUp: disabled ? null : (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: DT.fast,
          width: widget.fullWidth ? double.infinity : null,
          height: 56,
          decoration: BoxDecoration(
            color: disabled
                ? _bgColor.withOpacity(0.4)
                : _bgColor,
            borderRadius: BorderRadius.circular(DT.rMedium),
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _fgColor,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: _fgColor, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: DT.title17.copyWith(color: _fgColor),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
