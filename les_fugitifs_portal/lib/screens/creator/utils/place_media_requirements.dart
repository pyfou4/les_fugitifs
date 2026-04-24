List<Map<String, dynamic>> computeMediaRequirementsFromSequence(
  List<Map<String, dynamic>> sequence, {
  String? blockId,
}) {
  final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];

  for (int index = 0; index < sequence.length; index += 1) {
    final dynamic rawStep = sequence[index];
    if (rawStep is! Map) continue;

    final Map<String, dynamic> step =
        Map<String, dynamic>.from(rawStep as Map<dynamic, dynamic>);

    final String stepId = step['id']?.toString().trim().isNotEmpty == true
        ? step['id'].toString().trim()
        : 'unknown_step';
    final String type = step['type']?.toString().trim().toLowerCase() ?? 'popup';
    final String title = step['title']?.toString().trim().isNotEmpty == true
        ? step['title'].toString().trim()
        : _defaultTitleForStepType(type);

    final List<Map<String, dynamic>> usageRequirements =
        _requirementsFromMediaUsages(
      step: step,
      stepId: stepId,
      stepType: type,
      title: title,
      displayOrderBase: index + 1,
      blockId: blockId,
    );

    if (usageRequirements.isNotEmpty) {
      results.addAll(usageRequirements);
      continue;
    }

    final String? requiredFormat = mediaFormatForStepType(type);
    if (requiredFormat == null) continue;

    results.add(<String, dynamic>{
      'stepId': stepId,
      'stepType': type,
      'requiredFormat': requiredFormat,
      'acceptedTypes': acceptedTypesForMediaFormat(requiredFormat),
      'title': title,
      'displayOrder': index + 1,
      if ((blockId ?? '').trim().isNotEmpty) 'blockId': blockId!.trim(),
      'slotKey': mediaSlotKeyForStep(step),
    });
  }

  return results;
}

List<Map<String, dynamic>> _requirementsFromMediaUsages({
  required Map<String, dynamic> step,
  required String stepId,
  required String stepType,
  required String title,
  required int displayOrderBase,
  required String? blockId,
}) {
  final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
  final List<dynamic> rawMediaUsages =
      (step['mediaUsages'] as List<dynamic>? ?? const <dynamic>[]);

  for (int usageIndex = 0; usageIndex < rawMediaUsages.length; usageIndex += 1) {
    final dynamic rawUsage = rawMediaUsages[usageIndex];
    if (rawUsage is! Map) continue;

    final Map<String, dynamic> usage =
        Map<String, dynamic>.from(rawUsage as Map<dynamic, dynamic>);

    final String slotKey = usage['slotKey']?.toString().trim() ?? '';
    if (slotKey.isEmpty) continue;

    final String? requiredFormat = mediaFormatForUsage(
      usage,
      fallbackStepType: stepType,
    );
    if (requiredFormat == null) continue;

    final String role = usage['role']?.toString().trim().toLowerCase() ?? 'primary';

    results.add(<String, dynamic>{
      'stepId': stepId,
      'stepType': stepType,
      'requiredFormat': requiredFormat,
      'acceptedTypes': acceptedTypesForMediaFormat(requiredFormat),
      'title': _decorateTitleWithRole(title, role, usageIndex),
      'displayOrder': displayOrderBase * 100 + usageIndex,
      if ((blockId ?? '').trim().isNotEmpty) 'blockId': blockId!.trim(),
      'slotKey': slotKey,
      'role': role,
    });
  }

  return results;
}

String? mediaFormatForUsage(
  Map<String, dynamic> usage, {
  required String fallbackStepType,
}) {
  final String runtimeMode =
      usage['runtimeMode']?.toString().trim().toLowerCase() ?? '';

  switch (runtimeMode) {
    case 'standard_video':
      return 'video';
    case 'standard_audio':
      return 'audio';
    case 'standard_image':
    case 'dynamic_pan_zoom':
    case 'masked_view':
      return 'image';
  }

  final String slotKey = usage['slotKey']?.toString().trim().toLowerCase() ?? '';
  if (slotKey.endsWith('_video') || slotKey.contains('video')) return 'video';
  if (slotKey.endsWith('_audio') || slotKey.contains('audio')) return 'audio';
  if (slotKey.endsWith('_image') || slotKey.contains('image')) return 'image';
  if (slotKey.endsWith('_call') || slotKey.contains('call')) return 'audio';

  return mediaFormatForStepType(fallbackStepType);
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
    case 'physical':
      return 'image';
    case 'popup':
    default:
      return null;
  }
}

List<String> acceptedTypesForStepType(String type) {
  final String? format = mediaFormatForStepType(type);
  if (format == null) return const <String>[];
  return acceptedTypesForMediaFormat(format);
}

List<String> acceptedTypesForMediaFormat(String format) {
  switch (format.trim().toLowerCase()) {
    case 'video':
      return const <String>['video'];
    case 'audio':
      return const <String>['audio', 'video'];
    case 'image':
      return const <String>['image'];
    default:
      return const <String>[];
  }
}

String mediaSlotKeyForStep(Map<String, dynamic> step) {
  final List<dynamic> mediaUsages =
      (step['mediaUsages'] as List<dynamic>? ?? const <dynamic>[]);

  for (final dynamic rawUsage in mediaUsages) {
    if (rawUsage is! Map) continue;
    final usage = Map<String, dynamic>.from(rawUsage as Map<dynamic, dynamic>);
    final slotKey = usage['slotKey']?.toString().trim() ?? '';
    if (slotKey.isNotEmpty) {
      return slotKey;
    }
  }

  final String stepId = step['id']?.toString().trim().isNotEmpty == true
      ? step['id'].toString().trim()
      : 'unknown_step';
  final String type = step['type']?.toString().trim().toLowerCase() ?? 'popup';

  switch (type) {
    case 'call':
      return '${stepId}_primary_call';
    case 'video':
      return '${stepId}_primary_video';
    case 'audio':
      return '${stepId}_primary_audio';
    case 'image':
      return '${stepId}_primary_image';
    case 'popup':
    default:
      return '${stepId}_media';
  }
}

bool stepTypeRequiresMedia(String type) {
  return mediaFormatForStepType(type) != null;
}

String _decorateTitleWithRole(String title, String role, int usageIndex) {
  if (usageIndex == 0 && (role.isEmpty || role == 'primary')) {
    return title;
  }

  switch (role) {
    case 'secondary':
      return '$title · Média secondaire';
    case 'clue':
      return '$title · Indice';
    case 'support':
      return '$title · Support';
    case 'background':
      return '$title · Ambiance';
    case 'primary':
      return '$title · Média ${usageIndex + 1}';
    default:
      return '$title · ${_capitalize(role)}';
  }
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

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
