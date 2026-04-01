// test/algorithms/dose_step_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/algorithms/dose/dose_step.dart';

void main() {
  group('DoseStep', () {
    group('floor semantics — always LESS, never more', () {
      test('half step: 3.7 → 3.5 (NOT 4.0)', () {
        expect(DoseStep.half.floor(3.7), closeTo(3.5, 0.0001));
      });

      test('half step: 3.99 → 3.5', () {
        expect(DoseStep.half.floor(3.99), closeTo(3.5, 0.0001));
      });

      test('tenth step: 3.74 → 3.7', () {
        expect(DoseStep.tenth.floor(3.74), closeTo(3.7, 0.0001));
      });

      test('tenth step: 3.75 → 3.7 (floor, not round)', () {
        expect(DoseStep.tenth.floor(3.75), closeTo(3.7, 0.0001));
      });

      test('whole step: 9.99 → 9.0', () {
        expect(DoseStep.whole.floor(9.99), closeTo(9.0, 0.0001));
      });

      test('zero dose remains zero', () {
        expect(DoseStep.half.floor(0.0), equals(0.0));
        expect(DoseStep.tenth.floor(0.0), equals(0.0));
        expect(DoseStep.whole.floor(0.0), equals(0.0));
      });

      test('negative dose is clamped to zero', () {
        expect(DoseStep.half.floor(-1.0), equals(0.0));
      });
    });

    group('DoseStepApplicator', () {
      test('produces correct truncated amount', () {
        final result = DoseStepApplicator.apply(3.74, DoseStep.half);
        expect(result.rawDose, closeTo(3.74, 0.001));
        expect(result.steppedDose, closeTo(3.5, 0.001));
        expect(result.truncatedAmount, closeTo(0.24, 0.001));
        expect(result.wasTruncated, isTrue);
      });

      test('exact multiple produces zero truncation', () {
        final result = DoseStepApplicator.apply(3.5, DoseStep.half);
        expect(result.steppedDose, closeTo(3.5, 0.001));
        expect(result.wasTruncated, isFalse);
      });
    });
  });
}
