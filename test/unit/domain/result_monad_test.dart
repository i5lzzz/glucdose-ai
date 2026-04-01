// test/unit/domain/result_monad_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/core/result.dart';

void main() {
  group('Result<T> Monad', () {
    const failure = UnexpectedFailure('test error');

    group('Success', () {
      test('isSuccess = true', () => expect(Result<int>.success(42).isSuccess, isTrue));
      test('isFailure = false', () => expect(Result<int>.success(42).isFailure, isFalse));
      test('.value returns value', () => expect(Result<int>.success(42).value, equals(42)));
      test('.valueOrNull returns value', () => expect(Result<int>.success(42).valueOrNull, equals(42)));
      test('.failureOrNull returns null', () => expect(Result<int>.success(42).failureOrNull, isNull));
    });

    group('Failure', () {
      test('isFailure = true', () => expect(Result<int>.failure(failure).isFailure, isTrue));
      test('isSuccess = false', () => expect(Result<int>.failure(failure).isSuccess, isFalse));
      test('.failure returns failure', () => expect(Result<int>.failure(failure).failure, equals(failure)));
      test('.value throws StateError', () {
        expect(() => Result<int>.failure(failure).value, throwsStateError);
      });
      test('.valueOrNull returns null', () => expect(Result<int>.failure(failure).valueOrNull, isNull));
    });

    group('when()', () {
      test('success branch fires on success', () {
        final r = Result<int>.success(5).when(success: (v) => v * 2, failure: (_) => -1);
        expect(r, equals(10));
      });
      test('failure branch fires on failure', () {
        final r = Result<int>.failure(failure).when(success: (v) => v * 2, failure: (_) => -1);
        expect(r, equals(-1));
      });
    });

    group('map()', () {
      test('transforms success value', () {
        final r = Result<int>.success(5).map((v) => v.toString());
        expect(r.value, equals('5'));
      });
      test('propagates failure unchanged', () {
        final r = Result<int>.failure(failure).map((v) => v.toString());
        expect(r.isFailure, isTrue);
      });
    });

    group('flatMap()', () {
      test('chains successful computation', () {
        final r = Result<int>.success(5)
            .flatMap((v) => Result.success(v * 2));
        expect(r.value, equals(10));
      });
      test('short-circuits on failure', () {
        final r = Result<int>.failure(failure)
            .flatMap((v) => Result.success(v * 2));
        expect(r.isFailure, isTrue);
      });
    });

    group('getOrElse()', () {
      test('returns value on success', () {
        expect(Result<int>.success(5).getOrElse(0), equals(5));
      });
      test('returns default on failure', () {
        expect(Result<int>.failure(failure).getOrElse(42), equals(42));
      });
    });

    group('onSuccess/onFailure', () {
      test('onSuccess fires on success', () {
        var fired = false;
        Result<int>.success(1).onSuccess((_) => fired = true);
        expect(fired, isTrue);
      });
      test('onSuccess does not fire on failure', () {
        var fired = false;
        Result<int>.failure(failure).onSuccess((_) => fired = true);
        expect(fired, isFalse);
      });
      test('onFailure fires on failure', () {
        var fired = false;
        Result<int>.failure(failure).onFailure((_) => fired = true);
        expect(fired, isTrue);
      });
    });

    group('resultOf()', () {
      test('wraps successful computation', () async {
        final r = await resultOf(() async => 42);
        expect(r.value, equals(42));
      });
      test('wraps thrown exception as failure', () async {
        final r = await resultOf<int>(() async => throw Exception('boom'));
        expect(r.isFailure, isTrue);
      });
    });
  });
}
