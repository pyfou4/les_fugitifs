import 'package:flutter/material.dart';

import '../models/final/final_question_category.dart';
import '../models/final/final_question_model.dart';
import '../models/final/final_question_option.dart';
import '../models/final/final_question_type.dart';
import '../models/game_session.dart';
import '../models/motive_model.dart';
import '../models/suspect_model.dart';
import '../providers/final/final_quiz_provider.dart';
import '../services/final_score_service.dart';
import '../services/runtime_session_service.dart';
import 'investigation_screen.dart';
import 'final_result_screen.dart';
import 'final_video_screen.dart';

class FinalQuizTestScreen extends StatefulWidget {
  const FinalQuizTestScreen({super.key});

  @override
  State<FinalQuizTestScreen> createState() => _FinalQuizTestScreenState();
}

class _FinalQuizTestScreenState extends State<FinalQuizTestScreen> {
  late final FinalQuizProvider _provider;
  late final TextEditingController _freeTextController;
  late final FocusNode _freeTextFocusNode;
  final RuntimeSessionService _runtimeSessionService = RuntimeSessionService();

  GameSession? _session;
  List<SuspectModel> _suspects = <SuspectModel>[];
  List<MotiveModel> _motives = <MotiveModel>[];
  bool _isRuntimeLoading = true;
  String? _runtimeError;

  @override
  void initState() {
    super.initState();
    _provider = FinalQuizProvider();
    _provider.addListener(_onProviderChanged);

    _freeTextController = TextEditingController();
    _freeTextFocusNode = FocusNode();

    _initScreen();
  }

