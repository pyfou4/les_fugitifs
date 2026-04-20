part of 'master_game_screen.dart';

extension _MasterGameScreenSessionPanelExtension on _MasterGameScreenState {

  Widget _buildSidePanel(_GameSession? session) {
    if (session == null) {
      return _buildEmptySidePanel();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSessionDetailsCard(session),
        const SizedBox(height: 24),
        _buildRecentNotesCard(session.id),
        const SizedBox(height: 24),
        _buildTimelineCard(session.id),
      ],
    );
  }

  Widget _buildEmptySidePanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Détail session',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Aucune session sélectionnée pour le moment.',
              style: TextStyle(
                color: Color(0xFF8C99AE),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionDetailsCard(_GameSession session) {
    final tone = _sessionTone(session);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSessionDetailsHeader(session, tone),
            const SizedBox(height: 18),
            _buildSessionDetailsFacts(session),
            const SizedBox(height: 28),
            _buildSessionActionsSection(session),
            const SizedBox(height: 28),
            _buildAssistancePanel(session),
            const SizedBox(height: 28),
            _buildSessionProgressSection(session),
            const SizedBox(height: 18),
            _buildSessionOpenNodesSection(session),
            const SizedBox(height: 18),
            _buildSessionRuntimeSection(session),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionDetailsHeader(_GameSession session, _SessionTone tone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                session.teamName,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: tone.background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: tone.border),
              ),
              child: Text(
                session.statusLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${session.scenarioTitle} · ${session.siteIdLabel}',
          style: const TextStyle(
            color: Color(0xFF93A2B7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionDetailsFacts(_GameSession session) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildInfoTile('Lieu actuel', session.currentNodeId),
        _buildInfoTile('Phase', session.currentPhase),
        _buildInfoTile('Temps restant', session.remainingLabel),
        _buildInfoTile('Aides IA', '${session.aiHelpCount}'),
        _buildInfoTile('Blocage', session.blockageLabel),
        _buildInfoTile(
          'Aide humaine',
          session.humanHelpEnabled ? 'Oui' : 'Non',
        ),
        _buildInfoTile(
          'Assistance',
          session.assistanceStateLabel,
        ),
      ],
    );
  }

  Widget _buildSessionActionsSection(_GameSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions MJ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => _toggleHumanHelp(session),
              icon: Icon(
                session.humanHelpEnabled
                    ? Icons.support_agent_outlined
                    : Icons.support_agent,
              ),
              label: Text(
                session.humanHelpEnabled
                    ? 'Couper l’aide humaine'
                    : 'Autoriser l’aide humaine',
              ),
            ),
            FilledButton.icon(
              onPressed: () => _extendSessionByOneHour(session),
              icon: const Icon(Icons.schedule),
              label: const Text('Ajouter 1h'),
            ),
            FilledButton.icon(
              onPressed: () => _showAddNoteDialog(session),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Ajouter une note'),
            ),
            FilledButton.icon(
              onPressed: () => _showSendHumanHelpMessageDialog(session),
              icon: const Icon(Icons.mark_chat_unread_outlined),
              label: const Text('Envoyer un message'),
            ),
            OutlinedButton.icon(
              onPressed: session.humanEscalationRequired &&
                      session.assistanceState != _AssistanceState.claimed
                  ? () => _markEscalationClaimed(session)
                  : null,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Prendre en charge'),
            ),
            OutlinedButton.icon(
              onPressed: session.assistanceState == _AssistanceState.claimed ||
                      session.assistanceState == _AssistanceState.pending
                  ? () => _markEscalationResolved(session)
                  : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Marquer résolue'),
            ),
            OutlinedButton.icon(
              onPressed: session.humanHelpEnabled &&
                      session.assistanceState == _AssistanceState.resolved
                  ? () => _reopenEscalation(session)
                  : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Relancer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionProgressSection(_GameSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progression visible',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        _buildStringChipWrap(
          session.visitedNodeIds,
          const Color(0xFF2E8B57),
        ),
      ],
    );
  }

  Widget _buildSessionOpenNodesSection(_GameSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lieux ouverts',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        _buildStringChipWrap(
          session.openNodeIds,
          const Color(0xFFD65A00),
        ),
      ],
    );
  }

  Widget _buildSessionRuntimeSection(_GameSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Infos runtime',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        _buildRuntimeLine('Dernière progression', session.lastProgressAtLabel),
        _buildRuntimeLine(
          'Dernière demande d’aide',
          session.lastHelpRequestAtLabel,
        ),
        _buildRuntimeLine('Fin effective', session.effectiveEndsAtLabel),
        _buildRuntimeLine('Escalade', session.escalationLabel),
        _buildRuntimeLine(
          'Aide humaine autorisée',
          session.humanHelpEnabled ? 'Oui' : 'Non',
        ),
      ],
    );
  }

  Widget _buildAssistancePanel(_GameSession session) {
    final stateColor = _assistanceStateColor(session.assistanceState);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101925),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF263245)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assistance humaine',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Zone dédiée au suivi des demandes humaines. Elle permet de voir si une équipe attend une aide, si elle est déjà prise en charge, ou si le traitement est terminé.',
            style: TextStyle(
              color: Color(0xFF8C99AE),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildAssistanceBadge(
                'État ${session.assistanceStateLabel}',
                stateColor,
              ),
              _buildAssistanceBadge(
                session.humanHelpEnabled
                    ? 'Aide humaine autorisée'
                    : 'Aide humaine coupée',
                session.humanHelpEnabled
                    ? const Color(0xFF2E8B57)
                    : const Color(0xFF54708F),
              ),
              if (session.humanEscalationRequired)
                _buildAssistanceBadge(
                  'Escalade active',
                  const Color(0xFFC74343),
                ),
              if (!session.humanEscalationRequired &&
                  session.assistanceState == _AssistanceState.none &&
                  session.lastHelpRequestAt != null)
                _buildAssistanceBadge(
                  'Historique d’aide',
                  const Color(0xFFD65A00),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRuntimeLine(
            'Dernière demande',
            session.lastHelpRequestAtLabel,
          ),
          _buildRuntimeLine(
            'Statut d’escalade',
            session.escalationLabel,
          ),
          _buildRuntimeLine(
            'Niveau de blocage',
            session.blockageLabel,
          ),
          _buildRuntimeLine(
            'Aides IA déjà utilisées',
            '${session.aiHelpCount}',
          ),
          if (session.hasHelpContext) ...[
            const SizedBox(height: 14),
            const Text(
              'Contexte transmis par le joueur',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            _buildRuntimeLine(
              'Lieu ciblé',
              session.helpPlaceLabel,
            ),
            if (session.helpKeywords.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildStringChipWrap(
                  session.helpKeywords,
                  const Color(0xFF5AA6FF),
                ),
              ),
            if (session.helpRequiresAll.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildInfoCallout(
                  title: 'Prérequis obligatoires encore utiles',
                  body: session.helpRequiresAll.join(', '),
                  tone: const Color(0xFFD65A00),
                ),
              ),
            if (session.helpRequiresAny.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildInfoCallout(
                  title: 'Prérequis alternatifs possibles',
                  body: session.helpRequiresAny.join(', '),
                  tone: const Color(0xFF7E87FF),
                ),
              ),
            if (session.helpRevealSummary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildInfoCallout(
                  title: 'Valeur potentielle du lieu',
                  body: session.helpRevealSummary,
                  tone: const Color(0xFF2E8B57),
                ),
              ),
          ],
          if (!session.humanHelpEnabled) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF152336),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF54708F)),
              ),
              child: const Text(
                'L’aide humaine est actuellement désactivée pour cette session. Une équipe peut donc rester bloquée sans pouvoir être relayée vers un humain.',
                style: TextStyle(
                  color: Color(0xFFDCE6F5),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentNotesCard(String sessionId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dernières notes MJ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les notes ajoutées par les MJ aident à garder le contexte sans toucher à la logique de session.',
              style: TextStyle(
                color: Color(0xFF8C99AE),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('gameSessions')
                  .doc(sessionId)
                  .collection('mjNotes')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Erreur notes MJ : ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  );
                }

                final docs = snapshot.data?.docs ?? const [];

                if (docs.isEmpty) {
                  return const Text(
                    'Aucune note MJ pour cette session.',
                    style: TextStyle(
                      color: Color(0xFF6F7C90),
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final createdAt = _formatDateTime(_readDate(data['createdAt']));
                    final author = (data['createdByName'] ?? 'MJ').toString();
                    final text = (data['text'] ?? '').toString().trim();

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111A27),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF263245)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$author · $createdAt',
                            style: const TextStyle(
                              color: Color(0xFFAED0FF),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            text.isEmpty ? '—' : text,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(String sessionId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Timeline récente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Historique rapide des événements de session, utile pour recoller le film sans ouvrir Firestore à la main.',
              style: TextStyle(
                color: Color(0xFF8C99AE),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('gameSessions')
                  .doc(sessionId)
                  .collection('timeline')
                  .orderBy('createdAt', descending: true)
                  .limit(8)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Erreur timeline : ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  );
                }

                final docs = snapshot.data?.docs ?? const [];

                if (docs.isEmpty) {
                  return const Text(
                    'Aucune entrée timeline pour cette session.',
                    style: TextStyle(
                      color: Color(0xFF6F7C90),
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final createdAt = _formatDateTime(_readDate(data['createdAt']));
                    final label = (data['label'] ?? '').toString().trim();
                    final type = (data['type'] ?? '').toString().trim();
                    final source = (data['source'] ?? '').toString().trim();

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111A27),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF263245)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$createdAt · ${source.isEmpty ? 'runtime' : source}',
                            style: const TextStyle(
                              color: Color(0xFFAED0FF),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            label.isEmpty ? type : label,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (type.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              type,
                              style: const TextStyle(
                                color: Color(0xFF8C99AE),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if ((data['placeName'] ?? '').toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Lieu: ${(data['placeName'] ?? '').toString().trim()}',
                              style: const TextStyle(
                                color: Color(0xFFDCE6F5),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (_readStringList(data['keywords']).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildStringChipWrap(
                              _readStringList(data['keywords']),
                              const Color(0xFF5AA6FF),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(minWidth: 98),
      decoration: BoxDecoration(
        color: const Color(0xFF111A27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263245)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A99AF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStringChipWrap(List<String> values, Color color) {
    if (values.isEmpty) {
      return const Text(
        'Aucune donnée pour l’instant.',
        style: TextStyle(
          color: Color(0xFF6F7C90),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values
          .map(
            (value) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withOpacity(0.6)),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildInfoCallout({
    required String title,
    required String body,
    required Color tone,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tone,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFDCE6F5),
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A99AF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistanceBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.75)),
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
