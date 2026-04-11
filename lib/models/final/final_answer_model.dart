class FinalAnswerModel {
  final String questionId;

  final String? selectedOptionId;
  final String? selectedLabel;

  final String? freeTextAnswer;

  final bool isCorrect;
  final int awardedPoints;

  final DateTime answeredAt;

  const FinalAnswerModel({
    required this.questionId,
    this.selectedOptionId,
    this.selectedLabel,
    this.freeTextAnswer,
    required this.isCorrect,
    required this.awardedPoints,
    required this.answeredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'selectedOptionId': selectedOptionId,
      'selectedLabel': selectedLabel,
      'freeTextAnswer': freeTextAnswer,
      'isCorrect': isCorrect,
      'awardedPoints': awardedPoints,
      'answeredAt': answeredAt.toIso8601String(),
    };
  }

  factory FinalAnswerModel.fromMap(Map<String, dynamic> map) {
    return FinalAnswerModel(
      questionId: map['questionId'] as String? ?? '',
      selectedOptionId: map['selectedOptionId'] as String?,
      selectedLabel: map['selectedLabel'] as String?,
      freeTextAnswer: map['freeTextAnswer'] as String?,
      isCorrect: map['isCorrect'] as bool? ?? false,
      awardedPoints: map['awardedPoints'] as int? ?? 0,
      answeredAt: map['answeredAt'] != null
          ? DateTime.parse(map['answeredAt'])
          : DateTime.now(),
    );
  }

  FinalAnswerModel copyWith({
    String? questionId,
    String? selectedOptionId,
    String? selectedLabel,
    String? freeTextAnswer,
    bool? isCorrect,
    int? awardedPoints,
    DateTime? answeredAt,
  }) {
    return FinalAnswerModel(
      questionId: questionId ?? this.questionId,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
      selectedLabel: selectedLabel ?? this.selectedLabel,
      freeTextAnswer: freeTextAnswer ?? this.freeTextAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
      awardedPoints: awardedPoints ?? this.awardedPoints,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }
}