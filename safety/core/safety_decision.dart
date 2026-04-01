// lib/safety/core/safety_decision.dart
// ─────────────────────────────────────────────────────────────────────────────
// SafetyDecision — the final output of the safety engine for one evaluation.
//
// IMMUTABILITY:
//   Created once by [SafetyEvaluatorImpl.evaluate()].  Never mutated.
//   Attaching it to a [CalculationTrace] produces a NEW trace object.
//
// GUARANTEED INVARIANTS (enforced by factory):
//   1. If level == hardBlock  → isOverrideable == false  ALWAYS
//   2. If level == safe       → flags is empty
//   3. primaryMessage is the highest-severity flag's message,
//      or [SafetyMessage.empty] when level == safe
//   4. approvedDose is null when level.isBlockingLevel == true
//
// RULE: The UI layer reads [isOverrideable] and [level] only.
//       It MUST NOT re-implement any safety logic.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import 'package:insulin_assistant/safety/core/safety_flag_detail.dart';
import 'package:insulin_assistant/safety/core/safety_level.dart';

/// The complete, immutable safety verdict for one dose calculation.
final class SafetyDecision extends Equatable {
  SafetyDecision._({
    required this.level,
    required this.flags,
    required this.primaryMessage,
    required this.isOverrideable,
    required this.evaluatorVersion,
    required this.evaluatedAt,
    this.approvedDoseUnits,
  }) : assert(
          level != SafetyLevel.hardBlock || !isOverrideable,
          'hardBlock decisions MUST be non-overrideable',
        ),
        assert(
          !level.isBlockingLevel || approvedDoseUnits == null,
          'Blocking decisions must not carry an approved dose',
        );

  // ── Fields ────────────────────────────────────────────────────────────────

  /// Overall severity — the maximum level across all flags.
  final SafetyLevel level;

  /// All flags raised during evaluation.
  final List<SafetyFlagDetail> flags;

  /// The primary bilingual message shown to the user.
  /// For multiple flags, this is the highest-severity flag's message.
  final SafetyMessage primaryMessage;

  /// Whether the user may explicitly override this decision.
  /// ALWAYS false for [SafetyLevel.hardBlock].
  final bool isOverrideable;

  /// Version of the safety rule set that produced this decision.
  final String evaluatorVersion;

  /// UTC timestamp of evaluation.
  final DateTime evaluatedAt;

  /// The final approved dose, if [level] is safe or warning.
  /// Null for any blocking decision.
  final double? approvedDoseUnits;

  // ── Named factories ───────────────────────────────────────────────────────

  /// Creates a [SafetyLevel.safe] decision with no flags.
  factory SafetyDecision.safe({
    required double approvedDoseUnits,
    required String evaluatorVersion,
  }) =>
      SafetyDecision._(
        level: SafetyLevel.safe,
        flags: const [],
        primaryMessage: SafetyMessage.empty,
        isOverrideable: false,
        evaluatorVersion: evaluatorVersion,
        evaluatedAt: DateTime.now().toUtc(),
        approvedDoseUnits: approvedDoseUnits,
      );

  /// Creates a warning decision — user must acknowledge, may proceed.
  factory SafetyDecision.warning({
    required List<SafetyFlagDetail> flags,
    required double approvedDoseUnits,
    required String evaluatorVersion,
  }) {
    assert(flags.isNotEmpty, 'Warning must have at least one flag');
    return SafetyDecision._(
      level: SafetyLevel.warning,
      flags: flags,
      primaryMessage: _primaryMessageFrom(flags),
      isOverrideable: true,
      evaluatorVersion: evaluatorVersion,
      evaluatedAt: DateTime.now().toUtc(),
      approvedDoseUnits: approvedDoseUnits,
    );
  }

  /// Creates a soft-block — user may override after explicit acknowledgement.
  factory SafetyDecision.softBlock({
    required List<SafetyFlagDetail> flags,
    required String evaluatorVersion,
  }) {
    assert(flags.isNotEmpty, 'SoftBlock must have at least one flag');
    return SafetyDecision._(
      level: SafetyLevel.softBlock,
      flags: flags,
      primaryMessage: _primaryMessageFrom(flags),
      isOverrideable: true,
      evaluatorVersion: evaluatorVersion,
      evaluatedAt: DateTime.now().toUtc(),
    );
  }

  /// Creates a hard-block — no override, no dose.
  factory SafetyDecision.hardBlock({
    required List<SafetyFlagDetail> flags,
    required String evaluatorVersion,
  }) {
    assert(flags.isNotEmpty, 'HardBlock must have at least one flag');
    return SafetyDecision._(
      level: SafetyLevel.hardBlock,
      flags: flags,
      primaryMessage: _primaryMessageFrom(flags),
      isOverrideable: false, // ← immutably false — cannot be changed by caller
      evaluatorVersion: evaluatorVersion,
      evaluatedAt: DateTime.now().toUtc(),
    );
  }

  // ── Convenience accessors ─────────────────────────────────────────────────

  bool get isApproved =>
      level == SafetyLevel.safe || level == SafetyLevel.warning;

  bool get isBlocked => level.isBlockingLevel;
  bool get isHardBlocked => level == SafetyLevel.hardBlock;
  bool get isSoftBlocked => level == SafetyLevel.softBlock;

  /// All flags whose [level] matches [SafetyLevel.hardBlock].
  List<SafetyFlagDetail> get hardBlockFlags =>
      flags.where((f) => f.level.isHardBlock).toList();

  /// All warning-level flags.
  List<SafetyFlagDetail> get warningFlags =>
      flags.where((f) => f.level.isWarning).toList();

  /// Recommended actions from all flags (combined, de-duplicated).
  List<String> get recommendedActionsAr => flags
      .map((f) => f.recommendedActionAr)
      .whereType<String>()
      .toSet()
      .toList();

  List<String> get recommendedActionsEn => flags
      .map((f) => f.recommendedActionEn)
      .whereType<String>()
      .toSet()
      .toList();

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'level_ar': level.nameAr,
        'level_en': level.nameEn,
        'is_overrideable': isOverrideable,
        'primary_message_ar': primaryMessage.ar,
        'primary_message_en': primaryMessage.en,
        'flags': flags.map((f) => f.toJson()).toList(),
        'evaluator_version': evaluatorVersion,
        'evaluated_at': evaluatedAt.toIso8601String(),
        if (approvedDoseUnits != null) 'approved_dose_units': approvedDoseUnits,
      };

  // ── Private helpers ───────────────────────────────────────────────────────

  static SafetyMessage _primaryMessageFrom(List<SafetyFlagDetail> flags) {
    // The primary message is from the highest-severity flag.
    final sorted = [...flags]
      ..sort((a, b) => b.level.index.compareTo(a.level.index));
    return sorted.first.message;
  }

  @override
  List<Object?> get props => [level, flags, isOverrideable, evaluatedAt];

  @override
  String toString() =>
      'SafetyDecision(level=${level.name}, flags=${flags.length}, '
      'overrideable=$isOverrideable)';
}
