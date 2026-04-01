// lib/data/models/meal_dto.dart

import 'package:insulin_assistant/data/models/base_dto.dart';

/// Maps to the `meals` table.
final class MealDTO implements BaseDTO {
  const MealDTO({
    required this.id,
    required this.userId,
    required this.eatenAt,
    required this.totalCarbsEnc,
    this.notesEnc,
  });

  @override
  final String id;
  final String userId;
  final String eatenAt;
  final String totalCarbsEnc;
  final String? notesEnc;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'eaten_at': eatenAt,
        'total_carbs_enc': totalCarbsEnc,
        if (notesEnc != null) 'notes_enc': notesEnc,
      };

  factory MealDTO.fromMap(Map<String, dynamic> map) => MealDTO(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        eatenAt: map['eaten_at'] as String,
        totalCarbsEnc: map['total_carbs_enc'] as String,
        notesEnc: map['notes_enc'] as String?,
      );
}

/// Maps to the `meal_items` table (individual foods within a meal).
final class MealItemDTO implements BaseDTO {
  const MealItemDTO({
    required this.id,
    required this.mealId,
    required this.foodId,
    required this.quantityGrams,
    required this.carbsGrams,
  });

  @override
  final String id;
  final String mealId;
  final String foodId;
  final double quantityGrams;
  final double carbsGrams;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'meal_id': mealId,
        'food_id': foodId,
        'quantity_grams': quantityGrams,
        'carbs_grams': carbsGrams,
      };

  factory MealItemDTO.fromMap(Map<String, dynamic> map) => MealItemDTO(
        id: map['id'] as String,
        mealId: map['meal_id'] as String,
        foodId: map['food_id'] as String,
        quantityGrams: (map['quantity_grams'] as num).toDouble(),
        carbsGrams: (map['carbs_grams'] as num).toDouble(),
      );
}
