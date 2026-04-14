import 'package:flutter/material.dart';

import '../services/final_score_service.dart';
import 'final_video_screen.dart';

class FinalResultScreen extends StatefulWidget {
  final FinalScoreResult result;
  final WidgetBuilder? finalVideoBuilder;
  final String? finalVideoUrl;

  const FinalResultScreen({
    super.key,
    required this.result,
    this.finalVideoBuilder,
    this.finalVideoUrl,
  });

  @override
  State<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends State<FinalResultScreen> {
  bool _showDetails = false;

  bool get _isHighScore => widget.result.totalScore >= 2000;
  bool get _isMediumScore => widget.result.totalScore >= 1200;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FinalScoreResult result = widget.result;
    final bool success = result.isNarrativeSuccess;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF11151D),
              Color(0xFF0B0D12),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildHeroCard(theme, success),
                      const SizedBox(height: 18),
                      _buildScoreCard(theme),
                      const SizedBox(height: 18),
                      _buildPrimaryActions(context),
                      const SizedBox(height: 14),
                      _buildDetailsToggle(theme),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: !_showDetails
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: _buildDetailsSection(theme),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme, bool success) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: success
              ? const <Color>[Color(0xFF1D3A2F), Color(0xFF0F151A)]
              : const <Color>[Color(0xFF3A1D24), Color(0xFF0F151A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: success
              ? Colors.greenAccent.withValues(alpha: 0.22)
              : Colors.redAccent.withValues(alpha: 0.22),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildTopBadge(success),
          const SizedBox(height: 18),
          Text(
            success ? 'Vous êtes libres.' : 'Vous retournez en prison.',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            success
                ? 'Vous avez tenu jusqu’au bout. La vérité a cédé, et l’histoire vous laisse sortir debout.'
                : 'Vous avez touché quelque chose de vrai, mais pas assez pour briser la mécanique. La chute est brutale. La fin, elle, reste intense.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              success
                  ? 'Le dossier se referme sur une victoire nette. Votre équipe a imposé sa lecture de l’affaire.'
                  : 'Le dossier se referme sur vous. Pas comme un écran de statistiques, mais comme une porte lourde qu’on entend claquer derrière soi.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBadge(bool success) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: success
            ? Colors.green.withValues(alpha: 0.18)
            : Colors.red.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: success
              ? Colors.greenAccent.withValues(alpha: 0.28)
              : Colors.redAccent.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        success ? 'VERDICT : LIBÉRATION' : 'VERDICT : RETOUR EN PRISON',
        style: TextStyle(
          color: success ? Colors.greenAccent : Colors.redAccent,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildScoreCard(ThemeData theme) {
    final double progressValue = widget.result.maxScore <= 0
        ? 0
        : (widget.result.totalScore / widget.result.maxScore).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF12161D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'Score final',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${widget.result.totalScore}',
            style: theme.textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'sur ${widget.result.maxScore} points',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.64),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: progressValue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _scoreCommentary,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String get _scoreCommentary {
    if (widget.result.isNarrativeSuccess) {
      if (_isHighScore) {
        return 'Performance tranchante. Vous n’avez pas seulement survécu à l’affaire, vous l’avez dominée.';
      }
      if (_isMediumScore) {
        return 'Victoire solide. Tout n’était pas parfait, mais vous avez gardé la main au moment décisif.';
      }
      return 'Vous passez, de justesse peut-être, mais l’histoire vous laisse sortir. Et parfois, c’est tout ce qui compte.';
    }

    if (_isHighScore) {
      return 'L’échec n’efface pas la qualité de l’enquête. Vous étiez très proches, ce qui rend la chute encore plus violente.';
    }
    if (_isMediumScore) {
      return 'Vous avez tenu une bonne partie du parcours. Puis le dernier verrou a résisté. C’est dur, mais ce n’était pas vide.';
    }
    return 'La sortie vous échappe, mais la tension, elle, était bien réelle. Vous n’avez pas traversé cette affaire pour rien.';
  }

  Widget _buildPrimaryActions(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => _handleTruthAction(context),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Découvrir la vérité'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTruthAction(BuildContext context) async {
    if (widget.finalVideoBuilder != null) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: widget.finalVideoBuilder!),
      );
      return;
    }

    if (widget.finalVideoUrl != null && widget.finalVideoUrl!.trim().isNotEmpty) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => FinalVideoScreen(
            videoUrl: widget.finalVideoUrl!,
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF12161D),
          title: const Text(
            'Découvrir la vérité',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Le bouton est actif, mais la vidéo finale n’est pas encore branchée sur cet écran.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.84)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailsToggle(ThemeData theme) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          _showDetails = !_showDetails;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF12161D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _showDetails ? 'Masquer les détails' : 'Voir les détails',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              _showDetails ? Icons.expand_less : Icons.expand_more,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(ThemeData theme) {
    return Column(
      children: <Widget>[
        _buildPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Détail du score',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _buildScoreRow(
                'Questions',
                '${widget.result.questionScore} / ${widget.result.maxQuestionScore}',
              ),
              _buildScoreRow('Temps', '${widget.result.timeScore} / 500'),
              _buildScoreRow('Aides', '${widget.result.helpScore} / 250'),
              _buildScoreRow(
                'Réponses correctes',
                '${widget.result.correctAnswersCount} / ${widget.result.totalQuestionsCount}',
              ),
              _buildScoreRow(
                'Réponses envoyées',
                '${widget.result.answeredQuestionsCount}',
              ),
              _buildScoreRow(
                'Durée',
                _formatDuration(widget.result.playDuration),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Lecture finale',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _buildStatusTile(
                icon: widget.result.isCorrectSuspect
                    ? Icons.check_circle_outline
                    : Icons.highlight_off,
                title: 'Coupable',
                value:
                    widget.result.isCorrectSuspect ? 'Correct' : 'Incorrect',
                positive: widget.result.isCorrectSuspect,
              ),
              const SizedBox(height: 10),
              _buildStatusTile(
                icon: widget.result.isCorrectMotive
                    ? Icons.check_circle_outline
                    : Icons.highlight_off,
                title: 'Mobile',
                value: widget.result.isCorrectMotive ? 'Correct' : 'Incorrect',
                positive: widget.result.isCorrectMotive,
              ),
              const SizedBox(height: 10),
              _buildStatusTile(
                icon: widget.result.isNarrativeSuccess
                    ? Icons.lock_open_outlined
                    : Icons.gavel_outlined,
                title: 'Conséquence',
                value: widget.result.isNarrativeSuccess
                    ? 'Libération'
                    : 'Retour en prison',
                positive: widget.result.isNarrativeSuccess,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String title,
    required String value,
    required bool positive,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: positive
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: positive
              ? Colors.greenAccent.withValues(alpha: 0.22)
              : Colors.redAccent.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            color: positive ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: positive ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12161D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
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
}
