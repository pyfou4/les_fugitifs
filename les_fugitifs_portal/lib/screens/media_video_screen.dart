import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:les_fugitifs_portal/core/media/models/media_asset.dart';

enum MediaVideoCompletionBehavior {
  stay,
  pop,
  navigateToRoute,
  triggerAction,
}

class MediaVideoScreenConfig {
  final MediaVideoCompletionBehavior completionBehavior;
  final bool autoPlay;
  final bool loop;
  final bool startMuted;
  final bool showTapToPlayOverlay;
  final bool allowUnmuteButton;
  final String? targetRoute;
  final String? actionId;
  final int delayMs;
  final bool replaceRouteOnComplete;
  final Future<void> Function(String actionId)? onTriggerAction;

  const MediaVideoScreenConfig({
    this.completionBehavior = MediaVideoCompletionBehavior.stay,
    this.autoPlay = true,
    this.loop = false,
    this.startMuted = true,
    this.showTapToPlayOverlay = true,
    this.allowUnmuteButton = true,
    this.targetRoute,
    this.actionId,
    this.delayMs = 0,
    this.replaceRouteOnComplete = false,
    this.onTriggerAction,
  });
}

class MediaVideoScreen extends StatefulWidget {
  final MediaAsset media;
  final MediaVideoScreenConfig config;

  const MediaVideoScreen({
    super.key,
    required this.media,
    this.config = const MediaVideoScreenConfig(),
  });

  @override
  State<MediaVideoScreen> createState() => _MediaVideoScreenState();
}

class _MediaVideoScreenState extends State<MediaVideoScreen> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;
  bool _didHandleCompletion = false;
  bool _autoplayWasBlocked = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.config.startMuted;
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final url = await FirebaseStorage.instance
          .ref(widget.media.storagePath)
          .getDownloadURL();

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      await controller.setLooping(widget.config.loop);
      await controller.setVolume(_isMuted ? 0 : 1);

      controller.addListener(_handleControllerUpdate);

      if (widget.config.autoPlay) {
        try {
          await controller.play();
        } catch (_) {
          _autoplayWasBlocked = true;
        }
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isLoading = false;
      });

      // Some browsers quietly ignore autoplay attempts.
      // If playback still has not started shortly after init, we surface the overlay.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted || _controller != controller) return;

      if (widget.config.autoPlay && !controller.value.isPlaying) {
        setState(() {
          _autoplayWasBlocked = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de lancer la vidéo : $e';
        _isLoading = false;
      });
    }
  }

  void _handleControllerUpdate() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (mounted) {
      setState(() {});
    }

    final value = controller.value;
    final duration = value.duration;
    final position = value.position;

    if (!widget.config.loop &&
        !_didHandleCompletion &&
        duration > Duration.zero &&
        position >= duration &&
        !value.isPlaying) {
      _didHandleCompletion = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleCompletion();
      });
    }
  }

  Future<void> _handleCompletion() async {
    if (!mounted) return;

    final delayMs = widget.config.delayMs;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (!mounted) return;
    }

    switch (widget.config.completionBehavior) {
      case MediaVideoCompletionBehavior.stay:
        return;

      case MediaVideoCompletionBehavior.pop:
        await Navigator.of(context).maybePop();
        return;

      case MediaVideoCompletionBehavior.navigateToRoute:
        final targetRoute = widget.config.targetRoute;
        if (targetRoute == null || targetRoute.isEmpty) {
          if (!mounted) return;
          setState(() {
            _error =
                'Fin vidéo configurée sur navigateToRoute, mais targetRoute est absent.';
          });
          return;
        }

        if (widget.config.replaceRouteOnComplete) {
          await Navigator.of(context).pushReplacementNamed(targetRoute);
        } else {
          await Navigator.of(context).pushNamed(targetRoute);
        }
        return;

      case MediaVideoCompletionBehavior.triggerAction:
        final actionId = widget.config.actionId;
        if (actionId == null || actionId.isEmpty) {
          if (!mounted) return;
          setState(() {
            _error =
                'Fin vidéo configurée sur triggerAction, mais actionId est absent.';
          });
          return;
        }

        final onTriggerAction = widget.config.onTriggerAction;
        if (onTriggerAction == null) {
          if (!mounted) return;
          setState(() {
            _error =
                'Fin vidéo configurée sur triggerAction, mais aucun handler n\'est fourni.';
          });
          return;
        }

        try {
          await onTriggerAction(actionId);
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _error = 'Action de fin vidéo impossible : $e';
          });
        }
        return;
    }
  }

  Future<void> _playWithGesture() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.play();
      if (!mounted) return;
      setState(() {
        _autoplayWasBlocked = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Lecture impossible : $e';
      });
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;

    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);

    if (!mounted) return;
    setState(() {
      _isMuted = nextMuted;
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                    : controller == null
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _playWithGesture,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: controller.value.size.width,
                                  height: controller.value.size.height,
                                  child: VideoPlayer(controller),
                                ),
                              ),
                            ),
                          ),
          ),
          Positioned(
            top: 24,
            left: 16,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
          if (!_isLoading &&
              _error == null &&
              controller != null &&
              widget.config.allowUnmuteButton)
            Positioned(
              top: 24,
              right: 16,
              child: SafeArea(
                child: IconButton(
                  onPressed: _toggleMute,
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (!_isLoading &&
              _error == null &&
              controller != null &&
              widget.config.showTapToPlayOverlay &&
              (!controller.value.isPlaying || _autoplayWasBlocked) &&
              controller.value.position < controller.value.duration)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  color: Colors.black.withOpacity(0.28),
                  child: Center(
                    child: GestureDetector(
                      onTap: _playWithGesture,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Touchez pour lancer la vidéo',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
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
