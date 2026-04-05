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

  const RuntimeSessionBundle({
    required this.session,
    required this.places,
    required this.suspects,
    required this.motives,
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

    final sitePlacesSnapshot = await _firestore
        .collection('sites')
        .doc(session.siteId)
        .collection('places')
        .get();

    final templateMaps = _extractEntityMaps(
      lockedData,
      preferredKeys: const [
        'placeTemplates',
        'places',
        'lockedPlaces',
        'templates',
      ],
    );

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
      throw Exception(
        'Aucun lieu verrouillé exploitable trouvé dans lockedScenarios/${session.lockedScenarioId}.',
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

    return RuntimeSessionBundle(
      session: session,
      places: places,
      suspects: suspects,
      motives: motives,
    );
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
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
