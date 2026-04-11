import 'final_question_type.dart';
import 'final_question_category.dart';
import 'final_question_option.dart';
import 'final_free_text_answer_config.dart';

class FinalQuestionModel {
  final String id;
  final int order;
  final FinalQuestionCategory category;
  final String theme;
  final FinalQuestionType type;
  final String label;
  final String? linkedLocationId;
  final int points;

  final List<FinalQuestionOption>? options;
  final String? correctOptionId;

  final FinalFreeTextAnswerConfig? freeTextAnswerConfig;

  const FinalQuestionModel({
    required this.id,
    required this.order,
    required this.category,
    required this.theme,
    required this.type,
    required this.label,
    required this.points,
    this.linkedLocationId,
    this.options,
    this.correctOptionId,
    this.freeTextAnswerConfig,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order': order,
      'category': category.toShortString(),
      'theme': theme,
      'type': type.toShortString(),
      'label': label,
      'linkedLocationId': linkedLocationId,
      'points': points,
      'options': options?.map((e) => e.toMap()).toList(),
      'correctOptionId': correctOptionId,
      'freeTextAnswerConfig': freeTextAnswerConfig?.toMap(),
    };
  }

  factory FinalQuestionModel.fromMap(Map<String, dynamic> map) {
    return FinalQuestionModel(
      id: map['id'] as String? ?? '',
      order: map['order'] as int? ?? 0,
      category: FinalQuestionCategoryExtension.fromString(
        map['category'] as String? ?? 'main',
      ),
      theme: map['theme'] as String? ?? '',
      type: FinalQuestionTypeExtension.fromString(
        map['type'] as String? ?? 'singleChoice',
      ),
      label: map['label'] as String? ?? '',
      linkedLocationId: map['linkedLocationId'] as String?,
      points: map['points'] as int? ?? 0,
      options: (map['options'] as List?)
          ?.map((e) => FinalQuestionOption.fromMap(e))
          .toList(),
      correctOptionId: map['correctOptionId'] as String?,
      freeTextAnswerConfig: map['freeTextAnswerConfig'] != null
          ? FinalFreeTextAnswerConfig.fromMap(
        map['freeTextAnswerConfig'],
      )
          : null,
    );
  }

  FinalQuestionModel copyWith({
    String? id,
    int? order,
    FinalQuestionCategory? category,
    String? theme,
    FinalQuestionType? type,
    String? label,
    String? linkedLocationId,
    int? points,
    List<FinalQuestionOption>? options,
    String? correctOptionId,
    FinalFreeTextAnswerConfig? freeTextAnswerConfig,
  }) {
    return FinalQuestionModel(
      id: id ?? this.id,
      order: order ?? this.order,
      category: category ?? this.category,
      theme: theme ?? this.theme,
      type: type ?? this.type,
      label: label ?? this.label,
      linkedLocationId: linkedLocationId ?? this.linkedLocationId,
      points: points ?? this.points,
      options: options ?? this.options,
      correctOptionId: correctOptionId ?? this.correctOptionId,
      freeTextAnswerConfig:
      freeTextAnswerConfig ?? this.freeTextAnswerConfig,
    );
  }
}