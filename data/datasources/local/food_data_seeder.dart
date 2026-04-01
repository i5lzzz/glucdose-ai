// lib/data/datasources/local/food_data_seeder.dart
// ─────────────────────────────────────────────────────────────────────────────
// FoodDataSeeder — seeds the Saudi food reference database on first launch.
//
// The food table is NOT encrypted (reference data, no PHI).
// Seeding is idempotent — safe to call on every launch.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/core/database/database_manager.dart';
import 'package:insulin_assistant/domain/entities/food_item.dart';

final class FoodDataSeeder {
  const FoodDataSeeder(this._db);

  final DatabaseManager _db;

  /// Seeds the foods table if it is empty. Idempotent.
  Future<void> seedIfEmpty() async {
    final database = await _db.database;
    final count = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseManager.tableFoods}',
    );
    final existingCount = count.first['cnt'] as int? ?? 0;
    if (existingCount > 0) return;

    final batch = database.batch();
    for (final food in _saudiFoods) {
      batch.insert(
        DatabaseManager.tableFoods,
        food.toJson()..['created_at'] = DateTime.now().toUtc().toIso8601String(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // ── Saudi food dataset ────────────────────────────────────────────────────

  static final List<FoodItem> _saudiFoods = [
    _food(
      id: 'sa-001', nameAr: 'كبسة', nameEn: 'Kabsa',
      carbs: 45.0, gi: 65, speed: AbsorptionSpeed.medium,
      portion: 350.0, category: FoodCategory.mainDish,
      descAr: 'أرز مع لحم أو دجاج بالتوابل السعودية',
      descEn: 'Spiced rice with meat or chicken',
    ),
    _food(
      id: 'sa-002', nameAr: 'مندي', nameEn: 'Mandi',
      carbs: 42.0, gi: 62, speed: AbsorptionSpeed.medium,
      portion: 350.0, category: FoodCategory.mainDish,
      descAr: 'أرز مع لحم مطهو ببطء في التنور',
      descEn: 'Slow-cooked meat with rice in tandoor oven',
    ),
    _food(
      id: 'sa-003', nameAr: 'جريش', nameEn: 'Jareesh',
      carbs: 38.0, gi: 45, speed: AbsorptionSpeed.slow,
      portion: 250.0, category: FoodCategory.mainDish,
      descAr: 'قمح مطحون خشن مطبوخ مع اللحم',
      descEn: 'Coarsely ground wheat cooked with meat',
    ),
    _food(
      id: 'sa-004', nameAr: 'هريس', nameEn: 'Harees',
      carbs: 32.0, gi: 55, speed: AbsorptionSpeed.medium,
      portion: 300.0, category: FoodCategory.mainDish,
      descAr: 'قمح مع لحم مهروس',
      descEn: 'Wheat and meat porridge',
    ),
    _food(
      id: 'sa-005', nameAr: 'شاورما دجاج', nameEn: 'Chicken Shawarma',
      carbs: 35.0, gi: 60, speed: AbsorptionSpeed.medium,
      portion: 250.0, category: FoodCategory.mainDish,
      descAr: 'دجاج مشوي في خبز مع خضار',
      descEn: 'Grilled chicken wrap with vegetables',
    ),
    _food(
      id: 'sa-006', nameAr: 'فلافل', nameEn: 'Falafel',
      carbs: 28.0, gi: 52, speed: AbsorptionSpeed.slow,
      portion: 150.0, category: FoodCategory.mainDish,
      descAr: 'كرات حمص مقلية',
      descEn: 'Fried chickpea balls',
    ),
    _food(
      id: 'sa-007', nameAr: 'خبز تميس', nameEn: 'Tamees Bread',
      carbs: 55.0, gi: 75, speed: AbsorptionSpeed.fast,
      portion: 120.0, category: FoodCategory.bread,
      descAr: 'خبز هندي مخبوز في تنور',
      descEn: 'Tandoor-baked Indian-style flatbread',
    ),
    _food(
      id: 'sa-008', nameAr: 'تمر', nameEn: 'Dates',
      carbs: 75.0, gi: 46, speed: AbsorptionSpeed.fast,
      portion: 50.0, category: FoodCategory.fruits,
      descAr: 'تمر عربي طازج أو مجفف',
      descEn: 'Fresh or dried Arabian dates',
    ),
    _food(
      id: 'sa-009', nameAr: 'قهوة عربية', nameEn: 'Arabic Coffee',
      carbs: 0.5, gi: 5, speed: AbsorptionSpeed.fast,
      portion: 120.0, category: FoodCategory.beverages,
      descAr: 'قهوة عربية بالهيل بدون سكر',
      descEn: 'Cardamom-spiced Arabic coffee without sugar',
    ),
    _food(
      id: 'sa-010', nameAr: 'أرز أبيض', nameEn: 'White Rice',
      carbs: 28.0, gi: 72, speed: AbsorptionSpeed.medium,
      portion: 180.0, category: FoodCategory.rice,
      descAr: 'أرز أبيض مطبوخ',
      descEn: 'Cooked white rice',
    ),
    _food(
      id: 'sa-011', nameAr: 'خبز عربي', nameEn: 'Arabic Bread (Pita)',
      carbs: 55.0, gi: 57, speed: AbsorptionSpeed.medium,
      portion: 80.0, category: FoodCategory.bread,
      descAr: 'خبز عربي مسطح',
      descEn: 'Arabic flatbread',
    ),
    _food(
      id: 'sa-012', nameAr: 'سمبوسة', nameEn: 'Samboosa',
      carbs: 25.0, gi: 60, speed: AbsorptionSpeed.medium,
      portion: 100.0, category: FoodCategory.snacks,
      descAr: 'معجنات مقلية محشوة باللحم أو الجبن',
      descEn: 'Fried pastry filled with meat or cheese',
    ),
    _food(
      id: 'sa-013', nameAr: 'فول مدمس', nameEn: 'Foul Medames',
      carbs: 20.0, gi: 40, speed: AbsorptionSpeed.slow,
      portion: 200.0, category: FoodCategory.legumes,
      descAr: 'فول مطبوخ بالثوم والليمون',
      descEn: 'Cooked fava beans with garlic and lemon',
    ),
    _food(
      id: 'sa-014', nameAr: 'لبن (زبادي)', nameEn: 'Laban (Yoghurt)',
      carbs: 5.0, gi: 35, speed: AbsorptionSpeed.slow,
      portion: 200.0, category: FoodCategory.dairy,
      descAr: 'لبن طبيعي بدون إضافات',
      descEn: 'Plain natural yoghurt',
    ),
    _food(
      id: 'sa-015', nameAr: 'كنافة', nameEn: 'Kunafa',
      carbs: 45.0, gi: 70, speed: AbsorptionSpeed.fast,
      portion: 150.0, category: FoodCategory.sweets,
      descAr: 'حلوى شرقية بالجبن والقطر',
      descEn: 'Sweet cheese pastry soaked in syrup',
    ),
    _food(
      id: 'sa-016', nameAr: 'مجبوس', nameEn: 'Machboos',
      carbs: 48.0, gi: 65, speed: AbsorptionSpeed.medium,
      portion: 350.0, category: FoodCategory.mainDish,
      descAr: 'أرز بالتوابل مع لحم أو دجاج',
      descEn: 'Spiced rice with meat or chicken (Gulf-style)',
    ),
    _food(
      id: 'sa-017', nameAr: 'عصير برتقال', nameEn: 'Orange Juice',
      carbs: 11.0, gi: 50, speed: AbsorptionSpeed.fast,
      portion: 250.0, category: FoodCategory.beverages,
      descAr: 'عصير برتقال طازج',
      descEn: 'Fresh orange juice',
    ),
    _food(
      id: 'sa-018', nameAr: 'حمص', nameEn: 'Hummus',
      carbs: 14.0, gi: 28, speed: AbsorptionSpeed.slow,
      portion: 100.0, category: FoodCategory.legumes,
      descAr: 'معجون الحمص بالطحينة',
      descEn: 'Chickpea dip with tahini',
    ),
  ];

  static FoodItem _food({
    required String id,
    required String nameAr,
    required String nameEn,
    required double carbs,
    required int gi,
    required AbsorptionSpeed speed,
    required double portion,
    required FoodCategory category,
    String? descAr,
    String? descEn,
  }) =>
      FoodItem(
        id: id,
        nameAr: nameAr,
        nameEn: nameEn,
        carbsPer100g: carbs,
        glycaemicProfile: GlycaemicProfile(
          glycaemicIndex: gi,
          absorptionSpeed: speed,
        ),
        defaultPortionGrams: portion,
        category: category,
        isCustom: false,
        createdAt: DateTime.utc(2024, 1, 1),
        descriptionAr: descAr,
        descriptionEn: descEn,
      );
}

// ignore: avoid_classes_with_only_static_members
class ConflictAlgorithm {
  static const ignore = 5;
}
