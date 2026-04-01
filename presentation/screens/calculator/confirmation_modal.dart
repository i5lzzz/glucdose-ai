// lib/presentation/screens/calculator/confirmation_modal.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/presentation/theme/app_theme.dart';
import 'package:insulin_assistant/presentation/widgets/ia_button.dart';

class ConfirmationModal extends StatefulWidget {
  const ConfirmationModal({super.key, required this.dose, required this.onConfirmed, required this.onCancelled});
  final double dose;
  final VoidCallback onConfirmed;
  final VoidCallback onCancelled;
  @override
  State<ConfirmationModal> createState() => _ConfirmationModalState();
}

class _ConfirmationModalState extends State<ConfirmationModal> with SingleTickerProviderStateMixin {
  static const _delay = MedicalConstants.doseConfirmationDelaySeconds;
  late AnimationController _ctrl;
  Timer? _timer;
  int _countdown = _delay;
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(seconds: _delay))..forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) { t.cancel(); setState(() => _canConfirm = true); }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(28)),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outline.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 28),
        Container(width: 56, height: 56, decoration: const BoxDecoration(color: AppTheme.warningAmberSurface, shape: BoxShape.circle),
            child: const Icon(Icons.vaccines_rounded, color: AppTheme.warningAmber, size: 28))
            .animate().scale(begin: const Offset(0.1, 0.1), duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text('تأكيد الحقن', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(widget.dose.toStringAsFixed(1), style: const TextStyle(fontFamily: 'Cairo', fontSize: 64, fontWeight: FontWeight.w700, color: AppTheme.safeGreen, height: 1.0, letterSpacing: -2)),
          const SizedBox(width: 6),
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('وحدة', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline))),
        ]).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 24),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: AnimatedBuilder(animation: _ctrl, builder: (_, __) => LinearProgressIndicator(
            value: _ctrl.value, minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(_canConfirm ? AppTheme.safeGreen : theme.colorScheme.primary),
          ))),
        const SizedBox(height: 8),
        AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: _canConfirm
          ? Text('يمكنك التأكيد الآن', key: const ValueKey('r'), style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.safeGreen))
          : Text('انتظر $_countdown ثوانٍ', key: ValueKey(_countdown), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
        const SizedBox(height: 24),
        AnimatedOpacity(opacity: _canConfirm ? 1.0 : 0.38, duration: const Duration(milliseconds: 300),
          child: IAPrimaryButton(label: 'تأكيد الحقن', icon: Icons.check_circle_rounded, onPressed: _canConfirm ? widget.onConfirmed : null)),
        const SizedBox(height: 12),
        IATextButton(label: 'إلغاء', onPressed: widget.onCancelled, color: theme.colorScheme.outline),
      ]),
    ).animate().slideY(begin: 0.15, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }
}
