// lib/presentation/screens/shell/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:insulin_assistant/presentation/providers/providers.dart';
import 'package:insulin_assistant/presentation/router/app_router.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    _Tab(icon: Icons.home_outlined,    activeIcon: Icons.home_rounded,      label: 'الرئيسية', route: AppRoutes.home),
    _Tab(icon: Icons.calculate_outlined,activeIcon: Icons.calculate_rounded, label: 'الجرعة',   route: AppRoutes.calculator),
    _Tab(icon: Icons.history_outlined,  activeIcon: Icons.history_rounded,   label: 'السجل',    route: AppRoutes.history),
    _Tab(icon: Icons.tune_outlined,     activeIcon: Icons.tune_rounded,      label: 'الإعدادات',route: AppRoutes.settings),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(navIndexProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.10), width: 1)),
        ),
        child: SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: List.generate(_tabs.length, (i) {
            final tab = _tabs[i]; final sel = i == idx;
            final color = sel ? theme.colorScheme.primary : theme.colorScheme.outline;
            return Expanded(child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () { ref.read(navIndexProvider.notifier).state = i; context.go(tab.route); },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: sel ? BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(20)) : null,
                  child: Icon(sel ? tab.activeIcon : tab.icon, color: color, size: 22)),
                const SizedBox(height: 2),
                Text(tab.label, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: color)),
              ]),
            ));
          })),
        )),
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.icon, required this.activeIcon, required this.label, required this.route});
  final IconData icon, activeIcon;
  final String label, route;
}
