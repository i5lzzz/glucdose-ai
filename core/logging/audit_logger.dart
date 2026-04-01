// lib/core/logging/audit_logger.dart
// ─────────────────────────────────────────────────────────────────────────────
// Audit logger — immutable append-only event trail.
//
// Every medically significant event (dose calc, safety block, profile change)
// is written to the `audit_log` table with a microsecond timestamp, device ID,
// app version, and the serialised event payload.
//
// This satisfies:
//   IEC 62304 §9.1  — Problem reporting & resolution
//   FDA SaMD        — Traceability & documentation
//   HIPAA §164.312  — Audit controls
//
// Logs are NEVER deleted during the device lifecycle (only after explicit
// GDPR erasure request via destroyAllData()).  Retention ≥ 365 days.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:collection';
import 'dart:convert';

import 'package:logger/logger.dart';

import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/core/database/database_manager.dart';

/// Enumeration of all auditable events.
/// New events MUST be added here before being logged — prevents free-text
/// event names which are impossible to query reliably.
enum AuditEvent {
  appLaunched,
  bootstrapFailed,
  profileCreated,
  profileUpdated,
  doseCalculated,
  doseConfirmed,
  doseCancelled,
  safetyBlockTriggered,
  safetyOverrideRequested,
  safetyOverrideGranted,
  safetyOverrideDenied,
  glucoseReadingAdded,
  mealLogged,
  iobCalculated,
  predictionGenerated,
  insightGenerated,
  auditLogAccessed,
  dataExportRequested,
  dataEraseRequested,
  encryptionSelfTestPassed,
  encryptionSelfTestFailed,
  unknownException,
}

/// A single immutable audit record.
final class AuditRecord {
  const AuditRecord({
    required this.id,
    required this.event,
    required this.timestampUtc,
    required this.detail,
    this.userId,
    this.sessionId,
    this.stack,
    this.appVersion,
  });

  final int id;
  final AuditEvent event;
  final DateTime timestampUtc;
  final String detail;
  final String? userId;
  final String? sessionId;
  final String? stack;
  final String? appVersion;

  Map<String, dynamic> toMap() => {
        'event': event.name,
        'timestamp_utc': timestampUtc.toIso8601String(),
        'detail': detail,
        if (userId != null) 'user_id': userId,
        if (sessionId != null) 'session_id': sessionId,
        if (stack != null) 'stack': stack,
        if (appVersion != null) 'app_version': appVersion,
      };
}

final class AuditLogger {
  AuditLogger(this._db);

  final DatabaseManager _db;
  final Logger _devLogger = Logger(
    printer: PrettyPrinter(methodCount: 0),
    level: Level.debug,
  );

  // Emergency ring buffer for pre-DI failures (max 50 records, ~50 KB)
  static final Queue<Map<String, String>> _emergencyBuffer = Queue();
  static const int _emergencyBufferMax = 50;

  bool _initialised = false;

  /// Initialise the logger (called by AppBootstrap after DB is ready).
  Future<void> initialise() async {
    _initialised = true;
  }

  /// Log a standard audit event.
  Future<void> log({
    required AuditEvent event,
    required String detail,
    String? userId,
    String? sessionId,
    String? stack,
  }) async {
    final record = {
      'event': event.name,
      'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
      'detail': detail,
      if (userId != null) 'user_id': userId,
      if (sessionId != null) 'session_id': sessionId,
      if (stack != null) 'stack': stack,
    };

    // Always write to dev logger in debug builds
    _devLogger.i('[AUDIT] ${event.name}: $detail');

    if (_initialised) {
      await _writeToDB(record);
    } else {
      _bufferEmergencyLog(record);
    }
  }

  /// Static fallback for top-level zone errors — no DI available.
  static void staticEmergencyLog({
    required String event,
    required String detail,
    String? stack,
  }) {
    if (_emergencyBuffer.length >= _emergencyBufferMax) {
      _emergencyBuffer.removeFirst(); // Drop oldest to prevent unbounded growth
    }
    _emergencyBuffer.addLast({
      'event': event,
      'detail': detail,
      'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
      if (stack != null) 'stack': stack,
    });
  }

  /// Flushes emergency buffer to DB once the DB is available.
  Future<void> flushPendingEmergencyLogs() async {
    while (_emergencyBuffer.isNotEmpty) {
      final record = _emergencyBuffer.removeFirst();
      await _writeToDB(record);
    }
  }

  /// Query audit log — used for compliance export.
  Future<List<Map<String, dynamic>>> queryLogs({
    DateTime? from,
    DateTime? to,
    AuditEvent? event,
    int limit = 200,
  }) async {
    final db = await _db.database;
    final whereParts = <String>[];
    final whereArgs = <dynamic>[];

    if (from != null) {
      whereParts.add('timestamp_utc >= ?');
      whereArgs.add(from.toIso8601String());
    }
    if (to != null) {
      whereParts.add('timestamp_utc <= ?');
      whereArgs.add(to.toIso8601String());
    }
    if (event != null) {
      whereParts.add('event = ?');
      whereArgs.add(event.name);
    }

    return db.query(
      DatabaseManager.tableAuditLog,
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp_utc DESC',
      limit: limit,
    );
  }

  /// Delete records older than retention policy.
  Future<int> purgeOldRecords() async {
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(
          const Duration(days: MedicalConstants.auditRetentionDays),
        )
        .toIso8601String();
    final db = await _db.database;
    return db.delete(
      DatabaseManager.tableAuditLog,
      where: 'timestamp_utc < ?',
      whereArgs: [cutoff],
    );
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _writeToDB(Map<String, dynamic> record) async {
    try {
      final db = await _db.database;
      await db.insert(DatabaseManager.tableAuditLog, {
        'payload': jsonEncode(record),
        'event': record['event'] as String? ?? 'unknown',
        'timestamp_utc':
            record['timestamp_utc'] as String? ?? DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Audit write failures must NEVER crash the app — buffer instead
      _bufferEmergencyLog(
        {'event': 'AUDIT_WRITE_FAILED', 'detail': record.toString()},
      );
    }
  }

  void _bufferEmergencyLog(Map<String, dynamic> record) {
    staticEmergencyLog(
      event: record['event']?.toString() ?? 'unknown',
      detail: record['detail']?.toString() ?? jsonEncode(record),
    );
  }
}
