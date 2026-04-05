enum SiteReadinessSeverity {
  error,
  warning,
}

class SiteReadinessIssue {
  final SiteReadinessSeverity severity;
  final String code;
  final String message;
  final String? siteId;
  final String? placeId;
  final String? field;

  const SiteReadinessIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.siteId,
    this.placeId,
    this.field,
  });
}

class SiteReadinessResult {
  final String siteId;
  final bool isReady;
  final int templateCount;
  final int configuredPlacesCount;
  final List<SiteReadinessIssue> issues;

  const SiteReadinessResult({
    required this.siteId,
    required this.isReady,
    required this.templateCount,
    required this.configuredPlacesCount,
    required this.issues,
  });

  List<SiteReadinessIssue> get errors =>
      issues.where((issue) => issue.severity == SiteReadinessSeverity.error).toList();

  List<SiteReadinessIssue> get warnings =>
      issues.where((issue) => issue.severity == SiteReadinessSeverity.warning).toList();
}
