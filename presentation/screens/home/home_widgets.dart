// lib/presentation/screens/home/home_widgets.dart

import 'package:flutter/material.dart';
import 'package:insulin_assistant/presentation/providers/app_providers.dart';
import 'package:insulin_assistant/presentation/theme/design_tokens.dart';
import 'package:insulin_assistant/presentation/widgets/shared/ia_card.dart';

// ── BG Hero Card ──────────────────────────────────────────────────────────────

class BGHeroCard extends StatelessWidget {
  const BGHeroCard({super.key, required this.dashboard});
  final DashboardState dashboard;

  @override
  Widget build(BuildContext context) {
    final bg = dashboard.currentBGMgdl;
    final color = bg != null ? bgStatusColor(bg) : DT.inkTert;
    final surface = bg != null ? bgStatusSurface(bg) : DT.fill;
    final statusLabel = bg != null ? bgStatusLabelAr(bg) : '—';

    return IACard(
      color: surface,
      border: Border.all(color: color.withOpacity(0.2), width: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatusPill(label: statusLabel, color: color),
              Text('سكر الدم الحالي', style: DT.label),
            ],
          ),
          const SizedBox(height: DT.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('مغ/دل', style: DT.body13.copyWith(color: color)),
              ),
              const SizedBox(width: DT.s8),
              AnimatedSwitcher(
                duration: DT.medium,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  key: ValueKey(bg),
                  bg != null ? bg.toStringAsFixed(0) : '—',
                  style: DT.display96.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: DT.s8),
          Text(
            dashboard.lastDoseAt != null
                ? 'آخر جرعة: ${_timeAgo(dashboard.lastDoseAt!)}'
                : 'لا توجد جرعة مسجّلة اليوم',
            style: DT.body13,
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    return 'منذ ${diff.inHours} ساعة';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DT.s12, vertical: DT.s4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(DT.rFull),
      ),
      child: Text(
        label,
        style: DT.label.copyWith(color: color),
      ),
    );
  }
}

// ── Prediction Row ─────────────────────────────────────────────────────────────

class PredictionRow extends StatelessWidget {
  const PredictionRow({super.key, required this.dashboard});
  final DashboardState dashboard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PredCard(
            labelAr: '٣٠ د',
            valueMgdl: dashboard.prediction30,
          ),
        ),
        const SizedBox(width: DT.s8),
        Expanded(
          child: _PredCard(
            labelAr: 'ساعة',
            valueMgdl: dashboard.prediction60,
          ),
        ),
        const SizedBox(width: DT.s8),
        Expanded(
          child: _PredCard(
            labelAr: 'ساعتان',
            valueMgdl: dashboard.prediction120,
          ),
        ),
      ],
    );
  }
}

class _PredCard extends StatelessWidget {
  const _PredCard({required this.labelAr, this.valueMgdl});
  final String labelAr;
  final double? valueMgdl;

  @override
  Widget build(BuildContext context) {
    final color = valueMgdl != null ? bgStatusColor(valueMgdl!) : DT.inkTert;
    return IACard(
      padding: const EdgeInsets.all(DT.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(labelAr, style: DT.caption),
          const SizedBox(height: DT.s4),
          Text(
            valueMgdl != null ? valueMgdl!.toStringAsFixed(0) : '—',
            style: DT.title22.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── IOB Card ──────────────────────────────────────────────────────────────────

class IOBCard extends StatelessWidget {
  const IOBCard({super.key, required this.dashboard});
  final DashboardState dashboard;

  @override
  Widget build(BuildContext context) {
    final iob = dashboard.iobUnits;
    final hasIob = iob > 0.05;
    return IACard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasIob ? DT.info : DT.inkTert,
                ),
              ),
              const SizedBox(width: DT.s8),
              Text(
                hasIob ? 'أنسولين فعّال' : 'لا يوجد أنسولين فعّال',
                style: DT.body15.copyWith(
                  color: hasIob ? DT.ink : DT.inkTert,
                ),
              ),
            ],
          ),
          if (hasIob)
            RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: iob.toStringAsFixed(1),
                  style: DT.title22.copyWith(color: DT.info),
                ),
                TextSpan(
                  text: ' وحدة',
                  style: DT.body13.copyWith(color: DT.info),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
