// lib/domain/entities/food_item.dart
// ─────────────────────────────────────────────────────────────────────────────
// FoodItem entity — Saudi food database entry.
//
// Each food item carries enough data to:
//   1. Calculate total carbohydrates for a given serving
//   2. Estimate the absorption speed / shape of the glucose response
//   3. Display correctly in Arabic and English
//
// GlycaemicProfile encapsulates both GI and absorption speed — together they
// drive the carbohydrate absorption curve in the prediction engine.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Speed at which carbohydrates from this food raise blood glucose.
enum AbsorptionSpeed {
  /// Low GI, fibre-rich foods — carbs absorbed over 2–3 hours.
  /// Example: لوبيا (kidney beans), جريش (coarsely ground wheat)
  slow,

  /// Medium GI — carbs absorbed over 1–2 hours.
  /// Example: كبسة, رز أبيض (white rice)
  medium,

  /// High GI — carbs absorbed within 30–60 min.
  /// Example: تمر (dates), عصير (juice), خبز تميس (flatbread)
  fast,
}

extension AbsorptionSpeedX on AbsorptionSpeed {
  /// Approximate half-time of absorption (minutes) for prediction model.
  double get halfTimeMinutes => switch (this) {
        AbsorptionSpeed.slow => 120.0,
        AbsorptionSpeed.medium => 75.0,
        AbsorptionSpeed.fast => 35.0,
      };

  String get nameAr => switch (this) {
        AbsorptionSpeed.slow => 'بطيء',
        AbsorptionSpeed.medium => 'متوسط',
        AbsorptionSpeed.fast => 'سريع',
      };

  String get nameEn => switch (this) {
        AbsorptionSpeed.slow => 'Slow',
        AbsorptionSpeed.medium => 'Medium',
        AbsorptionSpeed.fast => 'Fast',
      };
}

/// Glycaemic profile combining GI category and absorption speed.
final class GlycaemicProfile extends Equatable {
  const GlycaemicProfile({
    required this.glycaemicIndex,
    required this.absorptionSpeed,
  });

  /// Approximate glycaemic index (1–100 scale).
  final int glycaemicIndex;
  final AbsorptionSpeed absorptionSpeed;

  bool get isLowGI => glycaemicIndex < 55;
  bool get isMediumGI => glycaemicIndex >= 55 && glycaemicIndex < 70;
  bool get isHighGI => glycaemicIndex >= 70;

  @override
  List<Object?> get props => [glycaemicIndex, absorptionSpeed];
}

/// Food category (for grouping in the food picker UI).
enum FoodCategory {
  mainDish, // أطباق رئيسية
  bread, // خبز ومخبوزات
  rice, // أرز
  legumes, // بقوليات
  fruits, // فواكه
  vegetables, // خضار
  dairy, // ألبان
  sweets, // حلويات
  beverages, // مشروبات
  snacks, // وجبات خفيفة
  custom, // مستخدم
}

extension FoodCategoryX on FoodCategory {
  String get nameAr => switch (this) {
        FoodCategory.mainDish => 'أطباق رئيسية',
        FoodCategory.bread => 'خبز ومخبوزات',
        FoodCategory.rice => 'أرز',
        FoodCategory.legumes => 'بقوليات',
        FoodCategory.fruits => 'فواكه',
        FoodCategory.vegetables => 'خضار',
        FoodCategory.dairy => 'ألبان',
        FoodCategory.sweets => 'حلويات',
        FoodCategory.beverages => 'مشروبات',
        FoodCategory.snacks => 'وجبات خفيفة',
        FoodCategory.custom => 'مخصص',
      };
}

/// Immutable food database entry.
final class FoodItem extends Equatable {
  const FoodItem({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.carbsPer100g,
    required this.glycaemicProfile,
    required this.defaultPortionGrams,
    required this.category,
    required this.createdAt,
    this.isCustom = false,
    this.descriptionAr,
    this.descriptionEn,
  });

  final String id;
  final String nameAr;
  final String nameEn;

  /// Grams of carbohydrate per 100 g of food.
  final double carbsPer100g;
  final GlycaemicProfile glycaemicProfile;

  /// Suggested serving size in grams.
  final double defaultPortionGrams;
  final FoodCategory category;
  final DateTime createdAt;

  /// True for user-added custom foods.
  final bool isCustom;
  final String? descriptionAr;
  final String? descriptionEn;

  // ── Calculation helpers ───────────────────────────────────────────────────

  /// Carbohydrates in [portionGrams] grams of this food.
  double carbsForPortion(double portionGrams) =>
      (portionGrams / 100.0) * carbsPer100g;

  /// Carbohydrates in the default portion.
  double get defaultPortionCarbs => carbsForPortion(defaultPortionGrams);

  AbsorptionSpeed get absorptionSpeed =>
      glycaemicProfile.absorptionSpeed;

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_ar': nameAr,
        'name_en': nameEn,
        'carbs_per_100g': carbsPer100g,
        'glycaemic_index': glycaemicProfile.glycaemicIndex,
        'absorption_speed': glycaemicProfile.absorptionSpeed.name,
        'default_portion_g': defaultPortionGrams,
        'category': category.name,
        'is_custom': isCustom ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        if (descriptionAr != null) 'description_ar': descriptionAr,
        if (descriptionEn != null) 'description_en': descriptionEn,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        nameAr: json['name_ar'] as String,
        nameEn: json['name_en'] as String,
        carbsPer100g: (json['carbs_per_100g'] as num).toDouble(),
        glycaemicProfile: GlycaemicProfile(
          glycaemicIndex: json['glycaemic_index'] as int,
          absorptionSpeed: AbsorptionSpeed.values.byName(
            json['absorption_speed'] as String,
          ),
        ),
        defaultPortionGrams: (json['default_portion_g'] as num).toDouble(),
        category: FoodCategory.values.byName(json['category'] as String),
        isCustom: (json['is_custom'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(json['created_at'] as String),
        descriptionAr: json['description_ar'] as String?,
        descriptionEn: json['description_en'] as String?,
      );

  @override
  List<Object?> get props => [id, nameAr, carbsPer100g];
}
