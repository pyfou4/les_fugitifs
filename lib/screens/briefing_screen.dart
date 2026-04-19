import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../constants/firebase_media.dart';
import '../media/repository/firestore_media_repository.dart';
import '../media/repository/media_repository.dart';
import '../services/media_preload_service.dart';
import 'home_screen.dart';

class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  final MediaRepository _mediaRepository = FirestoreMediaRepository();

  VideoPlayerController? _rulesController;
  VideoPlayerController? _briefingController;

  bool _rulesReady = false;
  bool _briefingReady = false;

  bool _rulesDone = false;
  bool _briefingDone = false;

  String? _rulesError;
  String? _briefingError;

  final bool _forceUnlockEnterButton = true;
  bool _isPreparing = true;

  @override
  void initState() {
    super.initState();
    _startVideoInitialization();
  }

  Future<String> _resolveVideoUrl({
    required bool isRules,
  }) async {
    final asset = await _mediaRepository.getActiveMediaForSlot(
      scenarioId: MediaPreloadService.scenarioId,
      slotKey: isRules
          ? MediaPreloadService.introRulesSlotKey
          : MediaPreloadService.introBriefingSlotKey,
    );

    final downloadUrl = asset?.downloadUrl.trim() ?? '';
    if (downloadUrl.isEmpty) {
      throw Exception(
        'Aucun média backend actif pour le slot '
        '${isRules ? MediaPreloadService.introRulesSlotKey : MediaPreloadService.introBriefingSlotKey}.',
      );
    }

    return downloadUrl;
  }

  Future<void> _initOneVideo({
    required bool isRules,
  }) async {
    try {
      final downloadUrl = await _resolveVideoUrl(isRules: isRules);

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(downloadUrl),
      );

      await controller.initialize().timeout(const Duration(seconds: 45));

      controller.addListener(() {
        final value = controller.value;
        if (!value.isInitialized) return;

        final d = value.duration.inMilliseconds;
        final p = value.position.inMilliseconds;

        if (d > 0 && p / d >= 0.8) {
          if (!mounted) return;
          setState(() {
            if (isRules) {
              _rulesDone = true;
            } else {
              _briefingDone = true;
            }
          });
        }
      });

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        if (isRules) {
          _rulesController = controller;
          _rulesReady = true;
          _rulesError = null;
        } else {
          _briefingController = controller;
          _briefingReady = true;
          _briefingError = null;
        }
      });
    } catch (e) {
      debugPrint(
        'ERREUR VIDEO BACKEND (${isRules ? "rules" : "briefing"}) : $e',
      );

      if (!mounted) return;
      setState(() {
        final message = _formatVideoError(e);
        if (isRules) {
          _rulesError = message;
          _rulesReady = false;
        } else {
          _briefingError = message;
          _briefingReady = false;
        }
      });
    }
  }

  void _startVideoInitialization() {
    unawaited(() async {
      if (!mounted) return;
      setState(() {
        _isPreparing = true;
      });

      await Future.wait([
        _initOneVideo(isRules: true),
        _initOneVideo(isRules: false),
      ]);

      if (!mounted) return;
      setState(() {
        _isPreparing = false;
      });
    }());
  }


  String _formatVideoError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) {
      return 'Vidéo backend indisponible';
    }

    if (raw.length <= 140) {
      return raw;
    }

    return '${raw.substring(0, 137)}...';
  }

  double _progress(VideoPlayerController? controller) {
    if (controller == null || !controller.value.isInitialized) return 0;
    final d = controller.value.duration.inMilliseconds;
    final p = controller.value.position.inMilliseconds;
    return d > 0 ? (p / d).clamp(0.0, 1.0) : 0;
  }

  bool get _canEnter =>
      _forceUnlockEnterButton || (_rulesDone && _briefingDone);

  Future<void> _openVideoFullscreen({
    required String title,
    required VideoPlayerController? controller,
    required bool isReady,
    required String? errorText,
  }) async {
    if (errorText != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText)),
      );
      return;
    }

    if (!isReady || controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La vidéo est encore en chargement.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPage(
          title: title,
          controller: controller,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _rulesController?.dispose();
    _briefingController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rulesProgress = _progress(_rulesController);
    final briefingProgress = _progress(_briefingController);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = h < 720;
          final isTablet = w >= 900;

          final double cardWidth = isTablet ? w * 0.26 : w * 0.30;
          final double cardHeight = isTablet ? h * 0.40 : h * 0.44;
          final double centerGap = isTablet ? w * 0.04 : w * 0.05;
          final double leftCardLeft = (w / 2) - cardWidth - (centerGap / 2);
          final double rightCardLeft = (w / 2) + (centerGap / 2);
          final double cardsTop = isTablet ? h * 0.30 : h * 0.32;
          final double titleTop = cardsTop + cardHeight + (isTablet ? 12 : 10);

          return Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: FirebaseMedia.bgBriefing,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black),
                  errorWidget: (_, __, ___) {
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1C120D),
                            Color(0xFF2A1B14),
                            Color(0xFF0F0B0A),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.05),
                ),
              ),
              if (_isPreparing)
                Positioned(
                  top: 24,
                  left: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Préparation des vidéos...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: compact ? 18 : 24,
                top: isTablet ? h * 0.16 : h * 0.18,
                child: _TopLogo(compact: compact),
              ),
              Positioned(
                left: leftCardLeft,
                top: cardsTop,
                width: cardWidth,
                height: cardHeight,
                child: Transform.rotate(
                  angle: -0.035,
                  child: _PolaroidOverlay(
                    compact: compact,
                    progress: rulesProgress,
                    isDone: _rulesDone,
                    isReady: _rulesReady,
                    errorText: _rulesError,
                    controller: _rulesController,
                    onTap: () {
                      _openVideoFullscreen(
                        title: 'Règles du jeu',
                        controller: _rulesController,
                        isReady: _rulesReady,
                        errorText: _rulesError,
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: rightCardLeft,
                top: cardsTop,
                width: cardWidth,
                height: cardHeight,
                child: Transform.rotate(
                  angle: 0.035,
                  child: _PolaroidOverlay(
                    compact: compact,
                    progress: briefingProgress,
                    isDone: _briefingDone,
                    isReady: _briefingReady,
                    errorText: _briefingError,
                    controller: _briefingController,
                    onTap: () {
                      _openVideoFullscreen(
                        title: 'Briefing',
                        controller: _briefingController,
                        isReady: _briefingReady,
                        errorText: _briefingError,
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: leftCardLeft,
                top: titleTop,
                width: cardWidth,
                child: Text(
                  'Règles du jeu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.90),
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: rightCardLeft,
                top: titleTop,
                width: cardWidth,
                child: Text(
                  'Briefing',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.90),
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: compact ? 18 : 24,
                bottom: 0,
                child: SafeArea(
                  minimum: EdgeInsets.only(
                    bottom: compact ? 12 : 18,
                  ),
                  child: ElevatedButton(
                    onPressed: _canEnter
                        ? () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const HomeScreen(),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.6),
                      backgroundColor: const Color(0xFFC69A5A),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white.withOpacity(0.18),
                      disabledForegroundColor: Colors.white54,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 18 : 22,
                        vertical: compact ? 11 : 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: TextStyle(
                        fontSize: compact ? 15 : 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Ouvrir le dossier'),
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

class _TopLogo extends StatelessWidget {
  final bool compact;

  const _TopLogo({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: compact ? 88 : 118,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return Text(
          'Les Fugitifs',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 28 : 38,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        );
      },
    );
  }
}

class _PolaroidOverlay extends StatelessWidget {
  final bool compact;
  final double progress;
  final bool isDone;
  final bool isReady;
  final String? errorText;
  final VideoPlayerController? controller;
  final VoidCallback onTap;

  const _PolaroidOverlay({
    required this.compact,
    required this.progress,
    required this.isDone,
    required this.isReady,
    required this.errorText,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 4 : 6),
      child: _PhotoSurface(
        isDone: isDone,
        isReady: isReady,
        errorText: errorText,
        controller: controller,
        progress: progress,
        onTap: onTap,
      ),
    );
  }
}

class _PhotoSurface extends StatelessWidget {
  final bool isDone;
  final bool isReady;
  final String? errorText;
  final VideoPlayerController? controller;
  final double progress;
  final VoidCallback onTap;

  const _PhotoSurface({
    required this.isDone,
    required this.isReady,
    required this.errorText,
    required this.controller,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasVideo = isReady &&
        errorText == null &&
        controller != null &&
        controller!.value.isInitialized;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            spreadRadius: -3,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasVideo)
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.10),
                  BlendMode.darken,
                ),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.size.width,
                    height: controller!.value.size.height,
                    child: VideoPlayer(controller!),
                  ),
                ),
              )
            else
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.10),
                  BlendMode.darken,
                ),
                child: CachedNetworkImage(
                  imageUrl: FirebaseMedia.bgBriefing,
                  fit: BoxFit.cover,
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.30),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.0,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.05,
                  child: CustomPaint(
                    painter: _GrainPainter(),
                  ),
                ),
              ),
            ),
            _PhotoOverlayUI(
              isDone: isDone,
              isReady: isReady,
              errorText: errorText,
              progress: progress,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoOverlayUI extends StatelessWidget {
  final bool isDone;
  final bool isReady;
  final String? errorText;
  final double progress;
  final VoidCallback onTap;

  const _PhotoOverlayUI({
    required this.isDone,
    required this.isReady,
    required this.errorText,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = errorText != null
        ? 'Erreur'
        : !isReady
            ? 'Chargement...'
            : '${(progress * 100).toInt()}%';

    return Stack(
      children: [
        Center(
          child: GestureDetector(
            onTap: errorText != null ? null : onTap,
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.22),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
              child: Icon(
                errorText != null
                    ? Icons.error_outline
                    : isDone
                        ? Icons.check_circle
                        : Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: isReady ? progress : null,
                minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.18),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFE3B560),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    const step = 10.0;

    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        final n = ((x * 13 + y * 7) % 23) / 23.0;
        if (n > 0.72) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, 1.2, 1.2),
            paint..color = Colors.white.withOpacity(0.18),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FullscreenVideoPage extends StatefulWidget {
  final String title;
  final VideoPlayerController controller;

  const _FullscreenVideoPage({
    required this.title,
    required this.controller,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _enterImmersiveMode();
    widget.controller.play();
    widget.controller.addListener(_refresh);
  }

  Future<void> _enterImmersiveMode() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    _enterImmersiveMode();
  }

  @override
  void dispose() {
    widget.controller.pause();
    widget.controller.removeListener(_refresh);
    _restoreSystemUi();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.controller.value.isPlaying;
    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio > 0
                      ? widget.controller.value.aspectRatio
                      : 16 / 9,
                  child: VideoPlayer(widget.controller),
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Stack(
                  children: [
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded),
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.white.withOpacity(0.12),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFE3B560),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      if (isPlaying) {
                                        widget.controller.pause();
                                      } else {
                                        widget.controller.play();
                                      }
                                      _enterImmersiveMode();
                                    },
                                    icon: Icon(
                                      isPlaying
                                          ? Icons.pause_circle_filled_rounded
                                          : Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDuration(position),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDuration(duration),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}