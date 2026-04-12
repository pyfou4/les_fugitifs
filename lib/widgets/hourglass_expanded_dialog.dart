import 'package:flutter/material.dart';

import 'hourglass_overlay.dart';

class HourglassExpandedDialog extends StatelessWidget {
  final double progress;

  const HourglassExpandedDialog({
    super.key,
    required this.progress,
  });

  String _getNarrativeText(double p) {
    if (p < 0.2) return 'Vous débutez votre enquête...';
    if (p < 0.4) return 'Des pistes se dessinent...';
    if (p < 0.6) return 'Les liens apparaissent...';
    if (p < 0.8) return 'Vous vous rapprochez de la vérité...';
    return 'La vérité est proche...';
  }

  String _getSubtitle(double p) {
    if (p < 0.2) return 'Les premières connexions commencent à émerger.';
    if (p < 0.4) return 'Le dossier s’épaissit, mais bien des zones restent troubles.';
    if (p < 0.6) return 'L’enquête gagne en densité et les motifs se répondent.';
    if (p < 0.8) return 'Le puzzle se ferme peu à peu autour des éléments essentiels.';
    return 'Tout converge. Le dénouement n’est plus très loin.';
  }

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).round();
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    final dialogWidth = isLandscape ? 760.0 : 430.0;
    final dialogHeight = isLandscape
        ? (size.height * 0.72).clamp(300.0, 410.0)
        : (size.height * 0.80).clamp(420.0, 580.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0E1C29),
                Color(0xFF09131D),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF2B4A68),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xBB000000),
                blurRadius: 44,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isLandscape ? 22 : 20,
              20,
              isLandscape ? 22 : 20,
              18,
            ),
            child: Column(
              children: [
                if (!isLandscape) ...[
                  _buildHeader(
                    isLandscape: false,
                    alignLeft: false,
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: isLandscape
                      ? _buildLandscapeBody(percent)
                      : _buildPortraitBody(percent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitBody(int percent) {
    return Column(
      children: [
        Expanded(
          flex: 7,
          child: _buildHourglassStage(compact: false),
        ),
        const SizedBox(height: 14),
        Expanded(
          flex: 5,
          child: _buildNarrativeBlock(percent, compact: false),
        ),
        const SizedBox(height: 10),
        _buildFooter,
      ],
    );
  }

  Widget _buildLandscapeBody(int percent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: _buildHourglassStage(compact: true),
        ),
        const SizedBox(width: 22),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                isLandscape: true,
                alignLeft: true,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _buildNarrativeBlock(percent, compact: true),
              ),
              const SizedBox(height: 10),
              _buildFooter,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({
    required bool isLandscape,
    required bool alignLeft,
  }) {
    return Column(
      crossAxisAlignment:
          alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          'Sablier de l’enquête',
          textAlign: alignLeft ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isLandscape ? 18 : 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Indicateur narratif de progression',
          textAlign: alignLeft ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF89A4C0),
            fontSize: isLandscape ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHourglassStage({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 10,
        vertical: compact ? 0 : 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.05,
          colors: [
            Color(0x1F77B6FF),
            Color(0x120E2233),
            Color(0x00000000),
          ],
        ),
      ),
      child: Center(
        child: SizedBox.expand(
          child: HourglassOverlay(
            progress: progress,
            interactive: false,
          ),
        ),
      ),
    );
  }

  Widget _buildNarrativeBlock(int percent, {required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFF111E2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF24384D),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getNarrativeText(progress),
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFE7EEF7),
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Expanded(
            child: Text(
              _getSubtitle(progress),
              maxLines: compact ? 4 : 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFABC0D4),
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2B3B),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF36506B),
              ),
            ),
            child: Text(
              '$percent%',
              style: const TextStyle(
                color: Color(0xFFD8E1EC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget get _buildFooter {
    return Align(
      alignment: Alignment.centerRight,
      child: Builder(
        builder: (context) {
          return TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Fermer'),
          );
        },
      ),
    );
  }
}
