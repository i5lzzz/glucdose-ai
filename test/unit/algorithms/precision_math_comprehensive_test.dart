// test/unit/algorithms/precision_math_comprehensive_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/algorithms/math/precision_math.dart';

void main() {
  group('PrecisionMath — Comprehensive', () {

    group('safeDivide', () {
      test('60 / 10 = 6.0', () => expect(PrecisionMath.safeDivide(60, 10), closeTo(6.0, 0.0001)));
      test('100 / 50 = 2.0', () => expect(PrecisionMath.safeDivide(100, 50), closeTo(2.0, 0.0001)));
      test('Negative numerator', () => expect(PrecisionMath.safeDivide(-50, 50), closeTo(-1.0, 0.0001)));
      test('Zero denominator throws', () => expect(() => PrecisionMath.safeDivide(10, 0), throwsArgumentError));
      test('Near-zero denominator throws', () => expect(() => PrecisionMath.safeDivide(10, 0.00001), throwsArgumentError));
    });

    group('floorToStep — dose safety (FLOOR, never round)', () {
      final cases = {
        (3.7, 0.5): 3.5,
        (3.5, 0.5): 3.5,   // exact
        (3.49, 0.5): 3.0,
        (7.9, 1.0): 7.0,
        (3.74, 0.1): 3.7,
        (3.75, 0.1): 3.7,  // floor not round
        (0.0, 0.5): 0.0,
        (-1.0, 0.5): 0.0,  // negative clamped
      };
      cases.forEach((input, expected) {
        test('floor(${input.$1}, ${input.$2}) = $expected', () {
          expect(PrecisionMath.floorToStep(input.$1, input.$2), closeTo(expected, 0.0001));
        });
      });

      test('Notorious 0.1+0.2 case', () {
        expect(PrecisionMath.floorToStep(0.1 + 0.2, 0.1), closeTo(0.3, 0.0001));
      });
    });

    group('clampToZero', () {
      test('Positive unchanged', () => expect(PrecisionMath.clampToZero(3.5), closeTo(3.5, 0.0001)));
      test('Zero unchanged', () => expect(PrecisionMath.clampToZero(0.0), equals(0.0)));
      test('Negative → 0', () => expect(PrecisionMath.clampToZero(-2.5), equals(0.0)));
      test('Tiny negative → 0', () => expect(PrecisionMath.clampToZero(-0.0001), equals(0.0)));
    });

    group('nearEqual', () {
      test('Floats within epsilon = equal', () => expect(PrecisionMath.nearEqual(0.30000000000000004, 0.3), isTrue));
      test('Far floats = not equal', () => expect(PrecisionMath.nearEqual(0.3, 0.5), isFalse));
    });

    group('DoseStep semantics', () {
      test('0.5U: 7.4 → 7.0 (never rounds to 7.5)', () {
        expect(DoseStep.half.floor(7.4), closeTo(7.0, 0.0001));
      });
      test('0.5U: 7.5 → 7.5 (exact)', () {
        expect(DoseStep.half.floor(7.5), closeTo(7.5, 0.0001));
      });
      test('0.1U: 3.74 → 3.7', () {
        expect(DoseStep.tenth.floor(3.74), closeTo(3.7, 0.0001));
      });
      test('1.0U: 9.99 → 9.0', () {
        expect(DoseStep.whole.floor(9.99), closeTo(9.0, 0.0001));
      });
      test('Zero dose → 0', () {
        for (final step in DoseStep.values) {
          expect(step.floor(0.0), equals(0.0));
        }
      });
      test('Negative dose → 0', () {
        for (final step in DoseStep.values) {
          expect(step.floor(-1.0), equals(0.0));
        }
      });
    });

    group('sq (squaring)', () {
      test('sq(3) = 9', () => expect(PrecisionMath.sq(3.0), closeTo(9.0, 0.0001)));
      test('sq(0) = 0', () => expect(PrecisionMath.sq(0.0), equals(0.0)));
      test('sq(-2) = 4', () => expect(PrecisionMath.sq(-2.0), closeTo(4.0, 0.0001)));
    });
  });
}
