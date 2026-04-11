// lib/screens/incoming_call_screen.dart
// VERSION PROPRE : UI VALIDÉE + FLAG RUNTIME + PANNEAUX DE FIN CONSERVÉS
// BRANCHÉE À FIRESTORE POUR callContext

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IncomingCallScreen extends StatefulWidget {
  final String sessionId;
  final VoidCallback onAccepted;
  final VoidCallback? onRejected;

  const IncomingCallScreen({
    super.key,
    required this.sessionId,
    required this.onAccepted,
    this.onRejected,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _ringPlayer = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _hapticTimer;
  StreamSubscription<void>? _voiceCompleteSubscription;

  bool _isPlayingVoice = false;
  bool _showReadyOverlay = false;
  bool _showConfirmOverlay = false;

  final String imageUrl =
      'https://firebasestorage.googleapis.com/v0/b/les-fugitifs.firebasestorage.app/o/images%2Fincoming_call_bg.png?alt=media&token=d9aa09dd-b6d5-4e06-8c5d-b60091afc156';

  final String audioUrl =
      'https://firebasestorage.googleapis.com/v0/b/les-fugitifs.firebasestorage.app/o/videos%2FD0%20lieu%20final%2FD0_cherry_on_the_cake.mp3?alt=media&token=ad41e833-2d69-418c-b524-b61e712e99ef';

  final String ringtoneUrl =
      'https://actions.google.com/sounds/v1/alarms/phone_alerts_and_rings.ogg';

  static const String _callId = 'final_call';

  Future<void> _runtimeEvent(String event) async {
    debugPrint("RUNTIME_EVENT: $event");

    final sessionId = widget.sessionId.trim();
    if (sessionId.isEmpty) {
      return;
    }

    final sessionRef = _firestore.collection('gameSessions').doc(sessionId);

    try {
      final snapshot = await sessionRef.get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final existingCallContext =
          (data['callContext'] is Map<String, dynamic>)
              ? Map<String, dynamic>.from(data['callContext'] as Map<String, dynamic>)
              : <String, dynamic>{};

      int helpAttemptsDuringCall = 0;
      final existingAttempts = existingCallContext['helpAttemptsDuringCall'];
      if (existingAttempts is int) {
        helpAttemptsDuringCall = existingAttempts;
      } else if (existingAttempts is num) {
        helpAttemptsDuringCall = existingAttempts.toInt();
      } else if (existingAttempts is String) {
        helpAttemptsDuringCall = int.tryParse(existingAttempts) ?? 0;
      }

      String phase = 'resolved';
      bool active = false;

      switch (event) {
        case 'incoming_call_ringing':
          phase = 'ringing';
          active = true;
          helpAttemptsDuringCall = 0;
          break;
        case 'incoming_call_accepted':
          phase = 'voice_playing';
          active = true;
          break;
        case 'incoming_call_voice_finished':
        case 'incoming_call_ready_overlay_confirm_opened':
        case 'incoming_call_confirm_overlay_closed':
          phase = 'awaiting_confirmation';
          active = true;
          break;
        case 'incoming_call_final_phase_confirmed':
          phase = 'resolved';
          active = false;
          break;
        case 'incoming_call_rejected':
          phase = 'ringing';
          active = true;
          break;
        default:
          phase = (existingCallContext['phase'] ?? 'resolved').toString();
          active = existingCallContext['active'] == true;
      }

      await sessionRef.set({
        'callContext': {
          'active': active,
          'phase': phase,
          'helpAttemptsDuringCall': helpAttemptsDuringCall,
          'callId': _callId,
          'sourceEvent': event,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('RUNTIME_EVENT_SYNC_FAILED: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_runtimeEvent("incoming_call_ringing"));
    _startRinging();
  }

  Future<void> _startRinging() async {
    await _ringPlayer.setReleaseMode(ReleaseMode.loop);
    await _ringPlayer.play(UrlSource(ringtoneUrl));

    _triggerIncomingHaptic();

    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _triggerIncomingHaptic();
    });
  }

  Future<void> _triggerIncomingHaptic() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await HapticFeedback.heavyImpact();
  }

  Future<void> _stopRinging() async {
    await _ringPlayer.stop();
    _hapticTimer?.cancel();
  }

  Future<void> _acceptCall() async {
    if (_isPlayingVoice) return;

    await _stopRinging();
    unawaited(_runtimeEvent("incoming_call_accepted"));

    setState(() {
      _isPlayingVoice = true;
    });

    await HapticFeedback.selectionClick();

    _voiceCompleteSubscription?.cancel();
    _voiceCompleteSubscription = _voicePlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;

      unawaited(_runtimeEvent("incoming_call_voice_finished"));

      setState(() {
        _showReadyOverlay = true;
      });
    });

    await _voicePlayer.play(UrlSource(audioUrl));
  }

  Future<void> _rejectCall() async {
    await _stopRinging();
    unawaited(_runtimeEvent("incoming_call_rejected"));

    await HapticFeedback.lightImpact();
    widget.onRejected?.call();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _openFinalConfirmation() {
    unawaited(_runtimeEvent("incoming_call_ready_overlay_confirm_opened"));
    setState(() {
      _showReadyOverlay = false;
      _showConfirmOverlay = true;
    });
  }

  void _closeFinalConfirmation() {
    unawaited(_runtimeEvent("incoming_call_confirm_overlay_closed"));
    setState(() {
      _showConfirmOverlay = false;
      _showReadyOverlay = true;
    });
  }

  void _confirmFinalPhase() {
    unawaited(_runtimeEvent("incoming_call_final_phase_confirmed"));
    widget.onAccepted();
  }

  @override
  void dispose() {
    _voiceCompleteSubscription?.cancel();
    _voicePlayer.dispose();
    _ringPlayer.dispose();
    _hapticTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final shortestSide = size.shortestSide;
    final isTabletLike = shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isTabletLike ? 28 : 12,
                20,
                isTabletLike ? 28 : 12,
                isTabletLike ? 110 : 28,
              ),
              child: Column(
                children: [
                  const Spacer(),
                  _IncomingCallActionBar(
                    title: 'Cherry on the Cake',
                    subtitle:
                        _isPlayingVoice ? 'Connexion établie…' : 'Appel entrant…',
                    isTabletLike: isTabletLike,
                    onReject: _rejectCall,
                    onAccept: _acceptCall,
                  ),
                ],
              ),
            ),
          ),
          if (_showReadyOverlay || _showConfirmOverlay)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.56),
              ),
            ),
          if (_showReadyOverlay)
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isTabletLike ? 64 : 18,
                  20,
                  isTabletLike ? 64 : 18,
                  isTabletLike ? 34 : 22,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _ImmersivePanel(
                      title: 'Transmission terminée',
                      body:
                          'Le point est fait. Si vous êtes prêts, vous pouvez entrer dans la dernière phase.',
                      child: Center(
                        child: ElevatedButton(
                          onPressed: _openFinalConfirmation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF285A32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Nous sommes prêts'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_showConfirmOverlay)
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isTabletLike ? 64 : 18,
                  20,
                  isTabletLike ? 64 : 18,
                  isTabletLike ? 34 : 22,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _ImmersivePanel(
                      title: 'Êtes-vous sûr ?',
                      body:
                          'Une fois engagés, vous entrez dans la phase finale du jeu. Aucun retour en arrière ne sera possible.',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 420;

                          if (stacked) {
                            return Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _closeFinalConfirmation,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.28),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: const Text('Non'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _confirmFinalPhase,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8A5A1F),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: const Text('Oui'),
                                  ),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _closeFinalConfirmation,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.28),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Text('Non'),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _confirmFinalPhase,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8A5A1F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Text('Oui'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IncomingCallActionBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isTabletLike;
  final Future<void> Function() onReject;
  final Future<void> Function() onAccept;

  const _IncomingCallActionBar({
    required this.title,
    required this.subtitle,
    required this.isTabletLike,
    required this.onReject,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final gap = isTabletLike ? 18.0 : 10.0;
        final buttonDiameter = isTabletLike
            ? 116.0
            : ((maxWidth - 180 - (gap * 2)) / 2).clamp(72.0, 92.0).toDouble();

        final centerWidth = isTabletLike
            ? (maxWidth - (buttonDiameter * 2) - (gap * 2))
                .clamp(220.0, 320.0)
                .toDouble()
            : (maxWidth - (buttonDiameter * 2) - (gap * 2))
                .clamp(150.0, 210.0)
                .toDouble();

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTabletLike ? 640 : 420,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CallActionCluster(
                  diameter: buttonDiameter,
                  glowColor: const Color(0x99E53935),
                  icon: Icons.call_end_rounded,
                  onTap: onReject,
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: centerWidth,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTabletLike ? 18 : 12,
                      vertical: isTabletLike ? 14 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xDD0D0E10),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFF8A6A33).withValues(alpha: 0.58),
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x77000000),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.98),
                            fontSize: isTabletLike ? 18 : 13,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 8),
                            ],
                          ),
                        ),
                        SizedBox(height: isTabletLike ? 6 : 4),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: isTabletLike ? 12 : 9,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: gap),
                _CallActionCluster(
                  diameter: buttonDiameter,
                  glowColor: const Color(0x9934A853),
                  icon: Icons.call_rounded,
                  onTap: onAccept,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CallActionCluster extends StatelessWidget {
  final double diameter;
  final Color glowColor;
  final IconData icon;
  final Future<void> Function() onTap;

  const _CallActionCluster({
    required this.diameter,
    required this.glowColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        onTap();
      },
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Center(
          child: Container(
            width: diameter * 0.72,
            height: diameter * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: glowColor.withValues(alpha: 0.34),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.70),
                  blurRadius: 24,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.98),
              size: diameter * 0.30,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImmersivePanel extends StatelessWidget {
  final String title;
  final String body;
  final Widget child;

  const _ImmersivePanel({
    required this.title,
    required this.body,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: const Color(0xE512171D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF7E6536).withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 26,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF2E6C9),
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 17,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
