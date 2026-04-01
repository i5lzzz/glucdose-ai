// lib/presentation/widgets/ia_number_field.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Large-type number entry field.
/// Keyboard is numeric; no suffix icons.
class IANumberField extends StatefulWidget {
  const IANumberField({
    super.key,
    required this.label,
    required this.hint,
    this.unit,
    this.onChanged,
    this.controller,
    this.errorText,
    this.enabled = true,
    this.decimal = true,
    this.autofocus = false,
    this.initialValue,
  });

  final String label;
  final String hint;
  final String? unit;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final String? errorText;
  final bool enabled;
  final bool decimal;
  final bool autofocus;
  final String? initialValue;

  @override
  State<IANumberField> createState() => _IANumberFieldState();
}

class _IANumberFieldState extends State<IANumberField> {
  late final TextEditingController _ctrl;
  bool _owned = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ctrl = widget.controller!;
    } else {
      _ctrl = TextEditingController(text: widget.initialValue);
      _owned = true;
    }
  }

  @override
  void dispose() {
    if (_owned) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label row
        Row(
          children: [
            Text(
              widget.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (widget.unit != null)
              Text(
                widget.unit!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Input container
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasError
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline.withOpacity(0.18),
              width: hasError ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _ctrl,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            keyboardType: TextInputType.numberWithOptions(
              decimal: widget.decimal,
              signed: false,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                widget.decimal
                    ? RegExp(r'^\d*\.?\d*')
                    : RegExp(r'^\d*'),
              ),
            ],
            textAlign: TextAlign.start,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.outline.withOpacity(0.35),
                fontWeight: FontWeight.w400,
              ),
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onChanged: widget.onChanged,
          ),
        ),
        // Error text
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
