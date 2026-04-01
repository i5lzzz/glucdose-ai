// lib/domain/core/clock.dart
// ─────────────────────────────────────────────────────────────────────────────
// Clock abstraction.
//
// WHY:
//   1. Testability — IOB calculations depend on elapsed time.  Without a
//      clock abstraction, tests are either flaky or rely on time.sleep().
//   2. Auditability — every timestamp in a medical calculation must come from
//      a single, controllable source. A future cloud sync implementation may
//      use a server-verified timestamp.
//   3. IEC 62304 §5.5 — software units must be independently testable.
//
// Usage:
//   Production code receives Clock via DI.
//   Test code receives FakeClock with a fixed instant.
//
// RULE: No domain or algorithm class may call DateTime.now() directly.
//       All time access goes through the injected Clock instance.
// ─────────────────────────────────────────────────────────────────────────────

/// Abstract clock interface — all domain classes depend on this, never on
/// the concrete system clock.
abstract interface class Clock {
  /// Returns the current instant in UTC.
  DateTime now();

  /// Returns true if [instant] is in the past relative to now().
  bool isPast(DateTime instant) => instant.isBefore(now());

  /// Elapsed time since [past].  Returns Duration.zero if [past] is future.
  Duration elapsed(DateTime past) {
    final diff = now().difference(past);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Minutes elapsed since [past].  Clamped to zero.
  double minutesElapsed(DateTime past) => elapsed(past).inSeconds / 60.0;
}

// ── Production implementation ─────────────────────────────────────────────────

/// System clock — delegates to [DateTime.now()].
/// Registered as a singleton in the DI container.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

// ── Test implementation ────────────────────────────────────────────────────────

/// Deterministic clock for unit and integration tests.
///
/// ```dart
/// final clock = FakeClock(DateTime.utc(2024, 6, 1, 12, 0));
/// clock.advance(const Duration(hours: 2));
/// expect(iobCalc.calculate(injections, clock), closeTo(1.4, 0.1));
/// ```
final class FakeClock implements Clock {
  FakeClock(DateTime initial) : _current = initial.toUtc();

  DateTime _current;

  @override
  DateTime now() => _current;

  /// Moves the clock forward by [duration].
  void advance(Duration duration) {
    _current = _current.add(duration);
  }

  /// Jumps to [instant].
  void jumpTo(DateTime instant) {
    _current = instant.toUtc();
  }

  /// Resets to the given [epoch].
  void reset(DateTime epoch) => jumpTo(epoch);
}
