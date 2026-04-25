import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_session.dart';
import '../models/motive_model.dart';
import '../models/place_node.dart';
import '../models/suspect_model.dart';
import '../services/ai_service.dart';
import '../services/narrative_progress_service.dart';
import '../services/runtime_session_service.dart';

import 'archives_screen.dart';
import 'investigation_screen.dart';
import 'map_screen.dart';
import 'scenario_screen.dart';
import 'sos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _RuntimeScoringThreshold {
  final num? min;
  final num? max;
  final String result;

  const _RuntimeScoringThreshold({
    required this.min,
    required this.max,
    required this.result,
  });

  bool matches(num score) {
    final aboveMin = min == null || score >= min!;
    final belowMax = max == null || score <= max!;
    return aboveMin && belowMax;
  }
}

class _RuntimePlaceConfig {
  final String type;
  final String? mechanicMode;
  final String? interaction;
  final String? rewardMode;
  final String? rewardTargetType;
  final String? rewardTargetSlot;
  final String? rulesSummary;
  final String? scoringSummary;
  final String? observationQuestion;
  final String? observationAnswerType;
  final String? observationSolution;
  final num? observationTolerance;
  final List<_RuntimeScoringThreshold> scoringThresholds;
  final bool hasScoring;

  const _RuntimePlaceConfig({
    required this.type,
    this.mechanicMode,
    this.interaction,
    this.rewardMode,
    this.rewardTargetType,
    this.rewardTargetSlot,
    this.rulesSummary,
    this.scoringSummary,
    this.observationQuestion,
    this.observationAnswerType,
    this.observationSolution,
    this.observationTolerance,
    this.scoringThresholds = const <_RuntimeScoringThreshold>[],
    required this.hasScoring,
  });

  bool get hasPreparedEngine =>
      (mechanicMode != null && mechanicMode!.trim().isNotEmpty) ||
      (interaction != null && interaction!.trim().isNotEmpty) ||
      hasScoring ||
      scoringThresholds.isNotEmpty ||
      (rulesSummary != null && rulesSummary!.trim().isNotEmpty) ||
      (scoringSummary != null && scoringSummary!.trim().isNotEmpty) ||
      (observationQuestion != null && observationQuestion!.trim().isNotEmpty) ||
      (observationAnswerType != null && observationAnswerType!.trim().isNotEmpty) ||
      (observationSolution != null && observationSolution!.trim().isNotEmpty) ||
      (rewardMode != null && rewardMode!.trim().isNotEmpty) ||
      (rewardTargetType != null && rewardTargetType!.trim().isNotEmpty) ||
      (rewardTargetSlot != null && rewardTargetSlot!.trim().isNotEmpty);
}

class _HomeScreenState extends State<HomeScreen> {
  final RuntimeSessionService _runtimeSessionService = RuntimeSessionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int currentIndex = 0;

  bool _isLoading = true;
  String? _error;

  List<PlaceNode> _places = [];
  List<SuspectModel> _suspects = [];
  List<MotiveModel> _motives = [];

  GameSession? _session;
  String? _storagePrefix;
  String? _currentHelpPlaceId;
  Map<String, _RuntimePlaceConfig> _runtimePlaceConfigById = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _humanHelpMessagesSubscription;
  bool _humanHelpDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  @override
  void dispose() {
    _humanHelpMessagesSubscription?.cancel();
    super.dispose();
  }

  int get progress => _places.where((p) => p.isVisited).length.clamp(0, 19);

  int get narrativeProgressScore =>
      NarrativeProgressService.narrativeProgressScore(_places);

  double get progressRatio =>
      NarrativeProgressService.progressRatio(_places);

  bool get canExitNarrative =>
      NarrativeProgressService.canExitNarrative(_places);

  List<String> get missingMainPlaceIds =>
      NarrativeProgressService.missingMainPlaceIds(_places);

  Future<void> _loadGameData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bundle = await _runtimeSessionService.loadActiveBundle();

      _places = bundle.places;
      _suspects = bundle.suspects;
      _motives = bundle.motives;
      _session = bundle.session;
      _storagePrefix = 'session_${bundle.session.id}';
      _runtimePlaceConfigById = await _loadRuntimePlaceConfigs();

