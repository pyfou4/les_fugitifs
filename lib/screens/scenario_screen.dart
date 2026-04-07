import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants/firebase_media.dart';
import '../widgets/beacon_dot.dart';
import '../widgets/desk_hotspot.dart';
import '../widgets/hourglass_overlay.dart';

class ScenarioScreen extends StatefulWidget {
  final int progress;
  final bool canExit;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenArchives;
  final VoidCallback? onOpenMicro;
  final VoidCallback? onOpenSOS;
  final VoidCallback? onOpenInvestigation;
  final VoidCallback? onExit;
  final VoidCallback? onMasterReset;
  final bool debugHotspots;
  final bool debugMasterReset;

  const ScenarioScreen({
    super.key,
    required this.progress,
    this.canExit = false,
    this.onOpenMap,
    this.onOpenArchives,
    this.onOpenMicro,
    this.onOpenSOS,
    this.onOpenInvestigation,
    this.onExit,
    this.onMasterReset,
    this.debugHotspots = false,
    this.debugMasterReset = false,
  });

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  void _showMasterResetDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
              SizedBox(width: 10),
              Text('Attention'),
            ],
          ),
          content: const Text(
            'Cette action est réservée au Maître de jeu, vous risquez de tout perdre !',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onMasterReset?.call();
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSosFlow() async {
    if (widget.onOpenSOS != null) {
      widget.onOpenSOS!.call();
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Aide',
      barrierColor: Colors.black.withOpacity(0.70),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _ScenarioHelpDialog();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clampedProgress = widget.progress.clamp(0, 9);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: FirebaseMedia.detectiveDesk,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.08),
                ),
              ),
              Positioned(
                left: 24,
                top: topInset + 16,
                child: const Text(
                  'Scénario',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              Positioned(
                left: w * 0.58,
                top: h * 0.20,
                child: const BeaconDot(
                  color: Color(0xFF9FD3FF),
                  size: 14,
                ),
              ),
              DeskHotspot(
                left: w * 0.58,
                top: h * 0.08,
                width: w * 0.18,
                height: h * 0.35,
                label: 'Archives',
                debug: widget.debugHotspots,
                glowColor: const Color(0x883B82F6),
                onTap: widget.onOpenArchives ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Archives')),
                      );
                    },
              ),

              Positioned(
                left: w * 0.38,
                top: h * 0.84,
                child: const BeaconDot(
                  color: Color(0xFFFFD36B),
                  size: 14,
                ),
              ),
              DeskHotspot(
                left: w * 0.28,
                top: h * 0.76,
                width: w * 0.23,
                height: h * 0.19,
                label: 'Enquête',
                debug: widget.debugHotspots,
                glowColor: const Color(0x88D8B36A),
                onTap: widget.onOpenInvestigation ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enquête')),
                      );
                    },
              ),

              Positioned(
                left: w * 0.65,
                top: h * 0.74,
                child: const BeaconDot(
                  color: Color(0xFFFFD89A),
                  size: 16,
                ),
              ),
              DeskHotspot(
                left: w * 0.58,
                top: h * 0.60,
                width: w * 0.22,
                height: h * 0.25,
                label: 'Micro',
                debug: widget.debugHotspots,
                glowColor: const Color(0x99D8B36A),
                onTap: widget.onOpenMicro ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Micro')),
                      );
                    },
              ),

              Positioned(
                left: w * 0.83,
                top: h * 0.63,
                child: const BeaconDot(
                  color: Color(0xFFFFFF80),
                  size: 16,
                ),
              ),
              DeskHotspot(
                left: w * 0.82,
                top: h * 0.45,
                width: w * 0.12,
                height: h * 0.20,
                label: 'SOS',
                debug: widget.debugHotspots,
                glowColor: const Color(0xAAFFE066),
                onTap: _openSosFlow,
              ),

              if (widget.canExit)
                Positioned(
                  left: w * 0.78,
                  top: h * 0.34,
                  child: const BeaconDot(
                    color: Color(0xFFFFE0A3),
                    size: 15,
                  ),
                ),
              DeskHotspot(
                left: w * 0.70,
                top: h * 0.02,
                width: w * 0.25,
                height: h * 0.48,
                label: 'Sortie',
                debug: widget.debugHotspots,
                glowColor: widget.canExit
                    ? const Color(0x99E9D4A0)
                    : const Color(0x33FFFFFF),
                onTap: widget.onExit ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sortie')),
                      );
                    },
              ),

              Positioned(
                left: w * 0.32,
                top: h * 0.22,
                child: const BeaconDot(
                  color: Color(0xFFFFFFFF),
                  size: 14,
                ),
              ),
              DeskHotspot(
                left: w * 0.02,
                top: h * 0.08,
                width: w * 0.50,
                height: h * 0.35,
                label: 'Carte',
                debug: widget.debugHotspots,
                glowColor: Colors.white.withOpacity(0.12),
                onTap: widget.onOpenMap ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Carte')),
                      );
                    },
              ),

              Positioned(
                left: w * 0.56,
                top: h * 0.45,
                width: w * 0.09,
                height: h * 0.24,
                child: IgnorePointer(
                  child: HourglassOverlay(
                    progress: clampedProgress / 9,
                  ),
                ),
              ),

              Positioned(
                left: w * 0.50,
                top: h * 0.02,
                width: w * 0.13,
                height: h * 0.10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: _showMasterResetDialog,
                  onDoubleTap: _showMasterResetDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.debugMasterReset
                          ? Colors.red.withOpacity(0.28)
                          : Colors.transparent,
                      border: widget.debugMasterReset
                          ? Border.all(color: Colors.red, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: widget.debugMasterReset
                        ? const Center(
                            child: Text(
                              'RESET',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScenarioHelpDialog extends StatefulWidget {
  const _ScenarioHelpDialog();

  @override
  State<_ScenarioHelpDialog> createState() => _ScenarioHelpDialogState();
}

class _ScenarioHelpDialogState extends State<_ScenarioHelpDialog> {
  _HelpStep _step = _HelpStep.intro;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxDialogHeight = size.height * 0.84;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: maxDialogHeight,
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF101A2A),
                      Color(0xFF0A1220),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF28405D),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 34,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD65A00).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFD65A00).withOpacity(0.55),
                                ),
                              ),
                              child: const Icon(
                                Icons.sticky_note_2_outlined,
                                color: Color(0xFFFFD7B8),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Post-it Help',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFFD6E2F2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Version test immersive intégrée au vrai bureau joueur. Cette étape met en scène le parcours d’aide avant le branchement complet vers l’IA puis vers le MJ.',
                          style: TextStyle(
                            color: Color(0xFF93A2B7),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildProgressRail(),
                        const SizedBox(height: 20),
                        _buildStepCard(),
                        const SizedBox(height: 18),
                        _buildActions(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRail() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _HelpStepChip(
          label: '1. Demande',
          active: _step == _HelpStep.intro,
          done: _step.index > _HelpStep.intro.index,
        ),
        _HelpStepChip(
          label: '2. IA',
          active: _step == _HelpStep.ai,
          done: _step.index > _HelpStep.ai.index,
        ),
        _HelpStepChip(
          label: '3. Escalade',
          active: _step == _HelpStep.escalation,
          done: _step.index > _HelpStep.escalation.index,
        ),
        _HelpStepChip(
          label: '4. Résultat',
          active: _step == _HelpStep.result,
          done: _step.index > _HelpStep.result.index,
        ),
      ],
    );
  }

  Widget _buildStepCard() {
    switch (_step) {
      case _HelpStep.intro:
        return _buildIntroCard();
      case _HelpStep.ai:
        return _buildAiCard();
      case _HelpStep.escalation:
        return _buildEscalationCard();
      case _HelpStep.result:
        return _buildResultCard();
    }
  }

  Widget _buildIntroCard() {
    return _HelpPanel(
      title: 'Besoin d’un coup de pouce',
      icon: Icons.help_outline,
      body:
          'Le post-it Help permet au joueur de signaler un blocage. Dans la logique visée pour Les Fugitifs, une aide IA doit intervenir en premier rideau avant une éventuelle escalade humaine.',
      bullets: const [
        'Le joueur reste dans l’ambiance du bureau de l’investigateur.',
        'La demande ne part pas directement chez le MJ.',
        'Le premier niveau de réponse est assuré par l’IA.',
      ],
      footer:
          'Cette première fenêtre sert à tester l’expérience au bon endroit, directement dans le flux réel du bureau.',
    );
  }

  Widget _buildAiCard() {
    return _HelpPanel(
      title: 'Analyse par l’assistant IA',
      icon: Icons.memory_outlined,
      body:
          'L’assistant tente d’identifier la nature du blocage. Il peut proposer un recentrage, rappeler une règle, ou reformuler ce que l’équipe doit observer sans révéler brutalement la solution.',
      bullets: const [
        'Exemple : rappeler le type de lieu exploré.',
        'Exemple : suggérer de recouper un indice déjà obtenu.',
        'Exemple : inviter à reconsidérer une contradiction entre deux pistes.',
      ],
      footer:
          'Dans la future version branchée, ce moment pourra ouvrir un vrai panneau d’aide IA ou une réponse contextuelle calculée.',
    );
  }

  Widget _buildEscalationCard() {
    return _HelpPanel(
      title: 'L’IA ne suffit pas',
      icon: Icons.support_agent_outlined,
      body:
          'Si l’équipe estime que l’aide IA ne débloque pas la situation, la demande pourra être transmise à un humain. Cette transmission dépendra de la configuration réelle de la session.',
      bullets: const [
        'Si l’aide humaine est autorisée, la demande part chez le MJ.',
        'Si elle est coupée, le joueur reste sur un message clair.',
        'Le MJ voit ensuite la session comme demande d’assistance en attente.',
      ],
      footer:
          'Ici, on prépare encore l’expérience utilisateur. Le vrai envoi au MJ sera branché dans l’étape suivante.',
    );
  }

  Widget _buildResultCard() {
    return _HelpPanel(
      title: 'Résultat simulé',
      icon: Icons.mark_chat_read_outlined,
      body:
          'Cette version ne contacte pas encore le backend. Elle joue le rôle d’un prototype vivant : le joueur comprend le chemin d’assistance sans casser le reste du bureau.',
      bullets: const [
        'Issue A : l’IA a aidé, retour au bureau.',
        'Issue B : l’IA ne suffit pas, demande transmise au MJ.',
        'Issue C : aide humaine indisponible pour cette session.',
      ],
      footer:
          'La prochaine étape consistera à relier ce flux à la session runtime réelle puis à l’écran MJ.',
    );
  }

  Widget _buildActions(BuildContext context) {
    switch (_step) {
      case _HelpStep.intro:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _step = _HelpStep.ai;
                  });
                },
                icon: const Icon(Icons.psychology_alt_outlined),
                label: const Text('Demander une aide IA'),
              ),
            ),
          ],
        );
      case _HelpStep.ai:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _step = _HelpStep.result;
                });
                _showResultSnack(
                  context,
                  'Aide IA simulée. Le joueur peut reprendre son enquête.',
                );
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Cette aide IA me suffit'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _step = _HelpStep.escalation;
                });
              },
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text('L’IA ne m’aide pas'),
            ),
          ],
        );
      case _HelpStep.escalation:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _step = _HelpStep.result;
                });
                _showResultSnack(
                  context,
                  'Simulation : demande transmise au MJ.',
                );
              },
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Simuler une transmission au MJ'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _step = _HelpStep.result;
                });
                _showResultSnack(
                  context,
                  'Simulation : aide humaine indisponible pour cette session.',
                );
              },
              icon: const Icon(Icons.lock_outline),
              label: const Text('Simuler une aide humaine indisponible'),
            ),
          ],
        );
      case _HelpStep.result:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _step = _HelpStep.intro;
                  });
                },
                icon: const Icon(Icons.replay),
                label: const Text('Rejouer le flux'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour au bureau'),
              ),
            ),
          ],
        );
    }
  }

  void _showResultSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _HelpPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final String body;
  final List<String> bullets;
  final String footer;

  const _HelpPanel({
    required this.title,
    required this.icon,
    required this.body,
    required this.bullets,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF24364F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFD7B8)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFD6E2F2),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.arrow_right_alt,
                      color: Color(0xFFD65A00),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(
                        color: Color(0xFFB9C7D8),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF121E31),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2B4566)),
            ),
            child: Text(
              footer,
              style: const TextStyle(
                color: Color(0xFFAED0FF),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpStepChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;

  const _HelpStepChip({
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = active
        ? const Color(0xFFD65A00)
        : done
            ? const Color(0xFF2E8B57)
            : const Color(0xFF29405C);

    final backgroundColor = active
        ? const Color(0xFF3A2112)
        : done
            ? const Color(0xFF14261A)
            : const Color(0xFF101925);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

enum _HelpStep {
  intro,
  ai,
  escalation,
  result,
}
