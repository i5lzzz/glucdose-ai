// lib/data/datasources/local/database_extensions.dart
// ─────────────────────────────────────────────────────────────────────────────
// Database extension utilities.
//
// Provides:
//   - SafeBatch — wraps SQLite batch in a try/catch, rolls back on error
//   - QueryBuilder — fluent WHERE clause construction
//   - PaginationParams — standard limit/offset container
//   - DateRangeFilter — UTC ISO-8601 range filtering
// ─────────────────────────────────────────────────────────────────────────────

import 'package:sqflite/sqflite.dart';

import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/core/result.dart';

// ── SafeBatch ─────────────────────────────────────────────────────────────────

/// Executes a SQLite batch, rolling back all operations if any fails.
///
/// In WAL mode, each batch is an implicit transaction.
/// This wrapper catches exceptions and wraps them in [Result.failure].
Future<Result<int>> executeSafeBatch(
  Database db,
  Future<void> Function(Batch batch) operations,
) async {
  final batch = db.batch();
  try {
    await operations(batch);
    final results = await batch.commit(noResult: false, continueOnError: false);
    return Result.success(results.length);
  } catch (e, st) {
    return Result.failure(
      DatabaseFailure(
        'Batch operation failed: $e',
        code: 'BATCH_FAIL',
      ),
    );
  }
}

// ── QueryBuilder ──────────────────────────────────────────────────────────────

/// Builds parameterised WHERE clauses to avoid string concatenation (SQL injection
/// prevention) and simplify multi-condition queries.
final class QueryBuilder {
  final List<String> _conditions = [];
  final List<dynamic> _args = [];

  QueryBuilder eq(String column, dynamic value) {
    _conditions.add('$column = ?');
    _args.add(value);
    return this;
  }

  QueryBuilder gte(String column, dynamic value) {
    _conditions.add('$column >= ?');
    _args.add(value);
    return this;
  }

  QueryBuilder lte(String column, dynamic value) {
    _conditions.add('$column <= ?');
    _args.add(value);
    return this;
  }

  QueryBuilder gt(String column, dynamic value) {
    _conditions.add('$column > ?');
    _args.add(value);
    return this;
  }

  QueryBuilder inList(String column, List<dynamic> values) {
    if (values.isEmpty) return this;
    final placeholders = List.filled(values.length, '?').join(', ');
    _conditions.add('$column IN ($placeholders)');
    _args.addAll(values);
    return this;
  }

  QueryBuilder isNull(String column) {
    _conditions.add('$column IS NULL');
    return this;
  }

  QueryBuilder isNotNull(String column) {
    _conditions.add('$column IS NOT NULL');
    return this;
  }

  QueryBuilder intFlag(String column, int value) => eq(column, value);

  String? get whereClause =>
      _conditions.isEmpty ? null : _conditions.join(' AND ');

  List<dynamic>? get whereArgs => _args.isEmpty ? null : _args;
}

// ── PaginationParams ──────────────────────────────────────────────────────────

/// Standard pagination parameters.
final class PaginationParams {
  const PaginationParams({
    required this.pageIndex,
    required this.pageSize,
  }) : assert(pageIndex >= 0),
       assert(pageSize > 0);

  final int pageIndex;
  final int pageSize;

  static const PaginationParams firstPage = PaginationParams(
    pageIndex: 0,
    pageSize: 20,
  );

  int get offset => pageIndex * pageSize;
  int get limit => pageSize;

  PaginationParams get next =>
      PaginationParams(pageIndex: pageIndex + 1, pageSize: pageSize);
}

// ── DateRangeFilter ───────────────────────────────────────────────────────────

/// Applies a UTC ISO-8601 date range to a [QueryBuilder].
final class DateRangeFilter {
  const DateRangeFilter({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  /// Adds `column >= from AND column <= to` conditions to [builder].
  void applyTo(QueryBuilder builder, String column) {
    if (from != null) builder.gte(column, from!.toUtc().toIso8601String());
    if (to != null) builder.lte(column, to!.toUtc().toIso8601String());
  }

  static DateRangeFilter last24Hours() {
    final now = DateTime.now().toUtc();
    return DateRangeFilter(from: now.subtract(const Duration(hours: 24)));
  }

  static DateRangeFilter last7Days() {
    final now = DateTime.now().toUtc();
    return DateRangeFilter(from: now.subtract(const Duration(days: 7)));
  }

  static DateRangeFilter last30Days() {
    final now = DateTime.now().toUtc();
    return DateRangeFilter(from: now.subtract(const Duration(days: 30)));
  }
}
