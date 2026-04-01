// lib/data/repositories/glucose_prediction_repository_impl.dart

import 'dart:convert';

import 'package:insulin_assistant/core/database/database_manager.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/core/security/encryption_service.dart';
import 'package:insulin_assistant/data/datasources/local/database_extensions.dart';
import 'package:insulin_assistant/data/mappers/encryption_mapper.dart';
import 'package:insulin_assistant/data/models/glucose_prediction_dto.dart';
import 'package:insulin_assistant/data/repositories/base_repository.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/entities/glucose_prediction.dart';
import 'package:insulin_assistant/domain/repositories/i_injection_repository.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';

final class GlucosePredictionRepositoryImpl extends BaseRepository
    implements IGlucosePredictionRepository {
  GlucosePredictionRepositoryImpl({
    required DatabaseManager dbManager,
    required EncryptionService encryptionService,
  })  : _enc = EncryptionMapper(encryptionService),
        super(dbManager);

  final EncryptionMapper _enc;
  static const _table = 'predictions';

  @override
  Future<Result<void>> save(GlucosePrediction prediction) async {
    return guardedWrite(
      (db) async {
        final dto = await _toDTO(prediction);
        await db.insert(
          _table,
          dto.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      },
      context: 'PredictionRepository.save(${prediction.id})',
    );
  }

  @override
  Future<Result<GlucosePrediction>> findById(String id) async {
    final rowResult = await guardedQuery(
      (db) => db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1),
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);

    final rows = rowResult.value;
    if (rows.isEmpty) {
      return Result.failure(NotFoundFailure('GlucosePrediction not found: $id'));
    }
    return _mapRow(rows.first);
  }

  @override
  Future<Result<GlucosePrediction?>> findByTraceId(String traceId) async {
    final rowResult = await guardedQuery(
      (db) => db.query(
        _table,
        where: 'linked_trace_id = ?',
        whereArgs: [traceId],
        limit: 1,
      ),
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);

    final rows = rowResult.value;
    if (rows.isEmpty) return Result.success(null);
    final r = await _mapRow(rows.first);
    return r.map((p) => p as GlucosePrediction?);
  }

  @override
  Future<Result<List<GlucosePrediction>>> findByUser({
    required String userId,
    required PaginationParams pagination,
  }) async {
    final rowResult = await guardedQuery(
      (db) => db.query(
        _table,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'generated_at DESC',
        limit: pagination.limit,
        offset: pagination.offset,
      ),
    );
    if (rowResult.isFailure) return Result.failure(rowResult.failure);
    return _mapRows(rowResult.value);
  }

  @override
  Future<Result<List<GlucosePrediction>>> findWithHypoRisk(
      String userId) async {
    final rowResult = await guardedQuery(
      (db) => db.query(
        _table,
        where: 'user_id = ? AND has_hypo_risk = 1',
        whereArgs: [userId],
        orderBy: 'generated_at DESC',
        limit: 100,
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

  Future<GlucosePredictionDTO> _toDTO(GlucosePrediction prediction) async {
    final jsonMap = prediction.toJson();
    final encJson = await _enc.encryptJson(jsonMap);

    return GlucosePredictionDTO(
      id: prediction.id,
      userId: prediction.userId,
      generatedAt: prediction.generatedAt.toUtc().toIso8601String(),
      predictionJsonEnc: encJson,
      modelVersion: prediction.modelVersion,
      linkedTraceId: prediction.linkedTraceId,
      hasHypoRisk: prediction.hasHypoRisk ? 1 : 0,
      hasCriticalHypoRisk: prediction.points
              .any((p) => p.risk == PredictionRisk.hypo)
          ? 1
          : 0,
      hasHyperRisk: prediction.hasHyperRisk ? 1 : 0,
    );
  }

  Future<Result<GlucosePrediction>> _mapRow(
      Map<String, dynamic> row) async {
    try {
      final dto = GlucosePredictionDTO.fromMap(row);
      final jsonMap = await _enc.decryptJson(dto.predictionJsonEnc);
      final prediction = _fromJson(dto, jsonMap);
      return Result.success(prediction);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('GlucosePrediction decryption failed: $e'),
      );
    }
  }

  GlucosePrediction _fromJson(
    GlucosePredictionDTO dto,
    Map<String, dynamic> json,
  ) {
    final pointsJson = json['points'] as List<dynamic>? ?? [];
    final points = pointsJson.map((p) {
      final pm = p as Map<String, dynamic>;
      final bgResult = BloodGlucose.fromMgdl(
        (pm['predicted_bg_mgdl'] as num).toDouble(),
      );
      return PredictedPoint(
        minutesAhead: pm['minutes_ahead'] as int,
        predictedBG: bgResult.getOrElse(BloodGlucose.fromMgdl(100).value),
        risk: PredictionRisk.values.byName(pm['risk'] as String),
        confidence: (pm['confidence'] as num).toDouble(),
      );
    }).toList();

    return GlucosePrediction(
      id: dto.id,
      userId: dto.userId,
      generatedAt: DateTime.parse(dto.generatedAt),
      points: points,
      modelVersion: dto.modelVersion,
      isHybridModel: json['is_hybrid'] as bool? ?? true,
      recommendedCarbIntakeGrams:
          (json['recommended_carbs_g'] as num?)?.toDouble(),
      recommendedCorrectionDose:
          (json['recommended_correction_u'] as num?)?.toDouble(),
    );
  }

  Future<Result<List<GlucosePrediction>>> _mapRows(
    List<Map<String, dynamic>> rows,
  ) async {
    final results = <GlucosePrediction>[];
    for (final row in rows) {
      final r = await _mapRow(row);
      if (r.isFailure) return Result.failure(r.failure);
      results.add(r.value);
    }
    return Result.success(results);
  }
}
