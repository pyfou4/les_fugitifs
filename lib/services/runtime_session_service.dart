import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_session.dart';
import '../models/motive_model.dart';
import '../models/place_node.dart';
import '../models/suspect_model.dart';

class RuntimeSessionBundle {
  final GameSession session;
  final List<PlaceNode> places;
  final List<SuspectModel> suspects;
  final List<MotiveModel> motives;
  final Map<String, dynamic> runtimeScenarioData;
  final Map<String, dynamic> lockedScenarioData;

  const RuntimeSessionBundle({
    required this.session,
    required this.places,
    required this.suspects,
    required this.motives,
    required this.runtimeScenarioData,
    required this.lockedScenarioData,
  });
}


class RuntimeSessionService {
  RuntimeSessionService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<RuntimeSessionBundle> loadActiveBundle() async {
    final prefs = await SharedPreferences.getInstance();

    final explicitSessionId = _firstNonEmpty([
      prefs.getString('active_game_session_id'),
      prefs.getString('game_session_id'),
    ]);

    final explicitActivationCode = _firstNonEmpty([
      prefs.getString('active_activation_code'),
      prefs.getString('activation_code'),
    ]);

    DocumentSnapshot<Map<String, dynamic>> sessionSnapshot;

    if (explicitSessionId != null) {
      sessionSnapshot =
          await _firestore.collection('gameSessions').doc(explicitSessionId).get();
      if (!sessionSnapshot.exists) {
        throw Exception(
          'Session introuvable pour l’identifiant stocké: $explicitSessionId',
        );
      }
    } else if (explicitActivationCode != null) {
      final query = await _firestore
          .collection('gameSessions')
          .where('activationCode', isEqualTo: explicitActivationCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception(
          'Aucune session trouvée pour le code d’activation $explicitActivationCode.',
        );
      }
      sessionSnapshot = query.docs.first;
    } else {
      throw Exception(
        'Aucune session active trouvée sur cet appareil. Il faudra relier ensuite l’écran de saisie du code à SharedPreferences.',
      );
    }

    final sessionData = sessionSnapshot.data();
    if (sessionData == null) {
      throw Exception('Les données de session sont vides.');
    }

    final session = GameSession.fromFirestore(sessionSnapshot.id, sessionData);
    if (session.lockedScenarioId.trim().isEmpty) {
      throw Exception('La session ne contient pas de lockedScenarioId.');
    }
    if (session.siteId.trim().isEmpty) {
      throw Exception('La session ne contient pas de siteId.');
    }

    final lockedSnapshot = await _firestore
        .collection('lockedScenarios')
        .doc(session.lockedScenarioId)
        .get();

    if (!lockedSnapshot.exists) {
      throw Exception(
        'Scénario verrouillé introuvable: ${session.lockedScenarioId}',
      );
    }

    final lockedData = lockedSnapshot.data();
    if (lockedData == null) {
      throw Exception('Le snapshot verrouillé est vide.');
    }

    final runtimeData = await _loadRuntimeScenarioDataForSession(
      session: session,
      sessionData: sessionData,
    );

    final sitePlacesSnapshot = await _firestore
        .collection('sites')
        .doc(session.siteId)
        .collection('places')
        .get();

    final lockedTemplateMaps = _extractEntityMaps(
      lockedData,
      preferredKeys: const [
        'placeTemplates',
        'places',
        'lockedPlaces',
        'templates',
      ],
    );

    final lockedTemplatesById = <String, Map<String, dynamic>>{
      for (final template in lockedTemplateMaps)
        if ((template['id'] ?? '').toString().trim().isNotEmpty)
          (template['id'] ?? '').toString().trim(): template,
    };

    final runtimeTemplateMaps = runtimeData == null
        ? const <Map<String, dynamic>>[]
        : _extractEntityMaps(
            runtimeData,
            preferredKeys: const [
              'places',
              'runtimePlaces',
              'placeTemplates',
              'lockedPlaces',
              'templates',
            ],
          );

    final templateMaps = runtimeTemplateMaps.isEmpty
        ? lockedTemplateMaps
        : runtimeTemplateMaps.map((runtimePlace) {
            final placeId = (runtimePlace['id'] ?? '').toString().trim();
            return _normalizeRuntimePlaceForPlaceNode(
              runtimePlace,
              fallbackTemplate: lockedTemplatesById[placeId],
            );
          }).toList();

    final suspectMaps = _extractEntityMaps(
      lockedData,
      preferredKeys: const [
        'suspects',
        'lockedSuspects',
      ],
    );

    final motiveMaps = _extractEntityMaps(
      lockedData,
      preferredKeys: const [
        'motives',
        'lockedMotives',
      ],
    );

    if (templateMaps.isEmpty) {
      final sourcePath = runtimeData == null
          ? 'lockedScenarios/${session.lockedScenarioId}'
          : 'runtime_scenarios/${runtimeData['id']}';
      throw Exception(
        'Aucun lieu exploitable trouvé dans $sourcePath.',
      );
    }

    final sitePlacesById = <String, Map<String, dynamic>>{
      for (final doc in sitePlacesSnapshot.docs) doc.id: doc.data(),
    };

    final suspects = suspectMaps.map(SuspectModel.fromRuntime).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final motives = motiveMaps.map(MotiveModel.fromRuntime).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final places = templateMaps.map((template) {
      final placeId = (template['id'] ?? '').toString().trim();
      final sitePlace = sitePlacesById[placeId] ?? const <String, dynamic>{};
      return PlaceNode.fromRuntime(
        template: template,
        sitePlace: sitePlace,
      );
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final normalizedLockedData = _normalizeScenarioData(lockedData);
    final normalizedRuntimeData = _normalizeScenarioData(
      runtimeData ?? const <String, dynamic>{},
      fallbackScenarioData: normalizedLockedData,
    );

    return RuntimeSessionBundle(
      session: session,
      places: places,
      suspects: suspects,
      motives: motives,
      runtimeScenarioData: normalizedRuntimeData,
      lockedScenarioData: normalizedLockedData,
    );
  }

  Map<String, dynamic> _normalizeScenarioData(
    Map<String, dynamic> source, {
    Map<String, dynamic>? fallbackScenarioData,
  }) {
    final normalized = Map<String, dynamic>.from(source);
    final data = _asStringKeyMap(normalized['data']);
    final fallback = fallbackScenarioData ?? const <String, dynamic>{};

    void hoist(String key) {
      if (_hasUsefulValue(normalized[key])) return;
      if (_hasUsefulValue(data[key])) {
        normalized[key] = data[key];
        return;
      }
      if (_hasUsefulValue(fallback[key])) {
        normalized[key] = fallback[key];
      }
    }

    hoist('clueSystem');
    hoist('suspects');
    hoist('motives');
    hoist('places');
    hoist('placeTemplates');

    return normalized;
  }

  bool _hasUsefulValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    return true;
  }

  Future<Map<String, dynamic>?> _loadRuntimeScenarioDataForSession({
    required GameSession session,
    required Map<String, dynamic> sessionData,
  }) async {
    final explicitRuntimeScenarioId = _firstNonEmpty([
      sessionData['runtimeScenarioId']?.toString(),
      sessionData['activeRuntimeScenarioId']?.toString(),
      _nestedString(sessionData['runtimeScenario'], 'id'),
    ]);

    if (explicitRuntimeScenarioId != null) {
      final runtimeData = await _loadRuntimeScenarioById(
        explicitRuntimeScenarioId,
        expectedLockedScenarioId: session.lockedScenarioId,
      );
      if (runtimeData != null) {
        return runtimeData;
      }
    }

    final gameId = _firstNonEmpty([
          sessionData['gameId']?.toString(),
          sessionData['game'] is Map
              ? (sessionData['game'] as Map)['id']?.toString()
              : null,
        ]) ??
        'les_fugitifs';

    final gameSnapshot = await _firestore.collection('games').doc(gameId).get();
    final gameData = gameSnapshot.data();
    final runtimeScenarioId = gameData?['lastRuntimeScenarioId']?.toString();

    if (runtimeScenarioId != null && runtimeScenarioId.trim().isNotEmpty) {
      final runtimeData = await _loadRuntimeScenarioById(
        runtimeScenarioId.trim(),
        expectedLockedScenarioId: session.lockedScenarioId,
      );
      if (runtimeData != null) {
        return runtimeData;
      }
    }

    return _loadRuntimeScenarioByLockedScenarioId(session.lockedScenarioId);
  }

  Future<Map<String, dynamic>?> _loadRuntimeScenarioByLockedScenarioId(
    String lockedScenarioId,
  ) async {
    final query = await _firestore
        .collection('runtime_scenarios')
        .where('sourceLockedScenarioId', isEqualTo: lockedScenarioId)
        .limit(20)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    final candidates = query.docs
        .map((doc) => {
              ...doc.data(),
              'id': doc.id,
            })
        .toList();

    candidates.sort((a, b) {
      final aGeneratedAt = (a['generatedAt'] ?? '').toString();
      final bGeneratedAt = (b['generatedAt'] ?? '').toString();
      return bGeneratedAt.compareTo(aGeneratedAt);
    });

    return candidates.first;
  }

  Future<Map<String, dynamic>?> _loadRuntimeScenarioById(
    String runtimeScenarioId, {
    required String expectedLockedScenarioId,
  }) async {
    final runtimeSnapshot = await _firestore
        .collection('runtime_scenarios')
        .doc(runtimeScenarioId)
        .get();

    final runtimeData = runtimeSnapshot.data();
    if (!runtimeSnapshot.exists || runtimeData == null) {
      return null;
    }

    final sourceLockedScenarioId =
        (runtimeData['sourceLockedScenarioId'] ?? '').toString().trim();

    if (sourceLockedScenarioId.isNotEmpty &&
        sourceLockedScenarioId != expectedLockedScenarioId) {
      return null;
    }

    return runtimeData;
  }

  Map<String, dynamic> _normalizeRuntimePlaceForPlaceNode(
    Map<String, dynamic> runtimePlace, {
    Map<String, dynamic>? fallbackTemplate,
  }) {
    final visibility = _asStringKeyMap(runtimePlace['visibility']);
    final narration = _asStringKeyMap(runtimePlace['narration']);
    final reward = _asStringKeyMap(runtimePlace['reward']);
    final fallback = fallbackTemplate ?? const <String, dynamic>{};

    return {
      ...fallback,
      ...runtimePlace,
      'id': runtimePlace['id'] ?? fallback['id'],
      'name': runtimePlace['title'] ?? runtimePlace['name'] ?? fallback['name'],
      'title': runtimePlace['title'] ?? runtimePlace['name'] ?? fallback['title'],
      'phase': runtimePlace['phase'] ?? fallback['phase'],
      'phaseIndex': runtimePlace['order'] ??
          runtimePlace['phaseIndex'] ??
          fallback['phaseIndex'],
      'experienceType': runtimePlace['type'] ??
          runtimePlace['experienceType'] ??
          fallback['experienceType'],
      'placeType': runtimePlace['type'] ??
          runtimePlace['placeType'] ??
          fallback['placeType'],
      'requiresAllVisited': visibility['requiresAll'] ??
          runtimePlace['requiresAllVisited'] ??
          fallback['requiresAllVisited'] ??
          const <String>[],
      'requiresAnyVisited': visibility['requiresAny'] ??
          runtimePlace['requiresAnyVisited'] ??
          fallback['requiresAnyVisited'] ??
          const <String>[],
      'unlockRules': visibility['unlockRules'] ??
          runtimePlace['unlockRules'] ??
          fallback['unlockRules'],
      'synopsis': narration['brief'] ??
          runtimePlace['synopsis'] ??
          fallback['synopsis'],
      'storySynopsis': narration['description'] ??
          runtimePlace['storySynopsis'] ??
          fallback['storySynopsis'],
      'targetType': reward['targetType'] ??
          runtimePlace['targetType'] ??
          fallback['targetType'],
      'targetSlot': reward['targetSlot'] ??
          runtimePlace['targetSlot'] ??
          fallback['targetSlot'],
    };
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String? _nestedString(dynamic rawParent, String key) {
    if (rawParent is! Map) return null;
    return rawParent[key]?.toString();
  }

  static Map<String, dynamic> _asStringKeyMap(dynamic raw) {
    if (raw is! Map) return const <String, dynamic>{};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  List<Map<String, dynamic>> _extractEntityMaps(
    Map<String, dynamic> root, {
    required List<String> preferredKeys,
  }) {
    for (final key in preferredKeys) {
      final extracted = _extractListOrMap(root[key]);
      if (extracted.isNotEmpty) {
        return extracted;
      }
    }

    const nestedParents = [
      'snapshot',
      'data',
      'payload',
      'lockedData',
    ];

    for (final parentKey in nestedParents) {
      final rawParent = root[parentKey];
      if (rawParent is! Map) continue;
      final parent = rawParent.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      for (final key in preferredKeys) {
        final extracted = _extractListOrMap(parent[key]);
        if (extracted.isNotEmpty) {
          return extracted;
        }
      }
    }

    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _extractListOrMap(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((entry) => entry.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .toList();
    }

    if (raw is Map) {
      return raw.entries
          .where((entry) => entry.value is Map)
          .map((entry) {
            final mapValue = (entry.value as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            );
            if ((mapValue['id'] ?? '').toString().trim().isEmpty) {
              return {
                'id': entry.key.toString(),
                ...mapValue,
              };
            }
            return mapValue;
          })
          .toList();
    }

    return const <Map<String, dynamic>>[];
  }
}
