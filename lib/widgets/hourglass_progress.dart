import 'package:flutter/material.dart';

class HourglassProgress extends StatelessWidget {
  final double progress;

  const HourglassProgress({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: p),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withOpacity(0.15),
                ),
              ),
            ),
            FractionallySizedBox(
              heightFactor: value,
              widthFactor: 0.5,
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6B36A),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}