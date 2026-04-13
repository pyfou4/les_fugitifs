import 'dart:math';

import 'package:flutter/material.dart';

class HourglassOverlay extends StatelessWidget {
  final double progress;
  final bool interactive;

  const HourglassOverlay({
    super.key,
    required this.progress,
    this.interactive = false,
  });

  @override
  Widget build(BuildContext context) {
    final raw = progress.clamp(0.0, 1.0);
    final p = pow(raw, 1.8).toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: p),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final topFill = (1.0 - value).clamp(0.0, 1.0);
        final bottomFill = value.clamp(0.0, 1.0);
        final glow = (0.18 + (value * 0.22)).clamp(0.18, 0.40);

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final frameWidth = width * 0.16;
            final chamberWidth = width * 0.54;
            final chamberLeft = (width - chamberWidth) / 2;
            final topHeight = height * 0.30;
            final bottomHeight = height * 0.30;
            final neckHeight = height * 0.18;
            final centerY = height * 0.50;
            final railLeft = (width / 2) - 1.5;
            final barLeft = chamberLeft * 0.92;
            final barWidth = chamberWidth * 1.08;

            return Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF162637).withOpacity(0.28),
                            const Color(0xFF0A1520).withOpacity(0.10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: chamberLeft - frameWidth * 0.18,
                  top: height * 0.08,
                  width: frameWidth,
                  height: height * 0.84,
                  child: _FrameRail(glow: glow),
                ),
                Positioned(
                  right: chamberLeft - frameWidth * 0.18,
                  top: height * 0.08,
                  width: frameWidth,
                  height: height * 0.84,
                  child: _FrameRail(glow: glow),
                ),

                Positioned(
                  left: barLeft,
                  top: height * 0.07,
                  width: barWidth,
                  height: 12,
                  child: _FrameBar(glow: glow),
                ),
                Positioned(
                  left: barLeft,
                  bottom: height * 0.07,
                  width: barWidth,
                  height: 12,
                  child: _FrameBar(glow: glow),
                ),

                Positioned(
                  left: barLeft - 6,
                  top: height * 0.07 - 2,
                  width: 18,
                  height: 18,
                  child: _BracketCap(glow: glow),
                ),
                Positioned(
                  right: barLeft - 6,
                  top: height * 0.07 - 2,
                  width: 18,
                  height: 18,
                  child: _BracketCap(glow: glow),
                ),
                Positioned(
                  left: barLeft - 6,
                  bottom: height * 0.07 - 2,
                  width: 18,
                  height: 18,
                  child: _BracketCap(glow: glow),
                ),
                Positioned(
                  right: barLeft - 6,
                  bottom: height * 0.07 - 2,
                  width: 18,
                  height: 18,
                  child: _BracketCap(glow: glow),
                ),

                Positioned(
                  left: chamberLeft,
                  top: height * 0.13,
                  width: chamberWidth,
                  height: topHeight,
                  child: _GlassChamber(
                    isTop: true,
                    fillRatio: topFill,
                    glow: glow,
                  ),
                ),
                Positioned(
                  left: railLeft,
                  top: centerY - (neckHeight / 2),
                  width: 3,
                  height: neckHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4D9A5).withOpacity(0.90),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF4D9A5).withOpacity(0.34),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: width * 0.445,
                  top: centerY - 11,
                  width: width * 0.11,
                  height: 22,
                  child: _NeckCollar(glow: glow),
                ),
                Positioned(
                  left: chamberLeft,
                  bottom: height * 0.13,
                  width: chamberWidth,
                  height: bottomHeight,
                  child: _GlassChamber(
                    isTop: false,
                    fillRatio: bottomFill,
                    glow: glow,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FrameRail extends StatelessWidget {
  final double glow;

  const _FrameRail({required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF3E2711).withOpacity(0.98),
            const Color(0xFF8A5A2B).withOpacity(0.98),
            const Color(0xFFD9A75A).withOpacity(0.98),
            const Color(0xFF6A431D).withOpacity(0.98),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD6B16B).withOpacity(glow),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _FrameBar extends StatelessWidget {
  final double glow;

  const _FrameBar({required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF4B2D12).withOpacity(0.98),
            const Color(0xFFB88644).withOpacity(0.98),
            const Color(0xFFE2B86B).withOpacity(0.98),
            const Color(0xFF66401B).withOpacity(0.98),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD6B16B).withOpacity(glow),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _BracketCap extends StatelessWidget {
  final double glow;

  const _BracketCap({required this.glow});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE5BC72).withOpacity(0.95),
            const Color(0xFF7C5228).withOpacity(0.98),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD6B16B).withOpacity(glow * 0.85),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _NeckCollar extends StatelessWidget {
  final double glow;

  const _NeckCollar({required this.glow});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF593415).withOpacity(0.96),
            const Color(0xFFF4D9A5).withOpacity(0.98),
            const Color(0xFF714723).withOpacity(0.96),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF4D9A5).withOpacity(glow * 0.7),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _GlassChamber extends StatelessWidget {
  final bool isTop;
  final double fillRatio;
  final double glow;

  const _GlassChamber({
    required this.isTop,
    required this.fillRatio,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HourglassChamberClipper(isTop: isTop),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
                end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  Colors.white.withOpacity(0.16),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF90A7C4).withOpacity(0.08),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Align(
            alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: fillRatio,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
                    end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
                    colors: [
                      const Color(0xFFA06C33).withOpacity(isTop ? 0.45 : 0.68),
                      const Color(0xFFF2C879).withOpacity(isTop ? 0.66 : 0.86),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF2C879).withOpacity(glow * 0.50),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: isTop ? Alignment.topLeft : Alignment.bottomLeft,
            child: Container(
              width: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
            left: 0,
            right: 0,
            height: 22,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
                    end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.transparent,
                    ],
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

class _HourglassChamberClipper extends CustomClipper<Path> {
  final bool isTop;

  const _HourglassChamberClipper({required this.isTop});

  @override
  Path getClip(Size size) {
    final path = Path();

    if (isTop) {
      path.moveTo(size.width * 0.05, 0);
      path.lineTo(size.width * 0.95, 0);
      path.lineTo(size.width * 0.60, size.height);
      path.lineTo(size.width * 0.40, size.height);
    } else {
      path.moveTo(size.width * 0.40, 0);
      path.lineTo(size.width * 0.60, 0);
      path.lineTo(size.width * 0.95, size.height);
      path.lineTo(size.width * 0.05, size.height);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _HourglassChamberClipper oldClipper) {
    return oldClipper.isTop != isTop;
  }
}
