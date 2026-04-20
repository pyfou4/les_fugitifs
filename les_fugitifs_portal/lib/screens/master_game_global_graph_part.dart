part of 'master_game_screen.dart';

extension _MasterGameScreenGlobalGraphExtension on _MasterGameScreenState {

  // ---------------------------------------------------------------------------
  // Global graph
  // ---------------------------------------------------------------------------

  Widget _buildGlobalGraphCard({
    required Map<String, _PlaceTemplate> templates,
    required Map<String, List<_GameSession>> sessionsByNode,
    required List<_GameSession> sessions,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGlobalGraphHeader(
              templates: templates,
              sessionsByNode: sessionsByNode,
            ),
            const SizedBox(height: 22),
            _buildGlobalGraphViewport(
              templates: templates,
              sessionsByNode: sessionsByNode,
            ),
            const SizedBox(height: 18),
            _buildGlobalGraphLegend(),
            _buildGlobalGraphEmptyState(sessions),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalGraphHeader({
    required Map<String, _PlaceTemplate> templates,
    required Map<String, List<_GameSession>> sessionsByNode,
  }) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Carte globale du scénario',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Vue d’ensemble compacte avec tous les postes visibles. Clique un lieu ou une équipe pour ouvrir le détail. Le bouton d’agrandissement ouvre une carte plus confortable à lire.',
                style: TextStyle(
                  color: Color(0xFF8C99AE),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _openBroadcastScreen,
          icon: const Icon(Icons.cast_connected_outlined),
          label: const Text('Diffuser'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => _openGraphDialog(
            templates: templates,
            sessionsByNode: sessionsByNode,
          ),
          icon: const Icon(Icons.open_in_full),
          label: const Text('Agrandir'),
        ),
      ],
    );
  }

