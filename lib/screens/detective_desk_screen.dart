import 'package:flutter/material.dart';
import '../models/game_progress.dart';
import '../widgets/desk_hotspot.dart';
import '../widgets/hourglass_progress.dart';

class DetectiveDeskScreen extends StatelessWidget {
  final GameProgress game;
  final bool debugHotspots;

  const DetectiveDeskScreen({
    super.key,
    required this.game,
    this.debugHotspots = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/detective_desk.png',
                  fit: BoxFit.cover,
                ),
              ),

              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.10),
                ),
              ),

              DeskHotspot(
                left: w * 0.03,
                top: h * 0.05,
                width: w * 0.42,
                height: h * 0.38,
                label: 'MAP',
                debug: debugHotspots,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ouvrir la carte')),
                  );
                },
              ),

              DeskHotspot(
                left: w * 0.77,
                top: h * 0.10,
                width: w * 0.17,
                height: h * 0.30,
                label: 'ARCHIVES',
                debug: debugHotspots,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ouvrir les archives')),
                  );
                },
              ),

              DeskHotspot(
                left: w * 0.57,
                top: h * 0.58,
                width: w * 0.20,
                height: h * 0.22,
                label: 'MICRO',
                debug: debugHotspots,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Activer le micro')),
                  );
                },
              ),

              DeskHotspot(
                left: w * 0.80,
                top: h * 0.47,
                width: w * 0.10,
                height: h * 0.16,
                label: 'SOS',
                debug: debugHotspots,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Aide / SOS')),
                  );
                },
              ),

              DeskHotspot(
                left: w * 0.62,
                top: h * 0.05,
                width: w * 0.18,
                height: h * 0.42,
                label: 'EXIT',
                debug: debugHotspots,
                onTap: () {
                  if (game.canExit) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Accès au test final')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Progression: ${game.visitedCount}/9 lieux explorés',
                        ),
                      ),
                    );
                  }
                },
              ),

              Positioned(
                left: w * 0.52,
                top: h * 0.46,
                width: w * 0.10,
                height: h * 0.22,
                child: HourglassProgress(
                  progress: game.progressRatio,
                ),
              ),

              Positioned(
                left: 16,
                top: 42,
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
                    'Progression : ${game.visitedCount}/9',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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