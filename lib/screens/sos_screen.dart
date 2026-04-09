import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

class _SOSSreenState extends State<SOSSreen> {
  final AiService _aiService = AiService();
  final TextEditingController _questionController = TextEditingController();

  bool _isSending = false;
  String? _errorMessage;
  AiHelpResponse? _lastResponse;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _requestAiHelp(Map<String, dynamic> sessionData) async {
    final playerQuestion = _questionController.text.trim();

    if (playerQuestion.isEmpty) {
      setState(() {
        _errorMessage = "Décris brièvement ton blocage avant d'envoyer la demande.";
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final scenarioTitle = widget.scenarioTitle ??
        _readString(sessionData, const ['scenarioTitle', 'scenarioName', 'title']) ??
        'Session Les Fugitifs';

    final progress =
        widget.progress ?? _readInt(sessionData, const ['progress', 'gameProgress']) ?? 0;

    final aiHelpCount =
        widget.aiHelpCount ?? _readInt(sessionData, const ['aiHelpCount']) ?? 0;

    final currentBlockageLevel = widget.currentBlockageLevel ??
        _readString(sessionData, const ['currentBlockageLevel', 'blockageLevel']) ??
        'low';

    final humanHelpEnabled = widget.humanHelpEnabledOverride ??
        sessionData['humanHelpEnabled'] == true;

    final visitedPlaces = widget.visitedPlaces ??
        _readStringList(sessionData, const ['visitedPlaces', 'visitedPlaceIds', 'placesVisited']);

    final blockedPrerequisites = widget.blockedPrerequisites ??
        _readStringList(
          sessionData,
          const ['blockedPrerequisites', 'missingPrerequisites'],
        );

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

  Color _hintColor(String hintLevel) {
    switch (hintLevel.toLowerCase()) {
      case 'high':
      case 'strong':
        return const Color(0xFFFFB347);
      case 'medium':
        return const Color(0xFF6EDB8F);
      case 'low':
      default:
        return const Color(0xFF8ED1FC);
    }
  }

  String _hintLabel(String hintLevel) {
    switch (hintLevel.toLowerCase()) {
      case 'high':
      case 'strong':
        return 'AIDE RENFORCÉE';
      case 'medium':
        return 'AIDE GUIDÉE';
      case 'low':
      default:
        return 'AIDE LÉGÈRE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060708),
      appBar: AppBar(
        title: const Text('Assistance'),
        backgroundColor: const Color(0xFF0B0C0E),
      ),
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

          final aiHelpCount =
              widget.aiHelpCount ?? _readInt(data, const ['aiHelpCount']) ?? 0;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF08090A),
                  Color(0xFF12161A),
                  Color(0xFF0A0B0C),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TerminalPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.memory,
                              title: 'NŒUD D’ASSISTANCE HENIGMA',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Décris ton blocage. L’assistance IA répond sans révéler directement la solution.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.78),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _StatusRow(
                              label: 'Session',
                              value: widget.sessionId,
                            ),
                            const SizedBox(height: 8),
                            _StatusRow(
                              label: 'Aides IA déjà demandées',
                              value: aiHelpCount.toString(),
                            ),
                            const SizedBox(height: 8),
                            _StatusRow(
                              label: 'Aide humaine',
                              value: humanHelpEnabled ? 'DISPONIBLE' : 'DÉSACTIVÉE',
                              valueColor: humanHelpEnabled
                                  ? const Color(0xFF6EDB8F)
                                  : const Color(0xFFFF7A7A),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _TerminalPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.edit_note,
                              title: 'DEMANDE JOUEUR',
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _questionController,
                              minLines: 4,
                              maxLines: 6,
                              style: const TextStyle(
                                color: Colors.white,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    "Ex. Nous avons visité plusieurs lieux mais nous ne savons plus quelle piste poursuivre.",
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.32),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F1316),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: const Color(0xFFFFB347).withOpacity(0.22),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: const Color(0xFFFFB347).withOpacity(0.22),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFFB347),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSending ? null : () => _requestAiHelp(data),
                                icon: _isSending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send),
                                label: Text(_isSending
                                    ? 'Analyse en cours...'
                                    : 'INTERROGER L’ASSISTANCE'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF29170C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: const Color(0xFFFFB347).withOpacity(0.28),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFFF7A7A),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _TerminalPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.assistant,
                              title: 'RÉPONSE IA',
                            ),
                            const SizedBox(height: 12),
                            if (_lastResponse == null)
                              Text(
                                "Aucune réponse pour l'instant. Décris votre blocage pour obtenir une orientation contextuelle.",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  height: 1.45,
                                ),
                              )
                            else ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoBadge(
                                    label: _hintLabel(_lastResponse!.hintLevel),
                                    color: _hintColor(_lastResponse!.hintLevel),
                                  ),
                                  _InfoBadge(
                                    label:
                                        'CONFIANCE ${(100 * _lastResponse!.confidence).round()}%',
                                    color: const Color(0xFF8ED1FC),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _ResponseBlock(
                                title: 'Message',
                                text: _lastResponse!.message,
                              ),
                              if (_lastResponse!.nextAction.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _ResponseBlock(
                                  title: 'Prochaine action conseillée',
                                  text: _lastResponse!.nextAction,
                                ),
                              ],
                              if (humanHelpEnabled) ...[
                                const SizedBox(height: 14),
                                Text(
                                  "Si votre équipe reste bloquée après cette réponse, le maître du jeu peut reprendre la main.",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.62),
                                    height: 1.4,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 14),
                                Text(
                                  "L’aide humaine est désactivée pour cette session. L’IA reste votre canal d’assistance principal.",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.62),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TerminalPanel extends StatelessWidget {
  final Widget child;

  const _TerminalPanel({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xAA0A0D0F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFB347).withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFB347)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFD6A0),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatusRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.34),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ResponseBlock extends StatelessWidget {
  final String title;
  final String text;

  const _ResponseBlock({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1215),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFB347).withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFFFD6A0),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
