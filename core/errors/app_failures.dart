// lib/core/errors/app_failures.dart
// ─────────────────────────────────────────────────────────────────────────────
// Typed failure hierarchy.
// All repository and use-case return types use Either<Failure, T> from dartz,
// ensuring errors are handled explicitly — no implicit exception propagation
// in business logic (required for IEC 62304 §5.5.3 error handling).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Base failure type.  All domain errors extend this.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

// ── Medical Safety Failures ───────────────────────────────────────────────────

/// Raised when a calculation is blocked due to safety rules.
final class SafetyBlockFailure extends Failure {
  const SafetyBlockFailure(super.message, {super.code, required this.reason});
  final SafetyBlockReason reason;

  @override
  List<Object?> get props => [...super.props, reason];
}

/// Raised for input validation errors in the medical domain.
final class MedicalValidationFailure extends Failure {
  const MedicalValidationFailure(super.message,
      {super.code, required this.field});
  final String field;
}

/// Raised when dose calculation produces a clinically implausible result.
final class ImplausibleDoseFailure extends Failure {
  const ImplausibleDoseFailure(super.message,
      {super.code, required this.calculatedDose});
  final double calculatedDose;
}

// ── Data Layer Failures ───────────────────────────────────────────────────────

final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.code});
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.code});
}

// ── Network Failures (future-proofing for cloud sync) ────────────────────────

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code, this.statusCode});
  final int? statusCode;
}

// ── AI / Prediction Failures ─────────────────────────────────────────────────

final class ModelLoadFailure extends Failure {
  const ModelLoadFailure(super.message, {super.code});
}

final class PredictionFailure extends Failure {
  const PredictionFailure(super.message, {super.code});
}

// ── General ───────────────────────────────────────────────────────────────────

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.code});
}

// ── Safety Block Reason Enum ─────────────────────────────────────────────────

/// Reason codes for [SafetyBlockFailure].
/// These map 1-to-1 with the risk register entries in RISK_MATRIX.md.
enum SafetyBlockReason {
  /// BG < 40 — absolute hard block.
  level2Hypoglycaemia,

  /// BG < 70 — soft block requiring confirmed override.
  level1Hypoglycaemia,

  /// Calculated dose exceeds absolute ceiling.
  doseExceedsAbsoluteCeiling,

  /// Calculated dose exceeds user-defined ceiling.
  doseExceedsUserCeiling,

  /// IOB stacking would result in unsafe total active insulin.
  iobStackingDetected,

  /// User has not completed profile (missing ICR, ISF, target BG).
  incompleteProfile,

  /// Negative dose calculated — indicates severe overcorrection.
  negativeDoseCalculated,

  /// Encryption self-test failure during bootstrap.
  encryptionFailure,
}
