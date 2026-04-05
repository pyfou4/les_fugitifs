import 'dart:math' as math;

import 'package:flutter/material.dart';

class CreatorSchemaBannerSection extends StatelessWidget {
  final Map<String, Map<String, dynamic>> docsById;
  final String? selectedId;
  final Color Function(String id) groupColorBuilder;
  final void Function(String id, Map<String, Map<String, dynamic>> docsById)
      onSelectFromMap;

  const CreatorSchemaBannerSection({
    super.key,
    required this.docsById,
    required this.selectedId,
    required this.groupColorBuilder,
    required this.onSelectFromMap,
  });

  @override
  Widget build(BuildContext context) {
    const bannerWidth = 1680.0;
    const bannerHeight = 302.0;

    final nodeRects = <String, Rect>{
      'A0': const Rect.fromLTWH(38, 102, 112, 62),
      'A1': const Rect.fromLTWH(198, 18, 72, 42),
      'A2': const Rect.fromLTWH(198, 62, 72, 42),
      'A3': const Rect.fromLTWH(198, 106, 72, 42),
      'A4': const Rect.fromLTWH(198, 150, 72, 42),
      'A5': const Rect.fromLTWH(198, 194, 72, 42),
      'A6': const Rect.fromLTWH(198, 238, 72, 42),
      'B0': const Rect.fromLTWH(362, 102, 112, 62),
      'B1': const Rect.fromLTWH(540, 32, 72, 42),
      'B2': const Rect.fromLTWH(540, 76, 72, 42),
      'B3': const Rect.fromLTWH(540, 120, 72, 42),
      'B4': const Rect.fromLTWH(540, 164, 72, 42),
      'B5': const Rect.fromLTWH(540, 208, 72, 42),
      'C0': const Rect.fromLTWH(788, 102, 112, 62),
      'C1': const Rect.fromLTWH(958, 42, 72, 42),
      'C2': const Rect.fromLTWH(958, 86, 72, 42),
      'C3': const Rect.fromLTWH(958, 130, 72, 42),
      'C4': const Rect.fromLTWH(958, 174, 72, 42),
      'D0': const Rect.fromLTWH(1178, 102, 112, 62),
    };

    return Container(
      width: double.infinity,
      height: bannerHeight,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF081220),
            Color(0xFF09172A),
            Color(0xFF07111F),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1B2A42)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: bannerWidth,
          height: bannerHeight - 16,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _SchemaPainter(
                    nodeRects: nodeRects,
                    selectedId: selectedId,
                    selectedColor:
                        selectedId == null ? null : groupColorBuilder(selectedId!),
                  ),
                ),
              ),
              ...nodeRects.entries.map((entry) {
                final id = entry.key;
                final rect = entry.value;
                final isMain =
                    id == 'A0' || id == 'B0' || id == 'C0' || id == 'D0';

                return Positioned(
                  left: rect.left,
                  top: rect.top,
                  child: isMain
                      ? _SchemaMainNode(
                          id: id,
                          selectedId: selectedId,
                          color: groupColorBuilder(id),
                          onTap: () => onSelectFromMap(id, docsById),
                        )
                      : _SchemaSubNode(
                          id: id,
                          selectedId: selectedId,
                          color: groupColorBuilder(id),
                          onTap: () => onSelectFromMap(id, docsById),
                        ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchemaMainNode extends StatelessWidget {
  final String id;
  final String? selectedId;
  final Color color;
  final VoidCallback onTap;

  const _SchemaMainNode({
    required this.id,
    required this.selectedId,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedId == id;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 112,
        height: 62,
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.20 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color,
            width: selected ? 2.2 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: Center(
          child: Text(
            id,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _SchemaSubNode extends StatelessWidget {
  final String id;
  final String? selectedId;
  final Color color;
  final VoidCallback onTap;

  const _SchemaSubNode({
    required this.id,
    required this.selectedId,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedId == id;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 84,
        height: 52,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 72,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.16)
                  : const Color(0xFF1B2435),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? color : const Color(0xFF334155),
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                id,
                style: TextStyle(
                  color: selected ? color : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SchemaPainter extends CustomPainter {
  final Map<String, Rect> nodeRects;
  final String? selectedId;
  final Color? selectedColor;

  const _SchemaPainter({
    required this.nodeRects,
    required this.selectedId,
    required this.selectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = const Color(0xFF35506F)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final highlightPaint = Paint()
      ..color = (selectedColor ?? const Color(0xFF6B7280)).withOpacity(0.78)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;

    void drawArrowHead(Canvas canvas, Offset tip, double angle, Paint paint) {
      const arrowSize = 6.0;
      final p1 = Offset(
        tip.dx - arrowSize * math.cos(angle - 0.45),
        tip.dy - arrowSize * math.sin(angle - 0.45),
      );
      final p2 = Offset(
        tip.dx - arrowSize * math.cos(angle + 0.45),
        tip.dy - arrowSize * math.sin(angle + 0.45),
      );

      canvas.drawLine(tip, p1, paint);
      canvas.drawLine(tip, p2, paint);
    }

    void drawForkFromMainToChildren(String mainId, List<String> children) {
      final main = nodeRects[mainId]!;
      final start = Offset(main.right, main.top + main.height / 2);

      for (final childId in children) {
        final child = nodeRects[childId]!;
        final end = Offset(child.left, child.top + child.height / 2);

        final highlighted = selectedId == mainId || selectedId == childId;
        final paint = highlighted ? highlightPaint : basePaint;

        canvas.drawLine(start, end, paint);
        final angle = (end - start).direction;
        drawArrowHead(canvas, end, angle, paint);
      }
    }

    void drawCollectorToMain({
      required List<String> sourceIds,
      required String targetMainId,
      required bool highlighted,
    }) {
      final paint = highlighted ? highlightPaint : basePaint;
      final target = nodeRects[targetMainId]!;
      final targetLeft = Offset(target.left, target.top + target.height / 2);

      final top = sourceIds
          .map((id) => nodeRects[id]!.top + nodeRects[id]!.height / 2)
          .reduce((a, b) => a < b ? a : b);
      final bottom = sourceIds
          .map((id) => nodeRects[id]!.top + nodeRects[id]!.height / 2)
          .reduce((a, b) => a > b ? a : b);

      final rightEdge = sourceIds
          .map((id) => nodeRects[id]!.right)
          .reduce((a, b) => a > b ? a : b);

      final collectorX = rightEdge + 20;
      final collectorMidY = (top + bottom) / 2;

      canvas.drawLine(
        Offset(collectorX, top),
        Offset(collectorX, bottom),
        paint,
      );

      for (final id in sourceIds) {
        final source = nodeRects[id]!;
        final sourceRight = Offset(source.right, source.top + source.height / 2);
        canvas.drawLine(
          sourceRight,
          Offset(collectorX, sourceRight.dy),
          paint,
        );
      }

      final elbow = Offset(targetLeft.dx - 18, collectorMidY);
      canvas.drawLine(
        Offset(collectorX, collectorMidY),
        elbow,
        paint,
      );
      canvas.drawLine(
        elbow,
        targetLeft,
        paint,
      );

      drawArrowHead(canvas, targetLeft, 0, paint);
    }

    const aChildren = ['A1', 'A2', 'A3', 'A4', 'A5', 'A6'];
    const bChildren = ['B1', 'B2', 'B3', 'B4', 'B5'];
    const cChildren = ['C1', 'C2', 'C3', 'C4'];

    drawForkFromMainToChildren('A0', aChildren);
    drawCollectorToMain(
      sourceIds: aChildren,
      targetMainId: 'B0',
      highlighted: selectedId == 'B0' || aChildren.contains(selectedId),
    );

    drawForkFromMainToChildren('B0', bChildren);
    drawCollectorToMain(
      sourceIds: bChildren,
      targetMainId: 'C0',
      highlighted: selectedId == 'C0' || bChildren.contains(selectedId),
    );

    drawForkFromMainToChildren('C0', cChildren);
    drawCollectorToMain(
      sourceIds: cChildren,
      targetMainId: 'D0',
      highlighted: selectedId == 'D0' || cChildren.contains(selectedId),
    );
  }

  @override
  bool shouldRepaint(covariant _SchemaPainter oldDelegate) {
    return oldDelegate.selectedId != selectedId ||
        oldDelegate.nodeRects != nodeRects ||
        oldDelegate.selectedColor != selectedColor;
  }
}
