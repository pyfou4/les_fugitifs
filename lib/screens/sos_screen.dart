import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/ai_service.dart';

class SOSSreen extends StatefulWidget {
  final String sessionId;

  final String? scenarioTitle;
  final int? progress;
  final int? aiHelpCount;
  final String? currentBlockageLevel;
  final List<String>? visitedPlaces;
  final List<String>? blockedPrerequisites;
  final bool? humanHelpEnabledOverride;
  final AiHelpPlaceContext? placeContext;

  const SOSSreen({
    super.key,
    required this.sessionId,
    this.scenarioTitle,
    this.progress,
    this.aiHelpCount,
    this.currentBlockageLevel,
    this.visitedPlaces,
    this.blockedPrerequisites,
    this.humanHelpEnabledOverride,
    this.placeContext,
  });

  @override
  State<SOSSreen> createState() => _SOSSreenState();
}

class _SOSSreenState extends State<SOSSreen>
    with SingleTickerProviderStateMixin {
  static const String _backgroundUrl =
      'https://firebasestorage.googleapis.com/v0/b/les-fugitifs.firebasestorage.app/o/images%2Fdetective_desk.png?alt=media&token=c5d76809-743b-4d78-8102-6fd89f171fc9';

  final AiService _aiService = AiService();
  final TextEditingController _questionController = TextEditingController();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _isSending = false;
  bool _showTextInput = false;
  bool _isListening = false;
  bool _speechAvailable = true;
  String _heardPreview = '';
  String? _errorMessage;
  AiHelpResponse? _lastResponse;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseGlow;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(
      begin: 0.985,
      end: 1.03,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseGlow = Tween<double>(
      begin: 0.14,
      end: 0.24,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _speechToText.stop();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    if (!mounted) return;
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _startListening() async {
    if (_isSending) return;

    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _speechAvailable = false;
          _showTextInput = true;
          _errorMessage =
              'La saisie vocale est indisponible. Utilisez le champ texte.';
        });
      },
    );

    if (!available) {
      if (!mounted) return;
      setState(() {
        _speechAvailable = false;
        _showTextInput = true;
        _isListening = false;
        _errorMessage =
            'La saisie vocale est indisponible. Utilisez le champ texte.';
      });
      return;
    }

    setState(() {
      _speechAvailable = true;
      _heardPreview = '';
      _isListening = true;
      _errorMessage = null;
      _showTextInput = false;
    });

    await _speechToText.listen(
      localeId: 'fr_FR',
      listenMode: stt.ListenMode.confirmation,
      onResult: (result) async {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        setState(() {
          _heardPreview = words;
          if (words.isNotEmpty) {
            _questionController.text = words;
            _questionController.selection = TextSelection.collapsed(
              offset: words.length,
            );
          }
        });

        if (result.finalResult) {
          await _speechToText.stop();
          if (!mounted) return;
          setState(() {
            _isListening = false;
            if (_heardPreview.isEmpty || _heardPreview.length < 6) {
              _showTextInput = true;
            }
          });
        }
      },
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _requestAiHelp(Map<String, dynamic> sessionData) async {
    final playerQuestion = _questionController.text.trim();

    if (playerQuestion.isEmpty) {
      setState(() {
        _errorMessage =
            "Décris brièvement ton blocage avant d'envoyer la demande.";
        _showTextInput = true;
      });
      return;
    }

    await _stopListening();

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final scenarioTitle = widget.scenarioTitle ??
        _readString(
              sessionData,
              const ['scenarioTitle', 'scenarioName', 'title'],
            ) ??
        'Session Les Fugitifs';

    final progress =
        widget.progress ??
            _readInt(sessionData, const ['progress', 'gameProgress']) ??
            0;

    final aiHelpCount =
        widget.aiHelpCount ?? _readInt(sessionData, const ['aiHelpCount']) ?? 0;

    final currentBlockageLevel = widget.currentBlockageLevel ??
        _readString(
              sessionData,
              const ['currentBlockageLevel', 'blockageLevel'],
            ) ??
        'low';

    final humanHelpEnabled =
        widget.humanHelpEnabledOverride ?? sessionData['humanHelpEnabled'] == true;

    final visitedPlaces = widget.visitedPlaces ??
        _readStringList(
          sessionData,
          const ['visitedPlaces', 'visitedPlaceIds', 'placesVisited'],
        );

    final blockedPrerequisites = widget.blockedPrerequisites ??
        _readStringList(
          sessionData,
          const ['blockedPrerequisites', 'missingPrerequisites'],
        );

    final callContext = _incrementCallContext(_readCallContext(sessionData));

    try {
      final response = await _aiService.getStructuredHelp(
        sessionId: widget.sessionId,
        scenarioTitle: scenarioTitle,
        progress: progress,
        aiHelpCount: aiHelpCount,
        currentBlockageLevel: currentBlockageLevel,
        humanHelpEnabled: humanHelpEnabled,
        visitedPlaces: visitedPlaces,
        blockedPrerequisites: blockedPrerequisites,
        place: widget.placeContext,
        callContext: callContext,
        playerQuestion: playerQuestion,
      );

      if (!mounted) return;

      setState(() {
        _lastResponse = response;
      });

      await FirebaseFirestore.instance
          .collection('gameSessions')
          .doc(widget.sessionId)
          .set(
        {
          'aiHelpCount': FieldValue.increment(1),
          'lastAiHelpQuestion': playerQuestion,
          'lastAiHelpResponse': response.message,
          'lastAiHelpHintLevel': response.hintLevel,
          'lastAiHelpNextAction': response.nextAction,
          'lastAiHelpConfidence': response.confidence,
          'lastAiHelpAt': FieldValue.serverTimestamp(),
          if (callContext != null && callContext.active)
            'callContext.helpAttemptsDuringCall':
                callContext.helpAttemptsDuringCall,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Impossible d'obtenir l'assistance IA : $e";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }
  }

  String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int? _readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  List<String> _readStringList(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return const <String>[];
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

  Color _hintColor(String hintLevel) {
    switch (hintLevel.toLowerCase()) {
      case 'high':
      case 'strong':
        return const Color(0xFFE6A35C);
      case 'medium':
        return const Color(0xFF87B9D8);
      case 'low':
      default:
        return const Color(0xFFBFD2E0);
    }
  }

  String _hintLabel(String hintLevel) {
    switch (hintLevel.toLowerCase()) {
      case 'high':
      case 'strong':
        return 'Transmission appuyée';
      case 'medium':
        return 'Transmission guidée';
      case 'low':
      default:
        return 'Transmission légère';
    }
  }

  String _buildTransmissionText(AiHelpResponse response) {
    return '[Signal reçu…]\n\n${response.message}\n\n[fin transmission]';
  }

  String _buildNextActionText(AiHelpResponse response) {
    if (response.nextAction.trim().isEmpty) {
      return 'Aucune consigne supplémentaire transmise.';
    }
    return response.nextAction.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050607),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gameSessions')
            .doc(widget.sessionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(
              child: Text(
                'Session introuvable',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final humanHelpEnabled =
              widget.humanHelpEnabledOverride ?? data['humanHelpEnabled'] == true;

          final media = MediaQuery.of(context);
          final isTablet = media.size.shortestSide >= 700;
          final panelWidth = isTablet ? 340.0 : media.size.width * 0.82;
          final outerPadding = isTablet ? 20.0 : 14.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              const _DeskBackdrop(),
              const _DeskOverlay(),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: outerPadding,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: panelWidth),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF08111B).withOpacity(0.80),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFF7A8FB7).withOpacity(0.24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.36),
                                blurRadius: 22,
                                spreadRadius: 1,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              isTablet ? 14 : 9,
                              isTablet ? 12 : 8,
                              isTablet ? 14 : 9,
                              isTablet ? 12 : 9,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _CompactHeader(
                                  humanHelpEnabled: humanHelpEnabled,
                                  onClose: () => Navigator.of(context).pop(),
                                  compact: !isTablet,
                                ),
                                SizedBox(height: isTablet ? 8 : 6),
                                _MainSignalPanel(
                                  isTablet: isTablet,
                                  isSending: _isSending,
                                  isListening: _isListening,
                                  speechAvailable: _speechAvailable,
                                  heardPreview: _heardPreview,
                                  pulseController: _pulseController,
                                  pulseScale: _pulseScale,
                                  pulseGlow: _pulseGlow,
                                  showTextInput: _showTextInput,
                                  questionController: _questionController,
                                  errorMessage: _errorMessage,
                                  response: _lastResponse,
                                  onToggleTextInput: () {
                                    setState(() {
                                      _showTextInput = !_showTextInput;
                                    });
                                  },
                                  onMicTap: _toggleListening,
                                  hintLabelBuilder: _hintLabel,
                                  hintColorBuilder: _hintColor,
                                  transmissionBuilder: _buildTransmissionText,
                                  nextActionBuilder: _buildNextActionText,
                                  compact: !isTablet,
                                ),
                                SizedBox(height: isTablet ? 8 : 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isSending
                                            ? null
                                            : () => Navigator.of(context).pop(),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFFE7DACA,
                                          ),
                                          side: BorderSide(
                                            color: const Color(
                                              0xFF7A8FB7,
                                            ).withOpacity(0.24),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            vertical: isTablet ? 13 : 11,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          textStyle: TextStyle(
                                            fontSize: isTablet ? 14 : 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        child: const Text('Fermer'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        onPressed: _isSending
                                            ? null
                                            : () => _requestAiHelp(data),
                                        icon: _isSending
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.send_rounded,
                                                size: 16,
                                              ),
                                        label: Text(
                                          _isSending ? 'Analyse…' : 'Analyser',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF7A57C6,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: isTablet ? 13 : 11,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          textStyle: TextStyle(
                                            fontSize: isTablet ? 14 : 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
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
            ],
          );
        },
      ),
    );
  }
}

class _DeskBackdrop extends StatelessWidget {
  const _DeskBackdrop();

  static const String _backgroundUrl =
      'https://firebasestorage.googleapis.com/v0/b/les-fugitifs.firebasestorage.app/o/images%2Fdetective_desk.png?alt=media&token=c5d76809-743b-4d78-8102-6fd89f171fc9';

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF040608),
        image: DecorationImage(
          image: NetworkImage(_backgroundUrl),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class _DeskOverlay extends StatelessWidget {
  const _DeskOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.68),
              Colors.black.withOpacity(0.42),
              Colors.black.withOpacity(0.58),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  final bool humanHelpEnabled;
  final VoidCallback onClose;
  final bool compact;

  const _CompactHeader({
    required this.humanHelpEnabled,
    required this.onClose,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 30 : 34,
          height: compact ? 30 : 34,
          decoration: BoxDecoration(
            color: const Color(0xFF2E1A0B).withOpacity(0.92),
            borderRadius: BorderRadius.circular(compact ? 9 : 10),
            border: Border.all(
              color: const Color(0xFFB9824B).withOpacity(0.34),
            ),
          ),
          child: Icon(
            Icons.graphic_eq,
            color: const Color(0xFFFFDDBB),
            size: compact ? 16 : 18,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ligne d’urgence',
                style: TextStyle(
                  color: const Color(0xFFF4E5D2),
                  fontSize: compact ? 13.5 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                humanHelpEnabled
                    ? 'Canal de supervision ouvert'
                    : 'Canal de supervision fermé',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.50),
                  fontSize: compact ? 9.5 : 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          iconSize: compact ? 20 : 24,
          visualDensity: const VisualDensity(
            horizontal: -2,
            vertical: -2,
          ),
          icon: const Icon(
            Icons.close,
            color: Color(0xFFE8D7C5),
          ),
        ),
      ],
    );
  }
}

class _MainSignalPanel extends StatelessWidget {
  final bool isTablet;
  final bool isSending;
  final bool isListening;
  final bool speechAvailable;
  final String heardPreview;
  final AnimationController pulseController;
  final Animation<double> pulseScale;
  final Animation<double> pulseGlow;
  final bool showTextInput;
  final TextEditingController questionController;
  final String? errorMessage;
  final AiHelpResponse? response;
  final VoidCallback onToggleTextInput;
  final VoidCallback onMicTap;
  final String Function(String hintLevel) hintLabelBuilder;
  final Color Function(String hintLevel) hintColorBuilder;
  final String Function(AiHelpResponse response) transmissionBuilder;
  final String Function(AiHelpResponse response) nextActionBuilder;
  final bool compact;

  const _MainSignalPanel({
    required this.isTablet,
    required this.isSending,
    required this.isListening,
    required this.speechAvailable,
    required this.heardPreview,
    required this.pulseController,
    required this.pulseScale,
    required this.pulseGlow,
    required this.showTextInput,
    required this.questionController,
    required this.errorMessage,
    required this.response,
    required this.onToggleTextInput,
    required this.onMicTap,
    required this.hintLabelBuilder,
    required this.hintColorBuilder,
    required this.transmissionBuilder,
    required this.nextActionBuilder,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final panelHeight = compact ? 206.0 : 300.0;
    final micSize = compact ? 58.0 : 84.0;
    final micIconSize = compact ? 22.0 : 30.0;

    return Container(
      constraints: BoxConstraints(minHeight: panelHeight),
      padding: EdgeInsets.fromLTRB(
        compact ? 9 : 14,
        compact ? 10 : 16,
        compact ? 9 : 14,
        compact ? 9 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF081425).withOpacity(0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7A8FB7).withOpacity(0.24),
        ),
      ),
      child: response == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Signal vocal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFE8E1D9),
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: compact ? 10 : 18),
                AnimatedBuilder(
                  animation: pulseController,
                  builder: (context, child) {
                    return Center(
                      child: Transform.scale(
                        scale:
                            (isSending || isListening) ? pulseScale.value : 1.0,
                        child: GestureDetector(
                          onTap: isSending ? null : onMicTap,
                          child: Container(
                            width: micSize,
                            height: micSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFFFA146),
                                  isListening
                                      ? const Color(0xFFF06E1D)
                                      : const Color(0xFFD96A07),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE2882D).withOpacity(
                                    (isSending || isListening)
                                        ? pulseGlow.value
                                        : 0.16,
                                  ),
                                  blurRadius: compact ? 18 : 24,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              isListening ? Icons.stop_rounded : Icons.mic,
                              color: Colors.white,
                              size: micIconSize,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: compact ? 10 : 18),
                Text(
                  isListening
                      ? 'Écoute en cours…'
                      : (speechAvailable
                            ? 'Touchez pour parler'
                            : 'Saisie texte'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: compact ? 10.2 : 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (heardPreview.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    heardPreview,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFBFD2E0).withOpacity(0.90),
                      fontSize: compact ? 10.0 : 11.0,
                    ),
                  ),
                ],
                TextButton(
                  onPressed: onToggleTextInput,
                  style: TextButton.styleFrom(
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    showTextInput ? 'Masquer' : 'Écrire',
                    style: TextStyle(fontSize: compact ? 9.5 : 10.5),
                  ),
                ),
                if (showTextInput) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: questionController,
                    minLines: 2,
                    maxLines: 2,
                    style: TextStyle(
                      color: const Color(0xFFF2E7D7),
                      height: 1.35,
                      fontSize: compact ? 12 : 13,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          "Ex. Nous tournons en rond entre deux lieux.",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.32),
                        fontSize: compact ? 10.5 : 12,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0C1722).withOpacity(0.90),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: compact ? 8 : 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: const Color(0xFF7A8FB7).withOpacity(0.18),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: const Color(0xFF7A8FB7).withOpacity(0.18),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                        borderSide: BorderSide(color: Color(0xFFE29A52)),
                      ),
                    ),
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFFFA8A0),
                      height: 1.3,
                      fontSize: compact ? 10.0 : 11.5,
                    ),
                  ),
                ],
              ],
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoBadge(
                        label: hintLabelBuilder(response!.hintLevel),
                        color: hintColorBuilder(response!.hintLevel),
                        compact: compact,
                      ),
                      _InfoBadge(
                        label:
                            'Confiance ${(100 * response!.confidence).round()}%',
                        color: const Color(0xFFBFD2E0),
                        compact: compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ResponseBlock(
                    title: 'Transmission',
                    text: transmissionBuilder(response!),
                    compact: compact,
                  ),
                  const SizedBox(height: 8),
                  _ResponseBlock(
                    title: 'Action conseillée',
                    text: nextActionBuilder(response!),
                    compact: compact,
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _InfoBadge({
    required this.label,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10.8 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _ResponseBlock extends StatelessWidget {
  final String title;
  final String text;
  final bool compact;

  const _ResponseBlock({
    required this.title,
    required this.text,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 11 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1822).withOpacity(0.86),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFB9824B).withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: const Color(0xFFE9C89E),
              fontSize: compact ? 10.8 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              color: const Color(0xFFF2E7D7),
              height: 1.45,
              fontSize: compact ? 11.5 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
