// test/ai/prediction/carb_absorption_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/ai/prediction/models/carb_absorption_model.dart';

void main() {
  group('CarbAbsorptionModel', () {
    // ── Boundary conditions ─────────────────────────────────────────────────

    group('fractionAbsorbed — boundary conditions', () {
      test('t=0 → 0% absorbed', () {
        expect(
          CarbAbsorptionModel.fractionAbsorbed(
            minutesElapsed: 0,
            halfTimeMinutes: 75,
          ),
          equals(0.0),
        );
      });

      test('t<0 → 0% (guard)', () {
        expect(
          CarbAbsorptionModel.fractionAbsorbed(
            minutesElapsed: -10,
            halfTimeMinutes: 75,
          ),
          equals(0.0),
        );
      });

      test('t = T½ → exactly 50% absorbed', () {
        const T = 75.0;
        expect(
          CarbAbsorptionModel.fractionAbsorbed(
            minutesElapsed: T,
            halfTimeMinutes: T,
          ),
          closeTo(0.5, 0.001),
        );
      });

      test('t >> T½ → approaches 100%', () {
        expect(
          CarbAbsorptionModel.fractionAbsorbed(
            minutesElapsed: 1000,
            halfTimeMinutes: 75,
          ),
          closeTo(1.0, 0.001),
        );
      });

      test('fraction is always in [0, 1]', () {
        const T = 75.0;
        for (var t = 0.0; t <= 600.0; t += 10.0) {
          final f = CarbAbsorptionModel.fractionAbsorbed(
            minutesElapsed: t,
            halfTimeMinutes: T,
          );
          expect(f, inInclusiveRange(0.0, 1.0),
              reason: 'fraction at t=$t out of range');
        }
      });
    });

    // ── Monotonicity ────────────────────────────────────────────────────────

    test('fraction monotonically increases over time', () {
      double prev = 0;
      for (var t = 0.0; t <= 300.0; t += 5.0) {
        final curr = CarbAbsorptionModel.fractionAbsorbed(
          minutesElapsed: t,
          halfTimeMinutes: 75,
        );
        expect(curr, greaterThanOrEqualTo(prev),
            reason: 'fraction should not decrease at t=$t');
        prev = curr;
      }
    });

    // ── Absorption speed presets ────────────────────────────────────────────

    group('absorption speed presets', () {
      test('fast (T½=35): 35 min → 50%', () {
        expect(
          CarbAbsorptionModel.fractionAbsorbed(
            minutesElapsed: 35,
            halfTimeMinutes: 35,
          ),
          closeTo(0.5, 0.001),
        );
      });

      test('medium (T½=75): 75 min → 50%', () {
        expect(
          CarbAbsorptionModel.fractionAbsorbed(
            minutesElapsed: 75,
            halfTimeMinutes: 75,
          ),
          closeTo(0.5, 0.001),
        );
      });

      test('slow (T½=120): 120 min → 50%', () {
        expect(
          CarbAbsorptionModel.fractionAbsorbed(
            minutesElapsed: 120,
            halfTimeMinutes: 120,
          ),
          closeTo(0.5, 0.001),
        );
      });

      test('fast absorbs more than slow at same time', () {
        const t = 60.0;
        final fast = CarbAbsorptionModel.fractionAbsorbed(
          minutesElapsed: t, halfTimeMinutes: 35,
        );
        final medium = CarbAbsorptionModel.fractionAbsorbed(
          minutesElapsed: t, halfTimeMinutes: 75,
        );
        final slow = CarbAbsorptionModel.fractionAbsorbed(
          minutesElapsed: t, halfTimeMinutes: 120,
        );
        expect(fast, greaterThan(medium));
        expect(medium, greaterThan(slow));
      });
    });

    // ── bgImpactAt ──────────────────────────────────────────────────────────

    group('bgImpactAt', () {
      test('zero carbs → zero impact', () {
        expect(
          CarbAbsorptionModel.bgImpactAt(
            carbsGrams: 0,
            isfMgdlPerUnit: 50,
            icrGramsPerUnit: 10,
            minutesElapsed: 60,
            halfTimeMinutes: 75,
          ),
          equals(0.0),
        );
      });

      test('correct max impact formula: 60g / 10ICR × 50ISF = 300 mg/dL total', () {
        // At t → ∞, all carbs absorbed → impact = 300
        final impact = CarbAbsorptionModel.bgImpactAt(
          carbsGrams: 60,
          isfMgdlPerUnit: 50,
          icrGramsPerUnit: 10,
          minutesElapsed: 10000,
          halfTimeMinutes: 75,
        );
        expect(impact, closeTo(300.0, 0.5));
      });

      test('impact at t=T½ = 50% of max impact', () {
        const T = 75.0;
        const maxImpact = 60.0 / 10.0 * 50.0; // 300 mg/dL
        final impact = CarbAbsorptionModel.bgImpactAt(
          carbsGrams: 60,
          isfMgdlPerUnit: 50,
          icrGramsPerUnit: 10,
          minutesElapsed: T,
          halfTimeMinutes: T,
        );
        expect(impact, closeTo(maxImpact * 0.5, 1.0));
      });

      test('impact at t=0 = 0', () {
        expect(
          CarbAbsorptionModel.bgImpactAt(
            carbsGrams: 60,
            isfMgdlPerUnit: 50,
            icrGramsPerUnit: 10,
            minutesElapsed: 0,
            halfTimeMinutes: 75,
          ),
          equals(0.0),
        );
      });

      test('impact is always non-negative', () {
        for (var t = 0.0; t <= 240.0; t += 15.0) {
          expect(
            CarbAbsorptionModel.bgImpactAt(
              carbsGrams: 45,
              isfMgdlPerUnit: 40,
              icrGramsPerUnit: 15,
              minutesElapsed: t,
              halfTimeMinutes: 75,
            ),
            greaterThanOrEqualTo(0.0),
          );
        }
      });
    });
  });
}
