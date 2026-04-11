import '../models/final/final_answer_model.dart';
import '../models/final/final_free_text_answer_config.dart';
import '../models/final/final_question_model.dart';
import '../models/game_session.dart';

class FinalScoreResult {
  final int questionScore;
  final int timeScore;
  final int helpScore;
  final int totalScore;

  final bool isCorrectSuspect;
  final bool isCorrectMotive;
  final bool isNarrativeSuccess;

  final Duration playDuration;
  final int answeredQuestionsCount;
  final int correctAnswersCount;
  final int totalQuestionsCount;
  final int maxQuestionScore;
  final int maxScore;

  const FinalScoreResult({
    required this.questionScore,
    required this.timeScore,
    required this.helpScore,
    required this.totalScore,
    required this.isCorrectSuspect,
    required this.isCorrectMotive,
    required this.isNarrativeSuccess,
    required this.playDuration,
    required this.answeredQuestionsCount,
    required this.correctAnswersCount,
    required this.totalQuestionsCount,
    required this.maxQuestionScore,
    this.maxScore = 2500,
  });

  Map<String, dynamic> toJson() {
    return {
      'questionScore': questionScore,
      'timeScore': timeScore,
      'helpScore': helpScore,
      'totalScore': totalScore,
      'isCorrectSuspect': isCorrectSuspect,
      'isCorrectMotive': isCorrectMotive,
      'isNarrativeSuccess': isNarrativeSuccess,
      'playDurationInSeconds': playDuration.inSeconds,
      'answeredQuestionsCount': answeredQuestionsCount,
      'correctAnswersCount': correctAnswersCount,
      'totalQuestionsCount': totalQuestionsCount,
      'maxQuestionScore': maxQuestionScore,
      'maxScore': maxScore,
    };
  }
}

class FinalScoreService {
  static const int maxTimeScore = 500;
  static const int maxHelpScore = 250;
  static const int absoluteMaxScore = 2500;

  const FinalScoreService._();

  static FinalScoreResult computeFinalScore({
    required GameSession session,
    required List<FinalQuestionModel> orderedQuestions,
    required Map<String, FinalAnswerModel> submittedAnswers,
    DateTime? now,
  }) {
    final DateTime computationTime = now ?? DateTime.now();

    int questionScore = 0;
    int correctAnswersCount = 0;
    int answeredQuestionsCount = 0;
    int maxQuestionScore = 0;

    for (final FinalQuestionModel question in orderedQuestions) {
      maxQuestionScore += question.points;

      final FinalAnswerModel? answer = submittedAnswers[question.id];
      if (answer == null) {
        continue;
      }

      answeredQuestionsCount += 1;

      final bool isCorrect = _isAnswerCorrect(
        question: question,
        answer: answer,
      );

      if (isCorrect) {
        correctAnswersCount += 1;
        questionScore += question.points;
      }
    }

    final Duration playDuration = _computePlayDuration(
      startedAtRaw: session.startedAt,
      now: computationTime,
    );

    final int timeScore = _computeTimeScore(playDuration);
    final int helpScore = _computeHelpScore(session.aiHelpCount);

    final bool isCorrectSuspect = _hasExactlyOneCorrectMarkedEntity(
      markedIds: session.playerMarkedSuspectIds,
      trueId: session.trueSuspectId,
    );

    final bool isCorrectMotive = _hasExactlyOneCorrectMarkedEntity(
      markedIds: session.playerMarkedMotiveIds,
      trueId: session.trueMotiveId,
    );

    final int totalScore = questionScore + timeScore + helpScore;

    return FinalScoreResult(
      questionScore: questionScore,
      timeScore: timeScore,
      helpScore: helpScore,
      totalScore: totalScore,
      isCorrectSuspect: isCorrectSuspect,
      isCorrectMotive: isCorrectMotive,
      isNarrativeSuccess: isCorrectSuspect && isCorrectMotive,
      playDuration: playDuration,
      answeredQuestionsCount: answeredQuestionsCount,
      correctAnswersCount: correctAnswersCount,
      totalQuestionsCount: orderedQuestions.length,
      maxQuestionScore: maxQuestionScore,
    );
  }

