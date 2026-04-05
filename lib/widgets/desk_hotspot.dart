import 'package:flutter/material.dart';

class DeskHotspot extends StatefulWidget {
  final double left;
  final double top;
  final double width;
  final double height;
  final VoidCallback onTap;
  final Color glowColor;
  final String? label;
  final bool debug;

  const DeskHotspot({
    super.key,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.onTap,
    this.glowColor = const Color(0x33D8B36A),
    this.label,
    this.debug = false,
  });

  @override
  State<DeskHotspot> createState() => _DeskHotspotState();
}

class _DeskHotspotState extends State<DeskHotspot> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.left,
      top: widget.top,
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: widget.debug
                ? Colors.red.withOpacity(0.12)
                : Colors.transparent,
            border: widget.debug
                ? Border.all(color: Colors.red, width: 2)
                : null,
            boxShadow: _pressed
                ? [
              BoxShadow(
                color: widget.glowColor,
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ]
                : [],
          ),
          child: widget.debug
              ? Center(
            child: Text(
              widget.label ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          )
              : null,
        ),
      ),
    );
  }
}