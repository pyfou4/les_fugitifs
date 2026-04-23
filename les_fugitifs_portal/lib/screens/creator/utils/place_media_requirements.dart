List<Map<String, dynamic>> computeMediaRequirementsFromSequence(
  List<Map<String, dynamic>> sequence,
) {
  final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];

  for (final dynamic rawStep in sequence) {
    if (rawStep is! Map) continue;

    final Map<String, dynamic> step =
        Map<String, dynamic>.from(rawStep as Map<dynamic, dynamic>);

    final String type = step['type']?.toString().trim() ?? 'popup';
    final String? requiredFormat = mediaFormatForStepType(type);

    if (requiredFormat == null) continue;

    final String stepId = step['id']?.toString().trim().isNotEmpty == true
        ? step['id'].toString().trim()
        : 'unknown_step';

    final String title = step['title']?.toString().trim().isNotEmpty == true
        ? step['title'].toString().trim()
        : _defaultTitleForStepType(type);

    results.add(<String, dynamic>{
      'stepId': stepId,
      'stepType': type,
      'requiredFormat': requiredFormat,
      'title': title,
    });
  }

  return results;
}

String? mediaFormatForStepType(String type) {
  switch (type.trim().toLowerCase()) {
    case 'call':
      return 'audio';
    case 'video':
      return 'video';
    case 'audio':
      return 'audio';
    case 'image':
      return 'image';
    case 'popup':
    default:
      return null;
  }
}

bool stepTypeRequiresMedia(String type) {
  return mediaFormatForStepType(type) != null;
}

String _defaultTitleForStepType(String type) {
  switch (type.trim().toLowerCase()) {
    case 'call':
      return 'Nouvel appel';
    case 'video':
      return 'Nouvelle vidéo';
    case 'audio':
      return 'Nouvel audio';
    case 'image':
      return 'Nouvelle image';
    case 'popup':
    default:
      return 'Nouvelle étape';
  }
}
