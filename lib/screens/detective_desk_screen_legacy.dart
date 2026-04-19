import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

import '../models/game_progress.dart';
import '../widgets/desk_hotspot.dart';
import '../widgets/hourglass_progress.dart';

class DetectiveDeskScreen extends StatefulWidget {
  final GameProgress game;
  final bool debugHotspots;

  const DetectiveDeskScreen({
    super.key,
    required this.game,
    this.debugHotspots = true,
  });

  @override
  State<DetectiveDeskScreen> createState() => _DetectiveDeskScreenState();
}

class _DetectiveDeskScreenState extends State<DetectiveDeskScreen> {
  static const String _deskAssetPath = 'assets/images/detective_desk.png';

  late final ImageProvider _deskImageProvider;
  Future<Size>? _imageSizeFuture;

  @override
  void initState() {
    super.initState();
    _deskImageProvider = const AssetImage(_deskAssetPath);
    _imageSizeFuture = _resolveImageSize(_deskImageProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Size>(
        future: _imageSizeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _deskAssetPath,
                  fit: BoxFit.cover,
                ),
                _buildDarkOverlay(),
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                const Center(
                  child: Text(
                    'Impossible de charger le décor du bureau.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          }

          final imageSize = snapshot.data!;

          return LayoutBuilder(
            builder: (context, constraints) {
              final screenSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final imageRect = _computeCoverRect(
                sourceSize: imageSize,
                destinationSize: screenSize,
              );

              final isTablet = screenSize.width >= 900;
              final layout = isTablet
                  ? DetectiveDeskLayouts.tablet
                  : DetectiveDeskLayouts.phone;

              return Stack(
                children: [
                  _buildBackground(),
                  _buildDarkOverlay(),
                  _buildHotspot(
                    context: context,
                    zone: layout.map,
                    imageRect: imageRect,
                    label: 'MAP',
                    onTap: () => _onMapTap(context),
                  ),
                  _buildHotspot(
                    context: context,
                    zone: layout.archives,
                    imageRect: imageRect,
                    label: 'ARCHIVES',
                    onTap: () => _onArchivesTap(context),
                  ),
                  _buildHotspot(
                    context: context,
                    zone: layout.micro,
                    imageRect: imageRect,
                    label: 'MICRO',
                    onTap: () => _onMicroTap(context),
                  ),
                  _buildHotspot(
                    context: context,
                    zone: layout.sos,
                    imageRect: imageRect,
                    label: 'SOS',
                    onTap: () => _onSosTap(context),
                  ),
                  _buildHotspot(
                    context: context,
                    zone: layout.exit,
                    imageRect: imageRect,
                    label: 'EXIT',
                    onTap: () => _onExitTap(context),
                  ),
                  _buildHourglass(
                    zone: layout.hourglass,
                    imageRect: imageRect,
                  ),
                  _buildProgressBadge(
                    zone: layout.progressBadge,
                    imageRect: imageRect,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Image.asset(
        _deskAssetPath,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildDarkOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.10),
      ),
    );
  }

  Widget _buildHotspot({
    required BuildContext context,
    required DeskZone zone,
    required Rect imageRect,
    required String label,
    required VoidCallback onTap,
  }) {
    return DeskHotspot(
      left: imageRect.left + (imageRect.width * zone.left),
      top: imageRect.top + (imageRect.height * zone.top),
      width: imageRect.width * zone.width,
      height: imageRect.height * zone.height,
      label: label,
      debug: widget.debugHotspots,
      onTap: onTap,
    );
  }

  Widget _buildHourglass({
    required DeskZone zone,
    required Rect imageRect,
  }) {
    return Positioned(
      left: imageRect.left + (imageRect.width * zone.left),
      top: imageRect.top + (imageRect.height * zone.top),
      width: imageRect.width * zone.width,
      height: imageRect.height * zone.height,
      child: HourglassProgress(
        progress: widget.game.progressRatio,
      ),
    );
  }

  Widget _buildProgressBadge({
    required DeskZone zone,
    required Rect imageRect,
  }) {
    return Positioned(
      left: imageRect.left + (imageRect.width * zone.left),
      top: imageRect.top + (imageRect.height * zone.top),
      width: imageRect.width * zone.width,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Progression : ${widget.game.visitedCount}/9',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _onMapTap(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ouvrir la carte')),
    );
  }

  void _onArchivesTap(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ouvrir les archives')),
    );
  }

  void _onMicroTap(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Activer le micro')),
    );
  }

  void _onSosTap(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aide / SOS')),
    );
  }

  void _onExitTap(BuildContext context) {
    if (widget.game.canExit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accès au test final')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Progression: ${widget.game.visitedCount}/9 lieux explorés',
          ),
        ),
      );
    }
  }

  Future<Size> _resolveImageSize(ImageProvider provider) async {
    final completer = Completer<Size>();
    final stream = provider.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        final image = info.image;
        final size = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );

        if (!completer.isCompleted) {
          completer.complete(size);
        }

        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }

        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
    return completer.future;
  }

  Rect _computeCoverRect({
    required Size sourceSize,
    required Size destinationSize,
  }) {
    final fitted = applyBoxFit(BoxFit.cover, sourceSize, destinationSize);
    final renderedSize = fitted.destination;
    final dx = (destinationSize.width - renderedSize.width) / 2;
    final dy = (destinationSize.height - renderedSize.height) / 2;

    return Rect.fromLTWH(
      dx,
      dy,
      renderedSize.width,
      renderedSize.height,
    );
  }
}

class DeskZone {
  final double left;
  final double top;
  final double width;
  final double height;

  const DeskZone({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

class DetectiveDeskLayoutSet {
  final DeskZone map;
  final DeskZone archives;
  final DeskZone micro;
  final DeskZone sos;
  final DeskZone exit;
  final DeskZone hourglass;
  final DeskZone progressBadge;

  const DetectiveDeskLayoutSet({
    required this.map,
    required this.archives,
    required this.micro,
    required this.sos,
    required this.exit,
    required this.hourglass,
    required this.progressBadge,
  });
}

class DetectiveDeskLayouts {
  static const phone = DetectiveDeskLayoutSet(
    map: DeskZone(left: 0.03, top: 0.05, width: 0.42, height: 0.38),
    archives: DeskZone(left: 0.77, top: 0.10, width: 0.17, height: 0.30),
    micro: DeskZone(left: 0.57, top: 0.58, width: 0.20, height: 0.22),
    sos: DeskZone(left: 0.80, top: 0.47, width: 0.10, height: 0.16),
    exit: DeskZone(left: 0.62, top: 0.05, width: 0.18, height: 0.42),
    hourglass: DeskZone(left: 0.52, top: 0.46, width: 0.10, height: 0.22),
    progressBadge: DeskZone(
      left: 0.02,
      top: 0.05,
      width: 0.20,
      height: 0.08,
    ),
  );

  static const tablet = DetectiveDeskLayoutSet(
    map: DeskZone(left: 0.03, top: 0.05, width: 0.42, height: 0.38),
    archives: DeskZone(left: 0.77, top: 0.14, width: 0.17, height: 0.30),
    micro: DeskZone(left: 0.57, top: 0.58, width: 0.20, height: 0.22),
    sos: DeskZone(left: 0.80, top: 0.47, width: 0.10, height: 0.16),
    exit: DeskZone(left: 0.62, top: 0.05, width: 0.18, height: 0.42),
    hourglass: DeskZone(left: 0.52, top: 0.50, width: 0.10, height: 0.22),
    progressBadge: DeskZone(
      left: 0.02,
      top: 0.05,
      width: 0.18,
      height: 0.08,
    ),
  );
}
