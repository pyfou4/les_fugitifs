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

              // Archives
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

              // Dossier / Enquête
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

              // Téléphone / Micro
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

              // HELP / SOS
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
                onTap: widget.onOpenSOS ??
                        () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SOS')),
                      );
                    },
              ),

              // Porte / Sortie
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

              // Carte
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

              // Sablier
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

              // RESET MAÎTRE DE JEU
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