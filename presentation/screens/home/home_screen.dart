// lib/presentation/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/entities/glucose_reading.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';
import 'package:insulin_assistant/presentation/providers/providers.dart';
import 'package:insulin_assistant/presentation/router/app_router.dart';
import 'package:insulin_assistant/presentation/theme/app_theme.dart';
import 'package:insulin_assistant/presentation/widgets/bg_value_display.dart';
import 'package:insulin_assistant/presentation/widgets/ia_button.dart';
import 'package:insulin_assistant/presentation/widgets/ia_card.dart';
import 'package:insulin_assistant/presentation/widgets/ia_scaffold.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bgStateProvider.notifier).state = BGState(
        value: BloodGlucose.fromMgdl(142).value,
        trend: GlucoseTrend.stable,
      );
      ref.read(iobProvider.notifier).state =
          InsulinUnits.fromUnitsUnclamped(1.8).value;
      ref.read(predictionProvider.notifier).state = const PredictionState(
        bg30: 158, bg60: 172, bg120: 148,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgState = ref.watch(bgStateProvider);
    final iob = ref.watch(iobProvider);
    final prediction = ref.watch(predictionProvider);
    final theme = Theme.of(context);

    return IAScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('سكر الدم الآن', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                      Text('منذ ٣ دقائق', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline.withOpacity(0.55))),
                    ]),
                    _LiveDot(active: bgState.value != null),
                  ],
                ),
                const SizedBox(height: 28),
                BGValueDisplay(bg: bgState.value, trend: bgState.trend)
                    .animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0, duration: 400.ms),
                const SizedBox(height: 36),
                Row(children: [
                  Expanded(
                    child: IACard(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('الأنسولين الفعّال', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                        const SizedBox(height: 8),
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text(iob.units.toStringAsFixed(1),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: iob.units > MedicalConstants.iobStackingWarningThreshold
                                  ? AppTheme.warningAmber : theme.colorScheme.onSurface,
                            )),
                          const SizedBox(width: 4),
                          Text('U', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                        ]),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IACard(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('الحالة', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                        const SizedBox(height: 8),
                        _buildStatusText(context, bgState),
                      ]),
                    ),
                  ),
                ]).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.06, end: 0, delay: 100.ms, duration: 350.ms),
                const SizedBox(height: 16),
                if (prediction.bg30 != null)
                  IACard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('توقع سكر الدم', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
                      const SizedBox(height: 16),
                      Row(children: [
                        _PredictionCell(label: '٣٠ د', value: prediction.bg30!),
                        Container(width: 1, height: 36, color: theme.colorScheme.outline.withOpacity(0.12)),
                        _PredictionCell(label: 'ساعة', value: prediction.bg60!),
                        Container(width: 1, height: 36, color: theme.colorScheme.outline.withOpacity(0.12)),
                        _PredictionCell(label: 'ساعتان', value: prediction.bg120!),
                      ]),
                    ]),
                  ).animate().fadeIn(delay: 180.ms, duration: 350.ms).slideY(begin: 0.06, end: 0, delay: 180.ms, duration: 350.ms),
                const SizedBox(height: 28),
                IAPrimaryButton(
                  label: 'احسب الجرعة',
                  icon: Icons.calculate_rounded,
                  onPressed: () => context.go(AppRoutes.calculator),
                ).animate().fadeIn(delay: 250.ms, duration: 350.ms),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusText(BuildContext context, BGState bgState) {
    final theme = Theme.of(context);
    if (bgState.value == null) return Text('—', style: theme.textTheme.headlineSmall);
    final (label, color) = bgState.isHypo ? ('منخفض', AppTheme.dangerRed)
        : bgState.isHyper ? ('مرتفع', AppTheme.dangerRed)
        : bgState.isInRange ? ('مثالي', AppTheme.safeGreen)
        : ('مقبول', AppTheme.warningAmber);
    return Text(label, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color));
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.active});
  final bool active;
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
      child: Container(width: 8, height: 8, decoration: BoxDecoration(
        color: AppTheme.safeGreen, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppTheme.safeGreen.withOpacity(0.45), blurRadius: 6)],
      )),
    );
  }
}

class _PredictionCell extends StatelessWidget {
  const _PredictionCell({required this.label, required this.value});
  final String label; final double value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = value < 70 ? AppTheme.dangerRed : value < 80 ? AppTheme.warningAmber
        : value <= 140 ? AppTheme.safeGreen : value <= 180 ? AppTheme.warningAmber : AppTheme.dangerRed;
    return Expanded(child: Column(children: [
      Text(value.toStringAsFixed(0), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 4),
      Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
    ]));
  }
}
