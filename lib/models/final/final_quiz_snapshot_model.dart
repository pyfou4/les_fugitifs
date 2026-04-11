import 'final_question_model.dart';

class FinalQuizSnapshotModel {
  final List<FinalQuestionModel> mainQuestions;
  final List<FinalQuestionModel> secondaryQuestions;

  const FinalQuizSnapshotModel({
    required this.mainQuestions,
    required this.secondaryQuestions,
  });

  List<FinalQuestionModel> get orderedQuestions {
    return [
      ...mainQuestions,
      ...secondaryQuestions,
    ];
  }

  Map<String, dynamic> toMap() {
    return {
      'mainQuestions': mainQuestions.map((e) => e.toMap()).toList(),
      'secondaryQuestions': secondaryQuestions.map((e) => e.toMap()).toList(),
    };
  }

  factory FinalQuizSnapshotModel.fromMap(Map<String, dynamic> map) {
    return FinalQuizSnapshotModel(
      mainQuestions: (map['mainQuestions'] as List? ?? const [])
          .map(
            (e) => FinalQuestionModel.fromMap(
          Map<String, dynamic>.from(e as Map),
        ),
      )
          .toList(),
      secondaryQuestions: (map['secondaryQuestions'] as List? ?? const [])
          .map(
            (e) => FinalQuestionModel.fromMap(
          Map<String, dynamic>.from(e as Map),
        ),
      )
          .toList(),
    );
  }

  FinalQuizSnapshotModel copyWith({
    List<FinalQuestionModel>? mainQuestions,
    List<FinalQuestionModel>? secondaryQuestions,
  }) {
    return FinalQuizSnapshotModel(
      mainQuestions: mainQuestions ?? this.mainQuestions,
      secondaryQuestions: secondaryQuestions ?? this.secondaryQuestions,
    );
  }
}