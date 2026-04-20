import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/portal_access_service.dart';
import '../widgets/header_brand.dart';
import 'public_broadcast_screen.dart';

part 'master_game_global_graph_part.dart';
part 'master_game_session_panel_part.dart';
part 'master_game_sessions_list_part.dart';

class MasterGameScreen extends StatefulWidget {
  final PortalAccessProfile profile;

  const MasterGameScreen({
    super.key,
    required this.profile,
  });

  @override
  State<MasterGameScreen> createState() => _MasterGameScreenState();
}

class _MasterGameScreenState extends State<MasterGameScreen> {
  static const String _gameId = 'les_fugitifs';

  static const List<_GraphColumn> _graphColumns = [
    _GraphColumn(
      title: 'Départ',
      subtitle: 'A0',
      nodeIds: ['A0'],
      accent: Color(0xFFD2B34C),
    ),
    _GraphColumn(
      title: 'Phase A',
      subtitle: 'Pistes initiales',
      nodeIds: ['A1', 'A2', 'A3', 'A4', 'A5', 'A6'],
      accent: Color(0xFF56C271),
    ),
    _GraphColumn(
      title: 'Pivot B0',
      subtitle: 'B0',
      nodeIds: ['B0'],
      accent: Color(0xFF56C271),
    ),
    _GraphColumn(
      title: 'Phase B',
      subtitle: 'Pistes croisées',
      nodeIds: ['B1', 'B2', 'B3', 'B4', 'B5'],
      accent: Color(0xFF5AA6FF),
    ),
    _GraphColumn(
      title: 'Pivot C0',
      subtitle: 'C0',
      nodeIds: ['C0'],
      accent: Color(0xFF7E87FF),
    ),
    _GraphColumn(
      title: 'Phase C',
      subtitle: 'Vérifications finales',
      nodeIds: ['C1', 'C2', 'C3', 'C4'],
      accent: Color(0xFFBE72FF),
    ),
    _GraphColumn(
      title: 'Accusation',
      subtitle: 'D0',
      nodeIds: ['D0'],
      accent: Color(0xFFE985FF),
    ),
  ];

  String? _selectedSessionId;
  final TextEditingController _noteController = TextEditingController();
  final TransformationController _graphTransformController =
      TransformationController();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _noteController.dispose();
    _graphTransformController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build entry point
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const HeaderBrand(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                widget.profile.role.label,
                style: const TextStyle(
                  color: Color(0xFFFFD7B8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _gameSessionsStream(),
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (sessionSnapshot.hasError) {
          return _buildErrorState(
            'Erreur Firestore (gameSessions) : ${sessionSnapshot.error}',
          );
        }

        final sessions = (sessionSnapshot.data?.docs ?? const [])
            .map(_GameSession.fromDoc)
            .toList(growable: false);
        final activeSessions = sessions
            .where((session) => session.isVisibleInMasterActiveView)
            .toList(growable: false);

        _ensureSelectedSession(activeSessions);

        return _buildPlaceTemplatesScope(activeSessions);
      },
    );
  }

