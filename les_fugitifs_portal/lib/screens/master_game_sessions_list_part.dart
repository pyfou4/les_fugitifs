part of 'master_game_screen.dart';

extension _MasterGameScreenSessionsListExtension on _MasterGameScreenState {
  Widget _buildSessionsCard(List<_GameSession> sessions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sessions suivies',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'La carte globale montre où regarder. Cette liste aide à parcourir rapidement les sessions une par une.',
              style: TextStyle(
                color: Color(0xFF8C99AE),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            if (sessions.isEmpty)
              const Text(
                'Aucune session disponible.',
                style: TextStyle(
                  color: Color(0xFF6F7C90),
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Column(
                children: sessions
                    .map(_buildSessionListItem)
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionListItem(_GameSession session) {
    final selected = session.id == _selectedSessionId;
    final tone = _sessionTone(session);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSessionId = session.id;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF162133)
                : const Color(0xFF111923),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? tone.border : const Color(0xFF253142),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSessionAvatar(session, tone),
              const SizedBox(width: 14),
              Expanded(
                child: _buildSessionListItemContent(session),
              ),
              const SizedBox(width: 12),
              _buildSessionAttentionBadge(session, tone),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionAvatar(_GameSession session, _SessionTone tone) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: tone.background,
        shape: BoxShape.circle,
        border: Border.all(color: tone.border),
      ),
      child: Center(
        child: Text(
          _safeInitial(
            session.teamCode.isNotEmpty ? session.teamCode : session.teamName,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionListItemContent(_GameSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.teamName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${session.scenarioTitle} · ${session.siteIdLabel}',
          style: const TextStyle(
            color: Color(0xFF93A2B7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MiniFactChip(
              label: 'Lieu',
              value: session.currentNodeId,
            ),
            _MiniFactChip(
              label: 'Reste',
              value: session.remainingLabel,
            ),
            _MiniFactChip(
              label: 'Blocage',
              value: session.blockageLabel,
            ),
            if (session.assistanceState != _AssistanceState.none)
              _AssistanceInlineChip(
                label: session.assistanceStateLabel,
                color: _assistanceStateColor(session.assistanceState),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionAttentionBadge(_GameSession session, _SessionTone tone) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.border),
      ),
      child: Text(
        session.attentionLabel,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
