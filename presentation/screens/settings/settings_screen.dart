// lib/presentation/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/domain/core/unit_system.dart';
import 'package:insulin_assistant/presentation/providers/providers.dart';
import 'package:insulin_assistant/presentation/widgets/ia_card.dart';
import 'package:insulin_assistant/presentation/widgets/ia_number_field.dart';
import 'package:insulin_assistant/presentation/widgets/ia_scaffold.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _icrCtrl, _isfCtrl, _targetCtrl, _maxDoseCtrl, _diaCtrl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(userSettingsProvider);
    _icrCtrl   = TextEditingController(text: s.icr.toStringAsFixed(0));
    _isfCtrl   = TextEditingController(text: s.isf.toStringAsFixed(0));
    _targetCtrl= TextEditingController(text: s.targetBG.toStringAsFixed(0));
    _maxDoseCtrl = TextEditingController(text: s.maxDose.toStringAsFixed(0));
    _diaCtrl   = TextEditingController(text: s.insulinDurationMinutes.toStringAsFixed(0));
  }

  @override
  void dispose() {
    for (final c in [_icrCtrl, _isfCtrl, _targetCtrl, _maxDoseCtrl, _diaCtrl]) c.dispose();
    super.dispose();
  }

  void _save() {
    final notifier = ref.read(userSettingsProvider.notifier);
    notifier.state = notifier.state.copyWith(
      icr: double.tryParse(_icrCtrl.text) ?? notifier.state.icr,
      isf: double.tryParse(_isfCtrl.text) ?? notifier.state.isf,
      targetBG: double.tryParse(_targetCtrl.text) ?? notifier.state.targetBG,
      maxDose: double.tryParse(_maxDoseCtrl.text) ?? notifier.state.maxDose,
      insulinDurationMinutes: double.tryParse(_diaCtrl.text) ?? notifier.state.insulinDurationMinutes,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('تم الحفظ ✓', style: TextStyle(fontFamily: 'Cairo')),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsProvider);
    final theme = Theme.of(context);

    return IAScaffold(
      title: 'الإعدادات',
      actions: [TextButton(onPressed: _save, child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)))],
      body: SafeArea(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
        const SizedBox(height: 20),

        // Units
        IASectionLabel('وحدة القياس'),
        IACard(child: _SegmentedRow(
          label: 'وحدة سكر الدم',
          options: const ['مغ/دل', 'مليمول/ل'],
          selected: settings.unitSystem.glucose == GlucoseUnit.mgdl ? 0 : 1,
          onChanged: (i) => ref.read(userSettingsProvider.notifier).state = settings.copyWith(
            unitSystem: i == 0 ? const UnitSystem.mgdl() : const UnitSystem.mmolL()),
        )),
        const SizedBox(height: 12),

        // Dose step
        IASectionLabel('دقة الجهاز'),
        IACard(child: _SegmentedRow(
          label: 'خطوة الجرعة',
          options: const ['٠.١ U', '٠.٥ U', '١ U'],
          selected: settings.doseStep.index,
          onChanged: (i) => ref.read(userSettingsProvider.notifier).state = settings.copyWith(doseStep: DoseStep.values[i]),
        )),
        const SizedBox(height: 12),

        // Clinical parameters
        IASectionLabel('المعاملات الطبية'),
        IACard(child: Column(children: [
          IANumberField(label: 'نسبة الكربوهيدرات (ICR)', hint: '10', unit: 'جرام/وحدة', controller: _icrCtrl),
          const SizedBox(height: 20),
          IANumberField(label: 'معامل الحساسية (ISF)', hint: '50', unit: 'مغ/دل/وحدة', controller: _isfCtrl),
          const SizedBox(height: 20),
          IANumberField(label: 'السكر المستهدف', hint: '100', unit: 'مغ/دل', controller: _targetCtrl),
          const SizedBox(height: 20),
          IANumberField(label: 'الجرعة القصوى', hint: '10', unit: 'وحدة', controller: _maxDoseCtrl),
          const SizedBox(height: 20),
          IANumberField(label: 'مدة الأنسولين', hint: '240', unit: 'دقيقة', controller: _diaCtrl),
        ])),

        const SizedBox(height: 24),

        // App version
        Text('المساعد الذكي للأنسولين  ·  v1.0.0',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline.withOpacity(0.5))),
        const SizedBox(height: 32),
      ]))),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({required this.label, required this.options, required this.selected, required this.onChanged});
  final String label;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
      const SizedBox(height: 12),
      Row(children: List.generate(options.length, (i) {
        final sel = i == selected;
        return Expanded(child: GestureDetector(
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(options[i], textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel ? Colors.white : theme.colorScheme.onSurface)),
          ),
        ));
      })),
    ]);
  }
}
