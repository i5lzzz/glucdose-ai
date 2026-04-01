// lib/data/repositories/injection_repository_impl.dart

import 'package:insulin_assistant/core/database/database_manager.dart';
import 'package:insulin_assistant/data/datasources/local/database_extensions.dart';
import 'package:insulin_assistant/data/mappers/encryption_mapper.dart';
import 'package:insulin_assistant/data/mappers/injection_record_mapper.dart';
import 'package:insulin_assistant/data/models/injection_record_dto.dart';
import 'package:insulin_assistant/data/repositories/base_repository.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';
import 'package:insulin_assistant/domain/repositories/i_injection_repository.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';

final class InjectionRepositoryImpl extends BaseRepository
    implements IInjectionRepository {
  InjectionRepositoryImpl({
    required DatabaseManager dbManager,
    required InjectionRecordMapper mapper,
  })  : _mapper = mapper,
        super(dbManager);

  final InjectionRecordMapper _mapper;
  static const _table = DatabaseManager.tableInjections;

  // ── Write operations ──────────────────────────────────────────────────────

  @override
  Future<Result<void>> save(InjectionRecord injection) async {
    return guardedWrite(
      (db) async {
        final dto = await _mapper.toDTO(injection);
        await db.insert(
          _table,
          dto.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      },
      context: 'InjectionRepository.save(${injection.id})',
    );
  }

  @override
  Future<Result<void>> confirm(String injectionId) async {
    return guardedWrite(
      (db) async {
        await db.update(
          _table,
          {'status': InjectionStatus.confirmed.name, 'confirmed': 1},
          where: 'id = ?',
          whereArgs: [injectionId],
        );
      },
      context: 'InjectionRepository.confirm($injectionId)',
    );
  }

  @override
  Future<Result<void>> cancel(String injectionId) async {
    return guardedWrite(
      (db) async {
        await db.update(
          _table,
          {'status': InjectionStatus.cancelled.name, 'confirmed': 0},
          where: 'id = ?',
          whereArgs: [injectionId],
        );
      },
      context: 'InjectionRepository.cancel($injectionId)',
    );
  }

  @override
  Future<Result<int>> saveAll(List<InjectionRecord> injections) async {
    return guardedTransaction(
      (txn) async {
        for (final injection in injections) {
          final dto = await _mapper.toDTO(injection);
          await txn.insert(
            _table,
            dto.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        return injections.length;
      },
      context: 'InjectionRepository.saveAll(${injections.length})',
    );
  }

  // ── Read operations ───────────────────────────────────────────────────────

  @override
  Future<Result<InjectionRecord>> findById(String id) async {
    final rowResult = await guardedQuery(
      (db) => db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1),
      context: 'InjectionRepository.findById($id)',
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);

    final rows = rowResult.value;
    if (rows.isEmpty) {
      return Result.failure(NotFoundFailure('Injection not found: $id'));
    }

    final dto = InjectionRecordDTO.fromMap(rows.first);
    return _mapper.toDomain(dto);
  }

  @override
  Future<Result<InjectionRecord?>> findMostRecent(String userId) async {
    final rowResult = await guardedQuery(
      (db) => db.query(
        _table,
        where: 'user_id = ? AND confirmed = 1',
        whereArgs: [userId],
        orderBy: 'injected_at DESC',
        limit: 1,
      ),
      context: 'InjectionRepository.findMostRecent($userId)',
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);

    final rows = rowResult.value;
    if (rows.isEmpty) return Result.success(null);

    final dto = InjectionRecordDTO.fromMap(rows.first);
    final domainResult = await _mapper.toDomain(dto);
    return domainResult.map((r) => r as InjectionRecord?);
  }

  @override
  Future<Result<List<InjectionRecord>>> findConfirmedSince({
    required String userId,
    required DateTime since,
  }) async {
    final rowResult = await guardedQuery(
      (db) => db.query(
        _table,
        where: 'user_id = ? AND confirmed = 1 AND injected_at >= ?',
        whereArgs: [userId, since.toUtc().toIso8601String()],
        orderBy: 'injected_at DESC',
      ),
      context: 'InjectionRepository.findConfirmedSince',
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);

    return _mapRows(rowResult.value);
  }

  @override
  Future<Result<List<InjectionRecord>>> findByUser({
    required String userId,
    required PaginationParams pagination,
    DateRangeFilter? dateRange,
  }) async {
    final qb = QueryBuilder().eq('user_id', userId);
    dateRange?.applyTo(qb, 'injected_at');

    final rowResult = await guardedQuery(
      (db) => db.query(
        _table,
        where: qb.whereClause,
        whereArgs: qb.whereArgs,
        orderBy: 'injected_at DESC',
        limit: pagination.limit,
        offset: pagination.offset,
      ),
      context: 'InjectionRepository.findByUser($userId)',
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);

    return _mapRows(rowResult.value);
  }

  @override
  Future<Result<int>> countByUser(String userId) async {
    return guardedQuery(
      (db) async {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM $_table WHERE user_id = ?',
          [userId],
        );
        return result.first['cnt'] as int? ?? 0;
      },
      context: 'InjectionRepository.countByUser($userId)',
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<Result<List<InjectionRecord>>> _mapRows(
    List<Map<String, dynamic>> rows,
  ) async {
    final results = <InjectionRecord>[];
    for (final row in rows) {
      final dto = InjectionRecordDTO.fromMap(row);
      final domain = await _mapper.toDomain(dto);
      if (domain.isFailure) return Result.failure(domain.failure);
      results.add(domain.value);
    }
    return Result.success(results);
  }
}
