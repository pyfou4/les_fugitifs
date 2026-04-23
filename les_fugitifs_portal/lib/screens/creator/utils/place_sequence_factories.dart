import 'dart:math';

const List<String> kAllowedSequenceStepTypes = <String>[
  'popup',
  'call',
  'video',
  'audio',
  'image',
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

List<String> allowedSequenceStepTypes() =>
    List<String>.from(kAllowedSequenceStepTypes);

List<String> allowedStepStartModes() =>
    List<String>.from(kAllowedStepStartModes);

List<String> allowedStepCloseModes() =>
    List<String>.from(kAllowedStepCloseModes);

List<String> allowedStepCloseGates() =>
    List<String>.from(kAllowedStepCloseGates);

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

  Map<String, dynamic> base;
  switch (type) {
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
    default:
      return buildSequenceStepForType(
        'popup',
        id: safeId,
        title: title,
        description: description,
        runtime: runtime,
      );
  }

  base['runtime'] = normalizeStepRuntime(runtime);
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

int _readInt(dynamic raw, {required int fallback}) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}
