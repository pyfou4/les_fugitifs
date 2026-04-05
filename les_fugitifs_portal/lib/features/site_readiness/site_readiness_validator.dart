import 'site_readiness_models.dart';

class SiteReadinessValidator {
  const SiteReadinessValidator();

  SiteReadinessResult validate({
    required String siteId,
    required Map<String, dynamic>? siteData,
    required Map<String, Map<String, dynamic>> templateDocsById,
    required Map<String, Map<String, dynamic>> sitePlacesById,
  }) {
    final issues = <SiteReadinessIssue>[];

    final templateIds = templateDocsById.keys.toSet();
    final sitePlaceIds = sitePlacesById.keys.toSet();

    if (siteData == null || siteData.isEmpty) {
      issues.add(
        SiteReadinessIssue(
          severity: SiteReadinessSeverity.error,
          code: 'site_missing',
          message: 'Le document du site est introuvable.',
          siteId: siteId,
        ),
      );
    }

    if (templateDocsById.length != 19) {
      issues.add(
        SiteReadinessIssue(
          severity: SiteReadinessSeverity.warning,
          code: 'template_count_unexpected',
          message:
              'Le scénario contient ${templateDocsById.length} lieux modèles au lieu de 19.',
          siteId: siteId,
        ),
      );
    }

    if (sitePlacesById.length != templateDocsById.length) {
      issues.add(
        SiteReadinessIssue(
          severity: SiteReadinessSeverity.error,
          code: 'site_places_count_mismatch',
          message:
              'Le site contient ${sitePlacesById.length} fiches places pour ${templateDocsById.length} lieux modèles.',
          siteId: siteId,
        ),
      );
    }

    for (final templateId in templateIds) {
      if (!sitePlaceIds.contains(templateId)) {
        issues.add(
          SiteReadinessIssue(
            severity: SiteReadinessSeverity.error,
            code: 'site_place_missing',
            message: 'La fiche place $templateId est absente pour ce site.',
            siteId: siteId,
            placeId: templateId,
          ),
        );
        continue;
      }

      final templateData = templateDocsById[templateId] ?? <String, dynamic>{};
      final sitePlaceData = sitePlacesById[templateId] ?? <String, dynamic>{};

      final placeTitle =
          (templateData['title'] ?? templateData['name'] ?? templateId).toString().trim();

      final lat = _toDouble(sitePlaceData['lat']);
      final lng = _toDouble(sitePlaceData['lng']);

      if (lat == null) {
        issues.add(
          SiteReadinessIssue(
            severity: SiteReadinessSeverity.error,
            code: 'lat_missing',
            message: 'Latitude manquante pour $placeTitle.',
            siteId: siteId,
            placeId: templateId,
            field: 'lat',
          ),
        );
      }

      if (lng == null) {
        issues.add(
          SiteReadinessIssue(
            severity: SiteReadinessSeverity.error,
            code: 'lng_missing',
            message: 'Longitude manquante pour $placeTitle.',
            siteId: siteId,
            placeId: templateId,
            field: 'lng',
          ),
        );
      }

      if (lat != null && (lat < -90 || lat > 90)) {
        issues.add(
          SiteReadinessIssue(
            severity: SiteReadinessSeverity.error,
            code: 'lat_out_of_range',
            message: 'Latitude hors plage pour $placeTitle.',
            siteId: siteId,
            placeId: templateId,
            field: 'lat',
          ),
        );
      }

      if (lng != null && (lng < -180 || lng > 180)) {
        issues.add(
          SiteReadinessIssue(
            severity: SiteReadinessSeverity.error,
            code: 'lng_out_of_range',
            message: 'Longitude hors plage pour $placeTitle.',
            siteId: siteId,
            placeId: templateId,
            field: 'lng',
          ),
        );
      }

      if (lat != null && lng != null && lat == 0 && lng == 0) {
        issues.add(
          SiteReadinessIssue(
            severity: SiteReadinessSeverity.error,
            code: 'coordinates_zero_zero',
            message: 'Coordonnées 0,0 pour $placeTitle.',
            siteId: siteId,
            placeId: templateId,
          ),
        );
      }
    }

    final extraIds = sitePlaceIds.difference(templateIds).toList()..sort();
    for (final extraId in extraIds) {
      issues.add(
        SiteReadinessIssue(
          severity: SiteReadinessSeverity.warning,
          code: 'extra_site_place',
          message: 'Le site contient une fiche place supplémentaire: $extraId.',
          siteId: siteId,
          placeId: extraId,
        ),
      );
    }

    final isFrozen = (siteData?['coordinatesFrozen'] ?? false) == true;
    if (!isFrozen) {
      issues.add(
        SiteReadinessIssue(
          severity: SiteReadinessSeverity.warning,
          code: 'site_not_frozen',
          message:
              'Les coordonnées du site ne sont pas gelées. Le site peut encore être modifié.',
          siteId: siteId,
        ),
      );
    }

    return SiteReadinessResult(
      siteId: siteId,
      isReady: !issues.any((issue) => issue.severity == SiteReadinessSeverity.error),
      templateCount: templateDocsById.length,
      configuredPlacesCount: sitePlacesById.length,
      issues: issues,
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
}
