import 'package:flutter/foundation.dart';

import '../../models/final/final_answer_model.dart';
import '../../models/final/final_free_text_answer_config.dart';
import '../../models/final/final_question_category.dart';
import '../../models/final/final_question_model.dart';
import '../../models/final/final_question_option.dart';
import '../../models/final/final_question_type.dart';
import '../../models/final/final_quiz_snapshot_model.dart';

class FinalQuizProvider extends ChangeNotifier {
  FinalQuizSnapshotModel? _quizSnapshot;
  List<FinalQuestionModel> _orderedQuestions = <FinalQuestionModel>[];
  int _currentQuestionIndex = 0;

  String? _draftSingleChoiceOptionId;
  String _draftFreeTextAnswer = '';

  final Map<String, FinalAnswerModel> _submittedAnswers =
  <String, FinalAnswerModel>{};

  bool _isLoading = false;
  bool _isSubmittingAnswer = false;
  String? _errorMessage;
  bool _isFolderOpen = false;

  FinalQuizSnapshotModel? get quizSnapshot => _quizSnapshot;

  List<FinalQuestionModel> get orderedQuestions =>
      List<FinalQuestionModel>.unmodifiable(_orderedQuestions);

  int get currentQuestionIndex => _currentQuestionIndex;

  FinalQuestionModel? get currentQuestion {
    if (_orderedQuestions.isEmpty) {
      return null;
    }
    if (_currentQuestionIndex < 0 ||
        _currentQuestionIndex >= _orderedQuestions.length) {
      return null;
    }
    return _orderedQuestions[_currentQuestionIndex];
  }

  int get questionNumber => _currentQuestionIndex + 1;

  int get totalQuestions => _orderedQuestions.length;

  String? get draftSingleChoiceOptionId => _draftSingleChoiceOptionId;

  String get draftFreeTextAnswer => _draftFreeTextAnswer;

  Map<String, FinalAnswerModel> get submittedAnswers =>
      Map<String, FinalAnswerModel>.unmodifiable(_submittedAnswers);

  bool get isLoading => _isLoading;

  bool get isSubmittingAnswer => _isSubmittingAnswer;

  String? get errorMessage => _errorMessage;

  bool get isFolderOpen => _isFolderOpen;

  bool get isOnLastQuestion =>
      _orderedQuestions.isNotEmpty &&
          _currentQuestionIndex == _orderedQuestions.length - 1;

  bool get isCompleted =>
      _orderedQuestions.isNotEmpty &&
          _submittedAnswers.length == _orderedQuestions.length;

  double get progressValue {
    if (_orderedQuestions.isEmpty) {
      return 0;
    }
    return questionNumber / _orderedQuestions.length;
  }

  bool get canSubmitCurrentAnswer {
    final FinalQuestionModel? question = currentQuestion;
    if (question == null) {
      return false;
    }

    switch (question.type) {
      case FinalQuestionType.singleChoice:
        return _draftSingleChoiceOptionId != null &&
            _draftSingleChoiceOptionId!.trim().isNotEmpty;
      case FinalQuestionType.freeText:
        return _draftFreeTextAnswer.trim().isNotEmpty;
    }
  }

