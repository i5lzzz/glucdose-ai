// test/unit/safety/safety_engine_comprehensive_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/safety/core/safety_level.dart';
import 'package:insulin_assistant/safety/core/safety_rule.dart';
import 'package:insulin_assistant/safety/engine/safety_evaluator_impl.dart';
import 'package:insulin_assistant/safety/engine/safety_rule_engine.dart';
import 'package:insulin_assistant/safety/rules/hard_block_rules.dart';
import 'package:insulin_assistant/safety/rules/soft_block_rules.dart';
import 'package:insulin_assistant/safety/rules/warning_rules.dart';

import '../../helpers/test_factories.dart';

const _eval = SafetyEvaluatorImpl();

void main() {
  group('SafetyEngine — Comprehensive Suite', () {

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 1 — Mandatory test cases from spec
    // ══════════════════════════════════════════════════════════════════════

    group('MANDATORY: specified cases', () {
      test('[BG=39] → HARD BLOCK — non-overrideable', () {
        final decision = _eval.evaluateRich(
          trace: TestFactories.trace(bgVal: 39),
          profile: TestFactories.profile(),
          currentBG: TestFactories.bg(39),
          currentIOB: TestFactories.iob(0),
        );
        expect(decision.level, equals(SafetyLevel.hardBlock));
        expect(decision.isOverrideable, isFalse);
        expect(decision.approvedDoseUnits, isNull);
        expect(decision.flags.any((f) => f.ruleId == 'R001_BG_LEVEL2_HYPO'), isTrue);
      });

      test('[BG=65] → WARNING — overrideable', () {
        final decision = _eval.evaluateRich(
          trace: TestFactories.trace(bgVal: 65),
          profile: TestFactories.profile(),
          currentBG: TestFactories.bg(65),
          currentIOB: TestFactories.iob(0),
        );
        expect(decision.level, equals(SafetyLevel.warning));
        expect(decision.isOverrideable, isTrue);
        expect(decision.flags.any((f) => f.ruleId == 'R201_BG_LEVEL1_HYPO'), isTrue);
      });

      test('[BG=150, normal] → SAFE — no flags', () {
        final decision = _eval.evaluateRich(
          trace: TestFactories.trace(),
          profile: TestFactories.profile(),
          currentBG: TestFactories.bg(150),
          currentIOB: TestFactories.iob(0),
        );
        expect(decision.level, equals(SafetyLevel.safe));
        expect(decision.flags, isEmpty);
        expect(decision.approvedDoseUnits, isNotNull);
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 2 — Hard block rules
    // ══════════════════════════════════════════════════════════════════════

    group('Hard block rules', () {
      final rule = const BgLevel2HypoglycaemiaRule();

      group('R001 — Level 2 Hypo', () {
        test('BG=39.9 → hardBlock', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(39.9),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
          );
          expect(rule.evaluate(ctx)?.level, equals(SafetyLevel.hardBlock));
        });

        test('BG=40.0 → null (boundary exclusive)', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(40.0),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
          );
          expect(rule.evaluate(ctx), isNull);
        });

        test('BG=20 (min valid) → hardBlock', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(20.0),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
          );
          expect(rule.evaluate(ctx)?.level, equals(SafetyLevel.hardBlock));
        });

        test('Message is bilingual and non-empty', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(35),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
          );
          final flag = rule.evaluate(ctx)!;
          expect(flag.message.ar, isNotEmpty);
          expect(flag.message.en, isNotEmpty);
        });

        test('numericContext contains bg_mgdl', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(30),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
          );
          expect(rule.evaluate(ctx)!.numericContext?['bg_mgdl'], closeTo(30, 0.1));
        });
      });

      group('R004 — Incomplete profile', () {
        test('Incomplete profile → hardBlock', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(150),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(complete: false),
          );
          final flag = const IncompleteProfileHardBlockRule().evaluate(ctx);
          expect(flag?.level, equals(SafetyLevel.hardBlock));
          expect(flag?.isOverrideable, isFalse);
        });

        test('Complete profile → no flag', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(150),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(complete: true),
          );
          expect(const IncompleteProfileHardBlockRule().evaluate(ctx), isNull);
        });
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 3 — Soft block rules
    // ══════════════════════════════════════════════════════════════════════

    group('Soft block rules', () {
      group('R101 — Dose ceiling', () {
        test('Raw dose > 20U → softBlock', () {
          // 300g / 10ICR = 30U raw > 20 absolute
          final trace = TestFactories.trace(carbsG: 300, bgVal: 100);
          final ctx = SafetyRuleContext(
            currentBG: TestFactories.bg(100),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(maxDose: 20.0),
            trace: trace,
            recentInjections: const [],
          );
          final flag = const DoseExceedsAbsoluteCeilingRule().evaluate(ctx);
          expect(flag?.level, equals(SafetyLevel.softBlock));
          expect(flag?.isOverrideable, isTrue);
        });
      });

      group('R102 — IOB stacking critical', () {
        test('IOB 70%+ of total → softBlock', () {
          final trace = TestFactories.trace(iobU: 21.0);
          final ctx = SafetyRuleContext(
            currentBG: TestFactories.bg(150),
            currentIOB: TestFactories.iob(21.0),
            profile: TestFactories.profile(),
            trace: trace,
            recentInjections: const [],
          );
          final flag = const IOBStackingCriticalRule().evaluate(ctx);
          expect(flag?.level, equals(SafetyLevel.softBlock));
        });

        test('Zero IOB → no flag', () {
          final ctx = SafetyRuleContext(
            currentBG: TestFactories.bg(150),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
            trace: TestFactories.trace(),
            recentInjections: const [],
          );
          expect(const IOBStackingCriticalRule().evaluate(ctx), isNull);
        });
      });

      group('R103 — Rapid repeat', () {
        test('5 min since last → softBlock', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(150),
            currentIOB: TestFactories.iob(2),
            profile: TestFactories.profile(),
            minutesSinceLastInjection: 5.0,
          );
          expect(const RapidRepeatInjectionRule().evaluate(ctx)?.level,
              equals(SafetyLevel.softBlock));
        });

        test('15 min → no flag (boundary)', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(150),
            currentIOB: TestFactories.iob(2),
            profile: TestFactories.profile(),
            minutesSinceLastInjection: 15.0,
          );
          expect(const RapidRepeatInjectionRule().evaluate(ctx), isNull);
        });

        test('Null minutesSince → no flag', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(150),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
          );
          expect(const RapidRepeatInjectionRule().evaluate(ctx), isNull);
        });
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 4 — Warning rules
    // ══════════════════════════════════════════════════════════════════════

    group('Warning rules', () {
      group('R201 — Level 1 Hypo', () {
        test('BG=65 → warning, overrideable', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(65),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
          );
          final flag = const BgLevel1HypoglycaemiaRule().evaluate(ctx);
          expect(flag?.level, equals(SafetyLevel.warning));
          expect(flag?.isOverrideable, isTrue);
        });

        test('BG=70 → null (threshold exclusive)', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(70),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
          );
          expect(const BgLevel1HypoglycaemiaRule().evaluate(ctx), isNull);
        });

        test('BG=39 → null (handled by R001)', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(39),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
          );
          expect(const BgLevel1HypoglycaemiaRule().evaluate(ctx), isNull);
        });
      });

      group('R202 — Hyperglycaemia', () {
        test('BG=350 → warning', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(350),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
          );
          expect(const BgHyperglycaemiaWarningRule().evaluate(ctx)?.level,
              equals(SafetyLevel.warning));
        });

        test('BG=300 → null (exclusive)', () {
          final ctx = PreCheckContext(
            currentBG: TestFactories.bg(300),
            currentIOB: TestFactories.iob(0),
            profile: TestFactories.profile(),
          );
          expect(const BgHyperglycaemiaWarningRule().evaluate(ctx), isNull);
        });
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 5 — Safety invariants
    // ══════════════════════════════════════════════════════════════════════

    group('Invariants', () {
      test('hardBlock.isOverrideable is ALWAYS false', () {
        for (final bg in [20.0, 30.0, 39.0, 39.9]) {
          final d = _eval.evaluateRich(
            trace: TestFactories.trace(bgVal: bg.clamp(40.0, 600.0)),
            profile: TestFactories.profile(),
            currentBG: TestFactories.bg(bg),
            currentIOB: TestFactories.iob(0),
          );
          if (d.isHardBlocked) {
            expect(d.isOverrideable, isFalse,
                reason: 'hardBlock at BG=$bg must be non-overrideable');
          }
        }
      });

      test('hardBlock short-circuits — no lower flags leak through', () {
        final engine = const SafetyRuleEngine();
        // Combine R001 (hardBlock) + R201 (warning)
        final rules = [
          const BgLevel2HypoglycaemiaRule(),
          const BgLevel1HypoglycaemiaRule(),
          const BgHyperglycaemiaWarningRule(),
        ];
        final ctx = SafetyRuleContext(
          currentBG: TestFactories.bg(39),
          currentIOB: TestFactories.iob(5),
          profile: TestFactories.profile(),
          trace: TestFactories.trace(bgVal: 39),
          recentInjections: const [],
          minutesSinceLastInjection: 5.0,
        );
        final d = engine.execute(rules: rules, context: ctx, evaluatorVersion: '1.0');
        expect(d.level, equals(SafetyLevel.hardBlock));
        expect(d.flags.every((f) => f.level == SafetyLevel.hardBlock), isTrue);
      });

      test('approvedDose is null for any blocking decision', () {
        final d = _eval.evaluateRich(
          trace: TestFactories.trace(bgVal: 25),
          profile: TestFactories.profile(),
          currentBG: TestFactories.bg(25),
          currentIOB: TestFactories.iob(0),
        );
        expect(d.isHardBlocked, isTrue);
        expect(d.approvedDoseUnits, isNull);
      });

      test('softBlock + warning → aggregate = softBlock', () {
        final engine = const SafetyRuleEngine();
        final ctx = SafetyRuleContext(
          currentBG: TestFactories.bg(65),
          currentIOB: TestFactories.iob(1),
          profile: TestFactories.profile(),
          trace: TestFactories.trace(bgVal: 65),
          recentInjections: const [],
          minutesSinceLastInjection: 5.0,
        );
        final d = engine.execute(
          rules: [
            const RapidRepeatInjectionRule(),
            const BgLevel1HypoglycaemiaRule(),
          ],
          context: ctx,
          evaluatorVersion: '1.0',
        );
        expect(d.level, equals(SafetyLevel.softBlock));
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 6 — Boundary sweep (12 BG values)
    // ══════════════════════════════════════════════════════════════════════

    group('Boundary sweep', () {
      final cases = <double, SafetyLevel>{
        20.0: SafetyLevel.hardBlock,
        39.0: SafetyLevel.hardBlock,
        39.9: SafetyLevel.hardBlock,
        40.0: SafetyLevel.warning,
        65.0: SafetyLevel.warning,
        69.9: SafetyLevel.warning,
        70.0: SafetyLevel.safe,
        100.0: SafetyLevel.safe,
        140.0: SafetyLevel.safe,
        300.0: SafetyLevel.safe,
        300.1: SafetyLevel.warning,
        350.0: SafetyLevel.warning,
      };

      cases.forEach((bg, expected) {
        test('BG=$bg → ${expected.name}', () {
          final safeBg = bg.clamp(20.0, 600.0);
          final d = _eval.evaluateRich(
            trace: TestFactories.trace(bgVal: safeBg),
            profile: TestFactories.profile(),
            currentBG: TestFactories.bg(bg),
            currentIOB: TestFactories.iob(0),
          );
          expect(d.level, equals(expected),
              reason: 'BG=$bg should produce ${expected.name}');
        });
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 7 — Pre-check
    // ══════════════════════════════════════════════════════════════════════

    group('Pre-check', () {
      test('BG=39 → canProceed=false', () {
        final check = _eval.preCheck(
          currentBG: TestFactories.bg(39),
          profile: TestFactories.profile(),
          currentIOB: TestFactories.iob(0),
        );
        expect(check.canProceed, isFalse);
        expect(check.blockReason, equals(SafetyBlockReason.level2Hypoglycaemia));
      });

      test('BG=65 → canProceed=true, has L1 hypo warning', () {
        final check = _eval.preCheck(
          currentBG: TestFactories.bg(65),
          profile: TestFactories.profile(),
          currentIOB: TestFactories.iob(0),
        );
        expect(check.canProceed, isTrue);
        expect(check.warningReasons,
            contains(SafetyBlockReason.level1Hypoglycaemia));
      });

      test('Normal BG → canProceed=true, no warnings', () {
        final check = _eval.preCheck(
          currentBG: TestFactories.bg(140),
          profile: TestFactories.profile(),
          currentIOB: TestFactories.iob(0),
        );
        expect(check.canProceed, isTrue);
        expect(check.warningReasons, isEmpty);
      });

      test('Incomplete profile → canProceed=false', () {
        final check = _eval.preCheck(
          currentBG: TestFactories.bg(140),
          profile: TestFactories.profile(complete: false),
          currentIOB: TestFactories.iob(0),
        );
        expect(check.canProceed, isFalse);
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 8 — Determinism
    // ══════════════════════════════════════════════════════════════════════

    group('Determinism', () {
      test('Same inputs → identical decision × 20', () {
        final trace = TestFactories.trace(bgVal: 65);
        final ref = _eval.evaluateRich(
          trace: trace,
          profile: TestFactories.profile(),
          currentBG: TestFactories.bg(65),
          currentIOB: TestFactories.iob(0),
        ).level;

        for (var i = 0; i < 20; i++) {
          final d = _eval.evaluateRich(
            trace: TestFactories.trace(bgVal: 65),
            profile: TestFactories.profile(),
            currentBG: TestFactories.bg(65),
            currentIOB: TestFactories.iob(0),
          );
          expect(d.level, equals(ref));
        }
      });

      test('Rules are stateless — alternating contexts do not bleed', () {
        final rule = const BgLevel2HypoglycaemiaRule();
        final ctxHard = PreCheckContext(
          currentBG: TestFactories.bg(39),
          currentIOB: TestFactories.iob(0),
          profile: TestFactories.profile(),
        );
        final ctxSafe = PreCheckContext(
          currentBG: TestFactories.bg(150),
          currentIOB: TestFactories.iob(0),
          profile: TestFactories.profile(),
        );
        for (var i = 0; i < 10; i++) {
          expect(rule.evaluate(ctxHard), isNotNull);
          expect(rule.evaluate(ctxSafe), isNull);
        }
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // GROUP 9 — Trace integration
    // ══════════════════════════════════════════════════════════════════════

    group('Trace integration', () {
      test('evaluate() returns new trace without mutating original', () {
        final original = TestFactories.trace();
        final originalFlagCount = original.output.safetyFlags.length;

        final eval = _eval.evaluate(
          trace: original,
          profile: TestFactories.profile(),
          currentBG: TestFactories.bg(350), // triggers R202
          currentIOB: TestFactories.iob(0),
        );

        // New trace may have more flags
        expect(
          eval.trace.output.safetyFlags.length,
          greaterThanOrEqualTo(originalFlagCount),
        );
        // Original unchanged
        expect(original.output.safetyFlags.length, equals(originalFlagCount));
      });

      test('Blocked evaluation sets wasBlocked=true on trace', () {
        final eval = _eval.evaluate(
          trace: TestFactories.trace(bgVal: 30),
          profile: TestFactories.profile(),
          currentBG: TestFactories.bg(30),
          currentIOB: TestFactories.iob(0),
        );
        expect(eval.trace.output.wasBlocked, isTrue);
      });

      test('Safe evaluation: wasBlocked=false on trace', () {
        final eval = _eval.evaluate(
          trace: TestFactories.trace(),
          profile: TestFactories.profile(),
          currentBG: TestFactories.bg(150),
          currentIOB: TestFactories.iob(0),
        );
        expect(eval.trace.output.wasBlocked, isFalse);
      });
    });
  });
}
