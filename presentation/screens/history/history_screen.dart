// lib/presentation/screens/history/history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:insulin_assistant/presentation/providers/providers.dart';
import 'package:insulin_assistant/presentation/theme/app_theme.dart';
import 'package:insulin_assistant/presentation/widgets/ia_card.dart';
import 'package:insulin_assistant/presentation/widgets/ia_scaffold.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(historyProvider);
    final theme = Theme.of(context);

    return IAScaffold(
      title: 'السجل',
      body: SafeArea(
        child: items.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history_rounded, size: 56, color: theme.colorScheme.outline.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('لا توجد سجلات بعد', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
            ]))
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final isFirst = i == 0 || !_sameDay(item.timestamp, items[i - 1].timestamp);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (isFirst) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(_dayLabel(item.timestamp), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline))),
                  ],
                  IACard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      _TypeIcon(type: item.type),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_typeLabel(item.type), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                        if (item.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(item.subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        RichText(text: TextSpan(
                          style: TextStyle(fontFamily: 'Cairo', color: _valueColor(item.type, item.primaryValue)),
                          children: [
                            TextSpan(text: item.primaryValue, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                            TextSpan(text: ' ${item.unit}', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                          ],
                        )),
                        Text(_timeLabel(item.timestamp), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline.withOpacity(0.6))),
                      ]),
                    ]),
                  ).animate(delay: Duration(milliseconds: i * 40)).fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0, duration: 280.ms),
                ]);
              },
            ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return 'اليوم';
    if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'أمس';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _timeLabel(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _typeLabel(HistoryItemType t) => switch (t) {
    HistoryItemType.injection => 'جرعة أنسولين',
    HistoryItemType.glucose => 'قراءة سكر',
    HistoryItemType.calculation => 'حساب جرعة',
  };

  Color _valueColor(HistoryItemType type, String value) {
    if (type == HistoryItemType.glucose) {
      final v = double.tryParse(value) ?? 0;
      if (v < 70) return AppTheme.dangerRed;
      if (v <= 140) return AppTheme.safeGreen;
      return AppTheme.warningAmber;
    }
    return AppTheme.safeGreen;
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});
  final HistoryItemType type;

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = switch (type) {
      HistoryItemType.injection => (Icons.vaccines_rounded, AppTheme.infoPurpleSurface, AppTheme.infoPurple),
      HistoryItemType.glucose   => (Icons.bloodtype_rounded, AppTheme.safeGreenSurface, AppTheme.safeGreen),
      HistoryItemType.calculation => (Icons.calculate_rounded, const Color(0xFFEFF6FF), AppTheme.infoPurple),
    };
    return Container(width: 40, height: 40, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: fg, size: 20));
  }
}