  Widget _buildGlobalGraphViewport({
    required Map<String, _PlaceTemplate> templates,
    required Map<String, List<_GameSession>> sessionsByNode,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: const Color(0xFF09111D),
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: double.infinity,
              height: 560,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topLeft,
                  child: _buildGraphBoard(
                    templates,
                    sessionsByNode,
                    compact: true,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlobalGraphLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: const [
        _LegendChip(
          color: Color(0xFF2E8B57),
          label: 'Parcours fluide',
        ),
        _LegendChip(
          color: Color(0xFFD65A00),
          label: 'Aide IA / blocage léger',
        ),
        _LegendChip(
          color: Color(0xFFC74343),
          label: 'Danger / escalade MJ',
        ),
        _LegendChip(
          color: Color(0xFF54708F),
          label: 'Aide humaine coupée',
        ),
      ],
    );
  }

  Widget _buildGlobalGraphEmptyState(List<_GameSession> sessions) {
    if (sessions.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return const Padding(
      padding: EdgeInsets.only(top: 18),
      child: Text(
        'Aucune session live pour le moment dans gameSessions.',
        style: TextStyle(
          color: Color(0xFF6F7C90),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGraphBoard(
    Map<String, _PlaceTemplate> templates,
    Map<String, List<_GameSession>> sessionsByNode, {
    required bool compact,
  }) {
    final boardWidth = compact ? 1820.0 : 2040.0;

    return SizedBox(
      width: boardWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int columnIndex = 0;
              columnIndex < _MasterGameScreenState._graphColumns.length;
              columnIndex++) ...[
            _buildGraphColumn(
              column: _MasterGameScreenState._graphColumns[columnIndex],
              templates: templates,
              sessionsByNode: sessionsByNode,
              compact: compact,
            ),
            if (columnIndex < _MasterGameScreenState._graphColumns.length - 1)
              _buildColumnConnector(
                from: _MasterGameScreenState._graphColumns[columnIndex],
                to: _MasterGameScreenState._graphColumns[columnIndex + 1],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildGraphColumn({
    required _GraphColumn column,
    required Map<String, _PlaceTemplate> templates,
    required Map<String, List<_GameSession>> sessionsByNode,
    required bool compact,
  }) {
    return SizedBox(
      width: 210,
      child: Column(
        children: [
          _GraphHeaderCard(column: column),
          const SizedBox(height: 18),
          for (int index = 0; index < column.nodeIds.length; index++) ...[
            _buildGraphNodeCard(
              nodeId: column.nodeIds[index],
              template: templates[column.nodeIds[index]],
              sessions: sessionsByNode[column.nodeIds[index]] ?? const [],
              accent: column.accent,
              compact: compact,
            ),
            if (index < column.nodeIds.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildGraphNodeCard({
    required String nodeId,
    required _PlaceTemplate? template,
    required List<_GameSession> sessions,
    required Color accent,
    required bool compact,
  }) {
    return compact
        ? _buildCompactNodeCard(
            nodeId: nodeId,
            template: template,
            sessions: sessions,
            accent: accent,
          )
        : _buildDetailedNodeCard(
            nodeId: nodeId,
            template: template,
            sessions: sessions,
            accent: accent,
          );
  }

  Widget _buildColumnConnector({
    required _GraphColumn from,
    required _GraphColumn to,
  }) {
    return SizedBox(
      width: 52,
      child: Padding(
        padding: const EdgeInsets.only(top: 108),
        child: Column(
          children: [
            Container(
              height: 2,
              width: 52,
              color: const Color(0xFF29405C),
            ),
            const SizedBox(height: 12),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF131E2C),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF2C4462)),
              ),
              child: const Icon(
                Icons.double_arrow_rounded,
                size: 20,
                color: Color(0xFFD65A00),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 2,
              width: 52,
              color: const Color(0xFF29405C),
            ),
            const SizedBox(height: 10),
            Text(
              '${from.subtitle} → ${to.subtitle}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF748398),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactNodeCard({
    required String nodeId,
    required _PlaceTemplate? template,
    required List<_GameSession> sessions,
    required Color accent,
  }) {
    final worstLevel = _worstAttentionLevel(sessions);
    final borderColor = _nodeBorderColor(sessions, worstLevel);
    final backgroundColor = _graphNodeBackgroundColor(sessions);

    return InkWell(
      onTap: _graphNodeTapHandler(sessions),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 210,
        padding: const EdgeInsets.all(12),
        decoration: _buildGraphNodeDecoration(
          sessions: sessions,
          borderColor: borderColor,
          backgroundColor: backgroundColor,
          borderRadius: 22,
          borderWidth: 1.4,
          shadowOpacity: 0.12,
          blurRadius: 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGraphNodeTopRow(
              nodeId: nodeId,
              sessions: sessions,
              accent: accent,
              compact: true,
            ),
            const SizedBox(height: 10),
            _buildGraphNodeTitle(template, compact: true),
            const SizedBox(height: 10),
            _buildCompactGraphNodeContent(sessions),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedNodeCard({
    required String nodeId,
    required _PlaceTemplate? template,
    required List<_GameSession> sessions,
    required Color accent,
  }) {
    final worstLevel = _worstAttentionLevel(sessions);
    final borderColor = _nodeBorderColor(sessions, worstLevel);
    final backgroundColor = _graphNodeBackgroundColor(sessions);

    return InkWell(
      onTap: _graphNodeTapHandler(sessions),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 210,
        padding: const EdgeInsets.all(16),
        decoration: _buildGraphNodeDecoration(
          sessions: sessions,
          borderColor: borderColor,
          backgroundColor: backgroundColor,
          borderRadius: 24,
          borderWidth: 1.5,
          shadowOpacity: 0.14,
          blurRadius: 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGraphNodeTopRow(
              nodeId: nodeId,
              sessions: sessions,
              accent: accent,
              compact: false,
            ),
            const SizedBox(height: 12),
            _buildGraphNodeTitle(template, compact: false),
            const SizedBox(height: 4),
            _buildGraphNodePhase(template),
            _buildGraphNodeSynopsis(template),
            const SizedBox(height: 14),
            _buildDetailedGraphNodeContent(sessions),
          ],
        ),
      ),
    );
  }

  VoidCallback? _graphNodeTapHandler(List<_GameSession> sessions) {
    if (sessions.isEmpty) {
      return null;
    }

    return () {
      setState(() {
        _selectedSessionId = sessions.first.id;
      });
    };
  }

  Color _graphNodeBackgroundColor(List<_GameSession> sessions) {
    return sessions.isEmpty
        ? const Color(0xFF101925)
        : const Color(0xFF152132);
  }

  BoxDecoration _buildGraphNodeDecoration({
    required List<_GameSession> sessions,
    required Color borderColor,
    required Color backgroundColor,
    required double borderRadius,
    required double borderWidth,
    required double shadowOpacity,
    required double blurRadius,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: sessions.isEmpty
          ? null
          : [
              BoxShadow(
                color: borderColor.withOpacity(shadowOpacity),
                blurRadius: blurRadius,
                spreadRadius: 1,
              ),
            ],
    );
  }

  Widget _buildGraphNodeTopRow({
    required String nodeId,
    required List<_GameSession> sessions,
    required Color accent,
    required bool compact,
  }) {
    final horizontalPadding = compact ? 10.0 : 12.0;
    final verticalPadding = compact ? 7.0 : 9.0;
    final borderRadius = compact ? 14.0 : 16.0;
    final fontSize = compact ? 15.0 : 16.0;
    final counterHorizontalPadding = compact ? 8.0 : 10.0;
    final counterVerticalPadding = compact ? 6.0 : 7.0;
    final counterFontSize = compact ? 10.0 : 12.0;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.16),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: accent.withOpacity(0.34)),
          ),
          child: Text(
            nodeId,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: counterHorizontalPadding,
            vertical: counterVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1D2A3C),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _graphNodeTeamCountLabel(sessions),
            style: TextStyle(
              color: const Color(0xFFFFD7B8),
              fontWeight: FontWeight.w800,
              fontSize: counterFontSize,
            ),
          ),
        ),
      ],
    );
  }

  String _graphNodeTeamCountLabel(List<_GameSession> sessions) {
    if (sessions.isEmpty) {
      return '0 équipe';
    }

    return '${sessions.length} équipe${sessions.length > 1 ? 's' : ''}';
  }

  Widget _buildGraphNodeTitle(_PlaceTemplate? template, {required bool compact}) {
    return Text(
      template?.displayName ?? 'Lieu à configurer',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: compact ? 14 : 16,
        height: compact ? 1.22 : 1.25,
      ),
    );
  }

  Widget _buildGraphNodePhase(_PlaceTemplate? template) {
    return Text(
      template?.phaseLabel ?? 'Phase inconnue',
      style: const TextStyle(
        color: Color(0xFF7F8CA0),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  Widget _buildGraphNodeSynopsis(_PlaceTemplate? template) {
    final synopsis = (template?.storySynopsis ?? '').trim();
    if (synopsis.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        synopsis,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF90A0B5),
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildCompactGraphNodeContent(List<_GameSession> sessions) {
    if (sessions.isEmpty) {
      return const Text(
        '—',
        style: TextStyle(
          color: Color(0xFF6F7C90),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGraphNodeAssistanceWrap(
          sessions,
          includeTeamLabel: false,
          bottomPadding: 8,
        ),
        _buildGraphNodeSessionWrap(sessions),
      ],
    );
  }

  Widget _buildDetailedGraphNodeContent(List<_GameSession> sessions) {
    if (sessions.isEmpty) {
      return const Text(
        'Aucune équipe sur ce lieu',
        style: TextStyle(
          color: Color(0xFF6F7C90),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGraphNodeAssistanceWrap(
          sessions,
          includeTeamLabel: true,
          bottomPadding: 10,
        ),
        _buildGraphNodeSessionWrap(sessions),
      ],
    );
  }

  Widget _buildGraphNodeAssistanceWrap(
    List<_GameSession> sessions, {
    required bool includeTeamLabel,
    required double bottomPadding,
  }) {
    final assistedSessions = sessions
        .where((session) => session.assistanceState != _AssistanceState.none)
        .toList(growable: false);

    if (assistedSessions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: assistedSessions
            .map(
              (session) => _buildAssistanceBadge(
                includeTeamLabel
                    ? '${session.teamCode.isNotEmpty ? session.teamCode : session.teamName} · ${session.assistanceStateLabel}'
                    : session.assistanceStateLabel,
                _assistanceStateColor(session.assistanceState),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildGraphNodeSessionWrap(List<_GameSession> sessions) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sessions
          .map(
            (session) => _buildSessionChip(
              session: session,
              highlighted: session.id == _selectedSessionId,
            ),
          )
          .toList(growable: false),
    );
  }


  Widget _buildSessionChip({
    required _GameSession session,
    required bool highlighted,
  }) {
    final tone = _sessionTone(session);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedSessionId = session.id;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: highlighted ? Colors.white : tone.border,
            width: highlighted ? 1.3 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: tone.dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              session.teamCode.isNotEmpty ? session.teamCode : session.teamName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
