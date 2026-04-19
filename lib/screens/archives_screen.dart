import 'package:flutter/material.dart';

import '../models/place_node.dart';

class ArchivesScreen extends StatelessWidget {
  final VoidCallback onBack;
  final List<PlaceNode> places;
  final ValueChanged<PlaceNode> onOpenPlaceMedia;

  const ArchivesScreen({
    super.key,
    required this.onBack,
    required this.places,
    required this.onOpenPlaceMedia,
  });

  static const String _backgroundImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/les-fugitifs.firebasestorage.app/o/images%2Fbg_archives.png?alt=media&token=10e907d0-a2d1-4740-8868-3643ced7f800';

  @override
  Widget build(BuildContext context) {
    final visitedPlaces = places.where((p) => p.isVisited).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 700;
    final crossAxisCount = isTablet ? 2 : 1;
    final horizontalPadding = isTablet ? 32.0 : 20.0;
    final topPadding = isTablet ? 24.0 : 16.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF120B08),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xFFF4E6D0),
          onPressed: onBack,
        ),
        title: const Text(
          'Archives',
          style: TextStyle(
            color: Color(0xFFF4E6D0),
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _backgroundImageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A120E), Color(0xFF0E0907)],
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A120E), Color(0xFF0E0907)],
                  ),
                ),
              );
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(7, 4, 3, 0.58),
                  Color.fromRGBO(10, 6, 5, 0.42),
                  Color.fromRGBO(5, 3, 2, 0.68),
                ],
              ),
            ),
          ),
          SafeArea(
            child: visitedPlaces.isEmpty
                ? _EmptyArchivesState(horizontalPadding: horizontalPadding)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          topPadding,
                          horizontalPadding,
                          12,
                        ),
                        child: _ArchivesHeader(
                          count: visitedPlaces.length,
                          isTablet: isTablet,
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            4,
                            horizontalPadding,
                            isTablet ? 32 : 24,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: isTablet ? 20 : 0,
                            mainAxisSpacing: 16,
                            childAspectRatio: isTablet ? 1.55 : 1.75,
                          ),
                          itemCount: visitedPlaces.length,
                          itemBuilder: (_, i) {
                            final place = visitedPlaces[i];
                            return _ArchiveCard(
                              place: place,
                              isTablet: isTablet,
                              onTap: () => onOpenPlaceMedia(place),
                              accentColor: _accentColorForIndex(i),
                              sectionLabel: _sectionLabelForIndex(i),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static Color _accentColorForIndex(int index) {
    const accents = [
      Color(0xFFCF9F5B),
      Color(0xFF7A6BC2),
      Color(0xFF7FAD8B),
      Color(0xFFC47B53),
    ];
    return accents[index % accents.length];
  }

  static String _sectionLabelForIndex(int index) {
    if (index == 0) return 'Dossier principal';
    if (index == 1) return 'Archive recoupée';
    return 'Pièce consultable';
  }
}

class _ArchivesHeader extends StatelessWidget {
  final int count;
  final bool isTablet;

  const _ArchivesHeader({
    required this.count,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final label = count > 1 ? 'lieux consultables' : 'lieu consultable';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(20, 12, 9, 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color.fromRGBO(207, 159, 91, 0.35),
            ),
          ),
          child: Text(
            '$count $label',
            style: TextStyle(
              color: const Color(0xFFE7D6B8),
              fontSize: isTablet ? 14 : 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Les archives regroupent les lieux déjà explorés par votre unité.',
          style: TextStyle(
            color: const Color(0xFFF2E6D4),
            fontSize: isTablet ? 16 : 14,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  final PlaceNode place;
  final bool isTablet;
  final VoidCallback onTap;
  final Color accentColor;
  final String sectionLabel;

  const _ArchiveCard({
    required this.place,
    required this.isTablet,
    required this.onTap,
    required this.accentColor,
    required this.sectionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromRGBO(39, 24, 18, 0.88),
                Color.fromRGBO(20, 12, 9, 0.94),
              ],
            ),
            border: Border.all(
              color: const Color.fromRGBO(236, 205, 158, 0.18),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.28),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -18,
                right: -10,
                child: Icon(
                  Icons.settings,
                  size: isTablet ? 78 : 64,
                  color: const Color.fromRGBO(255, 255, 255, 0.04),
                ),
              ),
              Positioned(
                left: 0,
                top: 20,
                bottom: 20,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.22),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 24 : 22,
                  isTablet ? 22 : 20,
                  isTablet ? 22 : 20,
                  isTablet ? 20 : 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accentColor.withOpacity(0.34),
                            ),
                          ),
                          child: Text(
                            sectionLabel,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: isTablet ? 12 : 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.visibility_outlined,
                          color: Color(0xFFE7D6B8),
                          size: 18,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      place.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFF7EBDD),
                        fontSize: isTablet ? 24 : 22,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: accentColor,
                          size: isTablet ? 18 : 17,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lieu déjà visité. Touchez pour consulter les éléments archivés.',
                            style: TextStyle(
                              color: const Color(0xFFD8C8B2),
                              fontSize: isTablet ? 14 : 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyArchivesState extends StatelessWidget {
  final double horizontalPadding;

  const _EmptyArchivesState({required this.horizontalPadding});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(20, 12, 9, 0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color.fromRGBO(236, 205, 158, 0.18),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.24),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.folder_open_rounded,
                size: 46,
                color: Color(0xFFCF9F5B),
              ),
              SizedBox(height: 16),
              Text(
                'Aucune archive disponible',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF4E6D0),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Les lieux explorés apparaîtront ici dès que votre unité commencera à constituer ses dossiers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD9C8B3),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
