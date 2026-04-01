// lib/domain/core/value_object.dart
// ─────────────────────────────────────────────────────────────────────────────
// ValueObject<T> — base for all domain value objects.
//
// Value objects are:
//   1. Immutable — no setters, all fields final
//   2. Self-validating — construction fails loudly with a typed failure
//   3. Equality by value — not by identity
//   4. Serialisable — every VO exposes .toJson() and a fromJson factory
//
// Construction always goes through the named factory constructor which
// returns Result<VO>.  The private constructor is only called after
// validation passes, guaranteeing no VO exists in an invalid state.
//
// This pattern satisfies the "Always Valid Domain Model" principle and
// eliminates an entire class of medical calculation errors caused by
// unvalidated inputs reaching algorithmic functions.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/core/result.dart';

/// Immutable value object base.
///
/// [T] is the primitive representation (double, int, String, …).
abstract base class ValueObject<T> extends Equatable {
  const ValueObject(this.value);

  final T value;

  /// Returns the validated value object or a [MedicalValidationFailure].
  static Result<VO> validate<VO extends ValueObject<Object?>>(
    VO Function() constructor,
  ) {
    try {
      return Result.success(constructor());
    } on ValidationException catch (e) {
      return Result.failure(
        MedicalValidationFailure(e.message, field: e.field),
      );
    }
  }

  @override
  List<Object?> get props => [value];

  @override
  String toString() => '$runtimeType($value)';
}

/// Thrown inside value object constructors when validation fails.
/// Only caught by [ValueObject.validate] — NEVER propagates to domain logic.
final class ValidationException implements Exception {
  const ValidationException({required this.message, required this.field});
  final String message;
  final String field;
}

// ── Validation helpers ────────────────────────────────────────────────────────

/// Asserts [condition] is true or throws [ValidationException].
void assertValid({
  required bool condition,
  required String message,
  required String field,
}) {
  if (!condition) throw ValidationException(message: message, field: field);
}

/// Asserts [value] is finite and not NaN.
void assertFinite(double value, {required String field}) {
  assertValid(
    condition: value.isFinite,
    message: '$field must be a finite number (got $value)',
    field: field,
  );
}

/// Asserts [value] is within [min]..[max] inclusive.
void assertRange(
  double value, {
  required double min,
  required double max,
  required String field,
}) {
  assertFinite(value, field: field);
  assertValid(
    condition: value >= min && value <= max,
    message: '$field must be between $min and $max (got $value)',
    field: field,
  );
}
