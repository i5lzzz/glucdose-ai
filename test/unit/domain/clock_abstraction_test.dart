// test/unit/domain/clock_abstraction_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/domain/core/clock.dart';

void main() {
  group('Clock Abstraction', () {
    final epoch = DateTime.utc(2024, 6, 1, 12, 0, 0);

    group('FakeClock', () {
      test('Returns fixed time initially', () {
        final clock = FakeClock(epoch);
        expect(clock.now(), equals(epoch));
      });

      test('advance() moves time forward', () {
        final clock = FakeClock(epoch);
        clock.advance(const Duration(minutes: 30));
        expect(clock.now(), equals(epoch.add(const Duration(minutes: 30))));
      });

      test('jumpTo() sets absolute time', () {
        final clock = FakeClock(epoch);
        final target = DateTime.utc(2024, 7, 1);
        clock.jumpTo(target);
        expect(clock.now(), equals(target));
      });

      test('isPast() returns true for past instants', () {
        final clock = FakeClock(epoch.add(const Duration(hours: 1)));
        expect(clock.isPast(epoch), isTrue);
        expect(clock.isPast(epoch.add(const Duration(hours: 2))), isFalse);
      });

      test('elapsed() returns correct duration', () {
        final clock = FakeClock(epoch.add(const Duration(minutes: 45)));
        expect(clock.elapsed(epoch).inMinutes, equals(45));
      });

      test('elapsed() returns zero for future instants', () {
        final clock = FakeClock(epoch);
        final future = epoch.add(const Duration(minutes: 10));
        expect(clock.elapsed(future), equals(Duration.zero));
      });

      test('minutesElapsed() returns fractional minutes', () {
        final clock = FakeClock(epoch.add(const Duration(seconds: 90)));
        expect(clock.minutesElapsed(epoch), closeTo(1.5, 0.01));
      });

      test('Multiple advance() calls accumulate', () {
        final clock = FakeClock(epoch);
        clock.advance(const Duration(minutes: 30));
        clock.advance(const Duration(minutes: 30));
        expect(clock.now(), equals(epoch.add(const Duration(hours: 1))));
      });

      test('Determinism: same FakeClock always returns same time', () {
        final clock = FakeClock(epoch);
        for (var i = 0; i < 100; i++) {
          expect(clock.now(), equals(epoch));
        }
      });

      test('FakeClock stores UTC time', () {
        final clock = FakeClock(epoch);
        expect(clock.now().isUtc, isTrue);
      });
    });

    group('SystemClock', () {
      test('now() returns current UTC time', () {
        const clock = SystemClock();
        final before = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
        final after = DateTime.now().toUtc().add(const Duration(seconds: 1));
        final t = clock.now();
        expect(t.isAfter(before), isTrue);
        expect(t.isBefore(after), isTrue);
      });

      test('now() returns UTC', () {
        const clock = SystemClock();
        expect(clock.now().isUtc, isTrue);
      });
    });
  });
}
