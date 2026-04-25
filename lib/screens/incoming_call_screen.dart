// lib/screens/incoming_call_screen.dart
// VERSION GÉNÉRIQUE : UI VALIDÉE + CALL CONTEXT DYNAMIQUE + COMPAT D0 CONSERVÉE

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/media_preload_service.dart';

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
  static const String _defaultImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/les-fugitifs.firebasestorage.app/o/images%2Fincoming_call_bg.png?alt=media&token=d9aa09dd-b6d5-4e06-8c5d-b60091afc156';

  static const String _defaultAudioUrl =
      'https://firebasestorage.googleapis.com/v0/b/les-fugitifs.firebasestorage.app/o/videos%2FD0%20lieu%20final%2FD0_cherry_on_the_cake.mp3?alt=media&token=ad41e833-2d69-418c-b524-b61e712e99ef';

  static const String _defaultRingtoneUrl =
      'https://actions.google.com/sounds/v1/alarms/phone_alerts_and_rings.ogg';

  static const String _defaultCallId = 'final_call';
  static const String _defaultCallType = 'final_phase';
  static const String _defaultDisplayName = 'Cherry on the Cake';
  static const String _defaultRetryPolicy = 'until_answered';
  static const String _defaultUiVariant = 'final_phase_call';

  final AudioPlayer _voicePlayer = AudioPlayer();
  final AudioPlayer _ringPlayer = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _hapticTimer;
  StreamSubscription<void>? _voiceCompleteSubscription;

  bool _isPlayingVoice = false;
  bool _showReadyOverlay = false;
  bool _showConfirmOverlay = false;
  bool _isLoadingCallContext = true;

  final MediaPreloadService _mediaPreloadService = MediaPreloadService();

  String _imageUrl = _defaultImageUrl;
  String _audioUrl = '';
  String _ringtoneUrl = _defaultRingtoneUrl;
  String _mediaSlotKey = '';
  String? _resolvedAudioFilePath;
  String _callId = _defaultCallId;
  String _callType = _defaultCallType;
  String _displayName = _defaultDisplayName;
  String _retryPolicy = _defaultRetryPolicy;
  String _uiVariant = _defaultUiVariant;

  bool get _isFinalPhaseCall => _uiVariant == 'final_phase_call';
  bool get _shouldRetryUntilAnswered => _retryPolicy == 'until_answered';

  Future<void> _initializeCallScreen() async {
    await _loadCallContext();
    await _prepareAudioForCall();
    await _runtimeEvent('incoming_call_ringing');
    await _startRinging();
  }

  Future<void> _loadCallContext() async {
    final sessionId = widget.sessionId.trim();
    if (sessionId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingCallContext = false;
        });
      }
      return;
    }

    try {
      final snapshot =
          await _firestore.collection('gameSessions').doc(sessionId).get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final rawCallContext = data['callContext'];

      if (rawCallContext is Map) {
        final callContext = Map<String, dynamic>.from(rawCallContext);

        _callId = _stringOrFallback(callContext['callId'], _defaultCallId);
        _callType =
            _stringOrFallback(callContext['callType'], _defaultCallType);
        _displayName = _stringOrFallback(
          callContext['displayName'],
          _defaultDisplayName,
        );
        _audioUrl = _stringOrFallback(callContext['audioUrl'], '');
        _mediaSlotKey = _stringOrFallback(callContext['mediaSlotKey'], '');
        _imageUrl = _stringOrFallback(
          callContext['backgroundImageUrl'],
          _defaultImageUrl,
        );
        _ringtoneUrl = _stringOrFallback(
          callContext['ringtoneUrl'],
          _defaultRingtoneUrl,
        );
        _retryPolicy = _stringOrFallback(
          callContext['retryPolicy'],
          _defaultRetryPolicy,
        );
        _uiVariant =
            _stringOrFallback(callContext['uiVariant'], _defaultUiVariant);
      }
    } catch (e) {
      debugPrint('CALL_CONTEXT_LOAD_FAILED: $e');
    }

    if (!mounted) return;

    setState(() {
      _isLoadingCallContext = false;
    });
  }


  String _fallbackAudioUrlForCurrentCall() {
    final normalizedSlotKey = _mediaSlotKey.trim();
    if (normalizedSlotKey == MediaPreloadService.d0FinalCallSlotKey ||
        _callType == 'final_phase' ||
        _callId == _defaultCallId) {
      return _defaultAudioUrl;
    }
    return '';
  }

  Future<void> _primeVoicePlayerIfPossible() async {
    try {
      if ((_resolvedAudioFilePath ?? '').trim().isNotEmpty) {
        await _voicePlayer.setSource(
          DeviceFileSource(_resolvedAudioFilePath!.trim()),
        );
        return;
      }

      final fallbackUrl = _fallbackAudioUrlForCurrentCall();
      final audioUrl = _audioUrl.trim().isNotEmpty ? _audioUrl.trim() : fallbackUrl;
      if (audioUrl.isNotEmpty) {
        await _voicePlayer.setSource(UrlSource(audioUrl));
      }
    } catch (e) {
      debugPrint('CALL_AUDIO_PRIME_FAILED: $e');
    }
  }
  String _stringOrFallback(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Future<void> _prepareAudioForCall() async {
    final normalizedSlotKey = _mediaSlotKey.trim();
    if (normalizedSlotKey.isEmpty) return;

    try {
      final cachedFile = await _mediaPreloadService.getCachedOrFetchAudio(
        slotKey: normalizedSlotKey,
        cacheBasename: "incoming_call_${_callId.isEmpty ? 'audio' : _callId}",
      );
      _resolvedAudioFilePath = cachedFile.path;
    } catch (e) {
      debugPrint('CALL_AUDIO_PREPARE_FAILED: $e');
    } finally {
      await _primeVoicePlayerIfPossible();
    }
  }

  Future<void> _runtimeEvent(String event) async {
    debugPrint('RUNTIME_EVENT: $event');

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
              ? Map<String, dynamic>.from(
                  data['callContext'] as Map<String, dynamic>,
                )
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
          if (_isFinalPhaseCall) {
            phase = 'awaiting_confirmation';
            active = true;
          } else {
            phase = 'resolved';
            active = false;
          }
          break;
        case 'incoming_call_ready_overlay_confirm_opened':
          phase = 'awaiting_confirmation';
          active = true;
          break;
        case 'incoming_call_confirm_overlay_closed':
          phase = 'awaiting_confirmation';
          active = true;
          break;
        case 'incoming_call_final_phase_confirmed':
          phase = 'resolved';
          active = false;
          break;
        case 'incoming_call_rejected':
          if (_shouldRetryUntilAnswered) {
            phase = 'ringing';
            active = true;
          } else {
            phase = 'resolved';
            active = false;
          }
          break;
      }

      await sessionRef.set({
        'callContext': {
          ...existingCallContext,
          'active': active,
          'phase': phase,
          'helpAttemptsDuringCall': helpAttemptsDuringCall,
          'callId': _callId,
          'callType': _callType,
          'displayName': _displayName,
          'audioUrl': _audioUrl,
          'mediaSlotKey': _mediaSlotKey,
          'backgroundImageUrl': _imageUrl,
          'retryPolicy': _retryPolicy,
          'uiVariant': _uiVariant,
          'ringtoneUrl': _ringtoneUrl,
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
    unawaited(_initializeCallScreen());
  }

  Future<void> _startRinging() async {
    final ringtone = _ringtoneUrl.trim().isEmpty
        ? _defaultRingtoneUrl
        : _ringtoneUrl.trim();

    await _ringPlayer.setReleaseMode(ReleaseMode.loop);
    await _ringPlayer.play(UrlSource(ringtone));

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
    if (_isPlayingVoice || _isLoadingCallContext) return;

    await _stopRinging();
    unawaited(_runtimeEvent('incoming_call_accepted'));

    setState(() {
      _isPlayingVoice = true;
    });

    await HapticFeedback.selectionClick();

    _voiceCompleteSubscription?.cancel();
    _voiceCompleteSubscription = _voicePlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;

      unawaited(_runtimeEvent('incoming_call_voice_finished'));

      if (_isFinalPhaseCall) {
        setState(() {
          _showReadyOverlay = true;
        });
      } else {
        Navigator.pop(context);
      }
    });

    if ((_resolvedAudioFilePath ?? '').trim().isNotEmpty) {
      try {
        await _voicePlayer.resume();
      } catch (_) {
        await _voicePlayer.play(DeviceFileSource(_resolvedAudioFilePath!.trim()));
      }
      return;
    }

    final fallbackUrl = _fallbackAudioUrlForCurrentCall();
    final audioSource =
        _audioUrl.trim().isNotEmpty ? _audioUrl.trim() : fallbackUrl;

    if (audioSource.isEmpty) {
      debugPrint(
        'CALL_AUDIO_SOURCE_MISSING: callId=$_callId mediaSlotKey=$_mediaSlotKey',
      );
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    try {
      await _voicePlayer.resume();
    } catch (_) {
      await _voicePlayer.play(UrlSource(audioSource));
    }
  }

  Future<void> _rejectCall() async {
    if (_isLoadingCallContext) return;

    await _stopRinging();
    unawaited(_runtimeEvent('incoming_call_rejected'));

    await HapticFeedback.lightImpact();
    if (_shouldRetryUntilAnswered) {
      widget.onRejected?.call();
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _openFinalConfirmation() {
    unawaited(_runtimeEvent('incoming_call_ready_overlay_confirm_opened'));
    setState(() {
      _showReadyOverlay = false;
      _showConfirmOverlay = true;
    });
  }

  void _closeFinalConfirmation() {
    unawaited(_runtimeEvent('incoming_call_confirm_overlay_closed'));
    setState(() {
      _showConfirmOverlay = false;
      _showReadyOverlay = true;
    });
  }

  void _confirmFinalPhase() {
    unawaited(_runtimeEvent('incoming_call_final_phase_confirmed'));
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


  bool _isUsableHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.trim().isNotEmpty;
  }

  Widget _buildCallBackground() {
    final resolvedImageUrl = _imageUrl.trim();

    if (!_isUsableHttpUrl(resolvedImageUrl)) {
      debugPrint(
        'CALL_BACKGROUND_URL_INVALID: callId=$_callId imageUrl=$resolvedImageUrl',
      );
      return const _IncomingCallFallbackBackground();
    }

    return Image.network(
      resolvedImageUrl,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const _IncomingCallFallbackBackground();
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          'CALL_BACKGROUND_LOAD_FAILED: callId=$_callId imageUrl=$resolvedImageUrl error=$error',
        );
        return const _IncomingCallFallbackBackground();
      },
    );
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
            child: _buildCallBackground(),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          if (_isLoadingCallContext)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: CircularProgressIndicator(),
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
                    title: _displayName,
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
          if ((_showReadyOverlay || _showConfirmOverlay) && _isFinalPhaseCall)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.56),
              ),
            ),
          if (_showReadyOverlay && _isFinalPhaseCall)
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
          if (_showConfirmOverlay && _isFinalPhaseCall)
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
                                        color: Colors.white.withValues(
                                          alpha: 0.28,
                                        ),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.28,
                                      ),
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

class _IncomingCallFallbackBackground extends StatelessWidget {
  const _IncomingCallFallbackBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, 0.72),
          radius: 1.18,
          colors: [
            Color(0xFF23140C),
            Color(0xFF0B0908),
            Color(0xFF000000),
          ],
          stops: [0.0, 0.52, 1.0],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.18),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.42),
            ],
          ),
        ),
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
        final gap = isTabletLike ? 24.0 : 16.0;
        final buttonDiameter = isTabletLike
            ? 116.0
            : (maxWidth * 0.24).clamp(74.0, 88.0).toDouble();
        final textWidth = isTabletLike
            ? (maxWidth * 0.24).clamp(170.0, 220.0).toDouble()
            : (maxWidth * 0.32).clamp(110.0, 150.0).toDouble();

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CallActionCluster(
                  diameter: buttonDiameter,
                  glowColor: const Color(0x99DB4437),
                  icon: Icons.call_end_rounded,
                  onTap: onReject,
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: textWidth,
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
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}
