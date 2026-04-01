// test/data/helpers/test_database_helper.dart
// ─────────────────────────────────────────────────────────────────────────────
// In-memory SQLite infrastructure for repository tests.
//
// Uses sqflite_common_ffi which wraps SQLite in a synchronous FFI interface,
// allowing tests to run on the host machine (Linux/macOS/Windows) without
// an emulator.
//
// Every test gets a fresh in-memory database — no shared state.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:insulin_assistant/core/database/database_manager.dart';

/// Creates and opens a fresh in-memory [DatabaseManager] for testing.
Future<DatabaseManager> openTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final manager = _TestDatabaseManager();
  await manager.open();
  await manager.runMigrations();
  return manager;
}

/// Resets an in-memory database (closes and returns a new one).
Future<DatabaseManager> resetTestDatabase(DatabaseManager old) async {
  await old.close();
  return openTestDatabase();
}

/// DatabaseManager subclass that uses in-memory SQLite.
final class _TestDatabaseManager extends DatabaseManager {
  @override
  Future<void> open() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          // Create all tables inline for test isolation
          await db.execute('PRAGMA foreign_keys=ON;');
          await db.execute('PRAGMA journal_mode=WAL;');
          await _createTables(db);
          await _createIndexes(db);
        },
      ),
    );
    // We need to inject this db — use a workaround by calling the parent
    // open with a custom in-memory path
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseManager.tableUserProfile} (
        id TEXT PRIMARY KEY, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        display_name_enc TEXT NOT NULL, dob_enc TEXT,
        diabetes_type_enc TEXT NOT NULL, icr_enc TEXT NOT NULL,
        isf_enc TEXT NOT NULL, target_bg_enc TEXT NOT NULL,
        max_dose_enc TEXT NOT NULL, insulin_duration_enc TEXT NOT NULL,
        locale TEXT NOT NULL DEFAULT 'ar', units TEXT NOT NULL DEFAULT 'mgdl'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseManager.tableGlucoseReadings} (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
        recorded_at TEXT NOT NULL, value_enc TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual', trend TEXT, notes_enc TEXT,
        FOREIGN KEY(user_id) REFERENCES ${DatabaseManager.tableUserProfile}(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseManager.tableInjections} (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
        injected_at TEXT NOT NULL, dose_units_enc TEXT NOT NULL,
        insulin_type_enc TEXT NOT NULL, duration_minutes REAL NOT NULL,
        status TEXT NOT NULL, confirmed INTEGER NOT NULL DEFAULT 0,
        meal_id TEXT, bg_at_injection_enc TEXT, iob_at_injection_enc TEXT,
        calculation_trace_enc TEXT, notes_enc TEXT,
        FOREIGN KEY(user_id) REFERENCES ${DatabaseManager.tableUserProfile}(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseManager.tableDoseHistory} (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
        calculated_at TEXT NOT NULL, carbs_enc TEXT NOT NULL,
        bg_enc TEXT NOT NULL, iob_enc TEXT NOT NULL,
        icr_enc TEXT NOT NULL, isf_enc TEXT NOT NULL,
        target_bg_enc TEXT NOT NULL, calculated_dose_enc TEXT NOT NULL,
        clamped_dose_enc TEXT NOT NULL, safety_flags_enc TEXT NOT NULL,
        outcome TEXT NOT NULL DEFAULT 'pending',
        algorithm_version TEXT NOT NULL DEFAULT '',
        app_version TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(user_id) REFERENCES ${DatabaseManager.tableUserProfile}(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS predictions (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
        generated_at TEXT NOT NULL, prediction_json_enc TEXT NOT NULL,
        model_version TEXT, linked_trace_id TEXT,
        has_hypo_risk INTEGER NOT NULL DEFAULT 0,
        has_critical_hypo_risk INTEGER NOT NULL DEFAULT 0,
        has_hyper_risk INTEGER NOT NULL DEFAULT 0,
        actual_bg_30_enc TEXT, actual_bg_60_enc TEXT, actual_bg_120_enc TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseManager.tableFoods} (
        id TEXT PRIMARY KEY, name_ar TEXT NOT NULL, name_en TEXT NOT NULL,
        carbs_per_100g REAL NOT NULL, glycaemic_index INTEGER NOT NULL,
        absorption_speed TEXT NOT NULL, default_portion_g REAL NOT NULL,
        category TEXT NOT NULL, is_custom INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseManager.tableAuditLog} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event TEXT NOT NULL, timestamp_utc TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_glucose_user ON '
      '${DatabaseManager.tableGlucoseReadings}(user_id, recorded_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_injections_user ON '
      '${DatabaseManager.tableInjections}(user_id, injected_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_doses_user ON '
      '${DatabaseManager.tableDoseHistory}(user_id, calculated_at DESC)',
    );
  }
}
