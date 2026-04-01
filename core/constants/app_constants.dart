// lib/core/constants/app_constants.dart

abstract final class AppConstants {
  // ── Identity ──────────────────────────────────────────────────────────────
  static const String appName = 'المساعد الذكي للأنسولين';
  static const String appNameEn = 'Smart Insulin Assistant';
  static const String appVersion = '1.0.0';

  // ── Locales ───────────────────────────────────────────────────────────────
  static const String defaultLocale = 'ar';
  static const String fallbackLocale = 'en';
  static const List<String> supportedLocales = ['ar', 'en'];

  // ── Database ──────────────────────────────────────────────────────────────
  static const String dbName = 'insulin_assistant.db';
  static const int dbVersion = 1;

  // ── Secure Storage Keys ───────────────────────────────────────────────────
  static const String keyEncryptionKeyAlias = 'ia_encryption_key_v1';
  static const String keyIVAlias = 'ia_iv_v1';
  static const String keyUserProfileAlias = 'ia_user_profile_v1';

  // ── UI ────────────────────────────────────────────────────────────────────
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;
  static const double inputBorderRadius = 12.0;
  static const double pageHorizontalPadding = 20.0;

  // ── BG chart display window (hours) ───────────────────────────────────────
  static const int bgChartWindowHours = 24;

  // ── Food search debounce ──────────────────────────────────────────────────
  static const int foodSearchDebounceMs = 300;

  // ── Asset paths ───────────────────────────────────────────────────────────
  static const String tfliteModelPath = 'assets/models/bg_predictor.tflite';
  static const String foodDataPath = 'assets/data/saudi_foods.json';

  // ── Snackbar durations ────────────────────────────────────────────────────
  static const int snackbarDurationMs = 3000;
  static const int criticalSnackbarDurationMs = 6000;

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int historyPageSize = 20;
}
