import 'package:flutter/material.dart';

import '../models/motive_model.dart';
import '../models/suspect_model.dart';

class InvestigationScreen extends StatelessWidget {
  static const String _backgroundUrl =
      'https://firebasestorage.googleapis.com/v0/b/les-fugitifs.firebasestorage.app/o/images%2Fbg_investigations.png?alt=media&token=d4057c99-22dc-43c7-8474-2ba223ed71aa';

  static const Color _fallbackBackground = Color(0xFF120A05);
  static const Color _titleInk = Color(0xFFF4E6D2);
  static const Color _bodyInk = Color(0xFFE7D6BE);
  static const Color _mutedInk = Color(0xFF96765A);
  static const Color _mutedInkStrong = Color(0xFF7C5D45);
  static const Color _introInk = Color(0xFFD9C3A4);
  static const Color _panelTint = Color(0x1EF3E8D6);
  static const Color _cardTint = Color(0x26F7ECDD);
  static const Color _dismissedTint = Color(0x26A54B3B);
  static const Color _dismissedBorder = Color(0x80D47967);

  final VoidCallback onBack;
  final List<SuspectModel> suspects;
  final List<MotiveModel> motives;
  final Set<String> markedSuspectIds;
  final Set<String> markedMotiveIds;
  final ValueChanged<String> onToggleSuspect;
  final ValueChanged<String> onToggleMotive;

