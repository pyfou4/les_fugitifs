import 'dart:math';

const List<String> kAllowedSequenceStepTypes = <String>[
  'popup',
  'call',
  'video',
  'audio',
  'image',
  'observation',
  'physical',
];

const List<String> kAllowedStepStartModes = <String>[
  'after_previous',
  'parallel',
  'after_delay',
];

const List<String> kAllowedStepCloseModes = <String>[
  'manual',
  'auto',
];

const List<String> kAllowedStepCloseGates = <String>[
  'none',
  'until_step',
];

const List<String> kAllowedMediaRuntimeModes = <String>[
  'standard_image',
  'standard_video',
  'standard_audio',
  'dynamic_pan_zoom',
  'masked_view',
];

const List<String> kAllowedArchiveModes = <String>[
  'none',
  'standard_media',
  'zoomable_image',
  'preserve_runtime',
];

List<String> allowedSequenceStepTypes() =>
    List<String>.from(kAllowedSequenceStepTypes);

const List<String> kMediaSequenceStepTypes = <String>[
  'popup',
  'call',
  'video',
  'audio',
  'image',
];

/// Valeur canonique interne pour les types de postes.
///
/// L'UI peut afficher du français, et d'anciennes données peuvent encore contenir
/// des variantes comme "physique". À partir d'ici, le code métier travaille
/// uniquement avec : media, observation, physical.
String normalizePlaceKind(String raw) {
  final value = raw.trim().toLowerCase();
  if (value == 'observation' || value.contains('observation')) {
    return 'observation';
  }
  if (value == 'physical' ||
      value == 'physique' ||
      value.contains('physical') ||
      value.contains('physique') ||
      value.contains('phys')) {
    return 'physical';
  }
  return 'media';
}

/// Valeur canonique interne pour les types d'étapes.
///
/// Tous les nouveaux enregistrements doivent écrire ces valeurs canoniques.
/// Les variantes françaises ne sont acceptées qu'en lecture, pour compatibilité.
String normalizeSequenceStepType(String raw) {
  final value = raw.trim().toLowerCase();
  if (value == 'appel') return 'call';
  if (value == 'vidéo' || value == 'video') return 'video';
  if (value == 'image') return 'image';
  if (value == 'audio') return 'audio';
  if (value == 'observation' || value.contains('observation')) {
    return 'observation';
  }
  if (value == 'physical' ||
      value == 'physique' ||
      value.contains('physical') ||
      value.contains('physique') ||
      value.contains('phys')) {
    return 'physical';
  }
  if (value == 'popup') return 'popup';
  return 'popup';
}

List<String> allowedSequenceStepTypesForPlaceKind(String placeKind) {
  final normalized = normalizePlaceKind(placeKind);
  if (normalized == 'observation') {
    return <String>[...kMediaSequenceStepTypes, 'observation'];
  }
  if (normalized == 'physical') {
    return <String>[...kMediaSequenceStepTypes, 'physical'];
  }
  return List<String>.from(kMediaSequenceStepTypes);
}

String inferPlaceKindFromSequence(List<Map<String, dynamic>> sequence) {
  final hasPhysical = sequence.any(
    (step) => normalizeSequenceStepType((step['type'] ?? '').toString()) == 'physical',
  );
  if (hasPhysical) return 'physical';

  final hasObservation = sequence.any(
    (step) => normalizeSequenceStepType((step['type'] ?? '').toString()) == 'observation',
  );
  if (hasObservation) return 'observation';

  return 'media';
}

Map<String, dynamic> buildDefaultSequenceStepForPlaceKind(String placeKind) {
  final allowedTypes = allowedSequenceStepTypesForPlaceKind(normalizePlaceKind(placeKind));
  return buildSequenceStepForType(allowedTypes.first);
}

List<String> allowedStepStartModes() =>
    List<String>.from(kAllowedStepStartModes);

List<String> allowedStepCloseModes() =>
    List<String>.from(kAllowedStepCloseModes);

List<String> allowedStepCloseGates() =>
    List<String>.from(kAllowedStepCloseGates);

List<String> allowedMediaRuntimeModes() =>
    List<String>.from(kAllowedMediaRuntimeModes);

List<String> allowedArchiveModes() => List<String>.from(kAllowedArchiveModes);

Map<String, dynamic> buildDefaultTrigger() {
  return <String, dynamic>{
    'type': 'manual_start',
    'delayMs': 0,
    'retryPolicy': 'none',
    'params': <String, dynamic>{
      'startLabel': 'Commencer',
    },
  };
}

String buildStableStepId() {
  final random = Random();
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = random.nextInt(1 << 20).toRadixString(36);
  return 'step_${now}_$salt';
}

Map<String, dynamic> buildDefaultStepRuntime() {
  return <String, dynamic>{
    'startMode': 'after_previous',
    'referenceStepId': null,
    'delayMs': 0,
    'closeMode': 'manual',
    'closeGate': 'none',
    'closeBlockedUntilStepId': null,
  };
}

