// lib/presentation/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:insulin_assistant/presentation/screens/calculator/calculator_screen.dart';
import 'package:insulin_assistant/presentation/screens/settings/settings_screen.dart';
import 'package:insulin_assistant/presentation/screens/shell/main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const MainShell(),
      ),
      GoRoute(
        path: '/calculator',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const CalculatorScreen(),
          transitionsBuilder: (context, anim, secAnim, child) =>
              SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
          transitionsBuilder: (context, anim, secAnim, child) =>
              SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    ],
  );
});
