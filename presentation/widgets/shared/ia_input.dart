// lib/presentation/widgets/shared/ia_input.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:insulin_assistant/presentation/theme/design_tokens.dart';

class IANumericInput extends StatefulWidget {
  const IANumericInput({
    super.key,
    required this.labelAr,
    required this.unit,
    required this.onChanged,
    this.hintAr,
    this.initialValue,
    this.allowDecimal = true,
  });

  final String labelAr;
  final String unit;
  final ValueChanged<String> onChanged;
  final String? hintAr;
  final String? initialValue;
  final bool allowDecimal;

  @override
  State<IANumericInput> createState() => _IANumericInputState();
}

class _IANumericInputState extends State<IANumericInput> {
  late final TextEditingController _ctrl;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: DT.s8, right: DT.s4),
          child: Text(widget.labelAr, style: DT.label),
        ),
        AnimatedContainer(
          duration: DT.fast,
          decoration: BoxDecoration(
            color: _focused ? DT.card : DT.fill,
            borderRadius: BorderRadius.circular(DT.rMedium),
            border: Border.all(
              color: _focused ? DT.ink : DT.separator,
              width: _focused ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (v) => setState(() => _focused = v),
                  child: TextField(
                    controller: _ctrl,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: widget.allowDecimal,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        widget.allowDecimal
                            ? RegExp(r'[\d.]')
                            : RegExp(r'\d'),
                      ),
                    ],
                    style: DT.display48.copyWith(
                      fontSize: 32,
                      color: DT.ink,
                      letterSpacing: -1,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintAr ?? '٠',
                      hintStyle: DT.display48.copyWith(
                        fontSize: 32,
                        color: DT.inkTert,
                        letterSpacing: -1,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: DT.s16,
                        vertical: DT.s16,
                      ),
                    ),
                    onChanged: widget.onChanged,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: DT.s16),
                child: Text(widget.unit, style: DT.body15),
              ),
              const SizedBox(width: DT.s16),
            ],
          ),
        ),
      ],
    );
  }
}