  Future<void> _initScreen() async {
    await _provider.loadFakeQuiz();
    await _loadRuntimeData();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadRuntimeData() async {
    setState(() {
      _isRuntimeLoading = true;
      _runtimeError = null;
    });

    try {
      final bundle = await _runtimeSessionService.loadActiveBundle();

      if (!mounted) return;

      setState(() {
        _session = bundle.session;
        _suspects = bundle.suspects;
        _motives = bundle.motives;
        _isRuntimeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRuntimeLoading = false;
        _runtimeError = 'Chargement runtime impossible : $e';
      });
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    _provider.dispose();
    _freeTextController.dispose();
    _freeTextFocusNode.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    final FinalQuestionModel? question = _provider.currentQuestion;

    if (question != null && question.type == FinalQuestionType.freeText) {
      final String providerText = _provider.draftFreeTextAnswer;
      if (_freeTextController.text != providerText) {
        _freeTextController.value = TextEditingValue(
          text: providerText,
          selection: TextSelection.collapsed(offset: providerText.length),
        );
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleInvestigationAction() async {
    if (_session == null) {
      await _showRuntimeRequiredDialog(
        title: 'Dossier d’enquête indisponible',
        message:
            'Le mode de démarrage direct ouvre bien le questionnaire, mais il ne charge pas de session runtime active. Sans cette session, le vrai dossier d’enquête ne peut pas être affiché ici.\n\nPour retrouver le dossier réel, il faut relancer le flux normal avec activation de session.',
      );
      return;
    }

    await _openInvestigationDialog();
  }

  Future<void> _openInvestigationDialog() async {
    _provider.openInvestigationFolder();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => InvestigationScreen(
          onBack: () => Navigator.of(context).pop(),
          suspects: _suspects,
          motives: _motives,
          markedSuspectIds: _session?.playerMarkedSuspectIds ?? <String>{},
          markedMotiveIds: _session?.playerMarkedMotiveIds ?? <String>{},
          onToggleSuspect: _toggleSuspect,
          onToggleMotive: _toggleMotive,
        ),
      ),
    );

    if (mounted) {
      _provider.closeInvestigationFolder();
      setState(() {});
    }
  }

  void _toggleSuspect(String id) {
    final GameSession? session = _session;
    if (session == null) return;

    setState(() {
      if (session.playerMarkedSuspectIds.contains(id)) {
        session.playerMarkedSuspectIds.remove(id);
      } else {
        session.playerMarkedSuspectIds.add(id);
      }
    });
  }

  void _toggleMotive(String id) {
    final GameSession? session = _session;
    if (session == null) return;

    setState(() {
      if (session.playerMarkedMotiveIds.contains(id)) {
        session.playerMarkedMotiveIds.remove(id);
      } else {
        session.playerMarkedMotiveIds.add(id);
      }
    });
  }

  Future<void> _handleSubmit() async {
    await _provider.submitCurrentAnswer();

    if (!mounted) return;

    if (!_provider.isCompleted) {
      return;
    }

    final GameSession? session = _session;
    if (session == null) {
      await _showRuntimeRequiredDialog(
        title: 'Scoring indisponible en démarrage direct',
        message:
            'Le questionnaire est bien terminé, mais aucune session runtime active n’a été chargée.\n\nDans ce mode direct, je préfère bloquer proprement le scoring réel plutôt que de calculer un faux résultat. Pour obtenir le vrai score, le vrai dossier et l’issue narrative réelle, il faut relancer le flux normal avec une session active.',
      );
      return;
    }

    final FinalScoreResult result = FinalScoreService.computeFinalScore(
      session: session,
      orderedQuestions: _provider.orderedQuestions,
      submittedAnswers: _provider.submittedAnswers,
    );

    await _showScoreDialog(result);
  }

  Future<void> _showRuntimeRequiredDialog({
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171A21),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Compris'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showScoreDialog(FinalScoreResult result) async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => FinalResultScreen(
            result: result,
            finalVideoBuilder: (_) => FinalVideoScreen(
              videoUrl: result.isNarrativeSuccess
                  ? 'https://firebasestorage.googleapis.com/v0/b/les-fugitifs.firebasestorage.app/o/videos%2FD0%20lieu%20final%2FFinal%20Success.mp4?alt=media&token=953346ec-0b46-4da1-a7f8-9ec19caab82e'
                  : 'https://firebasestorage.googleapis.com/v0/b/les-fugitifs.firebasestorage.app/o/videos%2FD0%20lieu%20final%2FFinal%20Failure.mp4?alt=media&token=179461cb-2c15-4101-bfda-bb1db4041ab8',
            ),
          ),
      ),
    );
  }

