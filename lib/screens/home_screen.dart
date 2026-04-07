import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_session.dart';
import '../models/motive_model.dart';
import '../models/place_node.dart';
import '../models/suspect_model.dart';
import '../services/runtime_session_service.dart';

import 'archives_screen.dart';
import 'investigation_screen.dart';
import 'map_screen.dart';
import 'scenario_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _SosStep {
  intro,
  ai,
  escalation,
  result,
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

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  int get progress => _places.where((p) => p.isVisited).length.clamp(0, 9);

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
    if (progress < 9) {
      final remaining = 9 - progress;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La porte reste fermée. Il te manque encore $remaining lieu${remaining > 1 ? 'x' : ''}.',
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

  Future<void> _openSosFlow() async {
    if (_session == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session introuvable pour la demande d’aide.'),
        ),
      );
      return;
    }

    final helpPlace = _currentHelpPlace();

    _SosStep step = _SosStep.intro;
    String resultTitle = '';
    String resultBody = '';
    bool resultNeedsMj = false;
    bool remoteSyncFailed = false;
    String? remoteSyncError;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Aide',
      barrierColor: Colors.black.withOpacity(0.70),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> finishAiHelp() async {
              final current = _session;
              if (current == null) return;

              final updated = GameSession(
                id: current.id,
                activationCode: current.activationCode,
                lockedScenarioId: current.lockedScenarioId,
                siteId: current.siteId,
                status: current.status,
                startedAt: current.startedAt,
                expiresAt: current.expiresAt,
                trueSuspectId: current.trueSuspectId,
                trueMotiveId: current.trueMotiveId,
                suspectByPlace: current.suspectByPlace,
                motiveByPlace: current.motiveByPlace,
                playerMarkedSuspectIds: current.playerMarkedSuspectIds,
                playerMarkedMotiveIds: current.playerMarkedMotiveIds,
                humanHelpEnabled: current.humanHelpEnabled,
                humanEscalationRequired: false,
                humanEscalationStatus: current.humanEscalationStatus,
                aiHelpCount: current.aiHelpCount + 1,
                currentBlockageLevel: 'low',
                lastHelpRequestAt: DateTime.now().toUtc().toIso8601String(),
              );

              setState(() {
                _session = updated;
              });
              await _saveProgress();

              remoteSyncFailed = false;
              remoteSyncError = null;
              try {
                await _syncAssistanceToFirestore(
                  session: updated,
                  timelineType: 'player_ai_help_used',
                  timelineLabel: helpPlace == null
                      ? 'Aide IA utilisée par le joueur'
                      : 'Aide IA utilisée par le joueur sur ${helpPlace.name}',
                );
              } catch (e) {
                remoteSyncFailed = true;
                remoteSyncError = e.toString();
              }

              resultTitle = remoteSyncFailed
                  ? 'Aide IA locale enregistrée'
                  : 'Aide IA envoyée';
              resultBody = remoteSyncFailed
                  ? 'L’aide IA a été enregistrée localement, mais la synchronisation Firestore a échoué. Le joueur peut continuer, mais le MJ ne verra pas encore cet événement.'
                  : 'L’assistant a pris en compte le blocage et a proposé un recentrage lié au contexte actuel du joueur. La tentative a aussi été synchronisée dans Firestore.';
              resultNeedsMj = false;

              setLocalState(() {
                step = _SosStep.result;
              });
            }

            Future<void> escalateAfterAiFailure() async {
              final current = _session;
              if (current == null) return;

              final nowIso = DateTime.now().toUtc().toIso8601String();

              GameSession updated;
              String timelineType;
              String timelineLabel;

              if (current.humanHelpEnabled) {
                updated = GameSession(
                  id: current.id,
                  activationCode: current.activationCode,
                  lockedScenarioId: current.lockedScenarioId,
                  siteId: current.siteId,
                  status: current.status,
                  startedAt: current.startedAt,
                  expiresAt: current.expiresAt,
                  trueSuspectId: current.trueSuspectId,
                  trueMotiveId: current.trueMotiveId,
                  suspectByPlace: current.suspectByPlace,
                  motiveByPlace: current.motiveByPlace,
                  playerMarkedSuspectIds: current.playerMarkedSuspectIds,
                  playerMarkedMotiveIds: current.playerMarkedMotiveIds,
                  humanHelpEnabled: current.humanHelpEnabled,
                  humanEscalationRequired: true,
                  humanEscalationStatus: 'pending',
                  aiHelpCount: current.aiHelpCount + 1,
                  currentBlockageLevel: 'medium',
                  lastHelpRequestAt: nowIso,
                );
                timelineType = 'player_human_help_requested';
                timelineLabel = helpPlace == null
                    ? 'Le joueur demande une aide humaine après échec de l’IA'
                    : 'Le joueur demande une aide humaine sur ${helpPlace.name} après échec de l’IA';
                resultNeedsMj = true;
              } else {
                updated = GameSession(
                  id: current.id,
                  activationCode: current.activationCode,
                  lockedScenarioId: current.lockedScenarioId,
                  siteId: current.siteId,
                  status: current.status,
                  startedAt: current.startedAt,
                  expiresAt: current.expiresAt,
                  trueSuspectId: current.trueSuspectId,
                  trueMotiveId: current.trueMotiveId,
                  suspectByPlace: current.suspectByPlace,
                  motiveByPlace: current.motiveByPlace,
                  playerMarkedSuspectIds: current.playerMarkedSuspectIds,
                  playerMarkedMotiveIds: current.playerMarkedMotiveIds,
                  humanHelpEnabled: current.humanHelpEnabled,
                  humanEscalationRequired: false,
                  humanEscalationStatus: '',
                  aiHelpCount: current.aiHelpCount + 1,
                  currentBlockageLevel: 'medium',
                  lastHelpRequestAt: nowIso,
                );
                timelineType = 'player_ai_help_failed_no_human_help';
                timelineLabel = helpPlace == null
                    ? 'Le joueur reste bloqué, aide humaine désactivée'
                    : 'Le joueur reste bloqué sur ${helpPlace.name}, aide humaine désactivée';
                resultNeedsMj = false;
              }

              setState(() {
                _session = updated;
              });
              await _saveProgress();

              remoteSyncFailed = false;
              remoteSyncError = null;
              try {
                await _syncAssistanceToFirestore(
                  session: updated,
                  timelineType: timelineType,
                  timelineLabel: timelineLabel,
                );
              } catch (e) {
                remoteSyncFailed = true;
                remoteSyncError = e.toString();
              }

              if (updated.humanHelpEnabled) {
                resultTitle = remoteSyncFailed
                    ? 'Escalade locale préparée'
                    : 'Demande transmise au MJ';
                resultBody = remoteSyncFailed
                    ? 'L’escalade a bien été préparée dans la session locale, mais l’écriture Firestore a échoué. Le MJ ne verra pas encore la demande tant que la synchronisation distante ne passera pas.'
                    : 'L’IA n’a pas suffi. Comme l’aide humaine est autorisée dans cette session, la demande a été synchronisée vers gameSessions et doit maintenant être visible côté MJ.';
              } else {
                resultTitle = remoteSyncFailed
                    ? 'Aide humaine indisponible'
                    : 'Aide humaine indisponible';
                resultBody = remoteSyncFailed
                    ? 'L’IA n’a pas suffi, l’aide humaine est désactivée, et la synchronisation Firestore a également échoué. La tentative reste enregistrée localement.'
                    : 'L’IA n’a pas suffi, mais l’aide humaine n’est pas autorisée dans cette session. La tentative a tout de même été synchronisée pour garder une trace côté MJ.';
              }

              setLocalState(() {
                step = _SosStep.result;
              });
            }

            final size = MediaQuery.of(context).size;
            final maxDialogHeight = size.height * 0.84;

            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 760,
                      maxHeight: maxDialogHeight,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF101A2A),
                              Color(0xFF0A1220),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF28405D),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 34,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD65A00).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFD65A00).withOpacity(0.55),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.sticky_note_2_outlined,
                                        color: Color(0xFFFFD7B8),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Text(
                                        'Post-it Help',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      icon: const Icon(
                                        Icons.close,
                                        color: Color(0xFFD6E2F2),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Session ${_session!.id} · aide humaine ${_session!.humanHelpEnabled ? 'autorisée' : 'désactivée'} · aides IA ${_session!.aiHelpCount}',
                                  style: const TextStyle(
                                    color: Color(0xFF93A2B7),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _HelpStepChip(
                                      label: '1. Demande',
                                      active: step == _SosStep.intro,
                                      done: step.index > _SosStep.intro.index,
                                    ),
                                    _HelpStepChip(
                                      label: '2. IA',
                                      active: step == _SosStep.ai,
                                      done: step.index > _SosStep.ai.index,
                                    ),
                                    _HelpStepChip(
                                      label: '3. Décision',
                                      active: step == _SosStep.escalation,
                                      done: step.index > _SosStep.escalation.index,
                                    ),
                                    _HelpStepChip(
                                      label: '4. Résultat',
                                      active: step == _SosStep.result,
                                      done: false,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (step == _SosStep.intro)
                                  _HelpPanel(
                                    title: 'Besoin d’un coup de pouce',
                                    icon: Icons.help_outline,
                                    body: _buildContextualAiBody(helpPlace),
                                    bullets: _buildContextualAiBullets(helpPlace),
                                    footer:
                                        'Le lieu actuellement ciblé par le joueur sert maintenant de contexte pour produire une aide plus fine et pour documenter la demande côté MJ.',
                                  ),
                                if (step == _SosStep.ai)
                                  _HelpPanel(
                                    title: 'Aide IA contextuelle',
                                    icon: Icons.memory_outlined,
                                    body: helpPlace == null
                                        ? 'Aucun lieu n’est ciblé. L’assistant reste prudent et propose un recentrage général sur la carte, les archives ou les lieux déjà débloqués.'
                                        : 'L’assistant se base sur ${helpPlace.id} - ${helpPlace.name}, ses mots-clés, ses prérequis et la progression du joueur pour proposer un recentrage moins générique.',
                                    bullets: [
                                      if (helpPlace != null)
                                        'Lieu ciblé : ${helpPlace.id} - ${helpPlace.name}',
                                      if (helpPlace != null && helpPlace.keywords.isNotEmpty)
                                        'Mots-clés : ${helpPlace.keywords.take(4).join(", ")}',
                                      'Une tentative supplémentaire augmente le compteur d’aide IA.',
                                      'Si cela ne suffit pas, on passera à la décision humaine.',
                                    ],
                                    footer:
                                        'Cette étape synchronise maintenant aussi l’événement dans Firestore pour que le MJ puisse suivre la suite.',
                                  ),
                                if (step == _SosStep.escalation)
                                  _HelpPanel(
                                    title: 'Décision d’escalade',
                                    icon: Icons.support_agent_outlined,
                                    body: _session!.humanHelpEnabled
                                        ? 'L’aide humaine est autorisée dans cette session. Si l’IA ne suffit pas, la demande sera marquée en attente pour le MJ.'
                                        : 'L’aide humaine est désactivée dans cette session. Si l’IA ne suffit pas, le joueur restera sur une information locale sans escalade MJ.',
                                    bullets: [
                                      'Aide humaine autorisée : ${_session!.humanHelpEnabled ? 'oui' : 'non'}',
                                      'Compteur IA actuel : ${_session!.aiHelpCount}',
                                      'Blocage actuel : ${_session!.currentBlockageLevel.isEmpty ? 'aucun' : _session!.currentBlockageLevel}',
                                    ],
                                    footer:
                                        'Cette étape écrit désormais les champs attendus dans gameSessions afin que le bureau MJ voie la demande.',
                                  ),
                                if (step == _SosStep.result)
                                  _HelpPanel(
                                    title: resultTitle,
                                    icon: resultNeedsMj
                                        ? Icons.flag_outlined
                                        : Icons.mark_chat_read_outlined,
                                    body: resultBody,
                                    bullets: [
                                      'Aides IA enregistrées : ${_session!.aiHelpCount}',
                                      'Escalade requise : ${_session!.humanEscalationRequired ? 'oui' : 'non'}',
                                      'Statut d’escalade : ${_session!.humanEscalationStatus.isEmpty ? 'aucun' : _session!.humanEscalationStatus}',
                                      if (remoteSyncFailed)
                                        'Synchronisation distante : échec',
                                      if (!remoteSyncFailed)
                                        'Synchronisation distante : réussie',
                                    ],
                                    footer: remoteSyncFailed && remoteSyncError != null
                                        ? 'Détail technique : $remoteSyncError'
                                        : 'La session locale et la session Firestore sont maintenant alignées sur le flux d’aide.',
                                  ),
                                const SizedBox(height: 18),
                                if (step == _SosStep.intro)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text('Fermer'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: FilledButton.icon(
                                          onPressed: () {
                                            setLocalState(() {
                                              step = _SosStep.ai;
                                            });
                                          },
                                          icon: const Icon(Icons.psychology_alt_outlined),
                                          label: const Text('Demander une aide IA'),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (step == _SosStep.ai)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: finishAiHelp,
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: const Text('Cette aide IA me suffit'),
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setLocalState(() {
                                            step = _SosStep.escalation;
                                          });
                                        },
                                        icon: const Icon(Icons.support_agent_outlined),
                                        label: const Text('L’IA ne m’aide pas'),
                                      ),
                                    ],
                                  ),
                                if (step == _SosStep.escalation)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: escalateAfterAiFailure,
                                        icon: const Icon(Icons.flag_outlined),
                                        label: Text(
                                          _session!.humanHelpEnabled
                                              ? 'Escalader vers le MJ'
                                              : 'Constater l’échec sans aide humaine',
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setLocalState(() {
                                            step = _SosStep.ai;
                                          });
                                        },
                                        icon: const Icon(Icons.arrow_back),
                                        label: const Text('Retour à l’étape IA'),
                                      ),
                                    ],
                                  ),
                                if (step == _SosStep.result)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            setLocalState(() {
                                              step = _SosStep.intro;
                                            });
                                          },
                                          icon: const Icon(Icons.replay),
                                          label: const Text('Rejouer le flux'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text('Retour au bureau'),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (!mounted) return;

    final summary = _session == null
        ? 'Aucune session active.'
        : _session!.humanEscalationRequired
            ? 'Demande d’aide synchronisée pour le MJ.'
            : 'Session locale et Firestore mises à jour.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(summary)),
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
            progress: progress,
            canExit: progress >= 9,
            onOpenMap: () => setState(() => currentIndex = 1),
            onOpenArchives: () => setState(() => currentIndex = 2),
            onOpenInvestigation: () => setState(() => currentIndex = 3),
            onOpenMicro: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Micro (à connecter)')),
              );
            },
            onOpenSOS: _openSosFlow,
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

class _HelpPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final String body;
  final List<String> bullets;
  final String footer;

  const _HelpPanel({
    required this.title,
    required this.icon,
    required this.body,
    required this.bullets,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1726),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF24364F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFD7B8)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFD6E2F2),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.arrow_right_alt,
                      color: Color(0xFFD65A00),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(
                        color: Color(0xFFB9C7D8),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF121E31),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2B4566)),
            ),
            child: Text(
              footer,
              style: const TextStyle(
                color: Color(0xFFAED0FF),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpStepChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;

  const _HelpStepChip({
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = active
        ? const Color(0xFFD65A00)
        : done
            ? const Color(0xFF2E8B57)
            : const Color(0xFF29405C);

    final backgroundColor = active
        ? const Color(0xFF3A2112)
        : done
            ? const Color(0xFF14261A)
            : const Color(0xFF101925);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
