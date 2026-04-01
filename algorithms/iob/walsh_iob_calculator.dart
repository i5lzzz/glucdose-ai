// lib/algorithms/iob/walsh_iob_calculator.dart
// ─────────────────────────────────────────────────────────────────────────────
// WalshIOBCalculator — implements [IOBCalculator] using the Walsh bilinear model.
//
// RESPONSIBILITIES:
//   1. Iterate over all recent injections.
//   2. Filter to only bolus-eligible injections (isActiveForIOB).
//   3. For each, compute elapsed time via Clock abstraction.
//   4. Apply Walsh model to get remaining units.
//   5. Sum across all injections.
//   6. Return Result<InsulinUnits> — never throws.
//
// STACKING AWARENESS:
//   The total IOB returned here is the VALUE used in the dose formula.
//   The SafetyEvaluator separately checks it against the stacking threshold.
//   This calculator does NOT make safety decisions — it computes only.
//
// INVARIANT:
//   The sum of all individual IOBs is the total IOB.
//   Individual IOBs are never negative (clamped at zero in Walsh model).
//   Total IOB is never greater than the sum of original doses.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/algorithms/iob/walsh_iob_model.dart';
import 'package:insulin_assistant/algorithms/math/precision_math.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/domain/contracts/iob_calculator.dart';
import 'package:insulin_assistant/domain/core/clock.dart';
import 'package:insulin_assistant/domain/core/result.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';

/// Production implementation of [IOBCalculator] using the Walsh bilinear model.
final class WalshIOBCalculator implements IOBCalculator {
  const WalshIOBCalculator();

  @override
  String get modelName => 'Walsh Bilinear v1.0';

  // ── IOBCalculator interface ───────────────────────────────────────────────

  @override
  Result<InsulinUnits> calculateSingleIOB({
    required InjectionRecord injection,
    required Clock clock,
  }) {
    try {
      // Guard 1: only confirmed bolus injections contribute
      if (!injection.isActiveForIOB) {
        return Result.success(InsulinUnits.zero);
      }

      final elapsed = clock.minutesElapsed(injection.injectedAt);
      final remaining = WalshIOBModel.remainingUnits(
        originalDoseUnits: injection.doseUnits.units,
        minutesElapsed: elapsed,
        durationMinutes: injection.duration.minutes,
      );

      return InsulinUnits.fromUnitsUnclamped(remaining);
    } catch (e, st) {
      return Result.failure(
        UnexpectedFailure(
          'IOB calculation failed for injection ${injection.id}: $e\n$st',
        ),
      );
    }
  }

  @override
  Result<InsulinUnits> calculateTotalIOB({
    required List<InjectionRecord> injections,
    required Clock clock,
  }) {
    try {
      var total = 0.0;

      for (final injection in injections) {
        final result = calculateSingleIOB(
          injection: injection,
          clock: clock,
        );

        // Propagate any failure immediately — partial IOB state is unsafe
        if (result.isFailure) return Result.failure(result.failure);

        total += result.value.units;
      }

      // Normalise accumulated sum to prevent floating-point drift across many
      // injection records (e.g., 12 stacked doses after a missed night)
      final normalised = PrecisionMath.normalise(total, decimals: 4);
      return InsulinUnits.fromUnitsUnclamped(normalised);
    } catch (e, st) {
      return Result.failure(
        UnexpectedFailure('Total IOB calculation failed: $e\n$st'),
      );
    }
  }

  @override
  Result<List<IOBBreakdownItem>> calculateIOBBreakdown({
    required List<InjectionRecord> injections,
    required Clock clock,
  }) {
    try {
      final items = <IOBBreakdownItem>[];

      for (final injection in injections) {
        // Include ALL injections in breakdown (including non-active ones
        // with 0 IOB) so the UI shows the complete picture.
        final elapsed = clock.minutesElapsed(injection.injectedAt);

        double iob;
        if (injection.isActiveForIOB) {
          iob = WalshIOBModel.remainingUnits(
            originalDoseUnits: injection.doseUnits.units,
            minutesElapsed: elapsed,
            durationMinutes: injection.duration.minutes,
          );
        } else {
          iob = 0.0;
        }

        final pct = injection.doseUnits.units > 0
            ? iob / injection.doseUnits.units
            : 0.0;

        final iobResult = InsulinUnits.fromUnitsUnclamped(iob);
        if (iobResult.isFailure) return Result.failure(iobResult.failure);

        items.add(
          IOBBreakdownItem(
            injectionId: injection.id,
            injectedAt: injection.injectedAt,
            originalDose: injection.doseUnits,
            remainingIOB: iobResult.value,
            percentRemaining: PrecisionMath.clamp(pct, min: 0.0, max: 1.0),
            minutesElapsed: elapsed,
          ),
        );
      }

      // Sort by injection time ascending (earliest first in breakdown UI)
      items.sort((a, b) => a.injectedAt.compareTo(b.injectedAt));

      return Result.success(items);
    } catch (e, st) {
      return Result.failure(
        UnexpectedFailure('IOB breakdown calculation failed: $e\n$st'),
      );
    }
  }

  // ── Convenience method (not on interface) ─────────────────────────────────

  /// Computes total IOB and returns the full breakdown together.
  ///
  /// More efficient than calling [calculateTotalIOB] and
  /// [calculateIOBBreakdown] separately when both are needed (e.g., the dose
  /// calculator screen which shows both the value and the per-injection list).
  Result<IOBCalculationResult> calculateWithBreakdown({
    required List<InjectionRecord> injections,
    required Clock clock,
  }) {
    final breakdownResult = calculateIOBBreakdown(
      injections: injections,
      clock: clock,
    );
    if (breakdownResult.isFailure) {
      return Result.failure(breakdownResult.failure);
    }

    final breakdown = breakdownResult.value;
    final total = breakdown.fold<double>(
      0.0,
      (sum, item) => sum + item.remainingIOB.units,
    );

    final normalisedTotal = PrecisionMath.normalise(total, decimals: 4);
    final totalResult = InsulinUnits.fromUnitsUnclamped(normalisedTotal);
    if (totalResult.isFailure) return Result.failure(totalResult.failure);

    return Result.success(
      IOBCalculationResult(
        totalIOB: totalResult.value,
        breakdown: breakdown,
      ),
    );
  }
}

/// Combined total IOB + per-injection breakdown.
final class IOBCalculationResult {
  const IOBCalculationResult({
    required this.totalIOB,
    required this.breakdown,
  });

  final InsulinUnits totalIOB;
  final List<IOBBreakdownItem> breakdown;

  int get injectionCount => breakdown.length;
  int get activeCount =>
      breakdown.where((b) => b.remainingIOB.isPositive).length;
}
