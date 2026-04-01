// lib/presentation/screens/calculator/calculator_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';
import 'package:insulin_assistant/presentation/providers/providers.dart';
import 'package:insulin_assistant/presentation/screens/calculator/confirmation_modal.dart';
import 'package:insulin_assistant/presentation/theme/app_theme.dart';
import 'package:insulin_assistant/presentation/widgets/ia_button.dart';
import 'package:insulin_assistant/presentation/widgets/ia_card.dart';
import 'package:insulin_assistant/presentation/widgets/ia_number_field.dart';
import 'package:insulin_assistant/presentation/widgets/ia_scaffold.dart';
import 'package:insulin_assistant/presentation/widgets/safety_banner.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});
  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  final _bgCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();

  @override
  void dispose() { _bgCtrl.dispose(); _carbsCtrl.dispose(); super.dispose(); }

  void _calculate() {
    final bg = double.tryParse(_bgCtrl.text.trim());
    final carbs = double.tryParse(_carbsCtrl.text.trim()) ?? 0;
    final settings = ref.read(userSettingsProvider);
    final iob = ref.read(iobProvider).units;

    if (bg == null) {
      ref.read(calculatorProvider.notifier).state =
          ref.read(calculatorProvider).copyWith(error: 'أدخل قيمة سكر الدم');
      return;
    }

    CalculatorSafetyLevel safetyLevel;
    String? safetyMsg;
    if (bg < MedicalConstants.bgLevel2HypoHardBlock) {
      safetyLevel = CalculatorSafetyLevel.hardBlock;
      safetyMsg = '🚨 سكر الدم أقل من ٤٠ مغ/دل\nلا يمكن حقن الأنسولين. تناول الجلوكوز فوراً.';
    } else if (bg < MedicalConstants.bgLevel1HypoWarn) {
      safetyLevel = CalculatorSafetyLevel.softBlock;
      safetyMsg = '⚠️ سكر الدم منخفض (${bg.toStringAsFixed(0)} مغ/دل)\nالحقن الآن قد يكون خطيراً.';
    } else if (bg > 300) {
      safetyLevel = CalculatorSafetyLevel.warning;
      safetyMsg = '⚠️ ارتفاع شديد (${bg.toStringAsFixed(0)} مغ/دل) — استشر طبيبك.';
    } else {
      safetyLevel = CalculatorSafetyLevel.safe;
    }

    final carbComp = carbs / settings.icr;
    final corrComp = (bg - settings.targetBG) / settings.isf;
    final raw = carbComp + corrComp - iob;
    final clamped = raw.clamp(0.0, settings.maxDose);
    final stepped = (clamped / settings.doseStep.value).floor() * settings.doseStep.value;

    ref.read(calculatorProvider.notifier).state = CalculatorInputState(
      bgInput: _bgCtrl.text,
      carbsInput: _carbsCtrl.text,
      calculatedDose: safetyLevel == CalculatorSafetyLevel.hardBlock ? null : stepped,
      carbComponent: carbComp,
      correctionComponent: corrComp,
      iobDeduction: iob,
      safetyMessage: safetyMsg,
      safetyLevel: safetyLevel,
    );
  }

  void _showConfirmation(BuildContext context, double dose) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ConfirmationModal(
        dose: dose,
        onConfirmed: () { Navigator.pop(context); _onConfirmed(dose); },
        onCancelled: () => Navigator.pop(context),
      ),
    );
  }

  void _onConfirmed(double dose) {
    final n = (ref.read(iobProvider).units + dose).clamp(0.0, 20.0);
    ref.read(iobProvider.notifier).state = InsulinUnits.fromUnitsUnclamped(n).value;
    ref.read(calculatorProvider.notifier).state = const CalculatorInputState();
    _bgCtrl.clear(); _carbsCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('تم تسجيل ${dose.toStringAsFixed(1)} وحدة ✓',
          style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: AppTheme.safeGreen, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final calc = ref.watch(calculatorProvider);
    final settings = ref.watch(userSettingsProvider);
    final theme = Theme.of(context);

    return IAScaffold(
      title: 'حساب الجرعة',
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            IACard(child: Column(children: [
              IANumberField(label: 'سكر الدم الحالي', hint: '120', unit: 'مغ/دل',
                  controller: _bgCtrl, errorText: calc.error,
                  onChanged: (_) { if (calc.error != null) ref.read(calculatorProvider.notifier).state = calc.copyWith(clearResult: true); }),
              const SizedBox(height: 24),
              IANumberField(label: 'الكربوهيدرات', hint: '0', unit: 'جرام', controller: _carbsCtrl),
            ])).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              _InfoChip(label: 'ICR', value: '${settings.icr.toStringAsFixed(0)} g/U'),
              _InfoChip(label: 'ISF', value: '${settings.isf.toStringAsFixed(0)} مغ/U'),
              _InfoChip(label: 'هدف', value: '${settings.targetBG.toStringAsFixed(0)}'),
            ]),
            const SizedBox(height: 24),
            if (calc.safetyLevel != null && calc.safetyLevel != CalculatorSafetyLevel.safe)
              Padding(padding: const EdgeInsets.only(bottom: 16),
                child: SafetyBanner(message: calc.safetyMessage ?? '', level: calc.safetyLevel!)),
            if (calc.hasResult) ...[
              _DoseResultCard(dose: calc.calculatedDose!, carbComponent: calc.carbComponent ?? 0,
                  correctionComponent: calc.correctionComponent ?? 0, iobDeduction: calc.iobDeduction ?? 0)
                  .animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.96, 0.96), duration: 300.ms, curve: Curves.easeOut),
              const SizedBox(height: 20),
              IAPrimaryButton(label: 'تأكيد الحقن', icon: Icons.check_rounded,
                  onPressed: (calc.calculatedDose ?? 0) > 0 ? () => _showConfirmation(context, calc.calculatedDose!) : null),
            ] else
              IAPrimaryButton(label: 'احسب الجرعة', onPressed: _calculate, isLoading: calc.isCalculating),
            const SizedBox(height: 32),
          ]),
        )),
      ),
    );
  }
}

