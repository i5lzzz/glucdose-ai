// lib/domain/core/unit_system.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit system abstraction — mg/dL and mmol/L.
//
// INTERNAL REPRESENTATION IS ALWAYS mg/dL.
// Conversion happens only at:
//   a) input parsing (data → domain)
//   b) display formatting (domain → presentation)
//
// This eliminates the entire class of unit-confusion bugs that have caused
// real-world insulin pump errors (FDA MAUDE database: multiple reports of
// mg/dL values interpreted as mmol/L, causing 18× overdose).
//
// Conversion factor: 1 mmol/L = 18.01559 mg/dL (molecular weight of glucose).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Supported glucose unit systems.
enum GlucoseUnit {
  /// Milligrams per decilitre — default in Saudi Arabia, USA.
  mgdl,

  /// Millimoles per litre — used in UK, Canada, most of Europe.
  mmolL,
}

extension GlucoseUnitX on GlucoseUnit {
  String get symbol => switch (this) {
        GlucoseUnit.mgdl => 'mg/dL',
        GlucoseUnit.mmolL => 'mmol/L',
      };

  String get symbolAr => switch (this) {
        GlucoseUnit.mgdl => 'مغ/دل',
        GlucoseUnit.mmolL => 'ملمول/ل',
      };
}

/// Stateless unit conversion service.
///
/// All methods are pure functions — no state, no side effects,
/// safe to call from any layer including widget build methods.
abstract final class GlucoseUnitConverter {
  /// Exact molecular-weight-based conversion factor.
  static const double _mgdlPerMmol = 18.01559;

  /// Converts [mgdl] to mmol/L, rounded to 1 decimal place.
  static double toMmol(double mgdl) =>
      double.parse((mgdl / _mgdlPerMmol).toStringAsFixed(1));

  /// Converts [mmol] to mg/dL, rounded to the nearest integer.
  static double toMgdl(double mmol) =>
      double.parse((mmol * _mgdlPerMmol).toStringAsFixed(0));

  /// Converts [value] from [fromUnit] to mg/dL (internal representation).
  static double normaliseTomgdl(double value, GlucoseUnit fromUnit) =>
      switch (fromUnit) {
        GlucoseUnit.mgdl => value,
        GlucoseUnit.mmolL => toMgdl(value),
      };

  /// Converts internal mg/dL [value] to [targetUnit] for display.
  static double fromMgdl(double value, GlucoseUnit targetUnit) =>
      switch (targetUnit) {
        GlucoseUnit.mgdl => value,
        GlucoseUnit.mmolL => toMmol(value),
      };

  /// Formats [mgdlValue] for display in [unit] with correct precision.
  static String format(double mgdlValue, GlucoseUnit unit) {
    final converted = fromMgdl(mgdlValue, unit);
    return switch (unit) {
      GlucoseUnit.mgdl => converted.toStringAsFixed(0),
      GlucoseUnit.mmolL => converted.toStringAsFixed(1),
    };
  }
}

/// Immutable unit system preference — passed through DI, never a global.
final class UnitSystem extends Equatable {
  const UnitSystem({required this.glucose});

  const UnitSystem.mgdl() : glucose = GlucoseUnit.mgdl;
  const UnitSystem.mmolL() : glucose = GlucoseUnit.mmolL;

  final GlucoseUnit glucose;

  UnitSystem copyWith({GlucoseUnit? glucose}) =>
      UnitSystem(glucose: glucose ?? this.glucose);

  Map<String, dynamic> toJson() => {'glucose': glucose.name};
  factory UnitSystem.fromJson(Map<String, dynamic> json) => UnitSystem(
        glucose: GlucoseUnit.values.byName(
          json['glucose'] as String? ?? 'mgdl',
        ),
      );

  @override
  List<Object?> get props => [glucose];
}
