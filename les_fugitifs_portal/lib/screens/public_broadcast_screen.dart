
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PublicBroadcastScreen extends StatelessWidget {
  const PublicBroadcastScreen({super.key});

  static const Map<String, String> _publicSlotByNode = {
    'A0': 'start',
    'A1': 'm11',
    'A2': 'm03',
    'A3': 'm15',
    'A4': 'm06',
    'A5': 'm13',
    'A6': 'm08',
    'B0': 'm01',
    'B1': 'm05',
    'B2': 'm12',
    'B3': 'm16',
    'B4': 'm09',
    'B5': 'm02',
    'C0': 'm07',
    'C1': 'm04',
    'C2': 'm14',
    'C3': 'm10',
    'C4': 'm17',
    'D0': 'final',
  };

  static const List<_PublicSlot> _slots = [
    _PublicSlot(
      id: 'start',
      alignment: Alignment(-0.92, -0.06),
      size: Size(220, 132),
      kind: _PublicSlotKind.start,
      label: 'Scène de crime',
    ),
    _PublicSlot(
      id: 'final',
      alignment: Alignment(0.92, 0.02),
      size: Size(220, 132),
      kind: _PublicSlotKind.finalSpot,
      label: 'Final',
    ),
    _PublicSlot(id: 'm01', alignment: Alignment(-0.52, -0.62), size: Size(112, 112)),
    _PublicSlot(id: 'm02', alignment: Alignment(-0.20, -0.42), size: Size(112, 112)),
    _PublicSlot(id: 'm03', alignment: Alignment(-0.62, 0.34), size: Size(118, 118)),
    _PublicSlot(id: 'm04', alignment: Alignment(0.26, -0.52), size: Size(110, 110)),
    _PublicSlot(id: 'm05', alignment: Alignment(-0.08, -0.68), size: Size(106, 106)),
    _PublicSlot(id: 'm06', alignment: Alignment(-0.38, 0.16), size: Size(110, 110)),
    _PublicSlot(id: 'm07', alignment: Alignment(0.08, 0.08), size: Size(110, 110)),
    _PublicSlot(id: 'm08', alignment: Alignment(-0.08, 0.58), size: Size(106, 106)),
    _PublicSlot(id: 'm09', alignment: Alignment(0.42, 0.46), size: Size(110, 110)),
    _PublicSlot(id: 'm10', alignment: Alignment(0.58, -0.34), size: Size(110, 110)),
    _PublicSlot(id: 'm11', alignment: Alignment(-0.74, -0.56), size: Size(106, 106)),
    _PublicSlot(id: 'm12', alignment: Alignment(0.14, -0.14), size: Size(106, 106)),
    _PublicSlot(id: 'm13', alignment: Alignment(-0.46, 0.62), size: Size(106, 106)),
    _PublicSlot(id: 'm14', alignment: Alignment(0.32, 0.62), size: Size(106, 106)),
    _PublicSlot(id: 'm15', alignment: Alignment(-0.50, 0.12), size: Size(102, 102)),
    _PublicSlot(id: 'm16', alignment: Alignment(0.02, -0.44), size: Size(106, 106)),
    _PublicSlot(id: 'm17', alignment: Alignment(0.72, 0.42), size: Size(106, 106)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B14),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('gameSessions')
            .where('active', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Erreur Firestore : ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 18,
                    height: 1.45,
                  ),
                ),
              ),
            );
          }

          final sessions = (snapshot.data?.docs ?? const [])
              .map(_PublicSession.fromDoc)
              .toList(growable: false);

          final sessionsBySlot = <String, List<_PublicSession>>{};
          for (final session in sessions) {
            final slotId = _publicSlotByNode[session.currentNodeId];
            if (slotId == null) continue;
            sessionsBySlot.putIfAbsent(slotId, () => <_PublicSession>[]).add(session);
          }

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/fond_tele_publique.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF08111D),
                            Color(0xFF102033),
                            Color(0xFF0A1625),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x44000000),
                        Color(0x28000000),
                        Color(0x66000000),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BroadcastLinkPainter(_slots),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          for (final slot in _slots)
                            _buildSlot(
                              boardSize: constraints.biggest,
                              slot: slot,
                              sessions: sessionsBySlot[slot.id] ?? const [],
                            ),
                          Positioned(
                            top: 0,
                            left: 0,
                            child: _buildTopPill(
                              icon: Icons.cast_connected_outlined,
                              label: 'Diffusion publique en direct',
                            ),
                          ),
                          Positioned(
                            top: 58,
                            left: 0,
                            child: _buildLogoBanner(),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: _buildTopPill(
                              icon: Icons.groups_2_outlined,
                              label: '${sessions.length} équipe${sessions.length > 1 ? 's' : ''} suivie${sessions.length > 1 ? 's' : ''}',
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC09111D),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0x334D6482)),
                                ),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.center,
                                  children: const [
                                    _PublicLegendChip(
                                      color: Color(0xFF2E8B57),
                                      label: 'Progression fluide',
                                    ),
                                    _PublicLegendChip(
                                      color: Color(0xFFD65A00),
                                      label: 'Besoin d’aide',
                                    ),
                                    _PublicLegendChip(
                                      color: Color(0xFFC74343),
                                      label: 'Alerte',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogoBanner() {
    return Image.asset(
      'assets/images/logo_fugitifs.png',
      height: 148,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox(
          height: 148,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Les Fugitifs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xCC09111D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x334D6482)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFFD7B8), size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot({
    required Size boardSize,
    required _PublicSlot slot,
    required List<_PublicSession> sessions,
  }) {
    final left = ((slot.alignment.x + 1) / 2) * (boardSize.width - slot.size.width);
    final top = ((slot.alignment.y + 1) / 2) * (boardSize.height - slot.size.height);
    final attention = _worstAttention(sessions);
    final border = _attentionColor(attention);
    final hasTeams = sessions.isNotEmpty;

    final child = slot.kind == _PublicSlotKind.hidden
        ? _buildAnonymousNode(sessions)
        : _buildAnchorNode(slot, sessions);

    return Positioned(
      left: left,
      top: top,
      width: slot.size.width,
      height: slot.size.height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: hasTeams
              ? const Color(0xD4172433)
              : const Color(0xB8142030),
          borderRadius: BorderRadius.circular(slot.kind == _PublicSlotKind.hidden ? 26 : 34),
          border: Border.all(
            color: border,
            width: hasTeams ? 1.8 : 1.25,
          ),
          boxShadow: hasTeams
              ? [
                  BoxShadow(
                    color: Color.fromRGBO(border.red, border.green, border.blue, 0.18),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }

  Widget _buildAnchorNode(
    _PublicSlot slot,
    List<_PublicSession> sessions,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot.label ?? '',
            style: TextStyle(
              color: Colors.white.withOpacity(0.96),
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: sessions.isEmpty
                ? Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      slot.kind == _PublicSlotKind.start
                          ? 'Aucune équipe au départ'
                          : 'Aucune équipe proche du final',
                      style: const TextStyle(
                        color: Color(0xFFCCD6E4),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: sessions
                        .map((session) => _buildPublicTeamChip(session))
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnonymousNode(List<_PublicSession> sessions) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: sessions.isEmpty
          ? Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                  ),
                ),
              ),
            )
          : Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: sessions
                    .map((session) => _buildPublicTeamChip(session))
                    .toList(growable: false),
              ),
            ),
    );
  }

  Widget _buildPublicTeamChip(_PublicSession session) {
    final color = _attentionColor(session.attention);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xCC111C2A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            session.teamLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  _BroadcastAttention _worstAttention(List<_PublicSession> sessions) {
    if (sessions.isEmpty) return _BroadcastAttention.neutral;
    if (sessions.any((session) => session.attention == _BroadcastAttention.alert)) {
      return _BroadcastAttention.alert;
    }
    if (sessions.any((session) => session.attention == _BroadcastAttention.help)) {
      return _BroadcastAttention.help;
    }
    return _BroadcastAttention.ok;
  }

  Color _attentionColor(_BroadcastAttention attention) {
    switch (attention) {
      case _BroadcastAttention.alert:
        return const Color(0xFFC74343);
      case _BroadcastAttention.help:
        return const Color(0xFFD65A00);
      case _BroadcastAttention.ok:
        return const Color(0xFF2E8B57);
      case _BroadcastAttention.neutral:
        return const Color(0x445E738F);
    }
  }
}

class _BroadcastLinkPainter extends CustomPainter {
  final List<_PublicSlot> slots;

  const _BroadcastLinkPainter(this.slots);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x447AA5C8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final start = slots.firstWhere((slot) => slot.id == 'start');
    final end = slots.firstWhere((slot) => slot.id == 'final');
    final middle = slots.where((slot) => slot.kind == _PublicSlotKind.hidden).toList(growable: false);

    Offset centerOf(_PublicSlot slot) {
      final left = ((slot.alignment.x + 1) / 2) * (size.width - slot.size.width);
      final top = ((slot.alignment.y + 1) / 2) * (size.height - slot.size.height);
      return Offset(left + slot.size.width / 2, top + slot.size.height / 2);
    }

    final startCenter = centerOf(start);
    final endCenter = centerOf(end);

    for (final slot in middle) {
      final c = centerOf(slot);
      final path = Path()
        ..moveTo(startCenter.dx, startCenter.dy)
        ..quadraticBezierTo(
          (startCenter.dx + c.dx) / 2,
          c.dy - 40,
          c.dx,
          c.dy,
        );
      canvas.drawPath(path, paint);
    }

    for (final slot in middle.where((slot) => slot.alignment.x > -0.1)) {
      final c = centerOf(slot);
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..quadraticBezierTo(
          (c.dx + endCenter.dx) / 2,
          c.dy + 34,
          endCenter.dx,
          endCenter.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BroadcastLinkPainter oldDelegate) => false;
}

class _PublicLegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _PublicLegendChip({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

enum _PublicSlotKind {
  start,
  hidden,
  finalSpot,
}

class _PublicSlot {
  final String id;
  final Alignment alignment;
  final Size size;
  final _PublicSlotKind kind;
  final String? label;

  const _PublicSlot({
    required this.id,
    required this.alignment,
    required this.size,
    this.kind = _PublicSlotKind.hidden,
    this.label,
  });
}

enum _BroadcastAttention {
  neutral,
  ok,
  help,
  alert,
}

class _PublicSession {
  final String id;
  final String teamName;
  final String teamCode;
  final String currentNodeId;
  final int aiHelpCount;
  final bool humanEscalationRequired;
  final String humanEscalationStatus;
  final String currentBlockageLevel;

  const _PublicSession({
    required this.id,
    required this.teamName,
    required this.teamCode,
    required this.currentNodeId,
    required this.aiHelpCount,
    required this.humanEscalationRequired,
    required this.humanEscalationStatus,
    required this.currentBlockageLevel,
  });

  factory _PublicSession.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _PublicSession(
      id: (data['id'] ?? doc.id).toString(),
      teamName: (data['teamName'] ?? '').toString(),
      teamCode: (data['teamCode'] ?? '').toString(),
      currentNodeId: (data['currentNodeId'] ?? '').toString(),
      aiHelpCount: _readInt(data['aiHelpCount']),
      humanEscalationRequired: _readBool(data['humanEscalationRequired']),
      humanEscalationStatus: (data['humanEscalationStatus'] ?? '').toString(),
      currentBlockageLevel: (data['currentBlockageLevel'] ?? '').toString(),
    );
  }

  String get teamLabel {
    final code = teamCode.trim();
    if (code.isNotEmpty) return code;
    final name = teamName.trim();
    if (name.isNotEmpty) return name;
    return 'Équipe';
  }

  _BroadcastAttention get attention {
    final blockage = currentBlockageLevel.toLowerCase();
    if (humanEscalationRequired ||
        humanEscalationStatus == 'pending' ||
        blockage == 'high') {
      return _BroadcastAttention.alert;
    }
    if (aiHelpCount > 0 || blockage == 'low' || blockage == 'medium') {
      return _BroadcastAttention.help;
    }
    return _BroadcastAttention.ok;
  }
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
  return false;
}
