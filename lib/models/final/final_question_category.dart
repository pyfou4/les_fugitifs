enum FinalQuestionCategory {
  main,
  secondary,
}

extension FinalQuestionCategoryExtension on FinalQuestionCategory {
  String toShortString() {
    return toString().split('.').last;
  }

  static FinalQuestionCategory fromString(String value) {
    switch (value) {
      case 'main':
        return FinalQuestionCategory.main;
      case 'secondary':
        return FinalQuestionCategory.secondary;
      default:
        throw Exception('Unknown FinalQuestionCategory: $value');
    }
  }
}