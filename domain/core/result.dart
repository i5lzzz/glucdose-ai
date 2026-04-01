// lib/domain/core/result.dart
// ─────────────────────────────────────────────────────────────────────────────
// Result<T> — discriminated union for domain operations.
//
// WHY NOT raw Either from dartz?
//   dartz.Either is excellent but its left/right semantics are unfamiliar to
//   medical reviewers and produce less readable audit traces.
//   This wrapper preserves Either under the hood while exposing a domain-native
//   API: Result.success / Result.failure / result.when().
//
// RULE: The domain layer NEVER throws. Every failable operation returns
//       Result<T>. Callers are forced by the type system to handle failures.
//       This satisfies IEC 62304 §5.5.3 — software unit acceptance criteria.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';

/// A domain result that is either a [Success] or a [Failure].
///
/// ```dart
/// final result = doseCalculator.calculate(input);
/// result.when(
///   success: (dose) => confirmInjection(dose),
///   failure: (f) => showSafetyAlert(f),
/// );
/// ```
sealed class Result<T> extends Equatable {
  const Result();

  /// Creates a successful result wrapping [value].
  factory Result.success(T value) => Success<T>._(value);

  /// Creates a failed result wrapping [failure].
  factory Result.failure(Failure failure) => FailureResult<T>._(failure);

  // ── Accessors ─────────────────────────────────────────────────────────────

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T get value {
    final self = this;
    if (self is Success<T>) return self._value;
    throw StateError(
      'Called .value on a Failure result. '
      'Always check isSuccess or use .when().',
    );
  }

  Failure get failure {
    final self = this;
    if (self is FailureResult<T>) return self._failure;
    throw StateError('Called .failure on a Success result.');
  }

  T? get valueOrNull => isSuccess ? value : null;
  Failure? get failureOrNull => isFailure ? failure : null;

  // ── Combinators ───────────────────────────────────────────────────────────

  /// Pattern match over success/failure branches.
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) {
    final self = this;
    if (self is Success<T>) return success(self._value);
    return failure((self as FailureResult<T>)._failure);
  }

  /// Transforms the success value; propagates failure unchanged.
  Result<R> map<R>(R Function(T value) transform) {
    final self = this;
    if (self is Success<T>) {
      return Result.success(transform(self._value));
    }
    return Result.failure((self as FailureResult<T>)._failure);
  }

  /// Chains a failable computation onto a success value.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) {
    final self = this;
    if (self is Success<T>) return transform(self._value);
    return Result.failure((self as FailureResult<T>)._failure);
  }

  /// Returns [defaultValue] if this is a failure.
  T getOrElse(T defaultValue) => isSuccess ? value : defaultValue;

  /// Executes [action] on success without transforming the result.
  Result<T> onSuccess(void Function(T value) action) {
    if (isSuccess) action(value);
    return this;
  }

  /// Executes [action] on failure without transforming the result.
  Result<T> onFailure(void Function(Failure f) action) {
    if (isFailure) action(failure);
    return this;
  }

  @override
  List<Object?> get props => [];
}

/// Successful result variant.
final class Success<T> extends Result<T> {
  const Success._(this._value);
  final T _value;

  @override
  List<Object?> get props => [_value];

  @override
  String toString() => 'Success<$T>($_value)';
}

/// Failed result variant.
final class FailureResult<T> extends Result<T> {
  const FailureResult._(this._failure);
  final Failure _failure;

  @override
  List<Object?> get props => [_failure];

  @override
  String toString() => 'Failure<$T>($_failure)';
}

// ── Async convenience ─────────────────────────────────────────────────────────

/// Wraps an async computation in a Result, catching all exceptions.
/// Use ONLY at the boundary between domain and data layers.
Future<Result<T>> resultOf<T>(Future<T> Function() computation) async {
  try {
    return Result.success(await computation());
  } on Failure catch (f) {
    return Result.failure(f);
  } catch (e, st) {
    return Result.failure(
      UnexpectedFailure('Unhandled exception: $e\n$st'),
    );
  }
}
