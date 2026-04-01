// lib/presentation/providers/app_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/domain/value_objects/blood_glucose.dart';
import 'package:insulin_assistant/domain/value_objects/carbohydrates.dart';
import 'package:insulin_assistant/domain/value_objects/insulin_units.dart';
import 'package:insulin_assistant/algorithms/dose/dose_step.dart';
import 'package:insulin_assistant/domain/core/unit_system.dart';

// ── User Settings State ───────────────────────────────────────────────────────

class UserSettingsState {
  const UserSettingsState({
    this.unitSystem = const UnitSystem.mgdl(),
    this.doseStep = DoseStep.half,
    this.icr = MedicalConstants.defaultICR,
    this.isf = MedicalConstants.defaultISF,
    this.targetBG = MedicalConstants.bgDefaultTarget,
    this.maxDose = MedicalConstants.defaultUserMaxDoseUnits,
    this.insulinDurationMinutes = MedicalConstants.defaultInsulinDurationMinutes,
    this.locale = 'ar',
  });

  final UnitSystem unitSystem;
  final DoseStep doseStep;
  final double icr;
  final double isf;
  final double targetBG;
  final double maxDose;
  final double insulinDurationMinutes;
  final String locale;

  UserSettingsState copyWith({
    UnitSystem? unitSystem,
    DoseStep? doseStep,
    double? icr,
    double? isf,
    double? targetBG,
    double? maxDose,
    double? insulinDurationMinutes,
    String? locale,
  }) => UserSettingsState(
    unitSystem: unitSystem ?? this.unitSystem,
    doseStep: doseStep ?? this.doseStep,
    icr: icr ?? this.icr,
    isf: isf ?? this.isf,
    targetBG: targetBG ?? this.targetBG,
    maxDose: maxDose ?? this.maxDose,
    insulinDurationMinutes: insulinDurationMinutes ?? this.insulinDurationMinutes,
    locale: locale ?? this.locale,
  );
}

class UserSettingsNotifier extends StateNotifier<UserSettingsState> {
  UserSettingsNotifier() : super(const UserSettingsState());

  void setDoseStep(DoseStep step) =>
      state = state.copyWith(doseStep: step);
  void setICR(double v) => state = state.copyWith(icr: v);
  void setISF(double v) => state = state.copyWith(isf: v);
  void setTargetBG(double v) => state = state.copyWith(targetBG: v);
  void setMaxDose(double v) => state = state.copyWith(maxDose: v);
  void setDurationMinutes(double v) =>
      state = state.copyWith(insulinDurationMinutes: v);
  void toggleUnits() => state = state.copyWith(
    unitSystem: state.unitSystem.glucose == GlucoseUnit.mgdl
        ? const UnitSystem.mmolL()
        : const UnitSystem.mgdl(),
  );
}

final userSettingsProvider =
    StateNotifierProvider<UserSettingsNotifier, UserSettingsState>(
  (ref) => UserSettingsNotifier(),
);

// ── Dashboard State ───────────────────────────────────────────────────────────

class DashboardState {
  const DashboardState({
    this.currentBGMgdl,
    this.iobUnits = 0.0,
    this.lastDoseUnits,
    this.lastDoseAt,
    this.prediction30,
    this.prediction60,
    this.prediction120,
    this.isLoading = false,
  });

  final double? currentBGMgdl;
  final double iobUnits;
  final double? lastDoseUnits;
  final DateTime? lastDoseAt;
  final double? prediction30;
  final double? prediction60;
  final double? prediction120;
  final bool isLoading;

