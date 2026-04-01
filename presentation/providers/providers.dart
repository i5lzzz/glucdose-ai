// lib/presentation/providers/providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/entities/glucose_reading.dart';
import 'package:insulin_assistant/domain/entities/injection_record.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/carbohydrates.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';
import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/presentation/providers/user_settings_provider.dart';

export 'user_settings_provider.dart';

// ── BG State ──────────────────────────────────────────────────────────────────

class BGState {
  const BGState({this.value, this.trend = GlucoseTrend.unknown});
  final BloodGlucose? value;
  final GlucoseTrend trend;

  BGState copyWith({BloodGlucose? value, GlucoseTrend? trend}) =>
      BGState(value: value ?? this.value, trend: trend ?? this.trend);

  bool get isHypo => value != null && (value!.mgdl < MedicalConstants.bgLevel1HypoWarn);
  bool get isHyper => value != null && (value!.mgdl > MedicalConstants.bgHyperAlertThreshold);
  bool get isInRange => value != null && value!.isInRange;
}

final bgStateProvider = StateProvider<BGState>((ref) => const BGState());

// ── IOB State ─────────────────────────────────────────────────────────────────

final iobProvider = StateProvider<InsulinUnits>((ref) => InsulinUnits.zero);

// ── Recent Injections ─────────────────────────────────────────────────────────

final recentInjectionsProvider =
    StateProvider<List<InjectionRecord>>((ref) => []);

// ── Predictions ───────────────────────────────────────────────────────────────

class PredictionState {
  const PredictionState({
    this.bg30,
    this.bg60,
    this.bg120,
    this.isLoading = false,
  });
  final double? bg30;
  final double? bg60;
  final double? bg120;
  final bool isLoading;

  PredictionState copyWith({double? bg30, double? bg60, double? bg120, bool? isLoading}) =>
      PredictionState(
        bg30: bg30 ?? this.bg30,
        bg60: bg60 ?? this.bg60,
        bg120: bg120 ?? this.bg120,
        isLoading: isLoading ?? this.isLoading,
      );
}

final predictionProvider = StateProvider<PredictionState>((ref) => const PredictionState());

// ── Calculator Input State ────────────────────────────────────────────────────

class CalculatorInputState {
  const CalculatorInputState({
    this.bgInput = '',
    this.carbsInput = '',
    this.calculatedDose,
    this.carbComponent,
    this.correctionComponent,
    this.iobDeduction,
    this.safetyMessage,
    this.safetyLevel,
    this.isCalculating = false,
    this.error,
  });

  final String bgInput;
  final String carbsInput;
  final double? calculatedDose;
  final double? carbComponent;
  final double? correctionComponent;
  final double? iobDeduction;
  final String? safetyMessage;
  final CalculatorSafetyLevel? safetyLevel;
  final bool isCalculating;
  final String? error;

  bool get hasResult => calculatedDose != null;
  bool get canCalculate =>
      bgInput.isNotEmpty && double.tryParse(bgInput) != null;

  CalculatorInputState copyWith({
    String? bgInput,
    String? carbsInput,
    double? calculatedDose,
    double? carbComponent,
    double? correctionComponent,
    double? iobDeduction,
    String? safetyMessage,
    CalculatorSafetyLevel? safetyLevel,
    bool? isCalculating,
    String? error,
    bool clearResult = false,
  }) =>
      CalculatorInputState(
        bgInput: bgInput ?? this.bgInput,
        carbsInput: carbsInput ?? this.carbsInput,
        calculatedDose: clearResult ? null : calculatedDose ?? this.calculatedDose,
        carbComponent: clearResult ? null : carbComponent ?? this.carbComponent,
        correctionComponent: clearResult ? null : correctionComponent ?? this.correctionComponent,
        iobDeduction: clearResult ? null : iobDeduction ?? this.iobDeduction,
        safetyMessage: clearResult ? null : safetyMessage ?? this.safetyMessage,
        safetyLevel: clearResult ? null : safetyLevel ?? this.safetyLevel,
        isCalculating: isCalculating ?? this.isCalculating,
        error: clearResult ? null : error ?? this.error,
      );
}

enum CalculatorSafetyLevel { safe, warning, softBlock, hardBlock }

final calculatorProvider =
    StateProvider<CalculatorInputState>((ref) => const CalculatorInputState());

// ── History List ──────────────────────────────────────────────────────────────

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.primaryValue,
    required this.unit,
    this.subtitle,
  });

  final String id;
  final HistoryItemType type;
  final DateTime timestamp;
  final String primaryValue;
  final String unit;
  final String? subtitle;
}

enum HistoryItemType { injection, glucose, calculation }

final historyProvider = StateProvider<List<HistoryItem>>((ref) {
  // Demo data — replaced by repository in production
  final now = DateTime.now();
  return [
    HistoryItem(
      id: '1', type: HistoryItemType.injection,
      timestamp: now.subtract(const Duration(hours: 1)),
      primaryValue: '4.0', unit: 'U',
      subtitle: 'بعد وجبة الغداء',
    ),
    HistoryItem(
      id: '2', type: HistoryItemType.glucose,
      timestamp: now.subtract(const Duration(hours: 2)),
      primaryValue: '142', unit: 'مغ/دل',
    ),
    HistoryItem(
      id: '3', type: HistoryItemType.injection,
      timestamp: now.subtract(const Duration(hours: 5)),
      primaryValue: '6.5', unit: 'U',
      subtitle: 'وجبة الإفطار',
    ),
    HistoryItem(
      id: '4', type: HistoryItemType.glucose,
      timestamp: now.subtract(const Duration(hours: 6)),
      primaryValue: '198', unit: 'مغ/دل',
    ),
    HistoryItem(
      id: '5', type: HistoryItemType.calculation,
      timestamp: now.subtract(const Duration(hours: 6, minutes: 5)),
      primaryValue: '7.0', unit: 'U',
      subtitle: '٦٠ جرام كربوهيدرات',
    ),
  ];
});

// ── Active nav index ──────────────────────────────────────────────────────────
final navIndexProvider = StateProvider<int>((ref) => 0);
