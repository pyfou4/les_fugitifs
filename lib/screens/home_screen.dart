import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  final AiService _aiService = AiService();
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
  final TextEditingController _sosQuestionController = TextEditingController();
  final stt.SpeechToText _sosSpeechToText = stt.SpeechToText();

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  @override
  void dispose() {
    _humanHelpMessagesSubscription?.cancel();
    _sosQuestionController.dispose();
    _sosSpeechToText.stop();
    super.dispose();
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


  String _buildDefaultHelpQuestion(PlaceNode? place) {
    if (place == null) {
      return 'Nous sommes bloqués. Quelle piste devrions-nous analyser maintenant sans spoiler la solution ?';
    }

    return 'Nous sommes bloqués sur ${place.name}. Que devrions-nous vérifier ou recouper sans révélation directe ?';
  }

  String _buildHumanHelpStatusLine(bool humanHelpEnabled) {
    return humanHelpEnabled
        ? 'Le canal de supervision peut encore être sollicité si l’analyse automatique ne suffit pas.'
        : 'Le canal de supervision est fermé. Aucune intervention humaine ne peut être sollicitée pour cette session.';
  }

  bool _canUnlockHumanRelay(GameSession? session) {
    if (session == null) return false;
    if (!session.humanHelpEnabled) return false;
    return session.aiHelpCount >= 4;
  }

  int _remainingAnalysesBeforeHumanRelay(GameSession? session) {
    if (session == null || !session.humanHelpEnabled) return 0;
    final remaining = 4 - session.aiHelpCount;
    return remaining > 0 ? remaining : 0;
  }

  String _buildHumanRelayGateText(GameSession? session) {
    if (session == null) {
      return 'Analyse en cours.';
    }
    if (!session.humanHelpEnabled) {
      return 'Le canal humain reste verrouillé pour cette session.';
    }
    final remaining = _remainingAnalysesBeforeHumanRelay(session);
    if (remaining <= 0) {
      return 'Relais humain déverrouillé.';
    }
    if (remaining == 1) {
      return 'Encore 1 analyse avant relais humain.';
    }
    return 'Encore $remaining analyses avant relais humain.';
  }


  String _buildImmersiveResultTitle({
    required bool needsMj,
    required bool humanHelpEnabled,
    required bool remoteSyncFailed,
  }) {
    if (needsMj) {
      return remoteSyncFailed
          ? 'Transmission instable'
          : 'Signal relayé';
    }

    if (!humanHelpEnabled) {
      return 'Canal verrouillé';
    }

    return remoteSyncFailed ? 'Trace locale conservée' : 'Trace enregistrée';
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
    _sosQuestionController.text = _buildDefaultHelpQuestion(helpPlace);

    _SosStep step = _SosStep.intro;
    String resultTitle = '';
    String resultBody = '';
    bool resultNeedsMj = false;
    bool remoteSyncFailed = false;
    String? remoteSyncError;
    bool aiLoading = false;
    AiHelpResponse? aiResponse;
    bool sosListening = false;
    bool showTextFallback = false;
    String heardPreview = '';

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Aide',
      barrierColor: Colors.black.withOpacity(0.76),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> stopListening() async {
              if (_sosSpeechToText.isListening) {
                await _sosSpeechToText.stop();
              }
              if (mounted) {
                setLocalState(() {
                  sosListening = false;
                });
              }
            }

            Future<void> startListening() async {
              final available = await _sosSpeechToText.initialize(
                onStatus: (status) {
                  if (!mounted) return;
                  if (status == 'done' || status == 'notListening') {
                    setLocalState(() {
                      sosListening = false;
                    });
                  }
                },
                onError: (_) {
                  if (!mounted) return;
                  setLocalState(() {
                    sosListening = false;
                    showTextFallback = !showTextFallback;
                  });
                },
              );

              if (!available) {
                if (!mounted) return;
                setLocalState(() {
                  sosListening = false;
                  showTextFallback = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La saisie vocale est indisponible. Utilise le champ texte.',
                    ),
                  ),
                );
                return;
              }

              setLocalState(() {
                heardPreview = '';
                sosListening = true;
              });

              await _sosSpeechToText.listen(
                localeId: 'fr_FR',
                listenMode: stt.ListenMode.confirmation,
                onResult: (result) async {
                  if (!mounted) return;
                  setLocalState(() {
                    heardPreview = result.recognizedWords.trim();
                    if (heardPreview.isNotEmpty) {
                      _sosQuestionController.text = heardPreview;
                    }
                  });

                  if (result.finalResult) {
                    await _sosSpeechToText.stop();
                    if (!mounted) return;
                    setLocalState(() {
                      sosListening = false;
                      if (heardPreview.isEmpty || heardPreview.length < 8) {
                        showTextFallback = true;
                      }
                    });
                  }
                },
              );
            }

            Future<void> requestAiHelp() async {
              final current = _session;
              if (current == null) return;

              final playerQuestion = _sosQuestionController.text.trim();
              if (playerQuestion.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Décris d’abord précisément ton blocage.'),
                  ),
                );
                setLocalState(() {
                  showTextFallback = true;
                });
                return;
              }

              await stopListening();

              setLocalState(() {
                step = _SosStep.ai;
                aiLoading = true;
                aiResponse = null;
              });

              try {
                final response = await _aiService.getStructuredHelp(
                  sessionId: current.id,
                  scenarioTitle: 'Les Fugitifs',
                  progress: progress,
                  aiHelpCount: current.aiHelpCount,
                  currentBlockageLevel: current.currentBlockageLevel,
                  humanHelpEnabled: current.humanHelpEnabled,
                  visitedPlaces: _places
                      .where((p) => p.isVisited)
                      .map((p) => p.id)
                      .toList(growable: false),
                  blockedPrerequisites: helpPlace == null
                      ? const <String>[]
                      : _missingPrerequisites(helpPlace),
                  place: helpPlace == null
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
                        ),
                  playerQuestion: playerQuestion,
                );

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
                  currentBlockageLevel: _hintLevelToBlockage(response.hintLevel),
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
                        ? 'Aide IA générée (${_hintLevelLabel(response.hintLevel)})'
                        : 'Aide IA générée sur ${helpPlace.name} (${_hintLevelLabel(response.hintLevel)})',
                  );
                } catch (e) {
                  remoteSyncFailed = true;
                  remoteSyncError = e.toString();
                }

                setLocalState(() {
                  aiResponse = response;
                  aiLoading = false;
                });
              } catch (e) {
                final errorText = e.toString();
                setLocalState(() {
                  aiLoading = false;
                  aiResponse = AiHelpResponse(
                    message: 'L’assistance IA n’a pas pu être récupérée.',
                    hintLevel: 'low',
                    nextAction: errorText,
                    confidence: 0.0,
                    responseMode: 'reframe',
                    shouldEscalate: false,
                    reasonTag: 'unknown',
                  );
                  remoteSyncFailed = true;
                  remoteSyncError = errorText;
                });
              }
            }

            Future<void> finishAiHelp() async {
              final current = _session;
              if (current == null) return;

              resultTitle = _buildImmersiveResultTitle(
                needsMj: false,
                humanHelpEnabled: current.humanHelpEnabled,
                remoteSyncFailed: remoteSyncFailed,
              );
              resultBody = aiResponse?.message.isNotEmpty == true
                  ? aiResponse!.message
                  : 'Le système a intégré une aide contextuelle au dossier.';
              resultNeedsMj = false;

              setLocalState(() {
                step = _SosStep.result;
              });
            }

            Future<void> escalateAfterAiFailure() async {
              final current = _session;
              if (current == null) return;

              if (!_canUnlockHumanRelay(current)) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_buildHumanRelayGateText(current)),
                  ),
                );
                return;
              }

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
                  aiHelpCount: current.aiHelpCount,
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
                  aiHelpCount: current.aiHelpCount,
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
                resultTitle = _buildImmersiveResultTitle(
                  needsMj: true,
                  humanHelpEnabled: updated.humanHelpEnabled,
                  remoteSyncFailed: remoteSyncFailed,
                );
                resultBody = remoteSyncFailed
                    ? 'L’escalade a bien été préparée dans la session locale, mais l’écriture Firestore a échoué. Le maître du jeu ne verra pas encore la demande tant que la synchronisation distante ne passera pas.'
                    : 'L’analyse automatique n’a pas suffi. Le signal a été transmis au maître du jeu.';
              } else {
                resultTitle = _buildImmersiveResultTitle(
                  needsMj: false,
                  humanHelpEnabled: updated.humanHelpEnabled,
                  remoteSyncFailed: remoteSyncFailed,
                );
                resultBody = remoteSyncFailed
                    ? 'L’analyse automatique n’a pas suffi, le canal humain est fermé, et la synchronisation Firestore a également échoué. La tentative reste enregistrée localement.'
                    : 'L’analyse automatique n’a pas suffi, et aucun relais humain ne peut être sollicité pour cette session.';
              }

              setLocalState(() {
                step = _SosStep.result;
              });
            }

            final size = MediaQuery.of(context).size;
            final maxDialogHeight = size.height * 0.81;
            final canUseHumanRelay = _canUnlockHumanRelay(_session);
            final humanRelayGateText = _buildHumanRelayGateText(_session);

            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 520,
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
                              Color(0xFF0C1017),
                              Color(0xFF080B11),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF233247),
                            width: 1.1,
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
                          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD65A00).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFD65A00).withOpacity(0.35),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.graphic_eq,
                                      color: Color(0xFFFFD7B8),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Ligne d’urgence',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          _session!.humanHelpEnabled
                                              ? 'Canal de supervision ouvert'
                                              : 'Canal de supervision fermé',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF93A2B7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      await stopListening();
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.close,
                                      color: Color(0xFFD6E2F2),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: step == _SosStep.intro
                                      ? _HelpComposerPanel(
                                          key: const ValueKey('intro'),
                                          place: helpPlace,
                                          controller: _sosQuestionController,
                                          contextBody: _buildContextualAiBody(helpPlace),
                                          bullets: _buildContextualAiBullets(helpPlace),
                                          isListening: sosListening,
                                          heardPreview: heardPreview,
                                          showTextFallback: showTextFallback,
                                          onStartListening: startListening,
                                          onStopListening: stopListening,
                                          onShowTextFallback: () {
                                            setLocalState(() {
                                              showTextFallback = !showTextFallback;
                                            });
                                          },
                                        )
                                      : step == _SosStep.ai
                                          ? (aiLoading
                                              ? const _HelpLoadingPanel(key: ValueKey('loading'))
                                              : _HelpPanel(
                                                  key: const ValueKey('ai'),
                                                  title: 'Retour de la Grid',
                                                  icon: Icons.psychology_alt_outlined,
                                                  body: aiResponse?.message ??
                                                      'La Grid prépare son retour contextuel.',
                                                  bullets: [
                                                    if ((aiResponse?.nextAction ?? '').trim().isNotEmpty)
                                                      aiResponse!.nextAction,
                                                    'Indice ${_hintLevelLabel(aiResponse?.hintLevel ?? 'low')} · ${((aiResponse?.confidence ?? 0) * 100).round()}%',
                                                    humanRelayGateText,
                                                    'Sync distante : ${remoteSyncFailed ? 'incomplète' : 'ok'}',
                                                  ],
                                                  footer: remoteSyncFailed && remoteSyncError != null
                                                      ? remoteSyncError!
                                                      : 'Le signal a été intégré au contexte de session.',
                                                ))
                                          : step == _SosStep.escalation
                                              ? _HelpPanel(
                                                  key: const ValueKey('escalation'),
                                                  title: 'Relais de la Grid',
                                                  icon: Icons.support_agent_outlined,
                                                  body: _session!.humanHelpEnabled
                                                      ? 'La Grid n’a pas suffi. Un relais peut être préparé vers la supervision humaine.'
                                                      : 'La Grid n’a pas suffi, mais le canal humain est verrouillé pour cette session. Seule une trace locale peut être conservée.',
                                                  bullets: [
                                                    if (helpPlace != null) 'Zone : ${helpPlace.name}',
                                                    'Relais humain : ${_session!.humanHelpEnabled ? 'oui' : 'non'}',
                                                    'Signal prêt à transmettre',
                                                  ],
                                                  footer:
                                                      'Le relais prépare la transmission si la supervision est autorisée.',
                                                )
                                              : _HelpPanel(
                                                  key: const ValueKey('result'),
                                                  title: resultTitle,
                                                  icon: resultNeedsMj
                                                      ? Icons.flag_outlined
                                                      : Icons.mark_chat_read_outlined,
                                                  body: resultBody,
                                                  bullets: [
                                                    'Aides IA : ${_session!.aiHelpCount}',
                                                    'Relais humain : ${_session!.humanEscalationRequired ? 'oui' : 'non'}',
                                                    'Sync distante : ${remoteSyncFailed ? 'échec' : 'ok'}',
                                                  ],
                                                  footer: remoteSyncFailed && remoteSyncError != null
                                                      ? remoteSyncError!
                                                      : 'Le flux d’aide a été enregistré.',
                                                ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (step == _SosStep.intro)
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          await stopListening();
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                        child: const Text('Fermer'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: FilledButton.icon(
                                        onPressed: requestAiHelp,
                                        icon: const Icon(Icons.psychology_alt_outlined),
                                        label: const Text('Analyser'),
                                      ),
                                    ),
                                  ],
                                ),
                              if (step == _SosStep.ai)
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: aiLoading
                                            ? null
                                            : () async {
                                                await stopListening();
                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                }
                                              },
                                        icon: const Icon(Icons.arrow_back),
                                        label: const Text('Retour au bureau'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: aiLoading
                                            ? null
                                            : () {
                                                setLocalState(() {
                                                  if (canUseHumanRelay) {
                                                    step = _SosStep.escalation;
                                                  } else {
                                                    step = _SosStep.intro;
                                                    aiResponse = null;
                                                    aiLoading = false;
                                                    heardPreview = '';
                                                    showTextFallback = true;
                                                    _sosQuestionController.selection =
                                                        TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset: _sosQuestionController.text.length,
                                                      ),
                                                    );
                                                  }
                                                });
                                              },
                                        icon: Icon(
                                          canUseHumanRelay
                                              ? Icons.support_agent_outlined
                                              : Icons.psychology_alt_outlined,
                                        ),
                                        label: Text(
                                          canUseHumanRelay
                                              ? 'Aide humaine'
                                              : 'Approfondir',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (step == _SosStep.escalation)
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: escalateAfterAiFailure,
                                        icon: const Icon(Icons.flag_outlined),
                                        label: Text(
                                          _session!.humanHelpEnabled
                                              ? 'Transmettre'
                                              : 'Archiver',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          setLocalState(() {
                                            step = _SosStep.ai;
                                          });
                                        },
                                        icon: const Icon(Icons.arrow_back),
                                        label: const Text('Retour'),
                                      ),
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
                                            aiResponse = null;
                                            aiLoading = false;
                                            heardPreview = '';
                                            showTextFallback = false;
                                            _sosQuestionController.text =
                                                _buildDefaultHelpQuestion(helpPlace);
                                          });
                                        },
                                        icon: const Icon(Icons.replay),
                                        label: const Text('Recommencer'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Retour'),
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

    if (_sosSpeechToText.isListening) {
      await _sosSpeechToText.stop();
    }

    if (!mounted) return;
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


class _HelpComposerPanel extends StatelessWidget {
  final PlaceNode? place;
  final TextEditingController controller;
  final String contextBody;
  final List<String> bullets;
  final bool isListening;
  final String heardPreview;
  final bool showTextFallback;
  final VoidCallback onStartListening;
  final VoidCallback onStopListening;
  final VoidCallback onShowTextFallback;

  const _HelpComposerPanel({
    super.key,
    required this.place,
    required this.controller,
    required this.contextBody,
    required this.bullets,
    required this.isListening,
    required this.heardPreview,
    required this.showTextFallback,
    required this.onStartListening,
    required this.onStopListening,
    required this.onShowTextFallback,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = isListening ? 'Écoute en cours' : 'Signal vocal';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 280;
        final ultraCompact = constraints.maxHeight < 235;
        final panelPadding = ultraCompact ? 8.0 : (compact ? 10.0 : 12.0);
        final micSize = ultraCompact
            ? (showTextFallback ? 58.0 : 64.0)
            : compact
                ? (showTextFallback ? 64.0 : 72.0)
                : 82.0;
        final micIconSize = ultraCompact ? 26.0 : (compact ? 30.0 : 34.0);
        final titleFontSize = ultraCompact ? 11.0 : (compact ? 12.0 : 13.0);
        final previewFontSize = ultraCompact ? 12.0 : (compact ? 13.0 : 14.0);
        final inputFontSize = ultraCompact ? 11.5 : (compact ? 12.0 : 13.0);
        final gapSmall = ultraCompact ? 1.0 : (compact ? 2.0 : 4.0);
        final gapMedium = ultraCompact ? 6.0 : (compact ? 8.0 : 10.0);
        final gapInput = ultraCompact ? 3.0 : (compact ? 4.0 : 6.0);

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(panelPadding),
          decoration: BoxDecoration(
            color: const Color(0xFF0D131D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF223247)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFB9C7D8),
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: gapMedium),
              Center(
                child: GestureDetector(
                  onTap: isListening ? onStopListening : onStartListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: micSize,
                    height: micSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isListening
                          ? const Color(0xFFA83F00)
                          : const Color(0xFFD65A00),
                      boxShadow: [
                        BoxShadow(
                          color: (isListening
                                  ? const Color(0xFFA83F00)
                                  : const Color(0xFFD65A00))
                              .withOpacity(0.24),
                          blurRadius: ultraCompact ? 10 : (compact ? 14 : 18),
                          spreadRadius: ultraCompact ? 0 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: micIconSize,
                    ),
                  ),
                ),
              ),
              SizedBox(height: gapMedium),
              Text(
                heardPreview.isNotEmpty
                    ? heardPreview
                    : (isListening ? 'Parle maintenant…' : 'Appuie pour parler'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: heardPreview.isNotEmpty
                      ? Colors.white
                      : const Color(0xFF93A2B7),
                  height: 1.1,
                  fontSize: previewFontSize,
                  fontWeight:
                      heardPreview.isNotEmpty ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              SizedBox(height: gapSmall),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: onShowTextFallback,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: ultraCompact ? 0 : 1,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity:
                        const VisualDensity(horizontal: -4, vertical: -4),
                  ),
                  child: Text(
                    showTextFallback ? 'Masquer' : 'Écrire',
                    style: TextStyle(fontSize: ultraCompact ? 12 : 13),
                  ),
                ),
              ),
              if (showTextFallback) ...[
                SizedBox(height: gapInput),
                TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.1,
                    fontSize: inputFontSize,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Décris le blocage.',
                    hintStyle: const TextStyle(
                      color: Color(0xFF7E8CA3),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF121A28),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: ultraCompact ? 6 : (compact ? 7 : 8),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF2B4566),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF2B4566),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFD65A00),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    required this.bullets,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ultraCompact = constraints.maxHeight < 300;
        final compact = constraints.maxHeight < 340;
        final panelPadding = ultraCompact ? 10.0 : (compact ? 12.0 : 14.0);
        final titleSize = ultraCompact ? 14.5 : (compact ? 16.0 : 17.0);
        final bodySize = ultraCompact ? 12.5 : (compact ? 13.5 : 14.5);
        final iconSize = ultraCompact ? 18.0 : 20.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(panelPadding),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1726),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF24364F)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFFFFD7B8), size: iconSize),
                  SizedBox(width: ultraCompact ? 8 : 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ultraCompact ? 4 : 6),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        body,
                        style: TextStyle(
                          color: const Color(0xFFD6E2F2),
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                          fontSize: bodySize,
                        ),
                      ),
                      if (bullets.isNotEmpty) ...[
                        SizedBox(height: ultraCompact ? 6 : 8),
                        ...bullets.map(
                          (bullet) => Padding(
                            padding: EdgeInsets.only(bottom: ultraCompact ? 6 : 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.arrow_right_alt,
                                    color: const Color(0xFFD65A00),
                                    size: ultraCompact ? 16 : 18,
                                  ),
                                ),
                                SizedBox(width: ultraCompact ? 3 : 4),
                                Expanded(
                                  child: Text(
                                    bullet,
                                    style: TextStyle(
                                      color: const Color(0xFFB9C7D8),
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                      fontSize: ultraCompact ? 12 : 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: ultraCompact ? 4 : 6),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(ultraCompact ? 6 : 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121E31),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2B4566)),
                        ),
                        child: Text(
                          footer,
                          style: TextStyle(
                            color: const Color(0xFFAED0FF),
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            fontSize: ultraCompact ? 10.5 : 11.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HelpLoadingPanel extends StatelessWidget {
  const _HelpLoadingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ultraCompact = constraints.maxHeight < 300;
        final compact = constraints.maxHeight < 340;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(ultraCompact ? 10 : (compact ? 12 : 16)),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1726),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF24364F)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: ultraCompact ? 18 : 20,
                    height: ultraCompact ? 18 : 20,
                    child: const CircularProgressIndicator(strokeWidth: 2.3),
                  ),
                  SizedBox(width: ultraCompact ? 8 : 10),
                  Expanded(
                    child: Text(
                      'Interrogation de la Grid',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ultraCompact ? 14.5 : (compact ? 16 : 17),
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ultraCompact ? 4 : 6),
              Text(
                'La Grid recoupe votre signal avec la zone active, la progression et les accès encore ouverts.',
                maxLines: ultraCompact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFD6E2F2),
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  fontSize: ultraCompact ? 12.5 : 13.5,
                ),
              ),
              SizedBox(height: ultraCompact ? 4 : 6),
              Text(
                'Décodage Grid…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFAED0FF),
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  fontSize: ultraCompact ? 12.5 : 13.5,
                ),
              ),
            ],
          ),
        );
      },
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