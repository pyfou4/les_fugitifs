import 'package:cloud_firestore/cloud_firestore.dart';

import 'scenario_lock_models.dart';
import 'scenario_lock_validator.dart';

class ScenarioLockService {
  ScenarioLockService({
    FirebaseFirestore? firestore,
    ScenarioLockValidator? validator,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _validator = validator ?? const ScenarioLockValidator();

  final FirebaseFirestore _firestore;
  final ScenarioLockValidator _validator;

  DocumentReference<Map<String, dynamic>> get _gameRef =>
      _firestore.collection('games').doc('les_fugitifs');

  CollectionReference<Map<String, dynamic>> get _placeTemplatesRef =>
      _gameRef.collection('placeTemplates');

  CollectionReference<Map<String, dynamic>> get _suspectsRef =>
      _gameRef.collection('suspects');

  CollectionReference<Map<String, dynamic>> get _motivesRef =>
      _gameRef.collection('motives');

  CollectionReference<Map<String, dynamic>> get _lockedScenariosRef =>
      _firestore.collection('lockedScenarios');

  Future<ScenarioDraftSnapshot> loadCurrentDraftSnapshot() async {
    final gameSnap = await _gameRef.get();
    final placeTemplatesSnap = await _placeTemplatesRef.get();
    final suspectsSnap = await _suspectsRef.get();
    final motivesSnap = await _motivesRef.get();

    return ScenarioDraftSnapshot(
      game: gameSnap.data(),
      placeTemplates: {
        for (final doc in placeTemplatesSnap.docs) doc.id: doc.data(),
      },
      suspects: {
        for (final doc in suspectsSnap.docs) doc.id: doc.data(),
      },
      motives: {
        for (final doc in motivesSnap.docs) doc.id: doc.data(),
      },
    );
  }

  Future<ScenarioLockResult> validateCurrentDraft() async {
    final snapshot = await loadCurrentDraftSnapshot();
    return _validator.validate(snapshot: snapshot);
  }

  Future<ScenarioLockResult> lockCurrentScenario({
    required String lockedBy,
  }) async {
    final snapshot = await loadCurrentDraftSnapshot();
    final validation = _validator.validate(snapshot: snapshot);

    if (!validation.success) {
      return validation;
    }

    final nowIso = DateTime.now().toIso8601String();
    final lockRef = _lockedScenariosRef.doc();

    final game = snapshot.game ?? <String, dynamic>{};

    final payload = <String, dynamic>{
      'id': lockRef.id,
      'gameId': (game['id'] ?? 'les_fugitifs').toString(),
      'title': (game['title'] ?? 'Les Fugitifs').toString(),
      'status': 'locked',
      'lockedAt': nowIso,
      'lockedBy': lockedBy,
      'version': 1,
      'source': {
        'gamePath': 'games/les_fugitifs',
        'lockedFromDraft': true,
        'gameUpdatedAt': game['updatedAt'],
      },
      'game': game,
      'placeTemplates': snapshot.placeTemplates.values.toList(),
      'suspects': snapshot.suspects.values.toList(),
      'motives': snapshot.motives.values.toList(),
      'validation': {
        'isValid': true,
        'errors': const <Map<String, dynamic>>[],
        'warnings': validation.warnings
            .map(
              (issue) => {
            'severity': issue.severity.name,
            'code': issue.code,
            'message': issue.message,
            'field': issue.field,
            'itemId': issue.itemId,
          },
        )
            .toList(),
      },
    };

    final batch = _firestore.batch();

    batch.set(lockRef, payload, SetOptions(merge: true));

    batch.set(
      _gameRef,
      {
        'creatorLocked': true,
        'creatorLockedAt': nowIso,
        'creatorLockedBy': lockedBy,
        'lastLockedScenarioId': lockRef.id,
        'lastLockedAt': nowIso,
        'status': 'locked',
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    return ScenarioLockResult(
      success: true,
      lockedScenarioId: lockRef.id,
      issues: validation.issues,
    );
  }
}