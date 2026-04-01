// lib/data/repositories/calculation_trace_repository_impl.dart

import 'package:insulin_assistant/core/database/database_manager.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/data/datasources/local/database_extensions.dart';
import 'package:insulin_assistant/data/mappers/calculation_trace_mapper.dart';
import 'package:insulin_assistant/data/models/calculation_trace_dto.dart';
import 'package:insulin_assistant/data/repositories/base_repository.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/entities/calculation_trace.dart';
import 'package:insulin_assistant/domain/repositories/i_injection_repository.dart';

final class CalculationTraceRepositoryImpl extends BaseRepository
    implements ICalculationTraceRepository {
  CalculationTraceRepositoryImpl({
    required DatabaseManager dbManager,
    required CalculationTraceMapper mapper,
  })  : _mapper = mapper,
        super(dbManager);

  final CalculationTraceMapper _mapper;
  static const _table = DatabaseManager.tableDoseHistory;

  @override
  Future<Result<void>> save(
    CalculationTrace trace, {
    String outcome = 'pending',
  }) async {
    return guardedWrite(
      (db) async {
        final dto = await _mapper.toDTO(trace, outcome: outcome);
        await db.insert(
          _table,
          dto.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      },
      context: 'TraceRepository.save(${trace.id})',
    );
  }

  @override
  Future<Result<void>> updateOutcome(String traceId, String outcome) async {
    return guardedWrite(
      (db) => db.update(
        _table,
        {'outcome': outcome},
        where: 'id = ?',
        whereArgs: [traceId],
      ) as Future<void>,
      context: 'TraceRepository.updateOutcome($traceId)',
    );
  }

  @override
  Future<Result<CalculationTrace>> findById(String id) async {
    final rowResult = await guardedQuery(
      (db) => db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1),
      context: 'TraceRepository.findById($id)',
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);

    final rows = rowResult.value;
    if (rows.isEmpty) {
      return Result.failure(NotFoundFailure('CalculationTrace not found: $id'));
    }

    final dto = CalculationTraceDTO.fromMap(rows.first);
    return _mapper.toDomain(dto);
  }

  @override
  Future<Result<List<CalculationTrace>>> findByUser({
    required String userId,
    required PaginationParams pagination,
    DateRangeFilter? dateRange,
  }) async {
    final qb = QueryBuilder().eq('user_id', userId);
    dateRange?.applyTo(qb, 'calculated_at');

    final rowResult = await guardedQuery(
      (db) => db.query(
        _table,
        where: qb.whereClause,
        whereArgs: qb.whereArgs,
        orderBy: 'calculated_at DESC',
        limit: pagination.limit,
        offset: pagination.offset,
      ),
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);
    return _mapRows(rowResult.value);
  }

  @override
  Future<Result<List<CalculationTrace>>> findByAlgorithmVersion({
    required String userId,
    required String algorithmVersion,
    required PaginationParams pagination,
  }) async {
    final rowResult = await guardedQuery(
      (db) => db.query(
        _table,
        where: 'user_id = ? AND algorithm_version = ?',
        whereArgs: [userId, algorithmVersion],
        orderBy: 'calculated_at DESC',
        limit: pagination.limit,
        offset: pagination.offset,
      ),
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);
    return _mapRows(rowResult.value);
  }

  @override
  Future<Result<int>> countByUser(String userId) async {
    return guardedQuery(
      (db) async {
        final r = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM $_table WHERE user_id = ?',
          [userId],
        );
        return r.first['cnt'] as int? ?? 0;
      },
    );
  }

  Future<Result<List<CalculationTrace>>> _mapRows(
    List<Map<String, dynamic>> rows,
  ) async {
    final results = <CalculationTrace>[];
    for (final row in rows) {
      final dto = CalculationTraceDTO.fromMap(row);
      final r = await _mapper.toDomain(dto);
      if (r.isFailure) return Result.failure(r.failure);
      results.add(r.value);
    }
    return Result.success(results);
  }
}