  DashboardState copyWith({
    double? currentBGMgdl,
    double? iobUnits,
    double? lastDoseUnits,
    DateTime? lastDoseAt,
    double? prediction30,
    double? prediction60,
    double? prediction120,
    bool? isLoading,
  }) => DashboardState(
    currentBGMgdl: currentBGMgdl ?? this.currentBGMgdl,
    iobUnits: iobUnits ?? this.iobUnits,
    lastDoseUnits: lastDoseUnits ?? this.lastDoseUnits,
    lastDoseAt: lastDoseAt ?? this.lastDoseAt,
    prediction30: prediction30 ?? this.prediction30,
    prediction60: prediction60 ?? this.prediction60,
    prediction120: prediction120 ?? this.prediction120,
    isLoading: isLoading ?? this.isLoading,
  );
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState());

  void setCurrentBG(double mgdl) =>
      state = state.copyWith(currentBGMgdl: mgdl);
  void setIOB(double units) => state = state.copyWith(iobUnits: units);
  void setPredictions(double p30, double p60, double p120) => state = state.copyWith(
    prediction30: p30, prediction60: p60, prediction120: p120,
  );
  void setLoading(bool v) => state = state.copyWith(isLoading: v);
  void recordDose(double units) => state = state.copyWith(
    lastDoseUnits: units, lastDoseAt: DateTime.now(),
  );
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(),
);

// ── Calculator State ──────────────────────────────────────────────────────────

enum CalcStatus { idle, calculating, result, error }

class CalculatorState {
  const CalculatorState({
    this.bgInput = '',
    this.carbsInput = '',
    this.calculatedDose,
    this.carbComponent,
    this.correctionComponent,
    this.iobDeduction,
    this.rawDose,
    this.safetyLevel,
    this.safetyMessageAr,
    this.status = CalcStatus.idle,
    this.errorMessage,
  });

  final String bgInput;
  final String carbsInput;
  final double? calculatedDose;
  final double? carbComponent;
  final double? correctionComponent;
  final double? iobDeduction;
  final double? rawDose;
  final String? safetyLevel;   // 'safe' | 'warning' | 'softBlock' | 'hardBlock'
  final String? safetyMessageAr;
  final CalcStatus status;
  final String? errorMessage;

  bool get hasResult => calculatedDose != null;
  bool get isBlocked =>
      safetyLevel == 'hardBlock' || safetyLevel == 'softBlock';
  bool get canConfirm => hasResult && !isBlocked;

  CalculatorState copyWith({
    String? bgInput,
    String? carbsInput,
    double? calculatedDose,
    double? carbComponent,
    double? correctionComponent,
    double? iobDeduction,
    double? rawDose,
    String? safetyLevel,
    String? safetyMessageAr,
    CalcStatus? status,
    String? errorMessage,
  }) => CalculatorState(
    bgInput: bgInput ?? this.bgInput,
    carbsInput: carbsInput ?? this.carbsInput,
    calculatedDose: calculatedDose ?? this.calculatedDose,
    carbComponent: carbComponent ?? this.carbComponent,
    correctionComponent: correctionComponent ?? this.correctionComponent,
    iobDeduction: iobDeduction ?? this.iobDeduction,
    rawDose: rawDose ?? this.rawDose,
    safetyLevel: safetyLevel ?? this.safetyLevel,
    safetyMessageAr: safetyMessageAr ?? this.safetyMessageAr,
    status: status ?? this.status,
    errorMessage: errorMessage,
  );
}

class CalculatorNotifier extends StateNotifier<CalculatorState> {
  CalculatorNotifier(this._ref) : super(const CalculatorState());

  final Ref _ref;

  void setBGInput(String v) => state = state.copyWith(bgInput: v);
  void setCarbsInput(String v) => state = state.copyWith(carbsInput: v);