  Future<void> loadFakeQuiz() async {
    _setLoading(true);
    _clearError();

    try {
      final FinalQuestionModel mainQuestion1 = FinalQuestionModel(
        id: 'main_culprit',
        order: 1,
        category: FinalQuestionCategory.main,
        theme: 'culprit',
        type: FinalQuestionType.singleChoice,
        label: 'Qui est, selon vous, le responsable des faits ?',
        points: 250,
        options: const <FinalQuestionOption>[
          FinalQuestionOption(id: 'suspect_anna', label: 'Anna'),
          FinalQuestionOption(id: 'suspect_marc', label: 'Marc'),
          FinalQuestionOption(id: 'suspect_eva', label: 'Eva'),
        ],
        correctOptionId: 'suspect_marc',
      );

      final FinalQuestionModel mainQuestion2 = FinalQuestionModel(
        id: 'main_motive',
        order: 2,
        category: FinalQuestionCategory.main,
        theme: 'motive',
        type: FinalQuestionType.singleChoice,
        label: 'Quel est le mobile principal ?',
        points: 250,
        options: const <FinalQuestionOption>[
          FinalQuestionOption(id: 'motive_money', label: 'Argent'),
          FinalQuestionOption(id: 'motive_revenge', label: 'Vengeance'),
          FinalQuestionOption(id: 'motive_fear', label: 'Peur'),
        ],
        correctOptionId: 'motive_revenge',
      );

      final FinalQuestionModel secondaryQuestion1 = FinalQuestionModel(
        id: 'secondary_a1',
        order: 6,
        category: FinalQuestionCategory.secondary,
        theme: 'detail',
        type: FinalQuestionType.freeText,
        label: 'Quel objet permettait de relier cette piste ?',
        linkedLocationId: 'A1',
        points: 100,
        freeTextAnswerConfig: const FinalFreeTextAnswerConfig(
          canonicalAnswer: 'badge',
          acceptedAliases: <String>[
            'le badge',
            'badge d acces',
            'badge d\'accès',
            'badge acces',
          ],
          ignoreCase: true,
          removeAccents: true,
          trimSpaces: true,
          ignorePunctuation: true,
          typoTolerance: 1,
        ),
      );

      _quizSnapshot = FinalQuizSnapshotModel(
        mainQuestions: <FinalQuestionModel>[
          mainQuestion1,
          mainQuestion2,
        ],
        secondaryQuestions: <FinalQuestionModel>[
          secondaryQuestion1,
        ],
      );

      _orderedQuestions = _quizSnapshot!.orderedQuestions;
      _currentQuestionIndex = 0;
      _draftSingleChoiceOptionId = null;
      _draftFreeTextAnswer = '';
      _submittedAnswers.clear();
      _isFolderOpen = false;
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement du quiz de test : $e';
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  void selectSingleChoiceOption(String optionId) {
    final FinalQuestionModel? question = currentQuestion;
    if (question == null) {
      return;
    }
    if (question.type != FinalQuestionType.singleChoice) {
      return;
    }

    _draftSingleChoiceOptionId = optionId;
    notifyListeners();
  }

  void updateFreeTextAnswer(String value) {
    final FinalQuestionModel? question = currentQuestion;
    if (question == null) {
      return;
    }
    if (question.type != FinalQuestionType.freeText) {
      return;
    }

    _draftFreeTextAnswer = value;
    notifyListeners();
  }

  void openInvestigationFolder() {
    _isFolderOpen = true;
    notifyListeners();
  }

  void closeInvestigationFolder() {
    _isFolderOpen = false;
    notifyListeners();
  }

  Future<void> submitCurrentAnswer() async {
    final FinalQuestionModel? question = currentQuestion;
    if (question == null) {
      _errorMessage = 'Aucune question courante.';
      notifyListeners();
      return;
    }

    if (!canSubmitCurrentAnswer) {
      _errorMessage = 'La réponse courante est incomplète.';
      notifyListeners();
      return;
    }

    _isSubmittingAnswer = true;
    _clearError();
    notifyListeners();

    try {
      FinalAnswerModel answer;

      if (question.type == FinalQuestionType.singleChoice) {
        final String selectedOptionId = _draftSingleChoiceOptionId!;
        final FinalQuestionOption? selectedOption = question.options
            ?.cast<FinalQuestionOption?>()
            .firstWhere(
              (FinalQuestionOption? option) => option?.id == selectedOptionId,
          orElse: () => null,
        );

        answer = FinalAnswerModel(
          questionId: question.id,
          selectedOptionId: selectedOptionId,
          selectedLabel: selectedOption?.label,
          freeTextAnswer: null,
          isCorrect: false,
          awardedPoints: 0,
          answeredAt: DateTime.now(),
        );
      } else {
        answer = FinalAnswerModel(
          questionId: question.id,
          selectedOptionId: null,
          selectedLabel: null,
          freeTextAnswer: _draftFreeTextAnswer.trim(),
          isCorrect: false,
          awardedPoints: 0,
          answeredAt: DateTime.now(),
        );
      }

      _submittedAnswers[question.id] = answer;

      if (!isOnLastQuestion) {
        _moveToNextQuestion();
      } else {
        _clearDraftAnswer();
      }
    } catch (e) {
      _errorMessage = 'Erreur lors de la soumission de la réponse : $e';
    } finally {
      _isSubmittingAnswer = false;
      notifyListeners();
    }
  }

  void resetQuiz() {
    _currentQuestionIndex = 0;
    _draftSingleChoiceOptionId = null;
    _draftFreeTextAnswer = '';
    _submittedAnswers.clear();
    _errorMessage = null;
    _isFolderOpen = false;
    _isSubmittingAnswer = false;
    notifyListeners();
  }

  void _moveToNextQuestion() {
    if (_currentQuestionIndex < _orderedQuestions.length - 1) {
      _currentQuestionIndex += 1;
    }
    _clearDraftAnswer();
  }

  void _clearDraftAnswer() {
    _draftSingleChoiceOptionId = null;
    _draftFreeTextAnswer = '';
  }

  void _setLoading(bool value) {
    _isLoading = value;
  }

  void _clearError() {
    _errorMessage = null;
  }
}
