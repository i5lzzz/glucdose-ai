// lib/safety/core/safety_level.dart
// ─────────────────────────────────────────────────────────────────────────────
// SafetyLevel — the four-tier severity hierarchy used throughout the engine.
//
// ORDERING (ascending severity):
//   safe < warning < softBlock < hardBlock
//
// CLINICAL RATIONALE:
//   hardBlock  → patient is in immediate danger.  No override possible.
//                Maps to ISO 14971 severity = Critical / Catastrophic.
//   softBlock  → dose cannot be safely administered without explicit
//                clinical re-assessment.  Requires confirmed override.
//                Maps to ISO 14971 severity = Serious.
//   warning    → calculation is valid but a risk factor exists.  User
//                must acknowledge before seeing the dose.
//                Maps to ISO 14971 severity = Moderate.
//   safe       → no safety concerns detected.
//
// OVERRIDE MATRIX:
//   hardBlock  → isOverrideable = false  (enforced by engine, not just UI)
//   softBlock  → isOverrideable = true   (requires double-confirm)
//   warning    → isOverrideable = true   (requires acknowledgement)
//   safe       → n/a
// ─────────────────────────────────────────────────────────────────────────────

/// Four-tier clinical safety severity.
enum SafetyLevel {
  /// No safety concerns — dose may proceed.
  safe,

  /// Risk factor detected — user must acknowledge.
  warning,

  /// Dose blocked pending explicit clinical override.
  softBlock,

  /// Absolute block — no override possible under any circumstances.
  hardBlock;

  // ── Ordering helpers ──────────────────────────────────────────────────────

  bool get isBlockingLevel =>
      this == softBlock || this == hardBlock;

  bool get isHardBlock => this == hardBlock;
  bool get isSoftBlock => this == softBlock;
  bool get isWarning => this == warning;
  bool get isSafe => this == safe;

  /// Returns the higher severity of [this] and [other].
  SafetyLevel max(SafetyLevel other) =>
      index >= other.index ? this : other;

  /// Arabic label for display.
  String get nameAr => switch (this) {
        SafetyLevel.safe => 'آمن',
        SafetyLevel.warning => 'تحذير',
        SafetyLevel.softBlock => 'موقوف',
        SafetyLevel.hardBlock => 'محظور نهائياً',
      };

  /// English label for display.
  String get nameEn => switch (this) {
        SafetyLevel.safe => 'Safe',
        SafetyLevel.warning => 'Warning',
        SafetyLevel.softBlock => 'Blocked',
        SafetyLevel.hardBlock => 'Hard Block',
      };
}

// ── Bilingual safety message ──────────────────────────────────────────────────

/// An immutable bilingual message attached to a [SafetyDecision].
///
/// Arabic is always the primary message.
/// English is the secondary / clinical-record language.
final class SafetyMessage {
  const SafetyMessage({
    required this.ar,
    required this.en,
  });

  final String ar;
  final String en;

  /// Empty — used when level is [SafetyLevel.safe] and no message is needed.
  static const SafetyMessage empty = SafetyMessage(ar: '', en: '');

  /// Combines multiple messages into one, joining with newlines.
  static SafetyMessage combine(List<SafetyMessage> messages) {
    if (messages.isEmpty) return empty;
    return SafetyMessage(
      ar: messages.map((m) => m.ar).where((s) => s.isNotEmpty).join('\n'),
      en: messages.map((m) => m.en).where((s) => s.isNotEmpty).join('\n'),
    );
  }

  bool get isEmpty => ar.isEmpty && en.isEmpty;

  @override
  String toString() => 'SafetyMessage(ar: $ar)';
}