  Future<void> calculate() async {
    final bg = double.tryParse(state.bgInput);
    final carbs = double.tryParse(state.carbsInput);
    if (bg == null || carbs == null) return;

    state = state.copyWith(status: CalcStatus.calculating);
    await Future.delayed(const Duration(milliseconds: 400));

    final settings = _ref.read(userSettingsProvider);
    final dashboard = _ref.read(dashboardProvider);
    final iob = dashboard.iobUnits;
    final icr = settings.icr;
    final isf = settings.isf;
    final targetBG = settings.targetBG;
    final doseStep = settings.doseStep;

    // Core formula
    final carbDose   = carbs / icr;
    final correction = (bg - targetBG) / isf;
    final raw        = carbDose + correction - iob;
    final clamped    = raw.clamp(0.0, settings.maxDose);
    final stepped    = doseStep.floor(clamped);

    // Safety evaluation (simplified for UI layer)
    String safetyLevel = 'safe';
    String? safetyMsg;
    if (bg < MedicalConstants.bgLevel2HypoHardBlock) {
      safetyLevel = 'hardBlock';
      safetyMsg = '🚨 سكر الدم أقل من ٤٠ مغ/دل — لا يمكن الحقن';
    } else if (bg < MedicalConstants.bgLevel1HypoWarn) {
      safetyLevel = 'warning';
      safetyMsg = '⚠️ سكر الدم منخفض — تأكد من تناول الطعام قريباً';
    } else if (bg > 300) {
      safetyLevel = 'warning';
      safetyMsg = '⚠️ سكر الدم مرتفع جداً — استشر طبيبك';
    } else if (clamped < raw - 0.01) {
      safetyLevel = 'warning';
      safetyMsg = '⚠️ الجرعة قُيِّدت للحد الأقصى المسموح';
    }

    state = state.copyWith(
      calculatedDose: stepped,
      carbComponent: carbDose,
      correctionComponent: correction,
      iobDeduction: iob,
      rawDose: raw,
      safetyLevel: safetyLevel,
      safetyMessageAr: safetyMsg,
      status: CalcStatus.result,
    );
  }

  void reset() => state = const CalculatorState();
}

final calculatorProvider =
    StateNotifierProvider<CalculatorNotifier, CalculatorState>(
  (ref) => CalculatorNotifier(ref),
);

// ── History State ─────────────────────────────────────────────────────────────

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.at,
    required this.type,
    required this.primaryValueAr,
    required this.secondaryAr,
    this.safetyLevel = 'safe',
  });
  final String id;
  final DateTime at;
  final String type; // 'dose' | 'reading' | 'meal'
  final String primaryValueAr;
  final String secondaryAr;
  final String safetyLevel;
}

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  HistoryNotifier() : super(_sampleHistory());

  void addEntry(HistoryEntry entry) => state = [entry, ...state];

  static List<HistoryEntry> _sampleHistory() {
    final now = DateTime.now();
    return [
      HistoryEntry(
        id: 'h1', at: now.subtract(const Duration(minutes: 30)),
        type: 'dose', primaryValueAr: '٤.٥ وحدة', secondaryAr: '٦٠ جرام كربوهيدرات',
      ),
      HistoryEntry(
        id: 'h2', at: now.subtract(const Duration(hours: 2)),
        type: 'reading', primaryValueAr: '١٤٥ مغ/دل', secondaryAr: 'قراءة يدوية',
        safetyLevel: 'warning',
      ),
      HistoryEntry(
        id: 'h3', at: now.subtract(const Duration(hours: 4)),
        type: 'dose', primaryValueAr: '٣.٠ وحدة', secondaryAr: '٤٥ جرام كربوهيدرات',
      ),
      HistoryEntry(
        id: 'h4', at: now.subtract(const Duration(hours: 6)),
        type: 'reading', primaryValueAr: '٩٨ مغ/دل', secondaryAr: 'قراءة يدوية',
        safetyLevel: 'safe',
      ),
      HistoryEntry(
        id: 'h5', at: now.subtract(const Duration(hours: 8)),
        type: 'meal', primaryValueAr: 'كبسة', secondaryAr: '٤٥ جرام كربوهيدرات',
      ),
      HistoryEntry(
        id: 'h6', at: now.subtract(const Duration(hours: 10)),
        type: 'dose', primaryValueAr: '٦.٠ وحدة', secondaryAr: '٨٠ جرام كربوهيدرات',
      ),
    ];
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>(
  (ref) => HistoryNotifier(),
);

// ── Navigation index ──────────────────────────────────────────────────────────
final navIndexProvider = StateProvider<int>((ref) => 0);
