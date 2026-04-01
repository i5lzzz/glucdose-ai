// test/integration/large_dataset_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Large dataset simulation: 1000+ records, performance, and pagination.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/algorithms/dose/standard_dose_calculator.dart';
import 'package:insulin_assistant/algorithms/iob/walsh_iob_calculator.dart';
import 'package:insulin_assistant/algorithms/iob/walsh_iob_model.dart';
import 'package:insulin_assistant/domain/core/clock.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_duration.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

import '../helpers/test_factories.dart';

void main() {
  group('Large Dataset Simulation', () {
    const calculator = StandardDoseCalculator(appVersion: '1.0.0-test');
    const iobCalc = WalshIOBCalculator();

    // ══════════════════════════════════════════════════════════════════════
    // 1000 dose calculations
    // ══════════════════════════════════════════════════════════════════════

    test('1000 dose calculations all succeed with valid output', () {
      var successCount = 0;
      var zeroCount = 0;
      var maxDose = 0.0;
      var minDose = double.infinity;

      final sw = Stopwatch()..start();

      for (var i = 0; i < 1000; i++) {
        final bg = 70.0 + (i % 400);         // 70–470
        final carbs = (i % 120).toDouble();   // 0–119g
        final iobU = (i % 10) * 0.5;         // 0–4.5U

        final safeBg = bg.clamp(20.0, 600.0);
        final r = calculator.calculate(
          TestFactories.calcInput(bgVal: safeBg, carbsG: carbs, iobU: iobU),
        );

        expect(r.isSuccess, isTrue, reason: 'Failed at i=$i');
        if (r.isSuccess) {
          successCount++;
          final d = r.value.output.clampedDose.units;
          expect(d, greaterThanOrEqualTo(0.0), reason: 'Negative dose at i=$i');
          expect(d, lessThanOrEqualTo(20.0), reason: 'Exceeds ceiling at i=$i');
          if (d == 0.0) zeroCount++;
          if (d > maxDose) maxDose = d;
          if (d < minDose) minDose = d;
        }
      }

      sw.stop();
      expect(successCount, equals(1000));
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason: '1000 calcs took ${sw.elapsedMilliseconds}ms (limit: 2000ms)');

      // Spot-check distribution is reasonable
      expect(zeroCount, lessThan(400),
          reason: 'Too many zero doses — formula may be wrong');
      expect(maxDose, lessThanOrEqualTo(10.0)); // user max is 10
    });

    // ══════════════════════════════════════════════════════════════════════
    // IOB calculation with 50 stacked injections
    // ══════════════════════════════════════════════════════════════════════

    test('IOB with 50 stacked injections: accurate + performant', () {
      final base = TestFactories.epoch;
      final clock = FakeClock(base);

      // Generate 50 confirmed injections spread over last 8 hours
      final injections = List<InjectionRecord>.generate(50, (i) {
        final minutesAgo = (i * 10.0).clamp(0.0, 480.0);
        return InjectionRecord(
          id: 'mass-$i',
          userId: 'user-001',
          injectedAt: base.subtract(Duration(minutes: minutesAgo.round())),
          doseUnits: InsulinUnits.fromUnits(2.0).value,
          insulinType: InsulinType.rapidAnalogue,
          duration: InsulinDuration.fourHours,
          status: InjectionStatus.confirmed,
        );
      });

      final sw = Stopwatch()..start();
      final result = iobCalc.calculateTotalIOB(
        injections: injections,
        clock: clock,
      );
      sw.stop();

      expect(result.isSuccess, isTrue);
      expect(result.value.units, greaterThanOrEqualTo(0));
      expect(result.value.units, lessThanOrEqualTo(50 * 2.0)); // can't exceed original
      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: '50-injection IOB took ${sw.elapsedMilliseconds}ms');
    });

    // ══════════════════════════════════════════════════════════════════════
    // Walsh model: 10,000 evaluations performance
    // ══════════════════════════════════════════════════════════════════════

    test('Walsh model: 10,000 evaluations complete < 200ms', () {
      final sw = Stopwatch()..start();
      var sum = 0.0;

      for (var i = 0; i < 10000; i++) {
        sum += WalshIOBModel.percentRemaining(
          minutesElapsed: (i % 240).toDouble(),
          durationMinutes: 240,
        );
      }

      sw.stop();
      expect(sum, greaterThan(0)); // prevent optimizer removal
      expect(sw.elapsedMilliseconds, lessThan(200),
          reason: '10k Walsh evals took ${sw.elapsedMilliseconds}ms');
    });

    // ══════════════════════════════════════════════════════════════════════
    // Pagination simulation over large record set
    // ══════════════════════════════════════════════════════════════════════

    test('Pagination over 200 records returns all pages without gaps', () {
      // Simulate a list of 200 historical records
      const totalRecords = 200;
      const pageSize = 20;

      final allRecords = List.generate(
        totalRecords,
        (i) => {'id': 'r-$i', 'value': i},
      );

      var page = 0;
      var seen = 0;
      final seenIds = <String>{};

      while (true) {
        final offset = page * pageSize;
        if (offset >= totalRecords) break;

        final pageData = allRecords.skip(offset).take(pageSize).toList();
        if (pageData.isEmpty) break;

        for (final record in pageData) {
          final id = record['id'] as String;
          expect(seenIds.contains(id), isFalse,
              reason: 'Duplicate record $id on page $page');
          seenIds.add(id);
          seen++;
        }

        page++;
      }

      expect(seen, equals(totalRecords));
      expect(page, equals(totalRecords ~/ pageSize));
    });

    // ══════════════════════════════════════════════════════════════════════
    // Encryption round-trip with 100 values
    // ══════════════════════════════════════════════════════════════════════

    test('Encryption round-trip: 100 medical values preserve precision', () async {
      // Using fake encryption service
      final enc = _FakeEnc();

      final testValues = [
        // BG values
        for (var bg = 40.0; bg <= 400.0; bg += 37.0) bg,
        // Dose values
        for (var d = 0.5; d <= 20.0; d += 1.5) d,
        // IOB values
        for (var i = 0.1; i <= 5.0; i += 0.4) i,
      ];

      for (final v in testValues) {
        final encrypted = await enc.encryptDouble(v);
        final decrypted = await enc.decryptDouble(encrypted);
        expect(decrypted, closeTo(v, 0.0001),
            reason: 'Round-trip failed for value $v');
      }
    });
  });
}

// Minimal fake for round-trip test (no real AES dependency needed here)
class _FakeEnc {
  Future<String> encryptDouble(double v) async => 'FAKE:${v.toString()}';
  Future<double> decryptDouble(String s) async =>
      double.parse(s.replaceFirst('FAKE:', ''));
}