  Widget _buildResultLine(
    String label,
    String value, {
    bool isEmphasis = false,
  }) {
    final TextStyle baseStyle = TextStyle(
      color: isEmphasis ? Colors.white : Colors.white70,
      fontSize: isEmphasis ? 18 : 14,
      fontWeight: isEmphasis ? FontWeight.w700 : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(label, style: baseStyle),
          ),
          const SizedBox(width: 12),
          Text(value, style: baseStyle),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isPositive
            ? Colors.green.withValues(alpha: 0.16)
            : Colors.red.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive
              ? Colors.green.withValues(alpha: 0.38)
              : Colors.red.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isPositive ? Icons.check_circle_outline : Icons.highlight_off,
            color: isPositive ? Colors.greenAccent : Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final int totalMinutes = duration.inMinutes;
    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;

    if (hours <= 0) {
      return '${minutes} min';
    }

    return '${hours} h ${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FinalQuestionModel? question = _provider.currentQuestion;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text('Test Quiz Final'),
      ),
      body: SafeArea(
        child: _provider.isLoading || _isRuntimeLoading
            ? const Center(child: CircularProgressIndicator())
            : question == null
                ? Center(
                    child: Text(
                      'Aucune question disponible.',
                      style: theme.textTheme.titleMedium,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final double bottomInset =
                          MediaQuery.of(context).viewInsets.bottom;

                      return AnimatedPadding(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.only(bottom: bottomInset),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 32,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  _buildTopCard(theme),
                                  const SizedBox(height: 16),
                                  _buildQuestionCard(theme, question),
                                  const SizedBox(height: 16),
                                  if (_runtimeError != null) ...<Widget>[
                                    _buildErrorCard(_runtimeError!),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_provider.errorMessage != null) ...<Widget>[
                                    _buildErrorCard(_provider.errorMessage!),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildActionRow(),
                                  const Spacer(),
                                  const SizedBox(height: 12),
                                  _buildFooterInfo(theme),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildTopCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171A21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Question ${_provider.questionNumber} / ${_provider.totalQuestions}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: _provider.progressValue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vous pouvez consulter le dossier d’enquête avant de valider votre réponse.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          if (_session != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Session active : ${_session!.id}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.56),
              ),
            ),
          ] else if (_runtimeError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Mode direct détecté : le scoring réel et le dossier runtime sont bloqués tant qu’aucune session active n’est chargée.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orangeAccent.withValues(alpha: 0.92),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(ThemeData theme, FinalQuestionModel question) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF171A21),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildQuestionMeta(question),
          const SizedBox(height: 16),
          Text(
            question.label,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          if (question.type == FinalQuestionType.singleChoice)
            _buildSingleChoice(question.options ?? const <FinalQuestionOption>[])
          else
            _buildFreeText(),
        ],
      ),
    );
  }

  Widget _buildQuestionMeta(FinalQuestionModel question) {
    final String categoryLabel =
        question.category == FinalQuestionCategory.main
            ? 'Question principale'
            : 'Question annexe';

    final String typeLabel = question.type == FinalQuestionType.singleChoice
        ? 'Choix'
        : 'Réponse libre';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _buildChip(categoryLabel),
        _buildChip(typeLabel),
        _buildChip('${question.points} pts'),
        if (question.linkedLocationId != null)
          _buildChip(question.linkedLocationId!),
      ],
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSingleChoice(List<FinalQuestionOption> options) {
    return Column(
      children: options.map((FinalQuestionOption option) {
        final bool selected = _provider.draftSingleChoiceOptionId == option.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _provider.selectSingleChoiceOption(option.id),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.blue.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? Colors.blue.withValues(alpha: 0.70)
                      : Colors.white.withValues(alpha: 0.08),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Radio<String>(
                    value: option.id,
                    groupValue: _provider.draftSingleChoiceOptionId,
                    onChanged: (String? value) {
                      if (value != null) {
                        _provider.selectSingleChoiceOption(value);
                      }
                    },
                  ),
                  Expanded(
                    child: Text(
                      option.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFreeText() {
    return TextField(
      controller: _freeTextController,
      focusNode: _freeTextFocusNode,
      maxLines: 4,
      minLines: 3,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Votre réponse',
        alignLabelWithHint: true,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        hintText: 'Écrivez votre réponse ici...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.blue.withValues(alpha: 0.80),
            width: 1.4,
          ),
        ),
      ),
      onChanged: _provider.updateFreeTextAnswer,
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _provider.isSubmittingAnswer
                ? null
                : _handleInvestigationAction,
            icon: const Icon(Icons.folder_outlined),
            label: Text(_session == null
                ? 'Dossier d’enquête (info)'
                : 'Dossier d’enquête'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _provider.canSubmitCurrentAnswer && !_provider.isSubmittingAnswer
                ? _handleSubmit
                : null,
            child: _provider.isSubmittingAnswer
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_provider.isOnLastQuestion ? 'Terminer' : 'Valider'),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterInfo(ThemeData theme) {
    final int markedSuspects = _session?.playerMarkedSuspectIds.length ?? 0;
    final int markedMotives = _session?.playerMarkedMotiveIds.length ?? 0;

    return Text(
      'Réponses validées : ${_provider.submittedAnswers.length} · Suspects cochés : $markedSuspects · Mobiles cochés : $markedMotives',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.white.withValues(alpha: 0.72),
      ),
      textAlign: TextAlign.center,
    );
  }
}
