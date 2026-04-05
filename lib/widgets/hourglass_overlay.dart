import 'package:flutter/material.dart';

class HourglassOverlay extends StatelessWidget {
  final double progress;

  const HourglassOverlay({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: p),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        final animatedBottomFill = value;
        final animatedTopFill = 1.0 - value;

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 8,
              left: 18,
              right: 18,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    widthFactor: 0.78,
                    heightFactor: animatedTopFill.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8B36A).withOpacity(0.28),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 44,
              bottom: 44,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9D4A0).withOpacity(0.75),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE9D4A0).withOpacity(0.30),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 18,
              right: 18,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    widthFactor: 0.78,
                    heightFactor: animatedBottomFill.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8B36A).withOpacity(0.42),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD8B36A).withOpacity(0.18),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 50,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(value * 9).round()}/9',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}