import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/firebase_media.dart';
import '../services/session_service.dart';
import 'activation_screen.dart';
import 'briefing_screen.dart';

class ScenariosScreen extends StatelessWidget {
  const ScenariosScreen({super.key});

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

          final portalSize = compact ? h * 0.49 : h * 0.49;
          final portalTop = compact ? h * 0.25 : h * 0.42;
          final left1 = w * 0.08;
          final left2 = w * 0.39;
          final left3 = w * 0.70;

          return Stack(
            children: [
              const _ScenariosBackground(),
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.18),
                ),
              ),
              Positioned(
                left: compact ? 16 : 24,
                top: compact ? 14 : 18,
                right: compact ? 16 : 24,
                child: _TopBanner(compact: compact),
              ),
              Positioned(
                right: compact ? 16 : 24,
                top: compact ? 16 : 20,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16,
                    vertical: compact ? 7 : 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.26),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.14),
                    ),
                  ),
                  child: Text(
                    'Portes temporelles',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: compact ? 12 : 14,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: left1,
                top: portalTop,
                width: portalSize,
                child: _ScenarioPortal(
                  compact: compact,
                  title: 'Les Fugitifs',
                  subtitle: 'Brèche stabilisée',
                  status: 'Disponible',
                  isLocked: false,
                  imagePath: 'assets/images/logo.png',
                  logoScale: 1.3,
                  portalDiameter: portalSize,
                  onTap: () => _openLesFugitifs(context),
                ),
              ),
              Positioned(
                left: left2,
                top: portalTop,
                width: portalSize,
                child: _ScenarioPortal(
                  compact: compact,
                  title: 'Les Illuvinatis',
                  subtitle: 'Connexion instable',
                  status: 'Bientôt disponible',
                  isLocked: true,
                  imagePath: 'assets/images/logo illuvinatis.png',
                  logoScale: 1.1,
                  portalDiameter: portalSize,
                ),
              ),
              Positioned(
                left: left3,
                top: portalTop,
                width: portalSize,
                child: _ScenarioPortal(
                  compact: compact,
                  title: 'In Tenebris',
                  subtitle: 'Accès restreint',
                  status: 'Bientôt disponible',
                  isLocked: true,
                  imagePath: 'assets/images/logo in tenebris.png',
                  logoScale: 1.15,
                  portalDiameter: portalSize,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBanner extends StatelessWidget {
  final bool compact;

  const _TopBanner({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/logo grid complet.png',
          height: compact ? 56 : 72,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return Container(
              width: compact ? 70 : 90,
              height: compact ? 56 : 72,
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
        SizedBox(width: compact ? 12 : 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: compact ? 2 : 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choisissez une destination narrative',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 26 : 34,
                    fontWeight: FontWeight.w800,
                    height: 1.02,
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  'HENIGMA Grid ouvre plusieurs brèches. Certaines sont stables. D’autres attendent encore leur heure.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.90),
                    fontSize: compact ? 14 : 16,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: compact ? 120 : 170),
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
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: portalDiameter,
          height: portalDiameter,
          child: _buildPortalCircle(),
        ),
        SizedBox(height: compact ? 8 : 10),
        Text(
          status,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isLocked ? Colors.white70 : const Color(0xFFFFD17A),
            fontSize: compact ? 12 : 14,
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
            fontSize: compact ? 11 : 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: compact ? 3 : 5),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 18 : 24,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ],
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
              width: compact ? 5 : 6,
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
                  width: compact ? 2 : 2.5,
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
  const _ScenariosBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CachedNetworkImage(
        imageUrl: FirebaseMedia.bgScenarios,
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