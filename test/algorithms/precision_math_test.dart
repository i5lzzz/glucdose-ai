// test/algorithms/precision_math_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/algorithms/math/precision_math.dart';

void main() {
  group('PrecisionMath', () {
    // ── safeDivide ───────────────────────────────────────────────────────────

    group('safeDivide', () {
      test('divides correctly', () {
        expect(PrecisionMath.safeDivide(60, 10), closeTo(6.0, 0.0001));
        expect(PrecisionMath.safeDivide(100, 50), closeTo(2.0, 0.0001));
      });

      test('throws on zero denominator', () {
        expect(
          () => PrecisionMath.safeDivide(10, 0),
          throwsArgumentError,
        );
      });

      test('throws on near-zero denominator', () {
        expect(
          () => PrecisionMath.safeDivide(10, 0.00001),
          throwsArgumentError,
        );
      });

      test('handles negative numerator', () {
        expect(PrecisionMath.safeDivide(-50, 50), closeTo(-1.0, 0.0001));
      });
    });

    // ── floorToStep ──────────────────────────────────────────────────────────

    group('floorToStep (FLOOR, never round up)', () {
      test('3.7 with step 0.5 → 3.5', () {
        expect(PrecisionMath.floorToStep(3.7, 0.5), closeTo(3.5, 0.0001));
      });

      test('3.5 with step 0.5 → 3.5 (exact multiple)', () {
        expect(PrecisionMath.floorToStep(3.5, 0.5), closeTo(3.5, 0.0001));
      });

      test('3.49 with step 0.5 → 3.0', () {
        expect(PrecisionMath.floorToStep(3.49, 0.5), closeTo(3.0, 0.0001));
      });

      test('7.9 with step 1.0 → 7.0', () {
        expect(PrecisionMath.floorToStep(7.9, 1.0), closeTo(7.0, 0.0001));
      });

      test('3.74 with step 0.1 → 3.7', () {
        expect(PrecisionMath.floorToStep(3.74, 0.1), closeTo(3.7, 0.0001));
      });

      test('0.0 returns 0.0', () {
        expect(PrecisionMath.floorToStep(0.0, 0.5), equals(0.0));
      });

      test('negative value returns 0.0', () {
        expect(PrecisionMath.floorToStep(-1.0, 0.5), equals(0.0));
      });

      test('floating-point notorious case: 0.1 + 0.2', () {
        // 0.1 + 0.2 = 0.30000000000000004 in naive float
        // With step 0.1, should floor to 0.3
        expect(PrecisionMath.floorToStep(0.1 + 0.2, 0.1), closeTo(0.3, 0.0001));
      });
    });

    // ── clampToZero ──────────────────────────────────────────────────────────

    group('clampToZero', () {
      test('positive value unchanged', () {
        expect(PrecisionMath.clampToZero(3.5), closeTo(3.5, 0.0001));
      });
      test('zero unchanged', () {
        expect(PrecisionMath.clampToZero(0.0), equals(0.0));
      });
      test('negative → 0.0', () {
        expect(PrecisionMath.clampToZero(-2.5), equals(0.0));
      });
      test('small negative → 0.0', () {
        expect(PrecisionMath.clampToZero(-0.001), equals(0.0));
      });
    });

    // ── nearEqual ────────────────────────────────────────────────────────────

    group('nearEqual', () {
      test('floats within epsilon are equal', () {
        expect(PrecisionMath.nearEqual(0.30000000000000004, 0.3), isTrue);
      });
      test('floats outside epsilon are not equal', () {
        expect(PrecisionMath.nearEqual(0.3, 0.5), isFalse);
      });
    });

    // ── sq ───────────────────────────────────────────────────────────────────

    group('sq', () {
      test('sq(3) = 9', () => expect(PrecisionMath.sq(3.0), closeTo(9.0, 0.0001)));
      test('sq(0) = 0', () => expect(PrecisionMath.sq(0.0), equals(0.0)));
      test('sq(-2) = 4', () => expect(PrecisionMath.sq(-2.0), closeTo(4.0, 0.0001)));
    });

    // ── roundTo ──────────────────────────────────────────────────────────────

    group('roundTo', () {
      test('rounds 3.145 to 2dp → 3.15', () {
        expect(PrecisionMath.roundTo(3.145, 2), closeTo(3.15, 0.0001));
      });
      test('rounds 3.14 to 1dp → 3.1', () {
        expect(PrecisionMath.roundTo(3.14, 1), closeTo(3.1, 0.0001));
      });
      test('rounds to 0dp → integer', () {
        expect(PrecisionMath.roundTo(3.7, 0), closeTo(4.0, 0.0001));
      });
    });
  });
}
