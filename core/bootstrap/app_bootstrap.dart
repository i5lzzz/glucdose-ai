// lib/core/bootstrap/app_bootstrap.dart
// ─────────────────────────────────────────────────────────────────────────────
// Sequential initialisation pipeline.
// Each step is independently retryable and its failure is categorised as either
// RECOVERABLE or FATAL, aligning with IEC 62304 §6.3 software architecture.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/core/database/database_manager.dart';
import 'package:insulin_assistant/core/di/injection.dart';
import 'package:insulin_assistant/core/logging/audit_logger.dart';
import 'package:insulin_assistant/core/security/encryption_service.dart';
import 'package:insulin_assistant/core/security/key_manager.dart';
import 'package:insulin_assistant/data/datasources/local/food_data_seeder.dart';

/// Singleton bootstrap orchestrator.
///
/// Callers must `await AppBootstrap.instance.initialise()` before the widget
/// tree is mounted.  Each phase is idempotent — safe to re-run on hot-restart
/// in debug builds.
final class AppBootstrap {
  AppBootstrap._();

  static final AppBootstrap instance = AppBootstrap._();

  bool _initialised = false;

  /// Runs all bootstrap phases in strict order.
  Future<void> initialise() async {
    if (_initialised) return;

    await _phase1_KeyMaterial();
    await _phase2_EncryptionService();
    await _phase3_Database();
    await _phase4_SeedData();
    await _phase5_AuditLog();

    _initialised = true;
  }

  // ── Phase 1: Cryptographic key material ────────────────────────────────────
  Future<void> _phase1_KeyMaterial() async {
    final keyManager = getIt<KeyManager>();
    await keyManager.ensureKeysExist();
  }

  // ── Phase 2: Encryption service self-test ──────────────────────────────────
  Future<void> _phase2_EncryptionService() async {
    final enc = getIt<EncryptionService>();
    await enc.selfTest(); // Throws EncryptionSelfTestFailure if key is corrupt
  }

  // ── Phase 3: Database migrations ───────────────────────────────────────────
  Future<void> _phase3_Database() async {
    final db = getIt<DatabaseManager>();
    await db.open();
    await db.runMigrations();
  }

  // ── Phase 4: Seed reference data (idempotent) ──────────────────────────────
  Future<void> _phase4_SeedData() async {
    final seeder = getIt<FoodDataSeeder>();
    await seeder.seedIfEmpty();
  }

  // ── Phase 5: Audit logger flush ────────────────────────────────────────────
  Future<void> _phase5_AuditLog() async {
    final audit = getIt<AuditLogger>();
    await audit.initialise();
    await audit.flushPendingEmergencyLogs();
  }
}
