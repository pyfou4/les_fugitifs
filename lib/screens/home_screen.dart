import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_session.dart';
import '../models/motive_model.dart';
import '../models/place_node.dart';
import '../models/suspect_model.dart';
import '../services/ai_service.dart';
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

  static const Map<String, int> _weightedProgressByPlaceId = {
    'A0': 18,
    'B0': 18,
    'C0': 18,
    'D0': 18,
    'A1': 6,
    'A2': 6,
    'B1': 5,
    'B2': 5,
    'C1': 6,
  };

  static const List<String> _requiredMainPlaceIds = [
    'A0',
    'B0',
    'C0',
    'D0',
  ];

  Set<String> get _visitedPlaceIds =>
      _places.where((p) => p.isVisited).map((p) => p.id).toSet();

  int get narrativeProgressScore {
    int score = 0;
    final visitedIds = _visitedPlaceIds;

    for (final entry in _weightedProgressByPlaceId.entries) {
      if (visitedIds.contains(entry.key)) {
        score += entry.value;
      }
    }

    return score.clamp(0, 100);
  }

  double get progressRatio {
    return (narrativeProgressScore / 100).clamp(0.0, 1.0);
  }

  bool get canExitNarrative {
    final visitedIds = _visitedPlaceIds;
    return _requiredMainPlaceIds.every(visitedIds.contains);
  }

  List<String> get missingMainPlaceIds {
    final visitedIds = _visitedPlaceIds;
    return _requiredMainPlaceIds.where((id) => !visitedIds.contains(id)).toList();
  }

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

    final revealedSuspect = _findSuspect(_session?.suspectByPlace[place.id]);
    final revealedMotive = _findMotive(_session?.motiveByPlace[place.id]);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(place.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Média à connecter plus tard.'),
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


  Future<AiHelpCallContext?> _loadIncrementedCallContextForSession(String sessionId) async {
    try {
      final snap = await _firestore.collection('gameSessions').doc(sessionId).get();
      final data = snap.data();
      if (data == null) return null;
      return _incrementCallContext(_readCallContext(data));
    } catch (_) {
      return null;
    }
  }

  AiHelpCallContext? _readCallContext(Map<String, dynamic> data) {
    final raw = data['callContext'];
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw as Map);
    final active = map['active'] == true;
    final phase = (map['phase'] ?? '').toString().trim();
    final callId = (map['callId'] ?? '').toString().trim();
    final sourceEvent = (map['sourceEvent'] ?? '').toString().trim();

    final attemptsRaw = map['helpAttemptsDuringCall'];
    final attempts = attemptsRaw is int
        ? attemptsRaw
        : attemptsRaw is num
            ? attemptsRaw.toInt()
            : int.tryParse(attemptsRaw?.toString() ?? '') ?? 0;

    if (!active && phase.isEmpty && callId.isEmpty && sourceEvent.isEmpty) {
      return null;
    }

    return AiHelpCallContext(
      active: active,
      phase: phase.isEmpty ? 'resolved' : phase,
      helpAttemptsDuringCall: attempts,
      callId: callId,
      sourceEvent: sourceEvent,
    );
  }

  AiHelpCallContext? _incrementCallContext(AiHelpCallContext? context) {
    if (context == null || !context.active) return context;
    return AiHelpCallContext(
      active: context.active,
      phase: context.phase,
      helpAttemptsDuringCall: context.helpAttemptsDuringCall + 1,
      callId: context.callId,
      sourceEvent: context.sourceEvent,
    );
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
