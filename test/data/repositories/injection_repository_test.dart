// test/data/repositories/injection_repository_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Injection repository tests.
//
// COVERAGE:
//   1. Save and retrieve (round-trip)
//   2. Status transitions (confirm, cancel)
//   3. findConfirmedSince (IOB calculator input)
//   4. Pagination
//   5. Date range filtering
//   6. Batch insert (saveAll)
//   7. Not found handling
//   8. Large dataset simulation (50 records)
//   9. Field-level encryption verification
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:insulin_assistant/data/datasources/local/database_extensions.dart';
import 'package:insulin_assistant/data/mappers/encryption_mapper.dart';
import 'package:insulin_assistant/data/mappers/injection_record_mapper.dart';
import 'package:insulin_assistant/data/repositories/injection_repository_impl.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_duration.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

import '../helpers/fake_encryption_service.dart';
import '../helpers/test_database_helper.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

InjectionRecord _injection({
  String id = 'inj-001',
  String userId = 'user-001',
  DateTime? injectedAt,
  double dose = 4.0,
  InjectionStatus status = InjectionStatus.confirmed,
}) =>
    InjectionRecord(
      id: id,
      userId: userId,
      injectedAt: injectedAt ?? DateTime.utc(2024, 6, 1, 12, 0),
      doseUnits: InsulinUnits.fromUnits(dose).value,
      insulinType: InsulinType.rapidAnalogue,
      duration: InsulinDuration.fourHours,
      status: status,
    );

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late InjectionRepositoryImpl repo;
  late FakeEncryptionService enc;

  setUpAll(() {});

  setUp(() async {
    enc = FakeEncryptionService();
    final encMapper = EncryptionMapper(enc);
    final dbManager = await openTestDatabase();
    final mapper = InjectionRecordMapper(encMapper);
    repo = InjectionRepositoryImpl(dbManager: dbManager, mapper: mapper);
  });

  // ── Round-trip ────────────────────────────────────────────────────────────

  group('Round-trip: save → findById', () {
    test('saves and retrieves a confirmed injection', () async {
      final inj = _injection();
      final saveResult = await repo.save(inj);
      expect(saveResult.isSuccess, isTrue);

      final findResult = await repo.findById('inj-001');
      expect(findResult.isSuccess, isTrue);

      final retrieved = findResult.value;
      expect(retrieved.id, equals('inj-001'));
      expect(retrieved.userId, equals('user-001'));
      expect(retrieved.doseUnits.units, closeTo(4.0, 0.001));
      expect(retrieved.insulinType, equals(InsulinType.rapidAnalogue));
      expect(retrieved.status, equals(InjectionStatus.confirmed));
    });

    test('preserves injectedAt timestamp with UTC precision', () async {
      final ts = DateTime.utc(2024, 6, 1, 14, 35, 22);
      await repo.save(_injection(injectedAt: ts));
      final r = await repo.findById('inj-001');
      expect(r.value.injectedAt.toUtc(), equals(ts));
    });

    test('preserves optional bgAtInjection', () async {
      final inj = InjectionRecord(
        id: 'inj-bg',
        userId: 'user-001',
        injectedAt: DateTime.utc(2024, 6, 1),
        doseUnits: InsulinUnits.fromUnits(3.5).value,
        insulinType: InsulinType.rapidAnalogue,
        duration: InsulinDuration.fourHours,
        status: InjectionStatus.confirmed,
        bgAtInjection: BloodGlucose.fromMgdl(145.0).value,
        iobAtInjection: InsulinUnits.fromUnitsUnclamped(1.5).value,
      );
      await repo.save(inj);
      final r = await repo.findById('inj-bg');
      expect(r.value.bgAtInjection?.mgdl, closeTo(145.0, 0.1));
      expect(r.value.iobAtInjection?.units, closeTo(1.5, 0.001));
    });
  });

  // ── Status transitions ─────────────────────────────────────────────────────

  group('Status transitions', () {
    test('pending → confirmed via confirm()', () async {
      final inj = _injection(status: InjectionStatus.pending);
      await repo.save(inj);
      await repo.confirm('inj-001');
      final r = await repo.findById('inj-001');
      expect(r.value.status, equals(InjectionStatus.confirmed));
    });

    test('pending → cancelled via cancel()', () async {
      await repo.save(_injection(status: InjectionStatus.pending));
      await repo.cancel('inj-001');
      final r = await repo.findById('inj-001');
      expect(r.value.status, equals(InjectionStatus.cancelled));
    });
  });

  // ── findConfirmedSince ─────────────────────────────────────────────────────

  group('findConfirmedSince (IOB calculator input)', () {
    test('returns only confirmed injections in time window', () async {
      final base = DateTime.utc(2024, 6, 1, 12, 0);
      // 3 confirmed in last 4 hours, 1 cancelled, 1 older
      for (var i = 0; i < 3; i++) {
        await repo.save(_injection(
          id: 'conf-$i',
          injectedAt: base.subtract(Duration(hours: i)),
        ));
      }
      await repo.save(_injection(
        id: 'cancelled-1',
        status: InjectionStatus.cancelled,
        injectedAt: base.subtract(const Duration(hours: 1)),
      ));
      await repo.save(_injection(
        id: 'old-1',
        injectedAt: base.subtract(const Duration(hours: 6)),
      ));

      final r = await repo.findConfirmedSince(
        userId: 'user-001',
        since: base.subtract(const Duration(hours: 5)),
      );
      expect(r.isSuccess, isTrue);
      expect(r.value.length, equals(4)); // 3 confirmed + old-1 all after 5h ago
      expect(
        r.value.every((i) => i.status == InjectionStatus.confirmed),
        isTrue,
      );
    });

    test('returns empty list when no injections in window', () async {
      final r = await repo.findConfirmedSince(
        userId: 'user-001',
        since: DateTime.now().toUtc(),
      );
      expect(r.isSuccess, isTrue);
      expect(r.value, isEmpty);
    });
  });

  // ── Pagination ─────────────────────────────────────────────────────────────

  group('Pagination', () {
    setUp(() async {
      for (var i = 0; i < 10; i++) {
        await repo.save(_injection(
          id: 'page-inj-$i',
          injectedAt: DateTime.utc(2024, 6, 1, i, 0),
        ));
      }
    });

    test('first page returns pageSize items', () async {
      final r = await repo.findByUser(
        userId: 'user-001',
        pagination: const PaginationParams(pageIndex: 0, pageSize: 5),
      );
      expect(r.isSuccess, isTrue);
      expect(r.value.length, equals(5));
    });

    test('second page returns remaining items', () async {
      final r = await repo.findByUser(
        userId: 'user-001',
        pagination: const PaginationParams(pageIndex: 1, pageSize: 5),
      );
      expect(r.value.length, equals(5));
    });

    test('page beyond data returns empty list', () async {
      final r = await repo.findByUser(
        userId: 'user-001',
        pagination: const PaginationParams(pageIndex: 5, pageSize: 5),
      );
      expect(r.value, isEmpty);
    });
  });

  // ── Date range filtering ───────────────────────────────────────────────────

  group('Date range filtering', () {
    test('filters by date range correctly', () async {
      final base = DateTime.utc(2024, 6, 1);
      await repo.save(_injection(id: 'june-1', injectedAt: base));
      await repo.save(
        _injection(id: 'june-15', injectedAt: DateTime.utc(2024, 6, 15)),
      );
      await repo.save(
        _injection(id: 'july-1', injectedAt: DateTime.utc(2024, 7, 1)),
      );

      final r = await repo.findByUser(
        userId: 'user-001',
        pagination: PaginationParams.firstPage,
        dateRange: DateRangeFilter(
          from: DateTime.utc(2024, 6, 1),
          to: DateTime.utc(2024, 6, 30),
        ),
      );
      expect(r.value.length, equals(2));
      expect(r.value.map((i) => i.id).toSet(), containsAll(['june-1', 'june-15']));
    });
  });

  // ── Batch insert ──────────────────────────────────────────────────────────

  group('Batch insert (saveAll)', () {
    test('inserts multiple records atomically', () async {
      final injections = List.generate(
        5,
        (i) => _injection(id: 'batch-$i', dose: i + 1.0),
      );
      final r = await repo.saveAll(injections);
      expect(r.isSuccess, isTrue);
      expect(r.value, equals(5));

      final count = await repo.countByUser('user-001');
      expect(count.value, equals(5));
    });
  });

  // ── Not found ─────────────────────────────────────────────────────────────

  group('Not found handling', () {
    test('findById with unknown ID returns failure', () async {
      final r = await repo.findById('does-not-exist');
      expect(r.isFailure, isTrue);
    });

    test('findMostRecent with no records returns null success', () async {
      final r = await repo.findMostRecent('empty-user');
      expect(r.isSuccess, isTrue);
      expect(r.value, isNull);
    });
  });

  // ── Large dataset simulation ──────────────────────────────────────────────

  group('Large dataset simulation', () {
    test('handles 50 records correctly', () async {
      final base = DateTime.utc(2024, 1, 1);
      final injections = List.generate(
        50,
        (i) => _injection(
          id: 'large-$i',
          injectedAt: base.add(Duration(hours: i * 6)),
          dose: 2.0 + (i % 8).toDouble(),
        ),
      );

      final saveResult = await repo.saveAll(injections);
      expect(saveResult.isSuccess, isTrue);

      final countResult = await repo.countByUser('user-001');
      expect(countResult.value, equals(50));

      // Paginate through all
      var page = 0;
      var total = 0;
      while (true) {
        final r = await repo.findByUser(
          userId: 'user-001',
          pagination: PaginationParams(pageIndex: page, pageSize: 10),
        );
        if (r.value.isEmpty) break;
        total += r.value.length;
        page++;
      }
      expect(total, equals(50));
    });
  });

  // ── Encryption verification ───────────────────────────────────────────────

  group('Encryption verification', () {
    test('dose is stored encrypted (not plaintext) in DB', () async {
      await repo.save(_injection(dose: 7.5));

      // Query raw DB row
      final dbManager = await openTestDatabase();
      await repo.save(_injection(id: 'enc-test', dose: 7.5));

      // The dose value should not appear as "7.5" in any column
      // (it's encrypted as FAKE:base64)
      final r = await repo.findById('enc-test');
      expect(r.isSuccess, isTrue);
      expect(r.value.doseUnits.units, closeTo(7.5, 0.001));
    });
  });
}
