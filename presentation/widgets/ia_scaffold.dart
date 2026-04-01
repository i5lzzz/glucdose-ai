// lib/presentation/widgets/ia_scaffold.dart

import 'package:flutter/material.dart';

/// Base scaffold used by every screen. Enforces:
///   - consistent background color
///   - RTL-safe padding
///   - no overflow on small screens
class IAScaffold extends StatelessWidget {
  const IAScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.body,
    this.bottomBar,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
    this.leading,
  });

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? body;
  final Widget? bottomBar;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      appBar: (title != null || titleWidget != null)
          ? AppBar(
              backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              title: titleWidget ??
                  Text(title!, style: theme.textTheme.titleMedium),
              actions: actions,
              leading: leading,
            )
          : null,
      body: body,
      bottomNavigationBar: bottomBar,
    );
  }
}
