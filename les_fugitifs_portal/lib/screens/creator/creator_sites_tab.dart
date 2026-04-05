import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../features/site_readiness/site_readiness_models.dart';
import 'creator_site_header_section.dart';
import 'creator_site_places_grid_section.dart';
import 'creator_sites_toolbar_section.dart';

class CreatorSitesTab extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> templateDocs;
  final String? selectedSiteId;
  final bool isCreatingSite;
  final bool isValidatingReadiness;
  final SiteReadinessResult? currentReadinessResult;
  final Stream<QuerySnapshot<Map<String, dynamic>>> sitesStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(String siteId)
      sitePlacesStreamBuilder;
  final String Function(DocumentSnapshot<Map<String, dynamic>> doc)
      siteLabelBuilder;
  final Color Function(String id) groupColorBuilder;
  final ValueChanged<String> onSelectSite;
  final VoidCallback onCreateSite;
  final Future<void> Function(String siteId) onValidateReadiness;
  final Future<void> Function(String siteId) onFreezeSite;
  final Future<void> Function(String siteId) onUnfreezeSite;
  final Future<void> Function({
    required String siteId,
    required String placeId,
    required Map<String, dynamic> templateData,
    required String latText,
    required String lngText,
  }) onSaveSitePlaceCoordinates;

  const CreatorSitesTab({
    super.key,
    required this.templateDocs,
    required this.selectedSiteId,
    required this.isCreatingSite,
    required this.isValidatingReadiness,
    required this.currentReadinessResult,
    required this.sitesStream,
    required this.sitePlacesStreamBuilder,
    required this.siteLabelBuilder,
    required this.groupColorBuilder,
    required this.onSelectSite,
    required this.onCreateSite,
    required this.onValidateReadiness,
    required this.onFreezeSite,
    required this.onUnfreezeSite,
    required this.onSaveSitePlaceCoordinates,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: sitesStream,
      builder: (context, sitesSnapshot) {
        if (sitesSnapshot.connectionState == ConnectionState.waiting &&
            !sitesSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (sitesSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur Firestore (sites) : ${sitesSnapshot.error}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 18,
                ),
              ),
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> siteDocs =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          sitesSnapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        )..sort(
                (a, b) => siteLabelBuilder(a)
                    .toLowerCase()
                    .compareTo(siteLabelBuilder(b).toLowerCase()),
              );

        final effectiveSelectedSiteId = _resolveSelectedSiteId(siteDocs);

        return Container(
          color: const Color(0xFF07111F),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sites et coordonnées',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Section séparée du créateur de lieux. Ici, on gère uniquement les implantations terrain par site.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFFAAB7C8),
                  ),
                ),
                const SizedBox(height: 18),
                CreatorSitesToolbarSection(
                  siteDocs: siteDocs,
                  selectedSiteId: effectiveSelectedSiteId,
                  isCreatingSite: isCreatingSite,
                  templateCount: templateDocs.length,
                  siteLabelBuilder: siteLabelBuilder,
                  onSelectSite: onSelectSite,
                  onCreateSite: onCreateSite,
                ),
                const SizedBox(height: 16),
                if (siteDocs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101C31),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF223250)),
                    ),
                    child: const Text(
                      'Aucun site n’existe encore. Crée un premier site pour initialiser automatiquement sa collection places.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: Color(0xFFAAB7C8),
                      ),
                    ),
                  )
                else if (effectiveSelectedSiteId == null)
                  const Center(child: CircularProgressIndicator())
                else
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: sitePlacesStreamBuilder(effectiveSelectedSiteId),
                    builder: (context, sitePlacesSnapshot) {
                      if (sitePlacesSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !sitePlacesSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (sitePlacesSnapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Erreur Firestore (places du site) : ${sitePlacesSnapshot.error}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 18,
                            ),
                          ),
                        );
                      }

                      final selectedSiteDoc = siteDocs.firstWhere(
                        (doc) => doc.id == effectiveSelectedSiteId,
                      );
                      final selectedSiteData =
                          selectedSiteDoc.data() ?? <String, dynamic>{};
                      final isFrozen =
                          (selectedSiteData['coordinatesFrozen'] ?? false) ==
                              true;
                      final selectedSiteLabel = siteLabelBuilder(selectedSiteDoc);
                      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                          sitePlacesDocs =
                          sitePlacesSnapshot.data?.docs ??
                              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      final sitePlacesById = <String, Map<String, dynamic>>{
                        for (final doc in sitePlacesDocs) doc.id: doc.data(),
                      };

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CreatorSiteHeaderSection(
                            selectedSiteDoc: selectedSiteDoc,
                            selectedSiteLabel: selectedSiteLabel,
                            currentCount: sitePlacesById.length,
                            templateCount: templateDocs.length,
                            isFrozen: isFrozen,
                            readinessResult: currentReadinessResult,
                            isValidatingReadiness: isValidatingReadiness,
                            onValidateReadiness: () async {
                              await onValidateReadiness(effectiveSelectedSiteId);
                            },
                            onFreeze: isFrozen
                                ? null
                                : () async {
                                    await onFreezeSite(effectiveSelectedSiteId);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Coordonnées gelées pour ce site.',
                                        ),
                                      ),
                                    );
                                  },
                            onUnfreeze: !isFrozen
                                ? null
                                : () async {
                                    await onUnfreezeSite(effectiveSelectedSiteId);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Coordonnées dégelées pour ce site.',
                                        ),
                                      ),
                                    );
                                  },
                          ),
                          const SizedBox(height: 14),
                          CreatorSitePlacesGridSection(
                            siteId: effectiveSelectedSiteId,
                            templateDocs: templateDocs,
                            sitePlacesById: sitePlacesById,
                            isFrozen: isFrozen,
                            groupColorBuilder: groupColorBuilder,
                            onSaveSitePlaceCoordinates:
                                ({required placeId,
                                required templateData,
                                required latText,
                                required lngText}) async {
                              await onSaveSitePlaceCoordinates(
                                siteId: effectiveSelectedSiteId,
                                placeId: placeId,
                                templateData: templateData,
                                latText: latText,
                                lngText: lngText,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Coordonnées sauvegardées pour $placeId.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _resolveSelectedSiteId(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> siteDocs,
  ) {
    if (siteDocs.isEmpty) return null;

    if (selectedSiteId != null &&
        siteDocs.any((doc) => doc.id == selectedSiteId)) {
      return selectedSiteId;
    }

    return siteDocs.first.id;
  }
}
