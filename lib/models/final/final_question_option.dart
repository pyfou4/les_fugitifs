class FinalQuestionOption {
  final String id;
  final String label;

  const FinalQuestionOption({
    required this.id,
    required this.label,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
    };
  }

  factory FinalQuestionOption.fromMap(Map<String, dynamic> map) {
    return FinalQuestionOption(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
    );
  }

  FinalQuestionOption copyWith({
    String? id,
    String? label,
  }) {
    return FinalQuestionOption(
      id: id ?? this.id,
      label: label ?? this.label,
    );
  }
}