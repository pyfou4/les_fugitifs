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

  DocumentReference<Map<String, dynamic>> get _scenarioRef =>
      _firestore.collection('scenarios').doc('les_fugitifs');

  CollectionReference<Map<String, dynamic>> get _gamePlaceTemplatesRef =>
      _gameRef.collection('placeTemplates');

  CollectionReference<Map<String, dynamic>> get _gameSuspectsRef =>
      _gameRef.collection('suspects');

  CollectionReference<Map<String, dynamic>> get _gameMotivesRef =>
      _gameRef.collection('motives');

  CollectionReference<Map<String, dynamic>> get _scenarioPlaceTemplatesRef =>
      _scenarioRef.collection('placeTemplates');

  DocumentReference<Map<String, dynamic>> get _clueSystemRef =>
      _scenarioRef.collection('clueSystem').doc('main');

  CollectionReference<Map<String, dynamic>> get _lockedScenariosRef =>
      _firestore.collection('lockedScenarios');

  Future<ScenarioDraftSnapshot> loadCurrentDraftSnapshot() async {
    final gameSnap = await _gameRef.get();
    final placeTemplatesSnap = await _gamePlaceTemplatesRef.get();
    final suspectsSnap = await _gameSuspectsRef.get();
    final motivesSnap = await _gameMotivesRef.get();

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
    final draftSnapshot = await loadCurrentDraftSnapshot();
    final validation = _validator.validate(snapshot: draftSnapshot);

    if (!validation.success) {
      return validation;
    }

    final scenarioPlaceTemplatesSnap = await _scenarioPlaceTemplatesRef.get();
    final clueSystemSnap = await _clueSystemRef.get();

    final scenarioPlaceTemplates = {
      for (final doc in scenarioPlaceTemplatesSnap.docs) doc.id: doc.data(),
    };

    if (scenarioPlaceTemplates.isEmpty) {
      return ScenarioLockResult(
        success: false,
        issues: <ScenarioValidationIssue>[
          const ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'missing_scenario_place_templates',
            message:
                'Aucun placeTemplate canonique trouvé dans scenarios/les_fugitifs/placeTemplates.',
            field: 'scenarios.placeTemplates',
          ),
        ],
      );
    }

    if (!clueSystemSnap.exists || clueSystemSnap.data() == null) {
      return ScenarioLockResult(
        success: false,
        issues: <ScenarioValidationIssue>[
          const ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'missing_clue_system',
            message:
                'Le clueSystem canonique est introuvable dans scenarios/les_fugitifs/clueSystem/main.',
            field: 'scenarios.clueSystem.main',
          ),
        ],
      );
    }

    final game = draftSnapshot.game ?? <String, dynamic>{};
    final nowIso = DateTime.now().toIso8601String();
    final lockRef = _lockedScenariosRef.doc();

    final suspects = <String, dynamic>{
      for (final entry in draftSnapshot.suspects.entries)
        entry.key: _transformSuspectToRuntime(entry.value),
    };

    final motives = <String, dynamic>{
      for (final entry in draftSnapshot.motives.entries)
        entry.key: _transformMotiveToRuntime(entry.value),
    };

    final payload = <String, dynamic>{
      'id': lockRef.id,
      'createdAt': nowIso,
      'sourceScenarioId': 'les_fugitifs',
      'createdBy': lockedBy,
      'status': 'locked',
      'version': _computeNextVersion(game),
      'source': <String, dynamic>{
        'scenarioPath': 'scenarios/les_fugitifs',
        'gamePath': 'games/les_fugitifs',
        'lockedFromDraft': true,
        'gameUpdatedAt': game['updatedAt'],
        'scenarioUpdatedAt': (await _scenarioRef.get()).data()?['updatedAt'],
      },
      'data': <String, dynamic>{
        'clueSystem': clueSystemSnap.data(),
        'suspects': suspects,
        'motives': motives,
        'placeTemplates': scenarioPlaceTemplates,
      },
      'validation': <String, dynamic>{
        'isValid': true,
        'errors': const <Map<String, dynamic>>[],
        'warnings': validation.warnings
            .map(
              (issue) => <String, dynamic>{
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
      <String, dynamic>{
        'creatorLocked': true,
        'creatorLockedAt': nowIso,
        'creatorLockedBy': lockedBy,
        'lastLockedScenarioId': lockRef.id,
        'lastLockedAt': nowIso,
        'status': 'locked',
      },
      SetOptions(merge: true),
    );

    batch.set(
      _scenarioRef,
      <String, dynamic>{
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

  Future<void> unlockCurrentScenario({
    required String unlockedBy,
  }) async {
    final nowIso = DateTime.now().toIso8601String();

    final batch = _firestore.batch();

    batch.set(
      _gameRef,
      <String, dynamic>{
        'creatorLocked': false,
        'status': 'draft',
        'creatorUnlockedAt': nowIso,
        'creatorUnlockedBy': unlockedBy,
      },
      SetOptions(merge: true),
    );

    batch.set(
      _scenarioRef,
      <String, dynamic>{
        'creatorLocked': false,
        'status': 'draft',
        'creatorUnlockedAt': nowIso,
        'creatorUnlockedBy': unlockedBy,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  int _computeNextVersion(Map<String, dynamic> game) {
    final raw = game['lockVersion'];
    if (raw is int) return raw + 1;
    if (raw is num) return raw.toInt() + 1;
    return 1;
  }

  Map<String, dynamic> _transformSuspectToRuntime(Map<String, dynamic> source) {
    return <String, dynamic>{
      'id': (source['id'] ?? '').toString(),
      'title': _normalizeText(
        source['name'] ?? source['title'] ?? source['id'] ?? '',
      ),
      'attributes': _buildSuspectAttributes(source),
      'identityVisual': <String, dynamic>{
        'mediaKey': _normalizeText(
          source['imagePath'] ?? source['image'] ?? '',
        ),
      },
    };
  }

  Map<String, dynamic> _transformMotiveToRuntime(Map<String, dynamic> source) {
    return <String, dynamic>{
      'id': (source['id'] ?? '').toString(),
      'title': _normalizeText(
        source['name'] ?? source['title'] ?? source['id'] ?? '',
      ),
      'attributes': _buildMotiveAttributes(source),
      'identityVisual': <String, dynamic>{
        'mediaKey': _normalizeText(
          source['imagePath'] ?? source['image'] ?? '',
        ),
      },
    };
  }

  List<String> _buildSuspectAttributes(Map<String, dynamic> source) {
    final values = <String>[];

    final age = source['age'];
    if (age != null && age.toString().trim().isNotEmpty) {
      values.add('${age.toString().trim()} ans');
    }

    final profession = _cleanQuotedText(source['profession']);
    if (profession.isNotEmpty) {
      values.add(profession);
    }

    final build = source['build'];
    if (build != null && build.toString().trim().isNotEmpty) {
      final parts = build
          .toString()
          .split('/')
          .map(_normalizeText)
          .where((part) => part.isNotEmpty);

      for (final part in parts) {
        final lower = part.toLowerCase();
        final startsWithVisualTrait = lower.startsWith('cheveux') ||
            lower.startsWith('barbe') ||
            lower.startsWith('moustache') ||
            lower.startsWith('yeux') ||
            lower.startsWith('tatoué') ||
            lower.startsWith('tatouée') ||
            lower.startsWith('blonde') ||
            lower.startsWith('brune') ||
            lower.startsWith('chauve');

        if (startsWithVisualTrait) {
          values.add(part);
        } else {
          values.add('silhouette $part');
        }
      }
    }

    return _dedupe(values);
  }

  List<String> _buildMotiveAttributes(Map<String, dynamic> source) {
    final values = <String>[];

    final preparations = _normalizeText(source['preparations'] ?? '');
    if (preparations.isNotEmpty) {
      values.add('Préparation : $preparations');
    }

    final delays = _normalizeText(source['delays'] ?? '');
    if (delays.isNotEmpty) {
      values.add('Délais : $delays');
    }

    final violence = _normalizeText(source['violence'] ?? '');
    if (violence.isNotEmpty) {
      values.add('Violence : $violence');
    }

    return _dedupe(values);
  }

  String _normalizeText(dynamic value) {
    return value == null
        ? ''
        : value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _cleanQuotedText(dynamic value) {
    final text = _normalizeText(value);
    return text.replaceAll(RegExp(r'^"+|"+$'), '');
  }

  List<String> _dedupe(List<String> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final value in values.map(_normalizeText)) {
      if (value.isEmpty) continue;
      final key = value.toLowerCase();
      if (seen.add(key)) {
        result.add(value);
      }
    }

    return result;
  }
}
