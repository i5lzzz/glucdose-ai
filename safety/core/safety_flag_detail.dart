// lib/safety/core/safety_flag_detail.dart
// ─────────────────────────────────────────────────────────────────────────────
// SafeFlagDetail — the engine-internal enriched flag produced by each rule.
//
// This is richer than the domain-layer [SafetyFlag]:
//   • carries bilingual [SafetyMessage]
//   • carries [SafetyLevel] (not just severity string)
//   • carries [ruleId] for independent rule tracing
//   • carries [isOverrideable] at the flag level
//   • carries optional [recommendedActionAr/En] for the UI
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/safety/core/safety_level.dart';

/// Internal safety flag produced by a single [SafetyRule].
final class SafetyFlagDetail extends Equatable {
  const SafetyFlagDetail({
    required this.ruleId,
    required this.level,
    required this.reason,
    required this.message,
    required this.isOverrideable,
    this.recommendedActionAr,
    this.recommendedActionEn,
    this.numericContext,
  });

  /// Unique rule identifier — matches [SafetyRule.ruleId].
  final String ruleId;

  /// Severity of this flag.
  final SafetyLevel level;

  /// Structured reason code (maps to risk register entry).
  final SafetyBlockReason reason;

  /// Bilingual human-readable message.
  final SafetyMessage message;

  /// Whether the user may override this specific flag.
  /// Always false when [level] == [SafetyLevel.hardBlock].
  final bool isOverrideable;

  /// Optional recommended action (e.g. "تناول ١٥ جرام كربوهيدرات").
  final String? recommendedActionAr;
  final String? recommendedActionEn;

  /// Optional numeric context (e.g. the BG value that triggered the rule).
  final Map<String, double>? numericContext;

  // ── Conversion to domain layer flag ───────────────────────────────────────

  SafetyFlag toDomainFlag() => SafetyFlag(
        reason: reason,
        severity: _domainSeverity(level),
        description: message.ar,
        wasBlocking: level.isBlockingLevel,
      );

  SafetyFlagSeverity _domainSeverity(SafetyLevel l) => switch (l) {
        SafetyLevel.hardBlock => SafetyFlagSeverity.critical,
        SafetyLevel.softBlock => SafetyFlagSeverity.critical,
        SafetyLevel.warning => SafetyFlagSeverity.warning,
        SafetyLevel.safe => SafetyFlagSeverity.info,
      };

  Map<String, dynamic> toJson() => {
        'rule_id': ruleId,
        'level': level.name,
        'reason': reason.name,
        'message_ar': message.ar,
        'message_en': message.en,
        'overrideable': isOverrideable,
        if (recommendedActionAr != null) 'action_ar': recommendedActionAr,
        if (recommendedActionEn != null) 'action_en': recommendedActionEn,
        if (numericContext != null) 'context': numericContext,
      };

  @override
  List<Object?> get props => [ruleId, level, reason];

  @override
  String toString() => 'SafetyFlagDetail(rule=$ruleId, level=${level.name})';
}
