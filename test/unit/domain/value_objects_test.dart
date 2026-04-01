// test/unit/domain/value_objects_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/core/unit_system.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/carb_ratio.dart';
import 'package:insulin_assistant/domain/value_objects/carbohydrates.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_duration.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_sensitivity_factor.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

void main() {
  group('Value Objects', () {

    // ── BloodGlucose ──────────────────────────────────────────────────────

    group('BloodGlucose', () {
      test('Valid mg/dL → success', () {
        expect(BloodGlucose.fromMgdl(120).isSuccess, isTrue);
      });

      test('Below min (19) → failure', () {
        expect(BloodGlucose.fromMgdl(19).isFailure, isTrue);
      });

      test('Above max (601) → failure', () {
        expect(BloodGlucose.fromMgdl(601).isFailure, isTrue);
      });

      test('Boundary min (20) → success', () {
        expect(BloodGlucose.fromMgdl(20).isSuccess, isTrue);
      });

      test('Boundary max (600) → success', () {
        expect(BloodGlucose.fromMgdl(600).isSuccess, isTrue);
      });

      test('NaN → failure', () {
        expect(BloodGlucose.fromMgdl(double.nan).isFailure, isTrue);
      });

      test('Infinity → failure', () {
        expect(BloodGlucose.fromMgdl(double.infinity).isFailure, isTrue);
      });

      test('mmol/L constructor round-trips correctly', () {
        const mmol = 7.2;
        final bg = BloodGlucose.fromMmol(mmol).value;
        expect(bg.mmol, closeTo(mmol, 0.1));
      });

      test('Unit conversion: 180 mg/dL ≈ 10.0 mmol/L', () {
        final bg = BloodGlucose.fromMgdl(180).value;
        expect(bg.mmol, closeTo(10.0, 0.1));
      });

      group('Classifiers', () {
        test('<40 → level2Hypo', () {
          expect(BloodGlucose.fromMgdl(39).value.isLevel2Hypo, isTrue);
        });
        test('40–69 → level1Hypo', () {
          expect(BloodGlucose.fromMgdl(65).value.isLevel1Hypo, isTrue);
        });
        test('80–140 → inRange', () {
          expect(BloodGlucose.fromMgdl(110).value.isInRange, isTrue);
        });
        test('>250 → isHyper', () {
          expect(BloodGlucose.fromMgdl(280).value.isHyper, isTrue);
        });
      });

      test('Equality: same value = equal', () {
        final a = BloodGlucose.fromMgdl(120).value;
        final b = BloodGlucose.fromMgdl(120).value;
        expect(a, equals(b));
      });

      test('Serialise → deserialise round-trip', () {
        final original = BloodGlucose.fromMgdl(145).value;
        final json = original.toJson();
        final restored = BloodGlucose.fromJson(json);
        expect(restored.mgdl, closeTo(original.mgdl, 0.001));
      });
    });

    // ── InsulinUnits ──────────────────────────────────────────────────────

    group('InsulinUnits', () {
      test('Valid: 0U → success', () {
        expect(InsulinUnits.fromUnits(0).isSuccess, isTrue);
      });

      test('Valid: 20U (ceiling) → success', () {
        expect(
          InsulinUnits.fromUnits(MedicalConstants.absoluteMaxSingleDoseUnits).isSuccess,
          isTrue,
        );
      });

      test('Above ceiling: 20.1U → failure', () {
        expect(
          InsulinUnits.fromUnits(
            MedicalConstants.absoluteMaxSingleDoseUnits + 0.1,
          ).isFailure,
          isTrue,
        );
      });

      test('Negative → failure', () {
        expect(InsulinUnits.fromUnits(-1).isFailure, isTrue);
      });

      test('fromUnitsUnclamped allows > 20U', () {
        expect(InsulinUnits.fromUnitsUnclamped(25).isSuccess, isTrue);
      });

      test('InsulinUnits.zero is 0.0', () {
        expect(InsulinUnits.zero.units, equals(0.0));
      });

      test('IOB subtraction clamps to zero', () {
        final dose = InsulinUnits.fromUnits(3.0).value;
        final iob = InsulinUnits.fromUnitsUnclamped(5.0).value;
        final result = dose.subtractIOB(iob);
        expect(result.isSuccess, isTrue);
        expect(result.value.units, equals(0.0));
      });

      test('Serialise round-trip', () {
        final u = InsulinUnits.fromUnits(4.5).value;
        final restored = InsulinUnits.fromJson(u.toJson());
        expect(restored.units, closeTo(4.5, 0.001));
      });
    });

    // ── Carbohydrates ─────────────────────────────────────────────────────

    group('Carbohydrates', () {
      test('0g (correction-only) → success', () {
        expect(Carbohydrates.fromGrams(0).isSuccess, isTrue);
      });

      test('Max 400g → success', () {
        expect(Carbohydrates.fromGrams(400).isSuccess, isTrue);
      });

      test('401g → failure', () {
        expect(Carbohydrates.fromGrams(401).isFailure, isTrue);
      });

      test('Negative → failure', () {
        expect(Carbohydrates.fromGrams(-1).isFailure, isTrue);
      });

      test('carbDoseFor: 60g / ICR=10 = 6.0U', () {
        final c = Carbohydrates.fromGrams(60).value;
        expect(c.carbDoseFor(10), closeTo(6.0, 0.001));
      });

      test('Carbohydrates.zero is 0.0g', () {
        expect(Carbohydrates.zero.grams, equals(0.0));
      });
    });

    // ── InsulinSensitivityFactor ───────────────────────────────────────────

    group('InsulinSensitivityFactor', () {
      test('Valid 50 → success', () {
        expect(InsulinSensitivityFactor.fromMgdlPerUnit(50).isSuccess, isTrue);
      });

      test('Below min (4) → failure', () {
        expect(InsulinSensitivityFactor.fromMgdlPerUnit(4).isFailure, isTrue);
      });

      test('Above max (201) → failure', () {
        expect(InsulinSensitivityFactor.fromMgdlPerUnit(201).isFailure, isTrue);
      });

      test('correctionDoseFor: (150-100)/50 = 1.0U', () {
        final isf = InsulinSensitivityFactor.fromMgdlPerUnit(50).value;
        expect(
          isf.correctionDoseFor(currentBgMgdl: 150, targetBgMgdl: 100),
          closeTo(1.0, 0.001),
        );
      });

      test('Negative correction when BG < target', () {
        final isf = InsulinSensitivityFactor.fromMgdlPerUnit(50).value;
        expect(
          isf.correctionDoseFor(currentBgMgdl: 80, targetBgMgdl: 100),
          closeTo(-0.4, 0.001),
        );
      });
    });

    // ── CarbRatio ─────────────────────────────────────────────────────────

    group('CarbRatio', () {
      test('Valid 10 g/U → success', () {
        expect(CarbRatio.fromGramsPerUnit(10).isSuccess, isTrue);
      });

      test('Below min (2) → failure', () {
        expect(CarbRatio.fromGramsPerUnit(2).isFailure, isTrue);
      });

      test('Above max (51) → failure', () {
        expect(CarbRatio.fromGramsPerUnit(51).isFailure, isTrue);
      });

      test('carbDoseFor: 60g / 10 g/U = 6.0 U', () {
        final icr = CarbRatio.fromGramsPerUnit(10).value;
        expect(icr.carbDoseFor(60), closeTo(6.0, 0.001));
      });

      test('carbDoseFor: 0g = 0 U', () {
        expect(CarbRatio.fromGramsPerUnit(10).value.carbDoseFor(0), equals(0.0));
      });
    });

    // ── InsulinDuration ───────────────────────────────────────────────────

    group('InsulinDuration', () {
      test('Valid 240 min → success', () {
        expect(InsulinDuration.fromMinutes(240).isSuccess, isTrue);
      });

      test('Below min (119) → failure', () {
        expect(InsulinDuration.fromMinutes(119).isFailure, isTrue);
      });

      test('Above max (481) → failure', () {
        expect(InsulinDuration.fromMinutes(481).isFailure, isTrue);
      });

      test('fromHours: 4h = 240 min', () {
        final d = InsulinDuration.fromHours(4).value;
        expect(d.minutes, closeTo(240, 0.001));
      });

      test('Presets are valid', () {
        expect(InsulinDuration.threeHours.minutes, equals(180));
        expect(InsulinDuration.fourHours.minutes, equals(240));
        expect(InsulinDuration.fiveHours.minutes, equals(300));
      });
    });

    // ── Unit system ───────────────────────────────────────────────────────

    group('GlucoseUnitConverter', () {
      test('180 mg/dL ≈ 10.0 mmol/L', () {
        expect(GlucoseUnitConverter.toMmol(180), closeTo(10.0, 0.1));
      });

      test('10.0 mmol/L ≈ 180 mg/dL', () {
        expect(GlucoseUnitConverter.toMgdl(10.0), closeTo(180, 1.0));
      });

      test('Round-trip: mg/dL → mmol/L → mg/dL within 1', () {
        for (final mgdl in [70.0, 100.0, 140.0, 180.0, 250.0]) {
          final roundtrip = GlucoseUnitConverter.toMgdl(
            GlucoseUnitConverter.toMmol(mgdl),
          );
          expect(roundtrip, closeTo(mgdl, 1.0),
              reason: 'Round-trip failed for $mgdl mg/dL');
        }
      });
    });
  });
}