  const InvestigationScreen({
    super.key,
    required this.onBack,
    required this.suspects,
    required this.motives,
    required this.markedSuspectIds,
    required this.markedMotiveIds,
    required this.onToggleSuspect,
    required this.onToggleMotive,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isTablet = mediaQuery.size.width >= 900;
    final horizontalPadding = isTablet ? 24.0 : 16.0;
    final topSpacing = isTablet ? 12.0 : 8.0;
    final suspectRemaining = suspects.length - markedSuspectIds.length;
    final motiveRemaining = motives.length - markedMotiveIds.length;

    return Scaffold(
      backgroundColor: _fallbackBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              _backgroundUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: _fallbackBackground,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.35),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topSpacing,
                horizontalPadding,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScreenHeader(onBack: onBack),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Rayez les pistes à mesure que votre théorie se précise.',
                      style: TextStyle(
                        color: _introInk,
                        fontSize: isTablet ? 17 : 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.12,
                        shadows: _textShadows(0.26),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: isTablet
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _InvestigationPanel(
                                  title: 'Suspects',
                                  subtitle:
                                      '$suspectRemaining à surveiller · ${markedSuspectIds.length} écarté${markedSuspectIds.length > 1 ? 's' : ''}',
                                  accentColor: const Color(0xFF8A6230),
                                  scrollable: true,
                                  children: [
                                    for (final suspect in suspects)
                                      _InvestigationCard(
                                        title: suspect.name,
                                        subtitle:
                                            '${suspect.age} ans · ${suspect.profession}',
                                        isMarked: markedSuspectIds.contains(
                                          suspect.id,
                                        ),
                                        accentColor: const Color(0xFFAD7A34),
                                        onTap: () =>
                                            onToggleSuspect(suspect.id),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: _InvestigationPanel(
                                  title: 'Mobiles',
                                  subtitle:
                                      '$motiveRemaining encore plausibles · ${markedMotiveIds.length} écarté${markedMotiveIds.length > 1 ? 's' : ''}',
                                  accentColor: const Color(0xFF925C3C),
                                  scrollable: true,
                                  children: [
                                    for (final motive in motives)
                                      _InvestigationCard(
                                        title: motive.name,
                                        subtitle:
                                            '${motive.preparations} · ${motive.violence}',
                                        isMarked: markedMotiveIds.contains(
                                          motive.id,
                                        ),
                                        accentColor: const Color(0xFFB47249),
                                        onTap: () => onToggleMotive(motive.id),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _InvestigationPanel(
                                  title: 'Suspects',
                                  subtitle:
                                      '$suspectRemaining à surveiller · ${markedSuspectIds.length} écarté${markedSuspectIds.length > 1 ? 's' : ''}',
                                  accentColor: const Color(0xFF8A6230),
                                  children: [
                                    for (final suspect in suspects)
                                      _InvestigationCard(
                                        title: suspect.name,
                                        subtitle:
                                            '${suspect.age} ans · ${suspect.profession}',
                                        isMarked: markedSuspectIds.contains(
                                          suspect.id,
                                        ),
                                        accentColor: const Color(0xFFAD7A34),
                                        onTap: () =>
                                            onToggleSuspect(suspect.id),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _InvestigationPanel(
                                  title: 'Mobiles',
                                  subtitle:
                                      '$motiveRemaining encore plausibles · ${markedMotiveIds.length} écarté${markedMotiveIds.length > 1 ? 's' : ''}',
                                  accentColor: const Color(0xFF925C3C),
                                  children: [
                                    for (final motive in motives)
                                      _InvestigationCard(
                                        title: motive.name,
                                        subtitle:
                                            '${motive.preparations} · ${motive.violence}',
                                        isMarked: markedMotiveIds.contains(
                                          motive.id,
                                        ),
                                        accentColor: const Color(0xFFB47249),
                                        onTap: () => onToggleMotive(motive.id),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _ScreenHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.14),
            ),
          ),
          child: IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back,
              color: InvestigationScreen._titleInk,
            ),
            tooltip: 'Retour',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Enquête',
            style: TextStyle(
              color: InvestigationScreen._titleInk,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.25,
              shadows: _textShadows(0.28),
            ),
          ),
        ),
      ],
    );
  }
}

class _InvestigationPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool scrollable;
  final List<Widget> children;

  const _InvestigationPanel({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.scrollable = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: InvestigationScreen._panelTint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: accentColor.withOpacity(0.32),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: InvestigationScreen._titleInk,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                shadows: _textShadows(0.26),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: InvestigationScreen._mutedInkStrong.withOpacity(0.92),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              shadows: _textShadows(0.16),
            ),
          ),
          const SizedBox(height: 12),
          if (scrollable)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _InvestigationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isMarked;
  final Color accentColor;
  final VoidCallback onTap;

  const _InvestigationCard({
    required this.title,
    required this.subtitle,
    required this.isMarked,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isMarked
                  ? InvestigationScreen._dismissedTint
                  : InvestigationScreen._cardTint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isMarked
                    ? InvestigationScreen._dismissedBorder
                    : accentColor.withOpacity(0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isMarked ? 0.06 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMarked
                        ? const Color(0xFF8F4B3E).withOpacity(0.12)
                        : accentColor.withOpacity(0.12),
                    border: Border.all(
                      color: isMarked
                          ? const Color(0xFFD08D7E).withOpacity(0.72)
                          : accentColor.withOpacity(0.46),
                    ),
                  ),
                  child: Icon(
                    isMarked ? Icons.close_rounded : Icons.circle_outlined,
                    size: isMarked ? 18 : 14,
                    color: isMarked
                        ? const Color(0xFFF1C7BF)
                        : accentColor.withOpacity(0.84),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isMarked
                              ? InvestigationScreen._bodyInk.withOpacity(0.58)
                              : InvestigationScreen._titleInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.08,
                          decoration:
                              isMarked ? TextDecoration.lineThrough : null,
                          decorationColor: const Color(0xFFE6B9AE),
                          decorationThickness: 2.0,
                          shadows: _textShadows(isMarked ? 0.14 : 0.24),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isMarked
                              ? InvestigationScreen._mutedInk.withOpacity(0.62)
                              : InvestigationScreen._mutedInkStrong,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.12,
                          decoration:
                              isMarked ? TextDecoration.lineThrough : null,
                          decorationColor: const Color(0xFFE6B9AE),
                          shadows: _textShadows(isMarked ? 0.10 : 0.16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isMarked
                      ? Container(
                          key: const ValueKey('dismissed'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8F4B3E).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFD08D7E).withOpacity(0.42),
                            ),
                          ),
                          child: Text(
                            'Écarté',
                            style: TextStyle(
                              color: const Color(0xFFF0CEC5),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.18,
                              shadows: _textShadows(0.12),
                            ),
                          ),
                        )
                      : Container(
                          key: const ValueKey('active'),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withOpacity(0.56),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<Shadow> _textShadows(double opacity) {
  return [
    Shadow(
      color: Colors.black.withOpacity(opacity),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
}
