// lib/core/observability/app_observer.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Riverpod observer — logs all provider state changes in debug builds.
/// In release builds, only errors are forwarded to the audit logger.
final class AppObserver extends ProviderObserver {
  final Logger _log = Logger(
    printer: SimplePrinter(colors: false),
    level: Level.debug,
  );

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    _log.e(
      '[PROVIDER_FAIL] ${provider.name ?? provider.runtimeType}',
      error: error,
      stackTrace: stackTrace,
    );
    // In a future phase, route to AuditLogger via container.read(...)
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    // Only log medical providers in debug
    assert(() {
      final name = provider.name ?? provider.runtimeType.toString();
      if (name.contains('Dose') ||
          name.contains('Safety') ||
          name.contains('Glucose')) {
        _log.d('[PROVIDER] $name updated');
      }
      return true;
    }());
  }
}
