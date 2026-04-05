import 'package:flutter/material.dart';

class BeaconDot extends StatefulWidget {
  final Color color;
  final double size;

  const BeaconDot({
    super.key,
    required this.color,
    this.size = 14,
  });

  @override
  State<BeaconDot> createState() => _BeaconDotState();
}

class _BeaconDotState extends State<BeaconDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.75, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulse.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.95),
                    blurRadius: 14,
                    spreadRadius: 1.5,
                  ),
                  BoxShadow(
                    color: widget.color.withOpacity(0.55),
                    blurRadius: 26,
                    spreadRadius: 3,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.85),
                  width: 1.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}