  Widget _buildPlaceTemplatesScope(List<_GameSession> activeSessions) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _placeTemplatesStream(),
      builder: (context, placeSnapshot) {
        if (placeSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (placeSnapshot.hasError) {
          return _buildErrorState(
            'Erreur Firestore (placeTemplates) : ${placeSnapshot.error}',
          );
        }

        final templates = _buildPlaceTemplatesMap(placeSnapshot);
        final selectedSession = _selectedSession(activeSessions);
        final sessionsByNode = _groupSessionsByNode(activeSessions);

        return LayoutBuilder(
          builder: (context, constraints) {
            return _buildResponsiveContent(
              constraints: constraints,
              activeSessions: activeSessions,
              selectedSession: selectedSession,
              templates: templates,
              sessionsByNode: sessionsByNode,
            );
          },
        );
      },
    );
  }

  Widget _buildResponsiveContent({
    required BoxConstraints constraints,
    required List<_GameSession> activeSessions,
    required _GameSession? selectedSession,
    required Map<String, _PlaceTemplate> templates,
    required Map<String, List<_GameSession>> sessionsByNode,
  }) {
    final isWide = constraints.maxWidth >= 1380;
    final padding = isWide ? 24.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIntroCard(activeSessions),
          const SizedBox(height: 24),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGlobalGraphCard(
                        templates: templates,
                        sessionsByNode: sessionsByNode,
                        sessions: activeSessions,
                      ),
                      const SizedBox(height: 24),
                      _buildSessionsCard(activeSessions),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: _buildSidePanel(selectedSession),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGlobalGraphCard(
                  templates: templates,
                  sessionsByNode: sessionsByNode,
                  sessions: activeSessions,
                ),
                const SizedBox(height: 24),
                _buildSessionsCard(activeSessions),
                const SizedBox(height: 24),
                _buildSidePanel(selectedSession),
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Firestore access
  // ---------------------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _gameSessionsStream() {
    return FirebaseFirestore.instance
        .collection('gameSessions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _placeTemplatesStream() {
    return FirebaseFirestore.instance
        .collection('games')
        .doc(_gameId)
        .collection('placeTemplates')
        .snapshots();
  }

  Map<String, _PlaceTemplate> _buildPlaceTemplatesMap(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> placeSnapshot,
  ) {
    return <String, _PlaceTemplate>{
      for (final doc in (placeSnapshot.data?.docs ??
          <QueryDocumentSnapshot<Map<String, dynamic>>>[]))
        doc.id: _PlaceTemplate.fromDoc(doc),
    };
  }

  // ---------------------------------------------------------------------------
  // Session selection and grouping
  // ---------------------------------------------------------------------------

  _GameSession? _selectedSession(List<_GameSession> sessions) {
    for (final session in sessions) {
      if (session.id == _selectedSessionId) {
        return session;
      }
    }
    return sessions.isEmpty ? null : sessions.first;
  }

  void _ensureSelectedSession(List<_GameSession> sessions) {
    if (sessions.isEmpty) {
      _selectedSessionId = null;
      return;
    }

    final stillExists = sessions.any((session) => session.id == _selectedSessionId);
    if (!stillExists) {
      _selectedSessionId = sessions.first.id;
    }
  }

  Map<String, List<_GameSession>> _groupSessionsByNode(List<_GameSession> sessions) {
    final result = <String, List<_GameSession>>{};
    for (final session in sessions) {
      result.putIfAbsent(session.currentNodeId, () => <_GameSession>[]).add(session);
    }
    return result;
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 16,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard(List<_GameSession> sessions) {
    final activeCount = sessions.where((session) => session.active).length;
    final warningCount = sessions
        .where((session) => session.attentionLevel == _AttentionLevel.warning)
        .length;
    final dangerCount = sessions
        .where((session) => session.attentionLevel == _AttentionLevel.danger)
        .length;
    final humanEnabledCount = sessions
        .where((session) => session.humanHelpEnabled)
        .length;
    final pendingAssistanceCount = sessions
        .where((session) => session.assistanceState == _AssistanceState.pending)
        .length;
    final claimedAssistanceCount = sessions
        .where((session) => session.assistanceState == _AssistanceState.claimed)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Salle de contrôle MJ',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Vue d’ensemble des lieux, des équipes et des points chauds. Le code couleur raconte le niveau d’attention, pas l’identité du groupe. Le panneau d’assistance te permet maintenant de suivre, prendre et clôturer les demandes humaines.',
              style: TextStyle(
                color: Color(0xFF9AA7BC),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMetricPill('Sessions', '${sessions.length}'),
                _buildMetricPill('Actives', '$activeCount'),
                _buildMetricPill('Orange', '$warningCount'),
                _buildMetricPill('Rouge', '$dangerCount'),
                _buildMetricPill('Aide humaine autorisée', '$humanEnabledCount'),
                _buildMetricPill('Assistance en attente', '$pendingAssistanceCount'),
                _buildMetricPill('Assistance prise en charge', '$claimedAssistanceCount'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF171E2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263245)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$value  ',
              style: const TextStyle(
                color: Color(0xFFFFD7B8),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            TextSpan(
              text: label,
              style: const TextStyle(
                color: Color(0xFF9AA7BC),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _assistanceStateColor(_AssistanceState state) {
    switch (state) {
      case _AssistanceState.pending:
        return const Color(0xFFC74343);
      case _AssistanceState.claimed:
        return const Color(0xFFD65A00);
      case _AssistanceState.resolved:
        return const Color(0xFF2E8B57);
      case _AssistanceState.none:
        return const Color(0xFF54708F);
    }
  }

  _AttentionLevel _worstAttentionLevel(List<_GameSession> sessions) {
    if (sessions.isEmpty) return _AttentionLevel.neutral;
    if (sessions.any(
      (session) => session.attentionLevel == _AttentionLevel.danger,
    )) {
      return _AttentionLevel.danger;
    }
    if (sessions.any(
      (session) => session.attentionLevel == _AttentionLevel.warning,
    )) {
      return _AttentionLevel.warning;
    }
    if (sessions.any(
      (session) => session.attentionLevel == _AttentionLevel.restricted,
    )) {
      return _AttentionLevel.restricted;
    }
    return _AttentionLevel.normal;
  }

  Color _nodeBorderColor(
    List<_GameSession> sessions,
    _AttentionLevel worstLevel,
  ) {
    if (sessions.isEmpty) return const Color(0xFF223142);

    switch (worstLevel) {
      case _AttentionLevel.danger:
        return const Color(0xFFC74343);
      case _AttentionLevel.warning:
        return const Color(0xFFD65A00);
      case _AttentionLevel.restricted:
        return const Color(0xFF54708F);
      case _AttentionLevel.normal:
        return const Color(0xFF2E8B57);
      case _AttentionLevel.neutral:
        return const Color(0xFF223142);
    }
  }

  _SessionTone _sessionTone(_GameSession session) {
    switch (session.attentionLevel) {
      case _AttentionLevel.danger:
        return const _SessionTone(
          background: Color(0xFF3B1719),
          border: Color(0xFFC74343),
          dot: Color(0xFFC74343),
        );
      case _AttentionLevel.warning:
        return const _SessionTone(
          background: Color(0xFF372112),
          border: Color(0xFFD65A00),
          dot: Color(0xFFD65A00),
        );
      case _AttentionLevel.restricted:
        return const _SessionTone(
          background: Color(0xFF152336),
          border: Color(0xFF54708F),
          dot: Color(0xFF7EA5D1),
        );
      case _AttentionLevel.normal:
        return const _SessionTone(
          background: Color(0xFF14261A),
          border: Color(0xFF2E8B57),
          dot: Color(0xFF2E8B57),
        );
      case _AttentionLevel.neutral:
        return const _SessionTone(
          background: Color(0xFF17202B),
          border: Color(0xFF445469),
          dot: Color(0xFF7F8CA0),
        );
    }
  }

  void _openBroadcastScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PublicBroadcastScreen(),
      ),
    );
  }

  Future<void> _openGraphDialog({
    required Map<String, _PlaceTemplate> templates,
    required Map<String, List<_GameSession>> sessionsByNode,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final dialogController = TransformationController();
        return Dialog(
          backgroundColor: const Color(0xFF0B1420),
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 1400,
            height: 860,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carte MJ agrandie',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Déplace-toi et zoome pour lire les lieux de plus près.',
                              style: TextStyle(
                                color: Color(0xFF93A2B7),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        color: const Color(0xFF09111D),
                        padding: const EdgeInsets.all(18),
                        child: InteractiveViewer(
                          transformationController: dialogController,
                          constrained: false,
                          minScale: 0.6,
                          maxScale: 2.5,
                          boundaryMargin: const EdgeInsets.all(240),
                          child: _buildGraphBoard(templates, sessionsByNode, compact: false),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleHumanHelp(_GameSession session) async {
    final nextValue = !session.humanHelpEnabled;
    final sessionRef =
        FirebaseFirestore.instance.collection('gameSessions').doc(session.id);

    await sessionRef.update({
      'humanHelpEnabled': nextValue,
    });

    await _addTimelineEntry(
      sessionId: session.id,
      type: nextValue ? 'human_help_enabled' : 'human_help_disabled',
      label: nextValue
          ? 'Aide humaine autorisée par le MJ'
          : 'Aide humaine coupée par le MJ',
      source: 'mj',
    );

    await _addMjAction(
      sessionId: session.id,
      type: nextValue ? 'enable_human_help' : 'disable_human_help',
      payload: {
        'enabled': nextValue,
      },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextValue
              ? 'Aide humaine autorisée pour ${session.teamName}.'
              : 'Aide humaine coupée pour ${session.teamName}.',
        ),
      ),
    );
  }

  Future<void> _extendSessionByOneHour(_GameSession session) async {
    final sessionRef =
        FirebaseFirestore.instance.collection('gameSessions').doc(session.id);
    final updatedExtraDuration = session.extraDurationHours + 1;
    final updatedEnd = session.startedAt.add(
      Duration(hours: session.baseDurationHours + updatedExtraDuration),
    );

    await sessionRef.update({
      'extraDurationHours': updatedExtraDuration,
      'effectiveEndsAt': updatedEnd.toUtc().toIso8601String(),
    });

    await _addTimelineEntry(
      sessionId: session.id,
      type: 'session_extended',
      label: 'Prolongation de 1h accordée par le MJ',
      source: 'mj',
    );

    await _addMjAction(
      sessionId: session.id,
      type: 'extend_session',
      payload: {
        'hoursAdded': 1,
      },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('1h ajoutée à ${session.teamName}.'),
      ),
    );
  }

  Future<void> _markEscalationClaimed(_GameSession session) async {
    final sessionRef =
        FirebaseFirestore.instance.collection('gameSessions').doc(session.id);

    await sessionRef.update({
      'humanEscalationStatus': 'claimed',
      'humanEscalationRequired': true,
    });

    await _addTimelineEntry(
      sessionId: session.id,
      type: 'human_escalation_claimed',
      label: 'Escalade humaine prise en charge par le MJ',
      source: 'mj',
    );

    await _addMjAction(
      sessionId: session.id,
      type: 'mark_escalation_claimed',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Escalade prise en charge pour ${session.teamName}.'),
      ),
    );
  }

  Future<void> _markEscalationResolved(_GameSession session) async {
    final sessionRef =
        FirebaseFirestore.instance.collection('gameSessions').doc(session.id);

    await sessionRef.update({
      'humanEscalationStatus': 'resolved',
      'humanEscalationRequired': false,
    });

    await _addTimelineEntry(
      sessionId: session.id,
      type: 'human_escalation_resolved',
      label: 'Assistance humaine marquée comme résolue par le MJ',
      source: 'mj',
    );

    await _addMjAction(
      sessionId: session.id,
      type: 'mark_escalation_resolved',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Assistance résolue pour ${session.teamName}.'),
      ),
    );
  }

  Future<void> _reopenEscalation(_GameSession session) async {
    final sessionRef =
        FirebaseFirestore.instance.collection('gameSessions').doc(session.id);

    await sessionRef.update({
      'humanEscalationStatus': 'pending',
      'humanEscalationRequired': true,
      'lastHelpRequestAt': DateTime.now().toUtc().toIso8601String(),
    });

    await _addTimelineEntry(
      sessionId: session.id,
      type: 'human_escalation_reopened',
      label: 'Escalade humaine relancée par le MJ',
      source: 'mj',
    );

    await _addMjAction(
      sessionId: session.id,
      type: 'reopen_escalation',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Escalade relancée pour ${session.teamName}.'),
      ),
    );
  }

  Future<void> _showSendHumanHelpMessageDialog(_GameSession session) async {
    _noteController.clear();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131A24),
          title: const Text(
            'Envoyer un message au joueur',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: _noteController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Exemple : Retournez vers A0 puis ouvrez la carte.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final text = _noteController.text.trim();
                if (text.isEmpty) return;

                Navigator.pop(context);
                await _sendHumanHelpMessage(session, text);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Message envoyé à ${session.teamName}.'),
                  ),
                );
              },
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendHumanHelpMessage(_GameSession session, String text) async {
    final sessionRef =
        FirebaseFirestore.instance.collection('gameSessions').doc(session.id);
    final now = DateTime.now().toUtc().toIso8601String();

    await sessionRef.collection('humanHelpMessages').add({
      'title': 'Réponse du maître du jeu',
      'text': text,
      'from': 'mj',
      'createdAt': now,
      'createdByUid': widget.profile.uid,
      'createdByName': widget.profile.displayName,
    });

    await _addTimelineEntry(
      sessionId: session.id,
      type: 'human_help_message_sent',
      label: 'Le MJ a envoyé un message au joueur',
      source: 'mj',
    );

    await _addMjAction(
      sessionId: session.id,
      type: 'send_human_help_message',
      payload: {
        'text': text,
      },
    );
  }

  Future<void> _showAddNoteDialog(_GameSession session) async {
    _noteController.clear();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131A24),
          title: const Text(
            'Ajouter une note MJ',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: _noteController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Observation, blocage, contexte utile...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final text = _noteController.text.trim();
                if (text.isEmpty) return;

                Navigator.pop(context);
                await _addMjNote(session.id, text);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Note MJ ajoutée pour ${session.teamName}.'),
                  ),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addMjNote(String sessionId, String text) async {
    final sessionRef =
        FirebaseFirestore.instance.collection('gameSessions').doc(sessionId);
    final now = DateTime.now().toUtc().toIso8601String();

    await sessionRef.collection('mjNotes').add({
      'createdAt': now,
      'createdByUid': widget.profile.uid,
      'createdByName': widget.profile.displayName,
      'text': text,
    });

    await _addTimelineEntry(
      sessionId: sessionId,
      type: 'mj_note_added',
      label: 'Note MJ ajoutée',
      source: 'mj',
    );

    await _addMjAction(
      sessionId: sessionId,
      type: 'add_note',
      payload: {
        'text': text,
      },
    );
  }

  Future<void> _addTimelineEntry({
    required String sessionId,
    required String type,
    required String label,
    required String source,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    await FirebaseFirestore.instance
        .collection('gameSessions')
        .doc(sessionId)
        .collection('timeline')
        .add({
      'type': type,
      'createdAt': now,
      'label': label,
      'source': source,
    });
  }

  Future<void> _addMjAction({
    required String sessionId,
    required String type,
    Map<String, dynamic>? payload,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    await FirebaseFirestore.instance
        .collection('gameSessions')
        .doc(sessionId)
        .collection('mjActions')
        .add({
      'type': type,
      'createdAt': now,
      'createdByUid': widget.profile.uid,
      'createdByName': widget.profile.displayName,
      ...?payload,
    });
  }
}

class _GraphHeaderCard extends StatelessWidget {
  final _GraphColumn column;

  const _GraphHeaderCard({required this.column});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101925),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: column.accent.withOpacity(0.38)),
      ),
      child: Column(
        children: [
          Text(
            column.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: column.accent,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            column.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF93A2B7),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendChip({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF121A24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF263245)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDEE7F5),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFactChip extends StatelessWidget {
  final String label;
  final String value;

  const _MiniFactChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF182130),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2A384B)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Color(0xFFDCE6F5),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AssistanceInlineChip extends StatelessWidget {
  final String label;
  final Color color;

  const _AssistanceInlineChip({
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
        border: Border.all(color: color.withOpacity(0.75)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _GraphColumn {
  final String title;
  final String subtitle;
  final List<String> nodeIds;
  final Color accent;

  const _GraphColumn({
    required this.title,
    required this.subtitle,
    required this.nodeIds,
    required this.accent,
  });
}

class _SessionTone {
  final Color background;
  final Color border;
  final Color dot;

  const _SessionTone({
    required this.background,
    required this.border,
    required this.dot,
  });
}

enum _AttentionLevel {
  neutral,
  normal,
  warning,
  danger,
  restricted,
}

enum _AssistanceState {
  none,
  pending,
  claimed,
  resolved,
}

class _PlaceTemplate {
  final String id;
  final String displayName;
  final String phase;
  final String storySynopsis;

  const _PlaceTemplate({
    required this.id,
    required this.displayName,
    required this.phase,
    required this.storySynopsis,
  });

  factory _PlaceTemplate.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final name = _firstNonEmpty([
      data['title'],
      data['name'],
      doc.id,
    ]);

    return _PlaceTemplate(
      id: doc.id,
      displayName: name,
      phase: (data['phase'] ?? '').toString(),
      storySynopsis: (data['storySynopsis'] ?? data['synopsis'] ?? '')
          .toString()
          .trim(),
    );
  }

  String get phaseLabel => phase.isEmpty ? 'Phase inconnue' : 'Phase $phase';
}

class _GameSession {
  final String id;
  final String gameId;
  final String siteId;
  final String scenarioId;
  final String scenarioTitle;
  final String teamName;
  final String teamCode;
  final String status;
  final bool active;
  final DateTime createdAt;
  final DateTime startedAt;
  final int baseDurationHours;
  final int extraDurationHours;
  final DateTime effectiveEndsAt;
  final String currentNodeId;
  final String currentPhase;
  final DateTime? lastProgressAt;
  final DateTime? lastHelpRequestAt;
  final int aiHelpCount;
  final bool humanHelpEnabled;
  final bool humanEscalationRequired;
  final String humanEscalationStatus;
  final String currentBlockageLevel;
  final String lastActionType;
  final String lastActionResult;
  final DateTime? finishedAt;
  final String finalOutcome;
  final List<String> visitedNodeIds;
  final List<String> visibleNodeIds;
  final List<String> openNodeIds;
  final List<String> blockedNodeIds;
  final List<String> completedNodeIds;
  final Map<String, dynamic> lastHelpContext;

  const _GameSession({
    required this.id,
    required this.gameId,
    required this.siteId,
    required this.scenarioId,
    required this.scenarioTitle,
    required this.teamName,
    required this.teamCode,
    required this.status,
    required this.active,
    required this.createdAt,
    required this.startedAt,
    required this.baseDurationHours,
    required this.extraDurationHours,
    required this.effectiveEndsAt,
    required this.currentNodeId,
    required this.currentPhase,
    required this.lastProgressAt,
    required this.lastHelpRequestAt,
    required this.aiHelpCount,
    required this.humanHelpEnabled,
    required this.humanEscalationRequired,
    required this.humanEscalationStatus,
    required this.currentBlockageLevel,
    required this.lastActionType,
    required this.lastActionResult,
    required this.finishedAt,
    required this.finalOutcome,
    required this.visitedNodeIds,
    required this.visibleNodeIds,
    required this.openNodeIds,
    required this.blockedNodeIds,
    required this.completedNodeIds,
    required this.lastHelpContext,
  });

  factory _GameSession.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return _GameSession(
      id: (data['id'] ?? doc.id).toString(),
      gameId: (data['gameId'] ?? '').toString(),
      siteId: (data['siteId'] ?? '').toString(),
      scenarioId: (data['scenarioId'] ?? '').toString(),
      scenarioTitle: (data['scenarioTitle'] ?? '').toString(),
      teamName: (data['teamName'] ?? '').toString(),
      teamCode: (data['teamCode'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      active: _readBool(data['active']),
      createdAt: _readDate(data['createdAt']) ?? DateTime.now().toUtc(),
      startedAt: _readDate(data['startedAt']) ?? DateTime.now().toUtc(),
      baseDurationHours: _readInt(data['baseDurationHours']),
      extraDurationHours: _readInt(data['extraDurationHours']),
      effectiveEndsAt:
          _readDate(data['effectiveEndsAt']) ?? DateTime.now().toUtc(),
      currentNodeId: (data['currentNodeId'] ?? '').toString(),
      currentPhase: (data['currentPhase'] ?? '').toString(),
      lastProgressAt: _readDate(data['lastProgressAt']),
      lastHelpRequestAt: _readDate(data['lastHelpRequestAt']),
      aiHelpCount: _readInt(data['aiHelpCount']),
      humanHelpEnabled: _readBool(data['humanHelpEnabled']),
      humanEscalationRequired: _readBool(data['humanEscalationRequired']),
      humanEscalationStatus: (data['humanEscalationStatus'] ?? '').toString(),
      currentBlockageLevel: (data['currentBlockageLevel'] ?? '').toString(),
      lastActionType: (data['lastActionType'] ?? '').toString(),
      lastActionResult: (data['lastActionResult'] ?? '').toString(),
      finishedAt: _readDate(data['finishedAt']),
      finalOutcome: (data['finalOutcome'] ?? '').toString(),
      visitedNodeIds: _readStringList(data['visitedNodeIds']),
      visibleNodeIds: _readStringList(data['visibleNodeIds']),
      openNodeIds: _readStringList(data['openNodeIds']),
      blockedNodeIds: _readStringList(data['blockedNodeIds']),
      completedNodeIds: _readStringList(data['completedNodeIds']),
      lastHelpContext: _readStringDynamicMap(data['lastHelpContext']),
    );
  }

  bool get isVisibleInMasterActiveView {
    if (finishedAt != null) return false;

    final normalizedStatus = status.trim().toLowerCase();
    const terminalStatuses = {
      'completed',
      'finished',
      'ended',
      'terminated',
      'closed',
      'archived',
      'cancelled',
      'canceled',
      'expired',
      'resolved',
    };

    if (terminalStatuses.contains(normalizedStatus)) {
      return false;
    }

    final nowUtc = DateTime.now().toUtc();

    if (effectiveEndsAt.isBefore(nowUtc) || effectiveEndsAt.isAtSameMomentAs(nowUtc)) {
      return false;
    }

    if (!active && normalizedStatus != 'paused') {
      return false;
    }

    return true;
  }

  _AttentionLevel get attentionLevel {
    if (humanEscalationRequired ||
        humanEscalationStatus == 'pending' ||
        currentBlockageLevel.toLowerCase() == 'high') {
      return _AttentionLevel.danger;
    }

    if (!humanHelpEnabled &&
        (aiHelpCount > 0 || currentBlockageLevel.toLowerCase() == 'medium')) {
      return _AttentionLevel.restricted;
    }

    if (aiHelpCount > 0 ||
        currentBlockageLevel.toLowerCase() == 'medium' ||
        currentBlockageLevel.toLowerCase() == 'low' ||
        lastHelpRequestAt != null) {
      return _AttentionLevel.warning;
    }

    return _AttentionLevel.normal;
  }

  _AssistanceState get assistanceState {
    final status = humanEscalationStatus.trim().toLowerCase();

    if (humanEscalationRequired) {
      if (status == 'claimed') return _AssistanceState.claimed;
      if (status == 'resolved') return _AssistanceState.resolved;
      return _AssistanceState.pending;
    }

    if (status == 'resolved') {
      return _AssistanceState.resolved;
    }

    return _AssistanceState.none;
  }

  String get assistanceStateLabel {
    switch (assistanceState) {
      case _AssistanceState.pending:
        return 'En attente';
      case _AssistanceState.claimed:
        return 'Prise en charge';
      case _AssistanceState.resolved:
        return 'Résolue';
      case _AssistanceState.none:
        return 'Aucune';
    }
  }

  String get attentionLabel {
    switch (attentionLevel) {
      case _AttentionLevel.danger:
        return 'Rouge';
      case _AttentionLevel.warning:
        return 'Orange';
      case _AttentionLevel.restricted:
        return 'Verrou';
      case _AttentionLevel.normal:
        return 'Stable';
      case _AttentionLevel.neutral:
        return 'Neutre';
    }
  }

  String get blockageLabel {
    final level = currentBlockageLevel.trim().toLowerCase();
    switch (level) {
      case 'high':
        return 'Élevé';
      case 'medium':
        return 'Moyen';
      case 'low':
        return 'Faible';
      default:
        return 'Aucun';
    }
  }

  String get statusLabel {
    if (status.trim().isNotEmpty) {
      switch (status.toLowerCase()) {
        case 'active':
          return 'En jeu';
        case 'completed':
          return 'Terminée';
        case 'paused':
          return 'En pause';
        case 'expired':
          return 'Expirée';
      }
      return status;
    }
    return active ? 'En jeu' : 'Inactive';
  }

  String get siteIdLabel => siteId.isEmpty ? 'site inconnu' : 'site $siteId';

  String get escalationLabel {
    if (humanEscalationRequired) {
      if (humanEscalationStatus == 'claimed') return 'Prise en charge';
      if (humanEscalationStatus == 'resolved') return 'Résolue';
      return 'Demandée';
    }
    return humanEscalationStatus.trim().toLowerCase() == 'resolved'
        ? 'Résolue'
        : 'Aucune';
  }

  String get remainingLabel {
    final difference = effectiveEndsAt.difference(DateTime.now().toUtc());
    final totalMinutes = difference.inMinutes;
    final absoluteMinutes = totalMinutes.abs();
    final hours = absoluteMinutes ~/ 60;
    final minutes = absoluteMinutes % 60;
    final formatted = '${hours}h${minutes.toString().padLeft(2, '0')}';
    return totalMinutes >= 0 ? formatted : '-$formatted';
  }

  bool get hasHelpContext => lastHelpContext.isNotEmpty;

  String get helpPlaceLabel {
    final placeId = (lastHelpContext['placeId'] ?? '').toString().trim();
    final placeName = (lastHelpContext['placeName'] ?? '').toString().trim();
    if (placeId.isEmpty && placeName.isEmpty) return '—';
    if (placeId.isNotEmpty && placeName.isNotEmpty) return '$placeId · $placeName';
    return placeId.isNotEmpty ? placeId : placeName;
  }

  List<String> get helpKeywords => _readStringList(lastHelpContext['keywords']);

  List<String> get helpRequiresAll =>
      _readStringList(lastHelpContext['requiresAllVisited']);

  List<String> get helpRequiresAny =>
      _readStringList(lastHelpContext['requiresAnyVisited']);

  String get helpRevealSummary {
    final revealSuspect = _readBool(lastHelpContext['revealSuspect']);
    final revealMotive = _readBool(lastHelpContext['revealMotive']);

    if (revealSuspect && revealMotive) {
      return 'Ce lieu peut potentiellement clarifier la piste suspect et la piste mobile.';
    }
    if (revealSuspect) {
      return 'Ce lieu peut potentiellement clarifier la piste suspect.';
    }
    if (revealMotive) {
      return 'Ce lieu peut potentiellement clarifier la piste mobile.';
    }
    return '';
  }

  String get lastProgressAtLabel => _formatDateTime(lastProgressAt);
  String get lastHelpRequestAtLabel => _formatDateTime(lastHelpRequestAt);
  String get effectiveEndsAtLabel => _formatDateTime(effectiveEndsAt);
}

String _safeInitial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first;
}

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is DateTime) return value.toUtc();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '—';
  final utc = value.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')} '
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')}';
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is num) return value != 0;
  return false;
}

List<String> _readStringList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

Map<String, dynamic> _readStringDynamicMap(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}
