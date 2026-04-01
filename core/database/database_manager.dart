// lib/core/database/database_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// SQLite database manager.
//
// Schema design principles:
//   - All PHI columns store encrypted ciphertext (Base64 strings)
//   - Timestamps are UTC ISO-8601 strings for timezone portability
//   - Foreign keys enforced at schema level
//   - Every table has a UUID primary key (not auto-increment) to support
//     future cloud sync without collisions
//   - All indexes are explicit to guarantee query performance
//
// Versioned migration system: each version bump adds a migration function.
// Rollback is NOT supported (append-only medical records).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:insulin_assistant/core/constants/app_constants.dart';

final class DatabaseManager {
  DatabaseManager();

  Database? _db;

  // ── Table name constants ─────────────────────────────────────────────────
  static const String tableUserProfile = 'user_profile';
  static const String tableGlucoseReadings = 'glucose_readings';
  static const String tableInjections = 'injections';
  static const String tableMeals = 'meals';
  static const String tableMealItems = 'meal_items';
  static const String tableFoods = 'foods';
  static const String tableInsights = 'insights';
  static const String tableAuditLog = 'audit_log';
  static const String tableDoseHistory = 'dose_history';

  /// Returns the open database, opening it if necessary.
  Future<Database> get database async {
    _db ??= await _openDatabase();
    return _db!;
  }

  Future<void> open() async {
    _db = await _openDatabase();
  }

  Future<void> runMigrations() async {
    // Migrations are applied inside onUpgrade callback.
    // This method is a hook for future programmatic migration runners.
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<Database> _openDatabase() async {
    final dbPath = join(await getDatabasesPath(), AppConstants.dbName);

    return openDatabase(
      dbPath,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onOpen(Database db) async {
    // Enable WAL mode for better concurrent read performance
    await db.execute('PRAGMA journal_mode=WAL;');
    // Enforce foreign key constraints (disabled by default in SQLite)
    await db.execute('PRAGMA foreign_keys=ON;');
    // Optimise page cache
    await db.execute('PRAGMA cache_size=-8000;'); // ~8 MB
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    _createAllTables(batch);
    _createAllIndexes(batch);
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrations run in sequence from oldVersion+1 to newVersion
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      final migration = _migrations[v];
      if (migration != null) await migration(db);
    }
  }

  // ── Table Definitions ─────────────────────────────────────────────────────

  void _createAllTables(Batch batch) {
    // user_profile — single row; PHI columns encrypted
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableUserProfile (
        id                TEXT PRIMARY KEY,
        created_at        TEXT NOT NULL,
        updated_at        TEXT NOT NULL,
        display_name_enc  TEXT NOT NULL,
        dob_enc           TEXT,
        diabetes_type_enc TEXT NOT NULL,
        icr_enc           TEXT NOT NULL,
        isf_enc           TEXT NOT NULL,
        target_bg_enc     TEXT NOT NULL,
        max_dose_enc      TEXT NOT NULL,
        insulin_duration_enc TEXT NOT NULL,
        locale            TEXT NOT NULL DEFAULT 'ar',
        units             TEXT NOT NULL DEFAULT 'mgdl'
      );
    ''');

    // glucose_readings — every BG measurement
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableGlucoseReadings (
        id              TEXT PRIMARY KEY,
        user_id         TEXT NOT NULL,
        recorded_at     TEXT NOT NULL,
        value_enc       TEXT NOT NULL,
        source          TEXT NOT NULL DEFAULT 'manual',
        trend           TEXT,
        notes_enc       TEXT,
        FOREIGN KEY(user_id) REFERENCES $tableUserProfile(id)
      );
    ''');

    // injections — every insulin dose administered
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableInjections (
        id                    TEXT PRIMARY KEY,
        user_id               TEXT NOT NULL,
        injected_at           TEXT NOT NULL,
        dose_units_enc        TEXT NOT NULL,
        insulin_type_enc      TEXT NOT NULL,
        duration_minutes      REAL NOT NULL,
        meal_id               TEXT,
        bg_at_injection_enc   TEXT,
        iob_at_injection_enc  TEXT,
        calculation_trace_enc TEXT,
        confirmed             INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(user_id) REFERENCES $tableUserProfile(id)
      );
    ''');

    // meals — a meal event (can contain multiple food items)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableMeals (
        id              TEXT PRIMARY KEY,
        user_id         TEXT NOT NULL,
        eaten_at        TEXT NOT NULL,
        total_carbs_enc TEXT NOT NULL,
        notes_enc       TEXT,
        FOREIGN KEY(user_id) REFERENCES $tableUserProfile(id)
      );
    ''');

    // meal_items — individual food items within a meal
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableMealItems (
        id              TEXT PRIMARY KEY,
        meal_id         TEXT NOT NULL,
        food_id         TEXT NOT NULL,
        quantity_grams  REAL NOT NULL,
        carbs_grams     REAL NOT NULL,
        FOREIGN KEY(meal_id) REFERENCES $tableMeals(id),
        FOREIGN KEY(food_id) REFERENCES $tableFoods(id)
      );
    ''');

    // foods — Saudi food database (reference data — NOT encrypted)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableFoods (
        id                TEXT PRIMARY KEY,
        name_ar           TEXT NOT NULL,
        name_en           TEXT NOT NULL,
        carbs_per_100g    REAL NOT NULL,
        glycemic_index    INTEGER NOT NULL,
        absorption_speed  TEXT NOT NULL,
        default_portion_g REAL NOT NULL,
        category          TEXT NOT NULL,
        is_custom         INTEGER NOT NULL DEFAULT 0,
        created_at        TEXT NOT NULL
      );
    ''');