      await _loadSessionAndProgress();
      await _startHumanHelpMessagesListener();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Erreur chargement runtime : $e';
      });
    }
  }

  Future<Map<String, _RuntimePlaceConfig>> _loadRuntimePlaceConfigs() async {
    try {
      final gameDoc = await _firestore.collection('games').doc('les_fugitifs').get();
      final gameData = gameDoc.data();
      final runtimeScenarioId = gameData?['lastRuntimeScenarioId']?.toString().trim();

      if (runtimeScenarioId == null || runtimeScenarioId.isEmpty) {
        return <String, _RuntimePlaceConfig>{};
      }

      final runtimeDoc = await _firestore
          .collection('runtime_scenarios')
          .doc(runtimeScenarioId)
          .get();

      final runtimeData = runtimeDoc.data();
      final rawPlaces = runtimeData?['places'];

      if (rawPlaces is! List) {
        return <String, _RuntimePlaceConfig>{};
      }

      final result = <String, _RuntimePlaceConfig>{};
      for (final rawPlace in rawPlaces) {
        if (rawPlace is! Map) continue;
        final place = rawPlace.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final id = place['id']?.toString().trim();
        final type = place['type']?.toString().trim();
        if (id == null || id.isEmpty || type == null || type.isEmpty) {
          continue;
        }

        final mechanic = _asStringKeyMap(place['mechanic']);
        final reward = _asStringKeyMap(place['reward']);
        final scoring = _asStringKeyMap(place['scoring']);
        final rules = _asStringKeyMap(mechanic['rules']);

        result[id] = _RuntimePlaceConfig(
          type: type,
          mechanicMode: mechanic['mode']?.toString(),
          interaction: mechanic['interaction']?.toString(),
          rewardMode: reward['mode']?.toString(),
          rewardTargetType: reward['targetType']?.toString(),
          rewardTargetSlot: reward['targetSlot']?.toString(),
          rulesSummary: _runtimeRulesSummary(rules),
          scoringSummary: _runtimeScoringSummary(scoring),
          observationQuestion: _runtimeObservationQuestion(rules, place),
          observationAnswerType: _runtimeObservationAnswerType(rules),
          observationSolution: _runtimeObservationSolution(rules),
          observationTolerance: _toNum(rules['tolerance']),
          scoringThresholds: _runtimeScoringThresholds(scoring),
          hasScoring: scoring.isNotEmpty,
        );
      }

      return result;
    } catch (_) {
      return <String, _RuntimePlaceConfig>{};
    }
  }

  Map<String, dynamic> _asStringKeyMap(dynamic raw) {
    if (raw is! Map) return const <String, dynamic>{};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  String? _runtimeRulesSummary(dynamic rawRules) {
    final rules = _asStringKeyMap(rawRules);
    if (rules.isEmpty) return null;

    final parts = <String>[];
    for (final entry in rules.entries) {
      final value = entry.value;
      if (value is Map || value is List) continue;
      final valueText = value?.toString().trim();
      if (valueText == null || valueText.isEmpty) continue;
      parts.add('${entry.key}: $valueText');
    }

    if (parts.isEmpty) return 'règles runtime présentes';
    return parts.take(4).join(' · ');
  }

  String? _runtimeObservationQuestion(
    Map<String, dynamic> rules,
    Map<String, dynamic> place,
  ) {
    final narration = _asStringKeyMap(place['narration']);
    final candidates = <dynamic>[
      rules['question'],
      rules['prompt'],
      rules['taskDescription'],
      narration['brief'],
      narration['description'],
      place['title'],
    ];

    for (final candidate in candidates) {
      final text = candidate?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  String? _runtimeObservationAnswerType(Map<String, dynamic> rules) {
    final raw = (rules['answerType'] ?? rules['type'] ?? rules['inputType'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    if (raw == 'number' || raw == 'numeric' || raw == 'integer') {
      return 'number';
    }
    if (raw == 'bool' || raw == 'boolean' || raw == 'yes_no') {
      return 'boolean';
    }
    return 'text';
  }

  String? _runtimeObservationSolution(Map<String, dynamic> rules) {
    final raw = rules['solution'] ?? rules['answer'] ?? rules['expectedAnswer'];
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String? _runtimeScoringSummary(dynamic rawScoring) {
    final scoring = _asStringKeyMap(rawScoring);
    if (scoring.isEmpty) return null;

    final type = scoring['type']?.toString().trim();
    final thresholds = scoring['thresholds'];
    if (thresholds is List && thresholds.isNotEmpty) {
      final items = thresholds
          .whereType<Map>()
          .map((raw) {
            final map = raw.map((key, value) => MapEntry(key.toString(), value));
            final min = map['min'];
            final max = map['max'];
            final result = map['result'] ?? map['strength'];
            if (result == null) return null;
            if (min == null && max == null) return result.toString();
            return '$result: ${min ?? '?'}-${max ?? '?'}';
          })
          .whereType<String>()
          .take(3)
          .toList();

      if (items.isNotEmpty) {
        final prefix = type == null || type.isEmpty ? 'scoring' : type;
        return '$prefix (${items.join(' · ')})';
      }
    }

    return type == null || type.isEmpty ? 'scoring runtime présent' : type;
  }

  List<_RuntimeScoringThreshold> _runtimeScoringThresholds(
    Map<String, dynamic> scoring,
  ) {
    final thresholds = scoring['thresholds'];
    if (thresholds is! List) return const <_RuntimeScoringThreshold>[];

    final result = <_RuntimeScoringThreshold>[];
    for (final raw in thresholds) {
      if (raw is! Map) continue;
      final map = raw.map((key, value) => MapEntry(key.toString(), value));
      final label = (map['result'] ?? map['strength'])?.toString().trim();
      if (label == null || label.isEmpty) continue;
      result.add(
        _RuntimeScoringThreshold(
          min: _toNum(map['min']),
          max: _toNum(map['max']),
          result: label,
        ),
      );
    }
    return result;
  }

  num? _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  Future<void> _loadSessionAndProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _storagePrefix ?? 'session_unknown';

    final visitedIds = prefs.getStringList('${prefix}_visited_places') ?? [];
    for (final place in _places) {
      place.isVisited = visitedIds.contains(place.id);
    }

    _currentHelpPlaceId = prefs.getString('${prefix}_current_help_place_id');

    final sessionRaw = prefs.getString('${prefix}_game_session_local');
    if (sessionRaw != null) {
      try {
        final localSession =
            GameSession.fromJson(jsonDecode(sessionRaw) as Map<String, dynamic>);

        if (_session != null) {
          _session = GameSession(
            id: _session!.id,
            activationCode: _session!.activationCode,
            lockedScenarioId: _session!.lockedScenarioId,
            siteId: _session!.siteId,
            status: _session!.status,
            startedAt: _session!.startedAt,
            expiresAt: _session!.expiresAt,
            trueSuspectId: _session!.trueSuspectId,
            trueMotiveId: _session!.trueMotiveId,
            suspectByPlace: _session!.suspectByPlace,
            motiveByPlace: _session!.motiveByPlace,
            playerMarkedSuspectIds: localSession.playerMarkedSuspectIds,
            playerMarkedMotiveIds: localSession.playerMarkedMotiveIds,
            humanHelpEnabled: _session!.humanHelpEnabled,
            humanEscalationRequired: localSession.humanEscalationRequired,
            humanEscalationStatus: localSession.humanEscalationStatus,
            aiHelpCount: localSession.aiHelpCount,
            currentBlockageLevel: localSession.currentBlockageLevel,
            lastHelpRequestAt: localSession.lastHelpRequestAt,
          );
        }
      } catch (_) {}
    }

    if (_session != null) {
      await _saveProgress();
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _storagePrefix ?? 'session_unknown';

    final visitedIds =
        _places.where((p) => p.isVisited).map((p) => p.id).toList();
    await prefs.setStringList('${prefix}_visited_places', visitedIds);

    if (_currentHelpPlaceId != null && _currentHelpPlaceId!.trim().isNotEmpty) {
      await prefs.setString('${prefix}_current_help_place_id', _currentHelpPlaceId!);
    } else {
      await prefs.remove('${prefix}_current_help_place_id');
    }

    if (_session != null) {
      await prefs.setString(
        '${prefix}_game_session_local',
        jsonEncode(_session!.toJson()),
      );
      await prefs.setString('active_game_session_id', _session!.id);
      await prefs.setString('active_activation_code', _session!.activationCode);
    }
  }

  Future<void> _startHumanHelpMessagesListener() async {
    await _humanHelpMessagesSubscription?.cancel();

    final sessionId = _session?.id;
    if (sessionId == null || sessionId.trim().isEmpty) return;

    _humanHelpMessagesSubscription = _firestore
        .collection('gameSessions')
        .doc(sessionId)
        .collection('humanHelpMessages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (!mounted || snapshot.docs.isEmpty) return;

      final latestDoc = snapshot.docs.first;
      final latestData = latestDoc.data();
      final sender = (latestData['from'] ?? '').toString().trim().toLowerCase();
      if (sender != 'mj') return;

      final prefs = await SharedPreferences.getInstance();
      final prefix = _storagePrefix ?? 'session_unknown';
      final seenKey = '${prefix}_last_seen_human_help_message_id';
      final lastSeenId = prefs.getString(seenKey);

      if (lastSeenId == latestDoc.id) return;
      if (_humanHelpDialogOpen) return;

      if (!mounted) return;
      _humanHelpDialogOpen = true;

      final title = (latestData['title'] ?? 'Message du MJ').toString().trim();
      final body = (latestData['text'] ?? '').toString().trim();
      final createdAt = (latestData['createdAt'] ?? '').toString().trim();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            title: Text(title.isEmpty ? 'Message du MJ' : title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(body.isEmpty
                    ? 'Le maître du jeu a répondu à votre demande.'
                    : body),
                if (createdAt.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    createdAt,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Compris'),
              ),
            ],
          );
        },
      );

      _humanHelpDialogOpen = false;
      await prefs.setString(seenKey, latestDoc.id);
    });
  }

  Future<void> _syncAssistanceToFirestore({
    required GameSession session,
    required String timelineType,
    required String timelineLabel,
  }) async {
    final place = _currentHelpPlace();
    final placeKeywords = place == null
        ? const <String>[]
        : place.keywords.take(6).toList(growable: false);

    final payload = <String, dynamic>{
      'aiHelpCount': session.aiHelpCount,
      'currentBlockageLevel': session.currentBlockageLevel,
      'humanEscalationRequired': session.humanEscalationRequired,
      'humanEscalationStatus': session.humanEscalationStatus,
      'lastHelpRequestAt': session.lastHelpRequestAt,
      'humanHelpEnabled': session.humanHelpEnabled,
    };

    if (place != null) {
      payload['currentNodeId'] = place.id;
      payload['currentPhase'] = place.id;
      payload['lastHelpContext'] = {
        'placeId': place.id,
        'placeName': place.name,
        'keywords': placeKeywords,
        'requiresAllVisited': place.requiresAllVisited,
        'requiresAnyVisited': place.requiresAnyVisited,
        'revealSuspect': place.revealSuspect,
        'revealMotive': place.revealMotive,
      };
    }

    final sessionRef = _firestore.collection('gameSessions').doc(session.id);

    await sessionRef.set(payload, SetOptions(merge: true));

    await sessionRef.collection('timeline').add({
      'type': timelineType,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'label': timelineLabel,
      'source': 'player',
      if (place != null) 'placeId': place.id,
      if (place != null) 'placeName': place.name,
      if (placeKeywords.isNotEmpty) 'keywords': placeKeywords,
    });
  }

  void _toggleSuspect(String id) {
    if (_session == null) return;

    setState(() {
      if (_session!.playerMarkedSuspectIds.contains(id)) {
        _session!.playerMarkedSuspectIds.remove(id);
      } else {
        _session!.playerMarkedSuspectIds.add(id);
      }
    });

    _saveProgress();
  }

  void _toggleMotive(String id) {
    if (_session == null) return;

    setState(() {
      if (_session!.playerMarkedMotiveIds.contains(id)) {
        _session!.playerMarkedMotiveIds.remove(id);
      } else {
        _session!.playerMarkedMotiveIds.add(id);
      }
    });

    _saveProgress();
  }

  void _markPlaceVisited(String placeId) {
    final matches = _places.where((p) => p.id == placeId);
    if (matches.isEmpty) return;

    final place = matches.first;

    if (!place.isVisited) {
      setState(() {
        place.isVisited = true;
        _currentHelpPlaceId = place.id;
      });
      _saveProgress();
    }
  }

  void _setCurrentHelpPlace(PlaceNode place) {
    setState(() {
      _currentHelpPlaceId = place.id;
    });
    _saveProgress();
  }

  PlaceNode? _currentHelpPlace() {
    final id = _currentHelpPlaceId;
    if (id == null || id.trim().isEmpty) return null;
    for (final place in _places) {
      if (place.id == id) return place;
    }
    return null;
  }

  SuspectModel? _findSuspect(String? id) {
    if (id == null) return null;
    for (final suspect in _suspects) {
      if (suspect.id == id) return suspect;
    }
    return null;
  }

  MotiveModel? _findMotive(String? id) {
    if (id == null) return null;
    for (final motive in _motives) {
      if (motive.id == id) return motive;
    }
    return null;
  }

  void _openPlaceMedia(PlaceNode place) {
    _setCurrentHelpPlace(place);

    final runtimeConfig = _runtimePlaceConfigById[place.id];
    final runtimeType = _normalizedRuntimeType(runtimeConfig);
    final revealedSuspect = _findSuspect(_session?.suspectByPlace[place.id]);
    final revealedMotive = _findMotive(_session?.motiveByPlace[place.id]);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(place.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_runtimeOpeningMessage(runtimeType)),
                if (runtimeConfig != null && runtimeConfig.hasPreparedEngine) ...[
                  const SizedBox(height: 12),
                  Text(
                    _runtimePlayerInstruction(runtimeConfig),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                _buildRuntimeTypePanel(runtimeType, runtimeConfig),
                if (revealedSuspect != null) ...[
                  const SizedBox(height: 12),
                  Text('Suspect innocenté : ${revealedSuspect.name}'),
                ],
                if (revealedMotive != null) ...[
                  const SizedBox(height: 8),
                  Text('Mobile innocenté : ${revealedMotive.name}'),
                ],
              ],
            ),
          ),
          actions: _runtimeDialogActions(runtimeType, place),
        );
      },
    );
  }

  String _normalizedRuntimeType(_RuntimePlaceConfig? config) {
    final type = config?.type.trim().toLowerCase();
    if (type == 'media' || type == 'observation' || type == 'physical') {
      return type!;
    }
    return 'media';
  }

  Widget _buildRuntimeTypePanel(
    String runtimeType,
    _RuntimePlaceConfig? runtimeConfig,
  ) {
    final theme = Theme.of(context);

    String title;
    String body;
    IconData icon;

    switch (runtimeType) {
      case 'physical':
        title = 'Épreuve physique';
        body =
            'Le poste est reconnu comme une épreuve physique. Le moteur peut déjà lire la mécanique, mais le calcul final du score sera activé quand les règles de poste seront stabilisées.';
        icon = Icons.directions_run;
        break;
      case 'observation':
        title = 'Observation';
        body =
            'Le poste est reconnu comme une observation. Le moteur peut déjà ouvrir une question ou une confirmation selon les données runtime disponibles.';
        icon = Icons.visibility;
        break;
      case 'media':
      default:
        title = 'Média';
        body =
            'Le poste est reconnu comme un média. La lecture finale passera par les slots média du backend lorsque le comportement de lecture sera activé.';
        icon = Icons.movie_filter;
        break;
    }

    final enginePreview = runtimeConfig == null
        ? null
        : _runtimeEnginePreview(runtimeConfig);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body),
          if (enginePreview != null && enginePreview.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              enginePreview,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _runtimeDialogActions(String runtimeType, PlaceNode place) {
    final actions = <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
    ];

    if (runtimeType == 'media') {
      actions.add(
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lecture média prête pour ${place.name}.'),
              ),
            );
          },
          child: const Text('Prévisualiser'),
        ),
      );
    }

    if (runtimeType == 'observation') {
      actions.add(
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _showObservationTestDialog(place);
          },
          child: const Text('Tester observation'),
        ),
      );
    }

    if (runtimeType == 'physical') {
      actions.add(
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _showPhysicalTestResult(place);
          },
          child: const Text('Tester épreuve'),
        ),
      );
    }

    return actions;
  }

  void _showObservationTestDialog(PlaceNode place) {
    final config = _runtimePlaceConfigById[place.id];
    final question = config?.observationQuestion?.trim().isNotEmpty == true
        ? config!.observationQuestion!.trim()
        : 'Observe le lieu et confirme ce que ton équipe constate.';
    final answerType = config?.observationAnswerType ?? 'confirmation';
    final hasSolution = config?.observationSolution?.trim().isNotEmpty == true;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Observation - ${place.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question),
                const SizedBox(height: 12),
                if (hasSolution) ...[
                  TextField(
                    controller: controller,
                    keyboardType: answerType == 'number'
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: answerType == 'number'
                          ? 'Réponse chiffrée'
                          : 'Réponse',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mode test : la réponse est comparée au contrat runtime quand il existe.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  Text(
                    'Mode confirmation : aucune solution n’est encore définie dans le runtime. Le poste valide seulement que l’observation a été faite.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            FilledButton(
              onPressed: () {
                final result = _runtimeObservationResult(
                  controller.text,
                  config,
                );
                Navigator.pop(context);
                _showObservationResult(place, result);
              },
              child: Text(hasSolution ? 'Valider' : 'Confirmer'),
            ),
          ],
        );
      },
    );
  }

  void _showObservationResult(PlaceNode place, String result) {
    final target = _runtimeRewardLabel(_runtimePlaceConfigById[place.id]);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Résultat observation - ${place.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Résultat runtime : $result'),
              if (target != null) ...[
                const SizedBox(height: 8),
                Text('Récompense visée : $target'),
              ],
              const SizedBox(height: 12),
              Text(
                'Ce test valide le moteur observation. Les vraies questions et solutions seront alimentées par le portal quand le contrat observation sera complété.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  String _runtimeObservationResult(
    String input,
    _RuntimePlaceConfig? config,
  ) {
    final solution = config?.observationSolution?.trim();
    if (solution == null || solution.isEmpty) {
      return 'confirmed';
    }

    final answerType = config?.observationAnswerType ?? 'text';
    final cleanInput = input.trim();

    if (answerType == 'number') {
      final expected = num.tryParse(solution.replaceAll(',', '.'));
      final actual = num.tryParse(cleanInput.replaceAll(',', '.'));
      if (expected == null || actual == null) return 'weak';
      final tolerance = config?.observationTolerance ?? 0;
      final diff = (actual - expected).abs();
      if (diff == 0) return 'strong';
      if (diff <= tolerance) return 'medium';
      return 'weak';
    }

    if (answerType == 'boolean') {
      final expected = _parseRuntimeBoolean(solution);
      final actual = _parseRuntimeBoolean(cleanInput);
      if (expected == null || actual == null) return 'weak';
      return expected == actual ? 'strong' : 'weak';
    }

    return cleanInput.toLowerCase() == solution.toLowerCase()
        ? 'strong'
        : 'weak';
  }

  bool? _parseRuntimeBoolean(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == 'oui' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == 'non' || normalized == 'no') {
      return false;
    }
    return null;
  }

  void _showPhysicalTestResult(PlaceNode place) {
    final config = _runtimePlaceConfigById[place.id];
    final random = Random();
    final score = random.nextInt(101);
    final result = _runtimePhysicalResult(score, config);
    final target = _runtimeRewardLabel(config);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Résultat de l’épreuve - ${place.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Score simulé : $score'),
              const SizedBox(height: 8),
              Text('Résultat runtime : $result'),
              if (target != null) ...[
                const SizedBox(height: 8),
                Text('Récompense visée : $target'),
              ],
              const SizedBox(height: 12),
              Text(
                'Ce test valide le moteur de score. Le score réel sera branché quand les règles précises du poste seront définies.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  String _runtimePhysicalResult(
    int score,
    _RuntimePlaceConfig? config,
  ) {
    final thresholds = config?.scoringThresholds ?? const <_RuntimeScoringThreshold>[];
    for (final threshold in thresholds) {
      if (threshold.matches(score)) {
        return threshold.result;
      }
    }

    if (score <= 30) return 'weak';
    if (score <= 70) return 'medium';
    return 'strong';
  }

  String? _runtimeRewardLabel(_RuntimePlaceConfig? config) {
    final targetType = config?.rewardTargetType?.trim();
    final targetSlot = config?.rewardTargetSlot?.trim();
    if (targetType == null || targetType.isEmpty) return null;
    if (targetSlot == null || targetSlot.isEmpty) return targetType;
    return '$targetType / $targetSlot';
  }

  String _runtimeOpeningMessage(String runtimeType) {
    switch (runtimeType) {
      case 'physical':
        return 'Épreuve physique à connecter plus tard.';
      case 'observation':
        return 'Poste d’observation prêt pour test.';
      case 'media':
      default:
        return 'Média à connecter plus tard.';
    }
  }

  String _runtimePlayerInstruction(_RuntimePlaceConfig config) {
    final type = config.type.trim().toLowerCase();
    final interaction = config.interaction?.trim().toLowerCase();
    final rules = config.rulesSummary?.trim();
    final scoring = config.scoringSummary?.trim();

    if (type == 'media') {
      if (rules != null && rules.contains('play_to_end')) {
        return 'Regarde attentivement le média jusqu’à la fin. Il prépare la suite de l’enquête.';
      }
      return 'Consulte le média disponible pour avancer dans l’enquête.';
    }

    if (type == 'observation') {
      if (interaction == 'confirmation_only') {
        return 'Observe le lieu, vérifie l’indice demandé, puis confirme quand l’équipe est sûre d’elle.';
      }
      if (interaction == 'numeric_input') {
        return 'Observe le lieu et saisis la réponse chiffrée demandée.';
      }
      if (interaction == 'text_input') {
        return 'Observe le lieu et saisis la réponse demandée.';
      }
      return 'Observe le lieu et réponds à la consigne du poste.';
    }

    if (type == 'physical') {
      final buffer = StringBuffer(
        'Réalise l’épreuve physique indiquée par le poste.',
      );
      if (scoring != null && scoring.isNotEmpty) {
        buffer.write(' Le résultat sera évalué selon la performance de l’équipe.');
      }
      return buffer.toString();
    }

    return 'Poste runtime prêt. Les consignes détaillées seront affichées ici.';
  }

  String _runtimeEnginePreview(_RuntimePlaceConfig config) {
    final parts = <String>[];

    if (config.mechanicMode != null && config.mechanicMode!.trim().isNotEmpty) {
      parts.add('mécanique: ${config.mechanicMode}');
    }
    if (config.interaction != null && config.interaction!.trim().isNotEmpty) {
      parts.add('interaction: ${config.interaction}');
    }
    if (config.rulesSummary != null && config.rulesSummary!.trim().isNotEmpty) {
      parts.add('règles: ${config.rulesSummary}');
    }
    if (config.scoringSummary != null && config.scoringSummary!.trim().isNotEmpty) {
      parts.add('scoring: ${config.scoringSummary}');
    } else if (config.hasScoring) {
      parts.add('scoring préparé');
    }
    if (config.rewardTargetType != null &&
        config.rewardTargetType!.trim().isNotEmpty) {
      final target = config.rewardTargetSlot == null ||
              config.rewardTargetSlot!.trim().isEmpty
          ? config.rewardTargetType!
          : '${config.rewardTargetType}/${config.rewardTargetSlot}';
      parts.add('récompense: $target');
    }

    if (parts.isEmpty) {
      return 'Moteur runtime prêt, configuration détaillée absente.';
    }

    return 'Moteur runtime préparé : ${parts.join(' · ')}.';
  }

  List<String> _missingPrerequisites(PlaceNode place) {
    final visitedIds = _places
        .where((p) => p.isVisited)
        .map((p) => p.id)
        .toSet();

    final missing = <String>[];

    for (final requiredId in place.requiresAllVisited) {
      if (!visitedIds.contains(requiredId)) {
        missing.add(requiredId);
      }
    }

    if (place.requiresAnyVisited.isNotEmpty &&
        !place.requiresAnyVisited.any(visitedIds.contains)) {
      missing.add('un des lieux ${place.requiresAnyVisited.join(", ")}');
    }

    return missing;
  }


  Future<Map<String, dynamic>?> _loadIncrementedCallContextForSession(
    String sessionId,
  ) async {
    try {
      final snap = await _firestore.collection('gameSessions').doc(sessionId).get();
      final data = snap.data();
      if (data == null) return null;
      return _incrementCallContext(_readCallContext(data));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _readCallContext(Map<String, dynamic> data) {
    final raw = data['callContext'];
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw as Map);
    final active = map['active'] == true;
    final phase = (map['phase'] ?? '').toString().trim();
    final callId = (map['callId'] ?? '').toString().trim();
    final sourceEvent = (map['sourceEvent'] ?? '').toString().trim();
    final callType = (map['callType'] ?? '').toString().trim();
    final displayName = (map['displayName'] ?? '').toString().trim();
    final audioUrl = (map['audioUrl'] ?? '').toString().trim();
    final backgroundImageUrl =
        (map['backgroundImageUrl'] ?? '').toString().trim();
    final retryPolicy = (map['retryPolicy'] ?? '').toString().trim();
    final uiVariant = (map['uiVariant'] ?? '').toString().trim();
    final ringtoneUrl = (map['ringtoneUrl'] ?? '').toString().trim();

    final attemptsRaw = map['helpAttemptsDuringCall'];
    final attempts = attemptsRaw is int
        ? attemptsRaw
        : attemptsRaw is num
            ? attemptsRaw.toInt()
            : int.tryParse(attemptsRaw?.toString() ?? '') ?? 0;

    final hasMinimalSignal =
        active || phase.isNotEmpty || callId.isNotEmpty || sourceEvent.isNotEmpty;
    final hasExtendedSignal =
        callType.isNotEmpty ||
        displayName.isNotEmpty ||
        audioUrl.isNotEmpty ||
        backgroundImageUrl.isNotEmpty ||
        retryPolicy.isNotEmpty ||
        uiVariant.isNotEmpty ||
        ringtoneUrl.isNotEmpty;

    if (!hasMinimalSignal && !hasExtendedSignal) {
      return null;
    }

    return {
      ...map,
      'active': active,
      'phase': phase.isEmpty ? 'resolved' : phase,
      'helpAttemptsDuringCall': attempts,
      'callId': callId,
      'sourceEvent': sourceEvent,
      'callType': callType,
      'displayName': displayName,
      'audioUrl': audioUrl,
      'backgroundImageUrl': backgroundImageUrl,
      'retryPolicy': retryPolicy,
      'uiVariant': uiVariant,
      'ringtoneUrl': ringtoneUrl,
    };
  }

  Map<String, dynamic>? _incrementCallContext(Map<String, dynamic>? context) {
    if (context == null || context['active'] != true) {
      return context;
    }

    final updated = Map<String, dynamic>.from(context);
    final attemptsRaw = updated['helpAttemptsDuringCall'];
    final attempts = attemptsRaw is int
        ? attemptsRaw
        : attemptsRaw is num
            ? attemptsRaw.toInt()
            : int.tryParse(attemptsRaw?.toString() ?? '') ?? 0;

    updated['helpAttemptsDuringCall'] = attempts + 1;
    return updated;
  }

  String _hintLevelLabel(String hintLevel) {
    switch (hintLevel.trim().toLowerCase()) {
      case 'high':
        return 'Fort';
      case 'medium':
        return 'Moyen';
      default:
        return 'Léger';
    }
  }

  String _hintLevelToBlockage(String hintLevel) {
    switch (hintLevel.trim().toLowerCase()) {
      case 'high':
        return 'high';
      case 'medium':
        return 'medium';
      default:
        return 'low';
    }
  }

  String _buildContextualAiBody(PlaceNode? place) {
    if (place == null) {
      return 'Aucun lieu précis n’est encore ciblé. L’assistant recommande de revenir sur la carte, de choisir un point d’intérêt, ou d’ouvrir un média déjà débloqué avant de demander une aide plus poussée.';
    }

    final missing = _missingPrerequisites(place);
    final visitedCount = _places.where((p) => p.isVisited).length;
    final revealHints = <String>[
      if (place.revealSuspect) 'ce lieu peut éclaircir la piste suspect',
      if (place.revealMotive) 'ce lieu peut éclaircir la piste mobile',
    ];

    final keywords = place.keywords.take(4).join(', ');

    final pieces = <String>[
      'Le blocage semble lié au lieu ${place.id} - ${place.name}.',
      if (keywords.trim().isNotEmpty)
        'Les mots-clés déjà associés à ce lieu sont : $keywords.',
      if (missing.isNotEmpty)
        'Avant d’insister ici, il manque encore : ${missing.join(", ")}.',
      if (missing.isEmpty)
        'Aucun prérequis bloquant évident n’est détecté pour ce lieu.',
      if (revealHints.isNotEmpty)
        'Indice de valeur : ${revealHints.join(" et ")}.',
      'Progression actuelle : $visitedCount lieu${visitedCount > 1 ? "x" : ""} visité${visitedCount > 1 ? "s" : ""} sur 9.',
    ];

    return pieces.join(' ');
  }

  List<String> _buildContextualAiBullets(PlaceNode? place) {
    if (place == null) {
      return const [
        'Choisis d’abord un lieu sur la carte ou via la commande vocale.',
        'Regarde si un média ou une archive déjà débloquée n’a pas été négligé.',
        'L’aide IA sera plus pertinente dès qu’un contexte de lieu sera connu.',
      ];
    }

    final bullets = <String>[
      'Recentre-toi sur ce que ${place.name} est censé apporter au dossier.',
      if (place.media.isNotEmpty)
        'Ce lieu contient des médias: vérifie si tout a bien été consulté.',
      if (place.keywords.isNotEmpty)
        'Relis les mots-clés du lieu pour retrouver l’angle d’analyse attendu.',
    ];

    final missing = _missingPrerequisites(place);
    if (missing.isNotEmpty) {
      bullets.add('Certains prérequis semblent manquer : ${missing.join(", ")}.');
    } else {
      bullets.add('Rien n’indique un verrou de progression strict sur ce lieu.');
    }

    if (place.revealSuspect || place.revealMotive) {
      bullets.add(
        'Ce lieu peut faire tomber une hypothèse, pas forcément révéler frontalement la solution.',
      );
    }

    return bullets;
  }

  void _tryExitGame() {
    if (!canExitNarrative) {
      final missing = missingMainPlaceIds;
      final missingLabel = missing.isEmpty ? 'aucun' : missing.join(', ');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La porte reste fermée. Il manque encore les jalons majeurs : $missingLabel.',
          ),
        ),
      );
      return;
    }

    _openFinalAnswerDialog();
  }

  void _openFinalAnswerDialog() {
    final session = _session;
    if (session == null) return;

    String? selectedSuspectId;
    String? selectedMotiveId;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Réponse finale'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Qui est coupable, et quel est le mobile ?',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedSuspectId,
                      decoration: const InputDecoration(
                        labelText: 'Coupable',
                        border: OutlineInputBorder(),
                      ),
                      items: _suspects.map((suspect) {
                        return DropdownMenuItem<String>(
                          value: suspect.id,
                          child: Text(suspect.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setLocalState(() {
                          selectedSuspectId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMotiveId,
                      decoration: const InputDecoration(
                        labelText: 'Mobile',
                        border: OutlineInputBorder(),
                      ),
                      items: _motives.map((motive) {
                        return DropdownMenuItem<String>(
                          value: motive.id,
                          child: Text(motive.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setLocalState(() {
                          selectedMotiveId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);

                    final suspectOk = selectedSuspectId == session.trueSuspectId;
                    final motiveOk = selectedMotiveId == session.trueMotiveId;

                    String message;
                    if (selectedSuspectId == null || selectedMotiveId == null) {
                      message =
                          'Tu dois choisir un coupable et un mobile avant de valider.';
                    } else if (suspectOk && motiveOk) {
                      message =
                          'Bravo, tu as identifié le bon coupable et le bon mobile.';
                    } else if (suspectOk && !motiveOk) {
                      message =
                          'Tu as trouvé le bon coupable, mais pas le bon mobile.';
                    } else if (!suspectOk && motiveOk) {
                      message =
                          'Tu as trouvé le bon mobile, mais pas le bon coupable.';
                    } else {
                      message =
                          'Ce n’est pas la bonne combinaison coupable / mobile.';
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  },
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _resetGameFull() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _storagePrefix ?? 'session_unknown';

    await prefs.remove('${prefix}_visited_places');
    await prefs.remove('${prefix}_game_session_local');
    await prefs.remove('${prefix}_current_help_place_id');

    if (!mounted) return;

    setState(() {
      for (final place in _places) {
        place.isVisited = false;
      }
      _currentHelpPlaceId = null;
      if (_session != null) {
        _session = GameSession(
          id: _session!.id,
          activationCode: _session!.activationCode,
          lockedScenarioId: _session!.lockedScenarioId,
          siteId: _session!.siteId,
          status: _session!.status,
          startedAt: _session!.startedAt,
          expiresAt: _session!.expiresAt,
          trueSuspectId: _session!.trueSuspectId,
          trueMotiveId: _session!.trueMotiveId,
          suspectByPlace: _session!.suspectByPlace,
          motiveByPlace: _session!.motiveByPlace,
          humanHelpEnabled: _session!.humanHelpEnabled,
        );
      }
      currentIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Jeu réinitialisé pour cette session.')),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          ScenarioScreen(
            progress: progressRatio,
            canExit: canExitNarrative,
            onOpenMap: () => setState(() => currentIndex = 1),
            onOpenArchives: () => setState(() => currentIndex = 2),
            onOpenInvestigation: () => setState(() => currentIndex = 3),
            onOpenMicro: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Micro (à connecter)')),
              );
            },
            onOpenSOS: () async {
              final session = _session;
              if (session == null) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Session introuvable pour la demande d’aide.'),
                  ),
                );
                return;
              }

              final helpPlace = _currentHelpPlace();
              final placeContext = helpPlace == null
                  ? null
                  : AiHelpPlaceContext(
                      id: helpPlace.id,
                      name: helpPlace.name,
                      keywords: helpPlace.keywords,
                      requiresAllVisited: helpPlace.requiresAllVisited,
                      requiresAnyVisited: helpPlace.requiresAnyVisited,
                      revealSuspect: helpPlace.revealSuspect,
                      revealMotive: helpPlace.revealMotive,
                      mediaCount: helpPlace.media.length,
                    );

              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SOSSreen(
                    sessionId: session.id,
                    scenarioTitle: 'Les Fugitifs',
                    progress: progress,
                    aiHelpCount: session.aiHelpCount,
                    currentBlockageLevel: session.currentBlockageLevel,
                    visitedPlaces: _places
                        .where((p) => p.isVisited)
                        .map((p) => p.id)
                        .toList(growable: false),
                    blockedPrerequisites: helpPlace == null
                        ? const <String>[]
                        : _missingPrerequisites(helpPlace),
                    humanHelpEnabledOverride: session.humanHelpEnabled,
                    placeContext: placeContext,
                  ),
                ),
              );
            },
            onExit: _tryExitGame,
            onMasterReset: _resetGameFull,
            debugMasterReset: false,
          ),
          MapScreen(
            onBack: () => setState(() => currentIndex = 0),
            places: _places,
            onPlaceVisited: _markPlaceVisited,
            onOpenPlaceMedia: _openPlaceMedia,
            onPlaceSelected: _setCurrentHelpPlace,
          ),
          ArchivesScreen(
            onBack: () => setState(() => currentIndex = 0),
            places: _places,
            onOpenPlaceMedia: _openPlaceMedia,
          ),
          InvestigationScreen(
            onBack: () => setState(() => currentIndex = 0),
            suspects: _suspects,
            motives: _motives,
            markedSuspectIds: _session?.playerMarkedSuspectIds ?? <String>{},
            markedMotiveIds: _session?.playerMarkedMotiveIds ?? <String>{},
            onToggleSuspect: _toggleSuspect,
            onToggleMotive: _toggleMotive,
          ),
        ],
      ),
    );
  }
}
