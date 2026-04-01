// lib/data/repositories/base_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// BaseRepository — shared infrastructure for all repository implementations.
//
// Provides:
//   1. [guardedQuery] — wraps any DB operation in Result, catches all exceptions
//   2. [guardedWrite] — same for writes, with explicit transaction support
//   3. Direct [db] access for repositories that need raw queries
//
// EXCEPTION STRATEGY:
//   SQLite operations can throw SqfliteDatabaseException (schema errors,
//   constraint violations), EncryptionFailure (key corruption), or
//   unexpected Dart exceptions.  [guardedQuery] / [guardedWrite] catch all
//   of these and return [Result.failure] with a [DatabaseFailure].
//
//   No repository method ever throws — callers always receive a Result.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:sqflite/sqflite.dart';

import 'package:insulin_assistant/core/database/database_manager.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/core/result.dart';

abstract base class BaseRepository {
  const BaseRepository(this._dbManager);

  final DatabaseManager _dbManager;

  /// Returns the open database.
  Future<Database> get db => _dbManager.database;

  /// Wraps a read query in a Result, catching all exceptions.
  Future<Result<T>> guardedQuery<T>(
    Future<T> Function(Database db) query, {
    String? context,
  }) async {
    try {
      final database = await db;
      final result = await query(database);
      return Result.success(result);
    } on DatabaseException catch (e) {
      return Result.failure(
        DatabaseFailure(
          '${context ?? 'Query'} failed (SQLite): ${e.toString()}',
          code: 'SQLITE_ERROR',
        ),
      );
    } catch (e, st) {
      return Result.failure(
        DatabaseFailure(
          '${context ?? 'Query'} failed: $e\n$st',
          code: 'UNEXPECTED',
        ),
      );
    }
  }

  /// Wraps a write operation in a Result.
  Future<Result<void>> guardedWrite(
    Future<void> Function(Database db) write, {
    String? context,
  }) async {
    try {
      final database = await db;
      await write(database);
      return Result.success(null);
    } on DatabaseException catch (e) {
      return Result.failure(
        DatabaseFailure(
          '${context ?? 'Write'} failed (SQLite): ${e.toString()}',
          code: 'SQLITE_WRITE_ERROR',
        ),
      );
    } catch (e, st) {
      return Result.failure(
        DatabaseFailure(
          '${context ?? 'Write'} failed: $e\n$st',
          code: 'UNEXPECTED_WRITE',
        ),
      );
    }
  }

  /// Wraps operations in an explicit SQLite transaction.
  Future<Result<T>> guardedTransaction<T>(
    Future<T> Function(Transaction txn) operations, {
    String? context,
  }) async {
    try {
      final database = await db;
      final result = await database.transaction(operations);
      return Result.success(result);
    } on DatabaseException catch (e) {
      return Result.failure(
        DatabaseFailure(
          '${context ?? 'Transaction'} failed: ${e.toString()}',
          code: 'TXN_ERROR',
        ),
      );
    } catch (e, st) {
      return Result.failure(
        DatabaseFailure(
          '${context ?? 'Transaction'} failed: $e\n$st',
          code: 'UNEXPECTED_TXN',
        ),
      );
    }
  }

  /// Convenience: maps a nullable row to NotFoundFailure.
  Result<T> rowOrNotFound<T>(
    Map<String, dynamic>? row,
    T Function(Map<String, dynamic>) fromMap,
    String entityName,
    String id,
  ) {
    if (row == null) {
      return Result.failure(
        NotFoundFailure('$entityName not found: $id'),
      );
    }
    return Result.success(fromMap(row));
  }
}
