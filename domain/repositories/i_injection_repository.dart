// lib/domain/repositories/i_injection_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Domain-layer repository contracts.
//
// ARCHITECTURE RULE:
//   The domain layer DEFINES the repository interfaces.
//   The data layer IMPLEMENTS them.
//   Use-cases depend only on these interfaces — never on implementations.
//   This enables:
//     1. Testing use-cases with in-memory mock repositories
//     2. Swapping SQLite for a cloud DB without changing use-cases
//     3. Clear boundary between domain and data concerns
//
// RETURN TYPES:
//   All operations return Result<T> — never throw.
//   Callers must explicitly handle both success and failure.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/data/datasources/local/database_extensions.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';
import 'package:insulin_assistant/domain/entities/glucose_reading.dart';
import 'package:insulin_assistant/domain/entities/calculation_trace.dart';
import 'package:insulin_assistant/domain/entities/glucose_prediction.dart';

// ── IInjectionRepository ──────────────────────────────────────────────────────

abstract interface class IInjectionRepository {
  /// Persists a new injection record.
  Future<Result<void>> save(InjectionRecord injection);

  /// Confirms a pending injection (updates status).
  Future<Result<void>> confirm(String injectionId);

  /// Cancels a pending injection.
  Future<Result<void>> cancel(String injectionId);

  /// Retrieves a single injection by [id].
  Future<Result<InjectionRecord>> findById(String id);

  /// Returns all confirmed injections for [userId] since [since].
  /// Used by the IOB calculator — only confirmed injections contribute to IOB.
  Future<Result<List<InjectionRecord>>> findConfirmedSince({
    required String userId,
    required DateTime since,
  });

  /// Returns paginated injection history for [userId].
  Future<Result<List<InjectionRecord>>> findByUser({
    required String userId,
    required PaginationParams pagination,
    DateRangeFilter? dateRange,
  });

  /// Returns the most recent confirmed injection for [userId].
  Future<Result<InjectionRecord?>> findMostRecent(String userId);

  /// Batch-inserts multiple records (used for data import).
  Future<Result<int>> saveAll(List<InjectionRecord> injections);

  /// Counts total injections for [userId] (for UI stats).
  Future<Result<int>> countByUser(String userId);
}

// ── IGlucoseReadingRepository ─────────────────────────────────────────────────

abstract interface class IGlucoseReadingRepository {
  Future<Result<void>> save(GlucoseReading reading);

  Future<Result<GlucoseReading>> findById(String id);

  /// Returns the most recent reading for [userId].
  Future<Result<GlucoseReading?>> findMostRecent(String userId);

  /// Returns all readings in [dateRange] for the insight engine.
  Future<Result<List<GlucoseReading>>> findByUser({
    required String userId,
    required PaginationParams pagination,
    DateRangeFilter? dateRange,
  });

  /// Returns readings in a specific time window (for pattern analysis).
  Future<Result<List<GlucoseReading>>> findInWindow({
    required String userId,
    required DateTime from,
    required DateTime to,
  });

  Future<Result<int>> countByUser(String userId);
}

// ── ICalculationTraceRepository ───────────────────────────────────────────────

abstract interface class ICalculationTraceRepository {
  /// Persists a new [CalculationTrace] with [outcome] status.
  Future<Result<void>> save(
    CalculationTrace trace, {
    String outcome,
  });

  /// Updates the outcome of an existing trace (pending → confirmed/cancelled).
  Future<Result<void>> updateOutcome(String traceId, String outcome);

  Future<Result<CalculationTrace>> findById(String id);

  Future<Result<List<CalculationTrace>>> findByUser({
    required String userId,
    required PaginationParams pagination,
    DateRangeFilter? dateRange,
  });

  /// Returns traces with a specific algorithm version (for regression analysis).
  Future<Result<List<CalculationTrace>>> findByAlgorithmVersion({
    required String userId,
    required String algorithmVersion,
    required PaginationParams pagination,
  });

  Future<Result<int>> countByUser(String userId);
}

// ── IGlucosePredictionRepository ──────────────────────────────────────────────

abstract interface class IGlucosePredictionRepository {
  Future<Result<void>> save(GlucosePrediction prediction);

  Future<Result<GlucosePrediction>> findById(String id);

  Future<Result<GlucosePrediction?>> findByTraceId(String traceId);

  Future<Result<List<GlucosePrediction>>> findByUser({
    required String userId,
    required PaginationParams pagination,
  });

  /// Returns predictions that predicted hypo risk (for accuracy analysis).
  Future<Result<List<GlucosePrediction>>> findWithHypoRisk(String userId);

  Future<Result<int>> countByUser(String userId);
}