Map<String, dynamic> buildDefaultSequenceStep() {
  return buildSequenceStepForType('popup');
}

Map<String, dynamic> buildSequenceStepForType(
  String type, {
  String? id,
  String? title,
  String? description,
  Map<String, dynamic>? runtime,
}) {
  final safeId =
      (id == null || id.trim().isEmpty) ? buildStableStepId() : id.trim();
  final safeDescription = description ?? '';
  final normalizedType = normalizeSequenceStepType(type);

  Map<String, dynamic> base;
  switch (normalizedType) {
    case 'popup':
      base = <String, dynamic>{
        'id': safeId,
        'type': 'popup',
        'title': title ?? 'Nouveau popup',
        'description': safeDescription,
        'blocking': true,
        'params': <String, dynamic>{
          'text': '',
          'confirmLabel': "D'accord",
        },
      };
      break;
    case 'call':
      base = <String, dynamic>{
        'id': safeId,
        'type': 'call',
        'title': title ?? 'Nouvel appel',
        'description': safeDescription,
        'blocking': true,
        'params': <String, dynamic>{
          'callerLabel': '',
        },
      };
      break;
    case 'video':
      base = <String, dynamic>{
        'id': safeId,
        'type': 'video',
        'title': title ?? 'Nouvelle vidéo',
        'description': safeDescription,
        'blocking': true,
        'params': <String, dynamic>{},
      };
      break;
    case 'audio':
      base = <String, dynamic>{
        'id': safeId,
        'type': 'audio',
        'title': title ?? 'Nouvel audio',
        'description': safeDescription,
        'blocking': true,
        'params': <String, dynamic>{},
      };
      break;
    case 'image':
      base = <String, dynamic>{
        'id': safeId,
        'type': 'image',
        'title': title ?? 'Nouvelle image',
        'description': safeDescription,
        'blocking': true,
        'params': <String, dynamic>{
          'displayMode': 'standard',
        },
      };
      break;
    case 'observation':
      base = <String, dynamic>{
        'id': safeId,
        'type': 'observation',
        'title': title ?? 'Nouvelle observation',
        'description': safeDescription,
        'blocking': true,
        'params': <String, dynamic>{
          'question': '',
          'answerType': 'text',
          'expectedAnswer': <String, dynamic>{
            'value': '',
          },
        },
      };
      break;
    case 'physical':
      base = <String, dynamic>{
        'id': safeId,
        'type': 'physical',
        'title': title ?? 'Nouvelle épreuve physique',
        'description': safeDescription,
        'blocking': true,
        'params': <String, dynamic>{
          'instruction': '',
          'equipment': '',
          'validationMode': 'success',
          'successCondition': '',
          'failureText': '',
          'targetRepetitions': 3,
          'timeLimitSeconds': 60,
          'targetScore': 1,
          'maxScore': 10,
          'targetTimeSeconds': 60,
          'performanceBenchmark': <String, dynamic>{
            'strongMin': 10,
            'mediumMin': 7,
            'mediumMax': 9,
            'weakMax': 6,
          },
          'requiresRulesImage': true,
          'requiredImagePurpose': 'physical_rules',
        },
      };
      break;
    default:
      return buildSequenceStepForType(
        'popup',
        id: safeId,
        title: title,
        description: description,
        runtime: runtime,
      );
  }

  final normalizedRuntime = normalizeStepRuntime(runtime);
  final params = Map<String, dynamic>.from(base['params'] as Map);
  base['runtime'] = normalizedRuntime;
  base['mediaUsages'] = buildDefaultMediaUsagesForStepType(
    base['type'].toString(),
    stepId: safeId,
    params: params,
  );
  return base;
}

Map<String, dynamic> normalizeStepRuntime(Map<String, dynamic>? raw) {
  final fallback = buildDefaultStepRuntime();
  if (raw == null) return fallback;

  final startMode = raw['startMode']?.toString();

  // Backward compatibility with V2/V3 where closeMode could be 'blocked_until_step'
  String? rawCloseMode = raw['closeMode']?.toString();
  String? rawCloseGate = raw['closeGate']?.toString();
  if (rawCloseMode == 'blocked_until_step') {
    rawCloseMode = 'manual';
    rawCloseGate = 'until_step';
  }

  return <String, dynamic>{
    'startMode': kAllowedStepStartModes.contains(startMode)
        ? startMode
        : fallback['startMode'],
    'referenceStepId': raw['referenceStepId']?.toString(),
    'delayMs': _readInt(raw['delayMs'], fallback: 0),
    'closeMode': kAllowedStepCloseModes.contains(rawCloseMode)
        ? rawCloseMode
        : fallback['closeMode'],
    'closeGate': kAllowedStepCloseGates.contains(rawCloseGate)
        ? rawCloseGate
        : fallback['closeGate'],
    'closeBlockedUntilStepId': raw['closeBlockedUntilStepId']?.toString(),
  };
}

