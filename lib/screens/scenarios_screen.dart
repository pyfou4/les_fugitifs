import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/session_service.dart';
import 'activation_screen.dart';
import 'briefing_screen.dart';

class ScenariosScreen extends StatelessWidget {
  const ScenariosScreen({super.key});

  static const String _backgroundUrl =
      'https://firebasestorage.googleapis.com/v0/b/les-fugitifs.firebasestorage.app/o/images%2Fbg_scenarios.png?alt=media&token=f0370aa2-3565-47ea-be5e-cc7dfec77882';

  Future<void> _openLesFugitifs(BuildContext context) async {
    final hasValidSession = await SessionService.isSessionValid();

    if (!context.mounted) return;

    if (hasValidSession) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const BriefingScreen(),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ActivationScreen(
          nextScreen: BriefingScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = h < 720;
          final isTablet = w >= 900;

          final horizontalPadding = compact ? 14.0 : 24.0;
          final topGap = compact ? 10.0 : 18.0;
          final headerGap = compact ? 12.0 : 18.0;
          final portalSpacing = compact ? 10.0 : 20.0;

          return Stack(
            children: [
              const _ScenariosBackground(imageUrl: _backgroundUrl),
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.18),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topGap,
                    horizontalPadding,
                    compact ? 12.0 : 20.0,
                  ),
                  child: Column(
                    children: [
                      _HeaderBar(
                        compact: compact,
                        badgeText: 'Portes temporelles',
                      ),
                      SizedBox(height: headerGap),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, portalConstraints) {
                            const labelBlockHeightPhone = 86.0;
                            const labelBlockHeightTablet = 96.0;
                            final labelBlockHeight =
                                compact ? labelBlockHeightPhone : labelBlockHeightTablet;

                            final availableWidth = portalConstraints.maxWidth;
                            final availableHeight = portalConstraints.maxHeight;

                            final widthBasedDiameter =
                                (availableWidth - (portalSpacing * 2)) / 3.0;
                            final heightBasedDiameter =
                                availableHeight - labelBlockHeight;

                            final minDiameter = compact ? 92.0 : 150.0;
                            final maxDiameter = compact ? 170.0 : 240.0;

                            final portalDiameter = math.max(
                              minDiameter,
                              math.min(
                                math.min(widthBasedDiameter, heightBasedDiameter),
                                maxDiameter,
                              ),
                            );

                            return Row(
                              crossAxisAlignment: isTablet
                                  ? CrossAxisAlignment.center
                                  : CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: isTablet
                                        ? Alignment.center
                                        : Alignment.bottomCenter,
                                    child: _ScenarioPortal(
                                      compact: compact,
                                      title: 'Les Fugitifs',
                                      subtitle: 'Brèche stabilisée',
                                      status: 'Disponible',
                                      isLocked: false,
                                      imagePath: 'assets/images/logo.png',
                                      logoScale: 1.3,
                                      portalDiameter: portalDiameter,
                                      onTap: () => _openLesFugitifs(context),
                                    ),
                                  ),
                                ),
                                SizedBox(width: portalSpacing),
                                Expanded(
                                  child: Align(
                                    alignment: isTablet
                                        ? Alignment.center
                                        : Alignment.bottomCenter,
                                    child: _ScenarioPortal(
                                      compact: compact,
                                      title: 'Les Illuvinatis',
                                      subtitle: 'Connexion instable',
                                      status: 'Bientôt disponible',
                                      isLocked: true,
                                      imagePath: 'assets/images/logo illuvinatis.png',
                                      logoScale: 1.1,
                                      portalDiameter: portalDiameter,
                                    ),
                                  ),
                                ),
                                SizedBox(width: portalSpacing),
                                Expanded(
                                  child: Align(
                                    alignment: isTablet
                                        ? Alignment.center
                                        : Alignment.bottomCenter,
                                    child: _ScenarioPortal(
                                      compact: compact,
                                      title: 'In Tenebris',
                                      subtitle: 'Accès restreint',
                                      status: 'Bientôt disponible',
                                      isLocked: true,
                                      imagePath: 'assets/images/logo in tenebris.png',
                                      logoScale: 1.15,
                                      portalDiameter: portalDiameter,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
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

class _HeaderBar extends StatelessWidget {
  final bool compact;
  final String badgeText;

  const _HeaderBar({
    required this.compact,
    required this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final logoHeight = compact ? 46.0 : 72.0;
    final titleSize = compact ? 24.0 : 34.0;
    final subtitleSize = compact ? 12.5 : 16.0;
    final badgeFontSize = compact ? 11.0 : 14.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/logo grid complet.png',
          height: logoHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return Container(
              width: compact ? 58 : 90,
              height: logoHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.28),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
              child: const Text(
                'HENIGMA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            );
          },
        ),
        SizedBox(width: compact ? 10 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choisissez une destination narrative',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              SizedBox(height: compact ? 4 : 8),
              Text(
                'HENIGMA Grid ouvre plusieurs brèches. Certaines sont stables. D’autres attendent encore leur heure.',
                maxLines: compact ? 2 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.90),
                  fontSize: subtitleSize,
                  height: 1.28,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: compact ? 10 : 16),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: compact ? 6 : 9,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.26),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.14),
            ),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              color: Colors.white70,
              fontSize: badgeFontSize,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScenarioPortal extends StatelessWidget {
  final bool compact;
  final String title;
  final String subtitle;
  final String status;
  final bool isLocked;
  final String? imagePath;
  final double logoScale;
  final VoidCallback? onTap;
  final double portalDiameter;

  const _ScenarioPortal({
    required this.compact,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isLocked,
    required this.portalDiameter,
    this.imagePath,
    this.logoScale = 1.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusSize = compact ? 11.0 : 14.0;
    final subtitleSize = compact ? 10.0 : 13.0;
    final titleSize = compact ? 14.0 : 24.0;

    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: portalDiameter + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: portalDiameter,
            height: portalDiameter,
            child: _buildPortalCircle(),
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            status,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isLocked ? Colors.white70 : const Color(0xFFFFD17A),
              fontSize: statusSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.86),
              fontSize: subtitleSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: compact ? 2 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );

    if (isLocked) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: content,
    );
  }

  Widget _buildPortalCircle() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: portalDiameter,
          height: portalDiameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFA63A).withOpacity(
                  isLocked ? 0.10 : 0.22,
                ),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        Container(
          width: portalDiameter,
          height: portalDiameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFD3AE68).withOpacity(
                isLocked ? 0.60 : 0.88,
              ),
              width: compact ? 4 : 6,
            ),
            gradient: RadialGradient(
              colors: [
                const Color(0xFF1F0828).withOpacity(0.95),
                const Color(0xFF100415).withOpacity(0.97),
                Colors.black.withOpacity(0.98),
              ],
              stops: const [0.15, 0.70, 1.0],
            ),
          ),
          child: Center(
            child: Container(
              width: portalDiameter * 0.86,
              height: portalDiameter * 0.86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFA84B).withOpacity(
                    isLocked ? 0.18 : 0.34,
                  ),
                  width: compact ? 1.8 : 2.5,
                ),
              ),
              child: ClipOval(
                child: _buildCenterContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCenterContent() {
    if (imagePath != null) {
      return Center(
        child: Opacity(
          opacity: isLocked ? 0.78 : 1.0,
          child: FractionallySizedBox(
            widthFactor: logoScale,
            heightFactor: logoScale,
            child: Image.asset(
              imagePath!,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) {
                return _buildLockedGlyph();
              },
            ),
          ),
        ),
      );
    }

    return _buildLockedGlyph();
  }

  Widget _buildLockedGlyph() {
    return Center(
      child: Container(
        width: portalDiameter * 0.34,
        height: portalDiameter * 0.34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.18),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
          ),
        ),
        child: Icon(
          Icons.lock_outline_rounded,
          color: Colors.white70,
          size: portalDiameter * 0.16,
        ),
      ),
    );
  }
}

class _ScenariosBackground extends StatelessWidget {
  final String imageUrl;

  const _ScenariosBackground({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        placeholder: (_, __) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1B0C08),
                Color(0xFF31160C),
                Color(0xFF0F0910),
              ],
            ),
          ),
        ),
        errorWidget: (_, __, ___) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B0C08),
                  Color(0xFF31160C),
                  Color(0xFF0F0910),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
