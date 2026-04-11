enum FinalQuestionType {
  singleChoice,
  freeText,
}

extension FinalQuestionTypeExtension on FinalQuestionType {
  String toShortString() {
    return toString().split('.').last;
  }

  static FinalQuestionType fromString(String value) {
    switch (value) {
      case 'singleChoice':
        return FinalQuestionType.singleChoice;
      case 'freeText':
        return FinalQuestionType.freeText;
      default:
        throw Exception('Unknown FinalQuestionType: $value');
    }
  }
}