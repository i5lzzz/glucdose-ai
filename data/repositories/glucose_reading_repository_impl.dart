// lib/data/repositories/glucose_reading_repository_impl.dart

import 'package:insulin_assistant/core/database/database_manager.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/core/security/encryption_service.dart';
import 'package:insulin_assistant/data/datasources/local/database_extensions.dart';
import 'package:insulin_assistant/data/mappers/encryption_mapper.dart';
import 'package:insulin_assistant/data/models/glucose_reading_dto.dart';
import 'package:insulin_assistant/data/repositories/base_repository.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/entities/glucose_reading.dart';
import 'package:insulin_assistant/domain/repositories/i_injection_repository.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';

final class GlucoseReadingRepositoryImpl extends BaseRepository
    implements IGlucoseReadingRepository {
  GlucoseReadingRepositoryImpl({
    required DatabaseManager dbManager,
    required EncryptionService encryptionService,
  })  : _enc = EncryptionMapper(encryptionService),
        super(dbManager);

  final EncryptionMapper _enc;
  static const _table = DatabaseManager.tableGlucoseReadings;

  // ── Write ─────────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> save(GlucoseReading reading) async {
    return guardedWrite(
      (db) async {
        final dto = await _toDTO(reading);
        await db.insert(
          _table,
          dto.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      },
      context: 'GlucoseReadingRepository.save(${reading.id})',
    );
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  @override
  Future<Result<GlucoseReading>> findById(String id) async {
    final rowResult = await guardedQuery(
      (db) => db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1),
      context: 'GlucoseReadingRepository.findById($id)',
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);

    final rows = rowResult.value;
    if (rows.isEmpty) {
      return Result.failure(NotFoundFailure('GlucoseReading not found: $id'));
    }
    return _mapRow(rows.first);
  }

  @override
  Future<Result<GlucoseReading?>> findMostRecent(String userId) async {
    final rowResult = await guardedQuery(
      (db) => db.query(
        _table,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'recorded_at DESC',
        limit: 1,
      ),
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);

    final rows = rowResult.value;
    if (rows.isEmpty) return Result.success(null);
    final result = await _mapRow(rows.first);
    return result.map((r) => r as GlucoseReading?);
  }

  @override
  Future<Result<List<GlucoseReading>>> findByUser({
    required String userId,
    required PaginationParams pagination,
    DateRangeFilter? dateRange,
  }) async {
    final qb = QueryBuilder().eq('user_id', userId);
    dateRange?.applyTo(qb, 'recorded_at');

    final rowResult = await guardedQuery(
      (db) => db.query(
        _table,
        where: qb.whereClause,
        whereArgs: qb.whereArgs,
        orderBy: 'recorded_at DESC',
        limit: pagination.limit,
        offset: pagination.offset,
      ),
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);
    return _mapRows(rowResult.value);
  }

  @override
  Future<Result<List<GlucoseReading>>> findInWindow({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rowResult = await guardedQuery(
      (db) => db.query(
        _table,
        where: 'user_id = ? AND recorded_at >= ? AND recorded_at <= ?',
        whereArgs: [
          userId,
          from.toUtc().toIso8601String(),
          to.toUtc().toIso8601String(),
        ],
        orderBy: 'recorded_at ASC',
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

  // ── Mapping ───────────────────────────────────────────────────────────────

  Future<GlucoseReadingDTO> _toDTO(GlucoseReading reading) async {
    return GlucoseReadingDTO(
      id: reading.id,
      userId: reading.userId,
      recordedAt: reading.recordedAt.toUtc().toIso8601String(),
      valueEnc: await _enc.encryptDouble(reading.value.mgdl),
      source: reading.source.name,
      trend: reading.trend.name,
      notesEnc: reading.notes != null
          ? await _enc.encryptString(reading.notes!)
          : null,
    );
  }

  Future<Result<GlucoseReading>> _mapRow(Map<String, dynamic> row) async {
    try {
      final dto = GlucoseReadingDTO.fromMap(row);
      final bgMgdl = await _enc.decryptDouble(dto.valueEnc);
      final bgResult = BloodGlucose.fromMgdl(bgMgdl);
      if (bgResult.isFailure) return Result.failure(bgResult.failure);

      final trend = dto.trend != null
          ? GlucoseTrend.values.byName(dto.trend!)
          : GlucoseTrend.unknown;

      final notes =
          dto.notesEnc != null ? await _enc.decryptOptionalString(dto.notesEnc) : null;

      return Result.success(
        GlucoseReading(
          id: dto.id,
          userId: dto.userId,
          recordedAt: DateTime.parse(dto.recordedAt),
          value: bgResult.value,
          source: GlucoseSource.values.byName(dto.source),
          trend: trend,
          notes: notes,
        ),
      );
    } catch (e) {
      return Result.failure(
        DatabaseFailure('GlucoseReading decryption failed: $e'),
      );
    }
  }

  Future<Result<List<GlucoseReading>>> _mapRows(
    List<Map<String, dynamic>> rows,
  ) async {
    final results = <GlucoseReading>[];
    for (final row in rows) {
      final r = await _mapRow(row);
      if (r.isFailure) return Result.failure(r.failure);
      results.add(r.value);
    }
    return Result.success(results);
  }
}