  static bool _isAnswerCorrect({
    required FinalQuestionModel question,
    required FinalAnswerModel answer,
  }) {
    final String correctOptionId = question.correctOptionId?.trim() ?? '';
    if (correctOptionId.isNotEmpty) {
      return answer.selectedOptionId?.trim() == correctOptionId;
    }

    final FinalFreeTextAnswerConfig? config = question.freeTextAnswerConfig;
    final String freeTextAnswer = answer.freeTextAnswer?.trim() ?? '';

    if (config != null && freeTextAnswer.isNotEmpty) {
      return _isFreeTextAnswerCorrect(
        answer: freeTextAnswer,
        config: config,
      );
    }

    return false;
  }

  static bool _isFreeTextAnswerCorrect({
    required String answer,
    required FinalFreeTextAnswerConfig config,
  }) {
    final String normalizedAnswer = _normalizeText(
      answer,
      ignoreCase: config.ignoreCase,
      removeAccents: config.removeAccents,
      trimSpaces: config.trimSpaces,
      ignorePunctuation: config.ignorePunctuation,
    );

    final List<String> acceptedAnswers = <String>[
      config.canonicalAnswer,
      ...config.acceptedAliases,
    ];

    for (final String candidate in acceptedAnswers) {
      final String normalizedCandidate = _normalizeText(
        candidate,
        ignoreCase: config.ignoreCase,
        removeAccents: config.removeAccents,
        trimSpaces: config.trimSpaces,
        ignorePunctuation: config.ignorePunctuation,
      );

      if (normalizedCandidate.isEmpty) {
        continue;
      }

      if (normalizedAnswer == normalizedCandidate) {
        return true;
      }

      final int maxDistance = config.typoTolerance;
      if (maxDistance > 0 &&
          _levenshteinDistance(normalizedAnswer, normalizedCandidate) <=
              maxDistance) {
        return true;
      }
    }

    return false;
  }

  static String _normalizeText(
    String value, {
    required bool ignoreCase,
    required bool removeAccents,
    required bool trimSpaces,
    required bool ignorePunctuation,
  }) {
    String result = value;

    if (trimSpaces) {
      result = result.trim().replaceAll(RegExp(r'\s+'), ' ');
    }

    if (ignoreCase) {
      result = result.toLowerCase();
    }

    if (removeAccents) {
      result = _stripAccents(result);
    }

    if (ignorePunctuation) {
      result = result.replaceAll(RegExp(r"[^\p{L}\p{N}\s]", unicode: true), '');
      result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    return result;
  }

  static String _stripAccents(String value) {
    const Map<String, String> replacements = <String, String>{
      'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
      'ç': 'c',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ñ': 'n',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ý': 'y', 'ÿ': 'y',
      'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
      'Ç': 'C',
      'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
      'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
      'Ñ': 'N',
      'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
      'Ý': 'Y',
      'œ': 'oe', 'Œ': 'OE', 'æ': 'ae', 'Æ': 'AE',
    };

    final StringBuffer buffer = StringBuffer();
    for (final int rune in value.runes) {
      final String char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString();
  }

  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final List<int> previous = List<int>.generate(b.length + 1, (i) => i);
    final List<int> current = List<int>.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      current[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final int cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = _min3(
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + cost,
        );
      }

      for (int j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[b.length];
  }

  static int _min3(int a, int b, int c) {
    if (a <= b && a <= c) return a;
    if (b <= a && b <= c) return b;
    return c;
  }

  static Duration _computePlayDuration({
    required String? startedAtRaw,
    required DateTime now,
  }) {
    if (startedAtRaw == null || startedAtRaw.trim().isEmpty) {
      return Duration.zero;
    }

    try {
      final DateTime startedAt = DateTime.parse(startedAtRaw);
      if (now.isBefore(startedAt)) {
        return Duration.zero;
      }
      return now.difference(startedAt);
    } catch (_) {
      return Duration.zero;
    }
  }

  static int _computeTimeScore(Duration playDuration) {
    final int minutes = playDuration.inMinutes;

    if (minutes <= 60) return 500;
    if (minutes <= 120) return 400;
    if (minutes <= 180) return 250;
    if (minutes <= 240) return 100;
    return 0;
  }

  static int _computeHelpScore(int aiHelpCount) {
    if (aiHelpCount <= 0) return 250;
    if (aiHelpCount == 1) return 200;
    if (aiHelpCount == 2) return 140;
    if (aiHelpCount == 3) return 80;
    return 0;
  }

  static bool _hasExactlyOneCorrectMarkedEntity({
    required Set<String> markedIds,
    required String trueId,
  }) {
    if (trueId.trim().isEmpty) {
      return false;
    }

    return markedIds.length == 1 && markedIds.contains(trueId);
  }
}
