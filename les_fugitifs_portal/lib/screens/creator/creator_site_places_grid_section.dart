import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'creator_site_place_editor_card.dart';

class CreatorSitePlacesGridSection extends StatelessWidget {
  final String siteId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> templateDocs;
  final Map<String, Map<String, dynamic>> sitePlacesById;
  final bool isFrozen;
  final Color Function(String id) groupColorBuilder;
  final Future<void> Function({
    required String placeId,
    required Map<String, dynamic> templateData,
    required String latText,
    required String lngText,
  }) onSaveSitePlaceCoordinates;

  const CreatorSitePlacesGridSection({
    super.key,
    required this.siteId,
    required this.templateDocs,
    required this.sitePlacesById,
    required this.isFrozen,
    required this.groupColorBuilder,
    required this.onSaveSitePlaceCoordinates,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: templateDocs.map((templateDoc) {
        final templateData = templateDoc.data();
        final sitePlaceData = sitePlacesById[templateDoc.id] ?? <String, dynamic>{};

        return CreatorSitePlaceEditorCard(
          key: ValueKey(
            'site:$siteId|place:${templateDoc.id}|lat:${sitePlaceData['lat']}|lng:${sitePlaceData['lng']}|frozen:$isFrozen',
          ),
          placeId: templateDoc.id,
          title: (templateData['title'] ?? templateData['name'] ?? templateDoc.id)
              .toString()
              .trim(),
          color: groupColorBuilder(templateDoc.id),
          latValue: sitePlaceData['lat'],
          lngValue: sitePlaceData['lng'],
          isFrozen: isFrozen,
          onSave: (latText, lngText) => onSaveSitePlaceCoordinates(
            placeId: templateDoc.id,
            templateData: templateData,
            latText: latText,
            lngText: lngText,
          ),
        );
      }).toList(),
    );
  }
}