class _DoseResultCard extends StatelessWidget {
  const _DoseResultCard({required this.dose, required this.carbComponent, required this.correctionComponent, required this.iobDeduction});
  final double dose, carbComponent, correctionComponent, iobDeduction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IACard(
      border: Border.all(color: AppTheme.safeGreen.withOpacity(0.3), width: 1.5),
      child: Column(children: [
        Text('الجرعة المحسوبة', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic, children: [
          Text(dose.toStringAsFixed(1), style: const TextStyle(fontFamily: 'Cairo', fontSize: 72,
              fontWeight: FontWeight.w700, color: AppTheme.safeGreen, height: 1.0, letterSpacing: -2)),
          const SizedBox(width: 6),
          Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Text('وحدة', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
        ]),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _BreakdownRow(label: 'جرعة الكربوهيدرات', value: carbComponent, positive: true),
        const SizedBox(height: 8),
        _BreakdownRow(label: 'جرعة التصحيح', value: correctionComponent, positive: correctionComponent > 0),
        const SizedBox(height: 8),
        _BreakdownRow(label: 'خصم الأنسولين الفعّال', value: -iobDeduction, positive: false),
      ]),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value, required this.positive});
  final String label; final double value; final bool positive;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = value.abs() < 0.01 ? theme.colorScheme.outline
        : positive ? AppTheme.safeGreen : AppTheme.dangerRed;
    final sign = value >= 0 ? '+' : '';
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
      Text('$sign${value.toStringAsFixed(2)} U', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: color)),
    ]);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.colorScheme.outline.withOpacity(0.12))),
      child: RichText(text: TextSpan(style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: theme.colorScheme.outline),
          children: [TextSpan(text: '$label: '), TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600))])),
    );
  }
}
