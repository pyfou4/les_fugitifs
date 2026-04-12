import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants/firebase_media.dart';
import '../widgets/beacon_dot.dart';
import '../widgets/desk_hotspot.dart';
import '../widgets/hourglass_expanded_dialog.dart';

class ScenarioScreen extends StatefulWidget {
  final double progress;
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

  Future<void> _openHourglassDialog(double progress) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.86),
      builder: (_) => HourglassExpandedDialog(progress: progress),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clampedProgress = widget.progress.clamp(0.0, 1.0);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final isTablet = screenWidth >= 900;
          final layout = isTablet
              ? ScenarioLayouts.tablet
              : ScenarioLayouts.phone;

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
                left: layout.titleLeft,
                top: topInset + layout.titleTopOffset,
                child: const Text(
                  'Scénario',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _buildBeacon(
                zone: layout.archivesDot,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                color: const Color(0xFF9FD3FF),
                size: 14,
              ),
              _buildHotspot(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                zone: layout.archivesHotspot,
                label: 'Archives',
                glowColor: const Color(0x883B82F6),
                onTap: widget.onOpenArchives ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Archives')),
                      );
                    },
              ),
              _buildBeacon(
                zone: layout.investigationDot,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                color: const Color(0xFFFFD36B),
                size: 14,
              ),
              _buildHotspot(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                zone: layout.investigationHotspot,
                label: 'Enquête',
                glowColor: const Color(0x88D8B36A),
                onTap: widget.onOpenInvestigation ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enquête')),
                      );
                    },
              ),
              _buildBeacon(
                zone: layout.microDot,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                color: const Color(0xFFFFD89A),
                size: 16,
              ),
              _buildHotspot(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                zone: layout.microHotspot,
                label: 'Micro',
                glowColor: const Color(0x99D8B36A),
                onTap: widget.onOpenMicro ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Micro')),
                      );
                    },
              ),
              _buildBeacon(
                zone: layout.sosDot,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                color: const Color(0xFFFFFF80),
                size: 16,
              ),
              _buildHotspot(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                zone: layout.sosHotspot,
                label: 'SOS',
                glowColor: const Color(0xAAFFE066),
                onTap: _openSosFlow,
              ),
              if (widget.canExit)
                _buildBeacon(
                  zone: layout.exitDot,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  color: const Color(0xFFFFE0A3),
                  size: 15,
                ),
              _buildHotspot(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                zone: layout.exitHotspot,
                label: 'Sortie',
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
              _buildBeacon(
                zone: layout.mapDot,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                color: const Color(0xFFFFFFFF),
                size: 14,
              ),
              _buildHotspot(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                zone: layout.mapHotspot,
                label: 'Carte',
                glowColor: Colors.white.withOpacity(0.12),
                onTap: widget.onOpenMap ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Carte')),
                      );
                    },
              ),
              _buildBeacon(
                zone: layout.hourglassDot,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                color: const Color(0xFF7B5630),
                size: 14,
              ),
              _buildHotspot(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                zone: layout.hourglass,
                label: 'Sablier',
                glowColor: const Color(0x665B4326),
                onTap: () => _openHourglassDialog(clampedProgress),
              ),
              _buildMasterReset(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                zone: layout.masterReset,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBeacon({
    required RelativeZone zone,
    required double screenWidth,
    required double screenHeight,
    required Color color,
    required double size,
  }) {
    return Positioned(
      left: screenWidth * zone.left,
      top: screenHeight * zone.top,
      child: BeaconDot(
        color: color,
        size: size,
      ),
    );
  }

  Widget _buildHotspot({
    required double screenWidth,
    required double screenHeight,
    required RelativeZone zone,
    required String label,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return DeskHotspot(
      left: screenWidth * zone.left,
      top: screenHeight * zone.top,
      width: screenWidth * zone.width,
      height: screenHeight * zone.height,
      label: label,
      debug: widget.debugHotspots,
      glowColor: glowColor,
      onTap: onTap,
    );
  }

  Widget _buildMasterReset({
    required double screenWidth,
    required double screenHeight,
    required RelativeZone zone,
  }) {
    return Positioned(
      left: screenWidth * zone.left,
      top: screenHeight * zone.top,
      width: screenWidth * zone.width,
      height: screenHeight * zone.height,
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
    );
  }
}

class RelativeZone {
  final double left;
  final double top;
  final double width;
  final double height;

  const RelativeZone({
    required this.left,
    required this.top,
    this.width = 0,
    this.height = 0,
  });
}

class ScenarioLayoutSet {
  final double titleLeft;
  final double titleTopOffset;
  final RelativeZone archivesDot;
  final RelativeZone archivesHotspot;
  final RelativeZone investigationDot;
  final RelativeZone investigationHotspot;
  final RelativeZone microDot;
  final RelativeZone microHotspot;
  final RelativeZone sosDot;
  final RelativeZone sosHotspot;
  final RelativeZone exitDot;
  final RelativeZone exitHotspot;
  final RelativeZone mapDot;
  final RelativeZone mapHotspot;
  final RelativeZone hourglass;
  final RelativeZone hourglassDot;
  final RelativeZone masterReset;

  const ScenarioLayoutSet({
    required this.titleLeft,
    required this.titleTopOffset,
    required this.archivesDot,
    required this.archivesHotspot,
    required this.investigationDot,
    required this.investigationHotspot,
    required this.microDot,
    required this.microHotspot,
    required this.sosDot,
    required this.sosHotspot,
    required this.exitDot,
    required this.exitHotspot,
    required this.mapDot,
    required this.mapHotspot,
    required this.hourglass,
    required this.hourglassDot,
    required this.masterReset,
  });
}

class ScenarioLayouts {
  static const phone = ScenarioLayoutSet(
    titleLeft: 24,
    titleTopOffset: 16,
    archivesDot: RelativeZone(left: 0.58, top: 0.20),
    archivesHotspot: RelativeZone(left: 0.58, top: 0.08, width: 0.18, height: 0.35),
    investigationDot: RelativeZone(left: 0.38, top: 0.84),
    investigationHotspot: RelativeZone(left: 0.28, top: 0.76, width: 0.23, height: 0.19),
    microDot: RelativeZone(left: 0.65, top: 0.74),
    microHotspot: RelativeZone(left: 0.60, top: 0.68, width: 0.16, height: 0.17),
    sosDot: RelativeZone(left: 0.83, top: 0.63),
    sosHotspot: RelativeZone(left: 0.82, top: 0.45, width: 0.12, height: 0.20),
    exitDot: RelativeZone(left: 0.78, top: 0.34),
    exitHotspot: RelativeZone(left: 0.70, top: 0.02, width: 0.25, height: 0.48),
    mapDot: RelativeZone(left: 0.32, top: 0.22),
    mapHotspot: RelativeZone(left: 0.02, top: 0.08, width: 0.50, height: 0.35),
    hourglass: RelativeZone(left: 0.56, top: 0.47, width: 0.09, height: 0.24),
    hourglassDot: RelativeZone(left: 0.585, top: 0.58),
    masterReset: RelativeZone(left: 0.50, top: 0.02, width: 0.13, height: 0.10),
  );

  static const tablet = ScenarioLayoutSet(
    titleLeft: 48,
    titleTopOffset: 18,
    archivesDot: RelativeZone(left: 0.58, top: 0.26),
    archivesHotspot: RelativeZone(left: 0.58, top: 0.14, width: 0.18, height: 0.35),
    investigationDot: RelativeZone(left: 0.38, top: 0.84),
    investigationHotspot: RelativeZone(left: 0.28, top: 0.76, width: 0.23, height: 0.19),
    microDot: RelativeZone(left: 0.65, top: 0.74),
    microHotspot: RelativeZone(left: 0.60, top: 0.68, width: 0.16, height: 0.17),
    sosDot: RelativeZone(left: 0.83, top: 0.63),
    sosHotspot: RelativeZone(left: 0.82, top: 0.45, width: 0.12, height: 0.20),
    exitDot: RelativeZone(left: 0.78, top: 0.34),
    exitHotspot: RelativeZone(left: 0.70, top: 0.02, width: 0.25, height: 0.48),
    mapDot: RelativeZone(left: 0.32, top: 0.22),
    mapHotspot: RelativeZone(left: 0.02, top: 0.08, width: 0.50, height: 0.35),
    hourglass: RelativeZone(left: 0.56, top: 0.50, width: 0.09, height: 0.24),
    hourglassDot: RelativeZone(left: 0.585, top: 0.61),
    masterReset: RelativeZone(left: 0.50, top: 0.02, width: 0.13, height: 0.10),
  );
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
