// lib/domain/entities/insight.dart

import 'package:equatable/equatable.dart';

enum InsightType {
  repeatedHighAfterMeal,
  nighttimeHypoglycaemia,
  insulinOvercorrection,
  missedMealBolus,
  consistentHighMorning,
  highVariability,
}

enum InsightSeverity { info, warning, actionRequired }

/// An AI-generated clinical insight derived from historical patterns.
final class Insight extends Equatable {
  const Insight({
    required this.id,
    required this.userId,
    required this.generatedAt,
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.severity,
    this.isRead = false,
    this.relatedEntityIds = const [],
  });

  final String id;
  final String userId;
  final DateTime generatedAt;
  final InsightType type;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final InsightSeverity severity;
  final bool isRead;

  /// IDs of glucose readings, injections, or meals that contributed.
  final List<String> relatedEntityIds;

  Insight markRead() => Insight(
        id: id,
        userId: userId,
        generatedAt: generatedAt,
        type: type,
        titleAr: titleAr,
        titleEn: titleEn,
        bodyAr: bodyAr,
        bodyEn: bodyEn,
        severity: severity,
        isRead: true,
        relatedEntityIds: relatedEntityIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'generated_at': generatedAt.toIso8601String(),
        'type': type.name,
        'title_ar': titleAr,
        'title_en': titleEn,
        'body_ar': bodyAr,
        'body_en': bodyEn,
        'severity': severity.name,
        'is_read': isRead ? 1 : 0,
        'related_ids': relatedEntityIds.join(','),
      };

  @override
  List<Object?> get props => [id, userId, type, generatedAt];
}
