// lib/core/l10n/app_localizations_ar.dart
// ─────────────────────────────────────────────────────────────────────────────
// Arabic localisation strings.
// Arabic is the PRIMARY language — English is a fallback.
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> arStrings = {
  // ── App ───────────────────────────────────────────────────────────────────
  'app_name': 'المساعد الذكي للأنسولين',
  'app_tagline': 'رفيقك الذكي لإدارة السكري',

  // ── Navigation ────────────────────────────────────────────────────────────
  'nav_home': 'الرئيسية',
  'nav_dose': 'جرعة الأنسولين',
  'nav_history': 'السجل',
  'nav_meals': 'الوجبات',
  'nav_insights': 'التحليلات',
  'nav_settings': 'الإعدادات',

  // ── Dashboard ─────────────────────────────────────────────────────────────
  'dashboard_current_bg': 'سكر الدم الحالي',
  'dashboard_iob': 'الأنسولين الفعّال',
  'dashboard_last_dose': 'آخر جرعة',
  'dashboard_prediction_30': 'توقع ٣٠ دقيقة',
  'dashboard_prediction_60': 'توقع ساعة',
  'dashboard_prediction_120': 'توقع ساعتين',
  'dashboard_unit_mgdl': 'مغ/دل',
  'dashboard_unit_units': 'وحدة',

  // ── Dose Calculator ───────────────────────────────────────────────────────
  'dose_title': 'حساب جرعة الأنسولين',
  'dose_current_bg': 'سكر الدم الحالي (مغ/دل)',
  'dose_carbs': 'الكربوهيدرات (جرام)',
  'dose_iob': 'الأنسولين الفعّال (وحدة)',
  'dose_calculate': 'احسب الجرعة',
  'dose_result': 'الجرعة المحسوبة',
  'dose_confirm': 'تأكيد الحقن',
  'dose_cancel': 'إلغاء',
  'dose_explanation': 'شرح الحساب',
  'dose_breakdown_carb': 'جرعة الكربوهيدرات',
  'dose_breakdown_correction': 'جرعة التصحيح',
  'dose_breakdown_iob_deduction': 'خصم الأنسولين الفعّال',
  'dose_breakdown_total': 'الجرعة الإجمالية',

  // ── Safety Messages ───────────────────────────────────────────────────────
  'safety_hypo_level2_title': '🚨 تحذير خطير',
  'safety_hypo_level2_body':
      'مستوى السكر أقل من ٤٠ مغ/دل.\nلا يمكن حقن الأنسولين الآن.\nتناول السكر فوراً واتصل بالطوارئ.',
  'safety_hypo_level1_title': '⚠️ سكر الدم منخفض',
  'safety_hypo_level1_body':
      'مستوى السكر أقل من ٧٠ مغ/دل.\nالحقن الآن قد يكون خطيراً.\nهل أنت متأكد من المتابعة؟',
  'safety_dose_ceiling_title': '⚠️ الجرعة تتجاوز الحد الأقصى',
  'safety_dose_ceiling_body':
      'الجرعة المحسوبة تتجاوز حدك الأقصى المحدد. يرجى مراجعة طبيبك.',
  'safety_iob_stacking_title': '⚠️ تراكم الأنسولين',
  'safety_iob_stacking_body':
      'يوجد أنسولين فعّال مرتفع. حقن جرعة إضافية قد يسبب انخفاضاً حاداً.',
  'safety_confirm_injection': 'هل تريد حقن {dose} وحدة؟',
  'safety_confirm_hold': 'اضغط مع الاستمرار {seconds} ثوانٍ للتأكيد',

  // ── Prediction ────────────────────────────────────────────────────────────
  'prediction_title': 'توقع سكر الدم',
  'prediction_hypo_alert': 'خطر انخفاض السكر متوقع خلال {minutes} دقيقة',
  'prediction_hyper_alert': 'ارتفاع السكر متوقع — يُنصح بجرعة تصحيح',
  'prediction_eat_carbs': 'يُنصح بتناول {carbs} جرام كربوهيدرات وقائياً',

  // ── Food / Meals ──────────────────────────────────────────────────────────
  'food_search_hint': 'ابحث عن طعام... (مثل: كبسة)',
  'food_carbs_per_100g': 'كربوهيدرات لكل ١٠٠ جرام',
  'food_gi': 'المؤشر الجلايسيمي',
  'food_absorption': 'سرعة الامتصاص',
  'food_absorption_slow': 'بطيء',
  'food_absorption_medium': 'متوسط',
  'food_absorption_fast': 'سريع',
  'food_portion': 'الحصة الافتراضية',
  'food_add_to_meal': 'أضف إلى الوجبة',
  'meal_total_carbs': 'إجمالي الكربوهيدرات',
  'meal_calculate_dose': 'احسب الجرعة لهذه الوجبة',

  // ── History ───────────────────────────────────────────────────────────────
  'history_title': 'سجل القراءات',
  'history_dose': 'جرعة',
  'history_reading': 'قراءة',
  'history_meal': 'وجبة',
  'history_empty': 'لا توجد سجلات حتى الآن',

  // ── Insights ──────────────────────────────────────────────────────────────
  'insights_title': 'التحليلات الذكية',
  'insights_empty': 'سيتم توليد تحليلات بعد تسجيل المزيد من البيانات',
  'insight_pattern_high_after_meal': 'ارتفاع متكرر بعد وجبة {meal}',
  'insight_nighttime_hypo': 'انخفاض ليلي متكرر بين {from} و{to}',
  'insight_overcorrection': 'نمط تصحيح زائد للأنسولين',

  // ── Settings / Profile ────────────────────────────────────────────────────
  'settings_title': 'الإعدادات',
  'profile_icr': 'نسبة الكربوهيدرات للأنسولين (ICR)',
  'profile_isf': 'معامل حساسية الأنسولين (ISF)',
  'profile_target_bg': 'مستوى السكر المستهدف',
  'profile_max_dose': 'الجرعة القصوى',
  'profile_insulin_duration': 'مدة تأثير الأنسولين (دقيقة)',
  'profile_save': 'حفظ',

  // ── Common ────────────────────────────────────────────────────────────────
  'common_units': 'وحدة',
  'common_grams': 'جرام',
  'common_mgdl': 'مغ/دل',
  'common_minutes': 'دقيقة',
  'common_yes': 'نعم',
  'common_no': 'لا',
  'common_ok': 'حسناً',
  'common_cancel': 'إلغاء',
  'common_save': 'حفظ',
  'common_loading': 'جاري التحميل...',
  'common_error': 'حدث خطأ',
  'common_retry': 'حاول مجدداً',
  'common_required_field': 'هذا الحقل مطلوب',
  'common_invalid_value': 'القيمة غير صالحة',

  // ── Errors ────────────────────────────────────────────────────────────────
  'error_incomplete_profile': 'يرجى إكمال ملفك الشخصي الطبي أولاً',
  'error_invalid_bg': 'قيمة سكر الدم غير صالحة',
  'error_invalid_carbs': 'قيمة الكربوهيدرات غير صالحة',
  'error_database': 'خطأ في قاعدة البيانات',
  'error_prediction': 'تعذّر توليد التوقع',
};