List<Map<String, dynamic>> buildDefaultMediaUsagesForStepType(
  String stepType, {
  required String stepId,
  Map<String, dynamic>? params,
}) {
  final mediaFormat = mediaFormatForStepType(stepType);
  if (mediaFormat == null) {
    return <Map<String, dynamic>>[];
  }

  return <Map<String, dynamic>>[
    <String, dynamic>{
      'role': 'primary',
      'slotKey': buildDefaultMediaSlotKey(
        stepId: stepId,
        stepType: stepType,
      ),
      'runtimeMode': defaultMediaRuntimeModeForStepType(
        stepType,
        params: params,
      ),
      'archive': <String, dynamic>{
        'enabled': false,
        'mode': 'none',
      },
    },
  ];
}

List<Map<String, dynamic>> normalizeMediaUsages(
  dynamic raw, {
  required String stepType,
  required String stepId,
  Map<String, dynamic>? params,
}) {
  final fallback = buildDefaultMediaUsagesForStepType(
    stepType,
    stepId: stepId,
    params: params,
  );

  if (mediaFormatForStepType(stepType) == null) {
    return <Map<String, dynamic>>[];
  }

  if (raw is! List || raw.isEmpty) {
    return fallback;
  }

  final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];

  for (final dynamic item in raw) {
    if (item is! Map) continue;
    final rawMap = Map<String, dynamic>.from(item.cast<dynamic, dynamic>());
    final runtimeMode = _normalizeMediaRuntimeMode(
      rawMap['runtimeMode']?.toString(),
      stepType: stepType,
      params: params,
    );

    final rawArchive = rawMap['archive'];
    final archiveMap = rawArchive is Map
        ? Map<String, dynamic>.from(rawArchive.cast<dynamic, dynamic>())
        : <String, dynamic>{};

    final archiveEnabled = archiveMap['enabled'] == true;
    final archiveMode = _normalizeArchiveMode(
      archiveEnabled
          ? archiveMap['mode']?.toString()
          : 'none',
      runtimeMode: runtimeMode,
      fallback: archiveEnabled
          ? defaultArchiveModeForRuntimeMode(runtimeMode)
          : 'none',
    );

    results.add(<String, dynamic>{
      'role': (rawMap['role'] ?? 'primary').toString().trim().isEmpty
          ? 'primary'
          : rawMap['role'].toString().trim(),
      'slotKey': (rawMap['slotKey'] ?? '').toString().trim().isEmpty
          ? buildDefaultMediaSlotKey(stepId: stepId, stepType: stepType)
          : rawMap['slotKey'].toString().trim(),
      'runtimeMode': runtimeMode,
      'archive': <String, dynamic>{
        'enabled': archiveEnabled,
        'mode': archiveEnabled ? archiveMode : 'none',
      },
    });
  }

  return results.isEmpty ? fallback : results;
}

String buildDefaultMediaSlotKey({
  required String stepId,
  required String stepType,
}) {
  final mediaFormat = mediaFormatForStepType(stepType) ?? 'media';
  return '${stepId}_primary_$mediaFormat';
}

String defaultMediaRuntimeModeForStepType(
  String stepType, {
  Map<String, dynamic>? params,
}) {
  switch (normalizeSequenceStepType(stepType)) {
    case 'call':
    case 'audio':
      return 'standard_audio';
    case 'video':
      return 'standard_video';
    case 'image':
      final displayMode = (params?['displayMode'] ?? 'standard').toString();
      return displayMode == 'exploration_window'
          ? 'dynamic_pan_zoom'
          : 'standard_image';
    case 'physical':
      return 'standard_image';
    case 'popup':
    default:
      return 'standard_image';
  }
}

String defaultArchiveModeForRuntimeMode(String runtimeMode) {
  switch (runtimeMode) {
    case 'dynamic_pan_zoom':
      return 'zoomable_image';
    case 'masked_view':
      return 'preserve_runtime';
    case 'standard_image':
    case 'standard_video':
    case 'standard_audio':
    default:
      return 'standard_media';
  }
}

String? mediaFormatForStepType(String type) {
  switch (normalizeSequenceStepType(type)) {
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

bool stepTypeRequiresMedia(String type) {
  return mediaFormatForStepType(type) != null;
}

String _normalizeMediaRuntimeMode(
  String? raw, {
  required String stepType,
  Map<String, dynamic>? params,
}) {
  if (raw != null && kAllowedMediaRuntimeModes.contains(raw)) {
    return raw;
  }
  return defaultMediaRuntimeModeForStepType(stepType, params: params);
}

String _normalizeArchiveMode(
  String? raw, {
  required String runtimeMode,
  required String fallback,
}) {
  if (raw == null || !kAllowedArchiveModes.contains(raw)) {
    return fallback;
  }

  if (raw == 'zoomable_image' &&
      runtimeMode != 'standard_image' &&
      runtimeMode != 'dynamic_pan_zoom' &&
      runtimeMode != 'masked_view') {
    return fallback;
  }

  return raw;
}

int _readInt(dynamic raw, {required int fallback}) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}
