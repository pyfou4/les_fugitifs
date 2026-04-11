class FinalFreeTextAnswerConfig {
  final String canonicalAnswer;
  final List<String> acceptedAliases;
  final bool ignoreCase;
  final bool removeAccents;
  final bool trimSpaces;
  final bool ignorePunctuation;
  final int typoTolerance;

  const FinalFreeTextAnswerConfig({
    required this.canonicalAnswer,
    required this.acceptedAliases,
    this.ignoreCase = true,
    this.removeAccents = true,
    this.trimSpaces = true,
    this.ignorePunctuation = true,
    this.typoTolerance = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'canonicalAnswer': canonicalAnswer,
      'acceptedAliases': acceptedAliases,
      'ignoreCase': ignoreCase,
      'removeAccents': removeAccents,
      'trimSpaces': trimSpaces,
      'ignorePunctuation': ignorePunctuation,
      'typoTolerance': typoTolerance,
    };
  }

  factory FinalFreeTextAnswerConfig.fromMap(Map<String, dynamic> map) {
    return FinalFreeTextAnswerConfig(
      canonicalAnswer: map['canonicalAnswer'] as String? ?? '',
      acceptedAliases: List<String>.from(
        map['acceptedAliases'] as List? ?? const [],
      ),
      ignoreCase: map['ignoreCase'] as bool? ?? true,
      removeAccents: map['removeAccents'] as bool? ?? true,
      trimSpaces: map['trimSpaces'] as bool? ?? true,
      ignorePunctuation: map['ignorePunctuation'] as bool? ?? true,
      typoTolerance: map['typoTolerance'] as int? ?? 1,
    );
  }

  FinalFreeTextAnswerConfig copyWith({
    String? canonicalAnswer,
    List<String>? acceptedAliases,
    bool? ignoreCase,
    bool? removeAccents,
    bool? trimSpaces,
    bool? ignorePunctuation,
    int? typoTolerance,
  }) {
    return FinalFreeTextAnswerConfig(
      canonicalAnswer: canonicalAnswer ?? this.canonicalAnswer,
      acceptedAliases: acceptedAliases ?? this.acceptedAliases,
      ignoreCase: ignoreCase ?? this.ignoreCase,
      removeAccents: removeAccents ?? this.removeAccents,
      trimSpaces: trimSpaces ?? this.trimSpaces,
      ignorePunctuation: ignorePunctuation ?? this.ignorePunctuation,
      typoTolerance: typoTolerance ?? this.typoTolerance,
    );
  }
}