    // dose_history — calculated (not necessarily confirmed) doses
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableDoseHistory (
        id                  TEXT PRIMARY KEY,
        user_id             TEXT NOT NULL,
        calculated_at       TEXT NOT NULL,
        carbs_enc           TEXT NOT NULL,
        bg_enc              TEXT NOT NULL,
        iob_enc             TEXT NOT NULL,
        icr_enc             TEXT NOT NULL,
        isf_enc             TEXT NOT NULL,
        target_bg_enc       TEXT NOT NULL,
        calculated_dose_enc TEXT NOT NULL,
        clamped_dose_enc    TEXT NOT NULL,
        safety_flags_enc    TEXT NOT NULL,
        outcome             TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY(user_id) REFERENCES $tableUserProfile(id)
      );
    ''');

    // insights — AI-generated pattern insights
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableInsights (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL,
        generated_at TEXT NOT NULL,
        type        TEXT NOT NULL,
        title_ar    TEXT NOT NULL,
        title_en    TEXT NOT NULL,
        body_ar     TEXT NOT NULL,
        body_en     TEXT NOT NULL,
        severity    TEXT NOT NULL,
        is_read     INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(user_id) REFERENCES $tableUserProfile(id)
      );
    ''');

    // audit_log — append-only compliance log
    batch.execute('''
      CREATE TABLE IF NOT EXISTS $tableAuditLog (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        event         TEXT NOT NULL,
        timestamp_utc TEXT NOT NULL,
        payload       TEXT NOT NULL
      );
    ''');
  }

  void _createAllIndexes(Batch batch) {
    // Glucose readings — time-series queries
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_glucose_user_time '
      'ON $tableGlucoseReadings(user_id, recorded_at DESC);',
    );

    // Injections — IOB calculation requires recent injections by time
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_injections_user_time '
      'ON $tableInjections(user_id, injected_at DESC);',
    );

    // Meals — meal history by time
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_meals_user_time '
      'ON $tableMeals(user_id, eaten_at DESC);',
    );

    // Meal items — lookup by meal
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_meal_items_meal '
      'ON $tableMealItems(meal_id);',
    );

    // Foods — Arabic name search
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_foods_name_ar '
      'ON $tableFoods(name_ar);',
    );

    // Dose history — time-ordered per user
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_dose_history_user_time '
      'ON $tableDoseHistory(user_id, calculated_at DESC);',
    );

    // Audit log — event-type queries for compliance reporting
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_event '
      'ON $tableAuditLog(event, timestamp_utc DESC);',
    );

    // Insights — unread first
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_insights_user_read '
      'ON $tableInsights(user_id, is_read, generated_at DESC);',
    );
  }

  // ── Migration registry ───────────────────────────────────────────────────
  // Version 1 is handled by onCreate.
  // Add future migrations here: _migrations[2] = (db) async { ... }
  final Map<int, Future<void> Function(Database)> _migrations = {};
}
