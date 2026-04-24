import 'place_sequence_factories.dart';

Map<String, dynamic> normalizePlaceTrigger(dynamic raw) {
  final fallback = buildDefaultTrigger();

  if (raw is! Map) {
    return fallback;
  }

  final rawMap = Map<String, dynamic>.from(raw.cast<dynamic, dynamic>());
  final type =
      (rawMap['type'] is String) ? rawMap['type'] as String : 'manual_start';
  final delayMs = _readInt(rawMap['delayMs'], fallback: 0);
  final retryPolicy = (rawMap['retryPolicy'] is String)
      ? rawMap['retryPolicy'] as String
      : 'none';
  final rawParams = rawMap['params'];
  final params = rawParams is Map
      ? Map<String, dynamic>.from(rawParams.cast<dynamic, dynamic>())
      : <String, dynamic>{};

  switch (type) {
    case 'auto_on_enter':
      return <String, dynamic>{
        'type': 'auto_on_enter',
        'delayMs': 0,
        'retryPolicy': retryPolicy,
        'params': <String, dynamic>{},
      };
    case 'delayed_auto':
      return <String, dynamic>{
        'type': 'delayed_auto',
        'delayMs': delayMs < 0 ? 0 : delayMs,
        'retryPolicy': retryPolicy,
        'params': <String, dynamic>{},
      };
    case 'manual_start':
    default:
      return <String, dynamic>{
        'type': 'manual_start',
        'delayMs': 0,
        'retryPolicy': retryPolicy,
        'params': <String, dynamic>{
          'startLabel': (params['startLabel'] ?? 'Commencer').toString(),
        },
      };
  }
}

List<Map<String, dynamic>> normalizePlaceSequence(dynamic raw) {
  if (raw is! List) {
    return <Map<String, dynamic>>[];
  }

  return raw.map<Map<String, dynamic>>(normalizeSequenceStep).toList();
}

Map<String, dynamic> normalizeSequenceStep(dynamic rawStep) {
  if (rawStep is! Map) {
    return buildDefaultSequenceStep();
  }

  final rawMap = Map<String, dynamic>.from(rawStep.cast<dynamic, dynamic>());
  final type = (rawMap['type'] ?? 'popup').toString();
  final id = (rawMap['id'] ?? '').toString().trim();
  final title = (rawMap['title'] ?? '').toString();
  final description = (rawMap['description'] ?? '').toString();
  final rawParams = rawMap['params'];
  final params = rawParams is Map
      ? Map<String, dynamic>.from(rawParams.cast<dynamic, dynamic>())
      : <String, dynamic>{};
  final runtimeRaw = rawMap['runtime'];
  final runtime = runtimeRaw is Map
      ? Map<String, dynamic>.from(runtimeRaw.cast<dynamic, dynamic>())
      : <String, dynamic>{};

  final rebuilt = buildSequenceStepForType(
    type,
    id: id.isEmpty ? null : id,
    title: title.isEmpty ? null : title,
    description: description,
    runtime: runtime,
  );

  switch (rebuilt['type']) {
    case 'popup':
      rebuilt['params'] = <String, dynamic>{
        'text': (params['text'] ?? '').toString(),
        'confirmLabel': (params['confirmLabel'] ?? "D'accord").toString(),
      };
      break;
    case 'call':
      rebuilt['params'] = <String, dynamic>{
        'callerLabel': (params['callerLabel'] ?? '').toString(),
      };
      break;
    case 'image':
      final displayMode = (params['displayMode'] ?? 'standard').toString();
      rebuilt['params'] = <String, dynamic>{
        'displayMode': displayMode == 'exploration_window'
            ? 'exploration_window'
            : 'standard',
      };
      break;
    case 'video':
    case 'audio':
      rebuilt['params'] = <String, dynamic>{};
      break;
    case 'observation':
      final answerType = (params['answerType'] ?? 'text').toString();
      final normalizedAnswerType = <String>{'text', 'number', 'boolean'}
              .contains(answerType)
          ? answerType
          : 'text';

      dynamic expectedValue;
      final rawExpectedAnswer = params['expectedAnswer'];
      if (rawExpectedAnswer is Map) {
        expectedValue = rawExpectedAnswer['value'];
      } else {
        expectedValue = null;
      }

      if (normalizedAnswerType == 'number') {
        expectedValue = _readInt(expectedValue, fallback: 0);
      } else if (normalizedAnswerType == 'boolean') {
        expectedValue = expectedValue == true;
      } else {
        expectedValue = (expectedValue ?? '').toString();
      }

      rebuilt['params'] = <String, dynamic>{
        'question': (params['question'] ?? '').toString(),
        'answerType': normalizedAnswerType,
        'expectedAnswer': <String, dynamic>{
          'value': expectedValue,
        },
      };
      break;
  }

  rebuilt['runtime'] = normalizeStepRuntime(runtime);
  rebuilt['blocking'] = true;
  rebuilt['mediaUsages'] = normalizeMediaUsages(
    rawMap['mediaUsages'],
    stepType: rebuilt['type'].toString(),
    stepId: rebuilt['id'].toString(),
    params: Map<String, dynamic>.from(rebuilt['params'] as Map),
  );
  return rebuilt;
}

Map<String, dynamic> normalizePlaceRuntimeFields(Map<String, dynamic> placeData) {
  return <String, dynamic>{
    'trigger': normalizePlaceTrigger(placeData['trigger']),
    'sequence': normalizePlaceSequence(placeData['sequence']),
  };
}

int _readInt(dynamic raw, {required int fallback}) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}
