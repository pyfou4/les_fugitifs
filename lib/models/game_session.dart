class GameSession {
  final String id;
  final String activationCode;
  final String lockedScenarioId;
  final String siteId;
  final String status;
  final String? startedAt;
  final String? expiresAt;

  final String trueSuspectId;
  final String trueMotiveId;
  final Map<String, String?> suspectByPlace;
  final Map<String, String?> motiveByPlace;
  final Set<String> playerMarkedSuspectIds;
  final Set<String> playerMarkedMotiveIds;

  GameSession({
    required this.id,
    required this.activationCode,
    required this.lockedScenarioId,
    required this.siteId,
    required this.status,
    required this.trueSuspectId,
    required this.trueMotiveId,
    required this.suspectByPlace,
    required this.motiveByPlace,
    this.startedAt,
    this.expiresAt,
    Set<String>? playerMarkedSuspectIds,
    Set<String>? playerMarkedMotiveIds,
  })  : playerMarkedSuspectIds = playerMarkedSuspectIds ?? <String>{},
        playerMarkedMotiveIds = playerMarkedMotiveIds ?? <String>{};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activationCode': activationCode,
      'lockedScenarioId': lockedScenarioId,
      'siteId': siteId,
      'status': status,
      'startedAt': startedAt,
      'expiresAt': expiresAt,
      'trueSuspectId': trueSuspectId,
      'trueMotiveId': trueMotiveId,
      'suspectByPlace': suspectByPlace,
      'motiveByPlace': motiveByPlace,
      'playerMarkedSuspectIds': playerMarkedSuspectIds.toList(),
      'playerMarkedMotiveIds': playerMarkedMotiveIds.toList(),
    };
  }

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: (json['id'] ?? '').toString(),
      activationCode: (json['activationCode'] ?? '').toString(),
      lockedScenarioId: (json['lockedScenarioId'] ?? '').toString(),
      siteId: (json['siteId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      startedAt: json['startedAt']?.toString(),
      expiresAt: json['expiresAt']?.toString(),
      trueSuspectId: (json['trueSuspectId'] ?? '').toString(),
      trueMotiveId: (json['trueMotiveId'] ?? '').toString(),
      suspectByPlace: (json['suspectByPlace'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value?.toString())),
      motiveByPlace: (json['motiveByPlace'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value?.toString())),
      playerMarkedSuspectIds:
          Set<String>.from(json['playerMarkedSuspectIds'] as List<dynamic>? ?? []),
      playerMarkedMotiveIds:
          Set<String>.from(json['playerMarkedMotiveIds'] as List<dynamic>? ?? []),
    );
  }

  factory GameSession.fromFirestore(String id, Map<String, dynamic> json) {
    final runtime = (json['runtime'] as Map<String, dynamic>?) ?? const {};
    final mystery = (json['mystery'] as Map<String, dynamic>?) ?? const {};
    final selections = (json['playerSelections'] as Map<String, dynamic>?) ?? const {};

    return GameSession(
      id: id,
      activationCode: (json['activationCode'] ?? '').toString(),
      lockedScenarioId: (json['lockedScenarioId'] ?? '').toString(),
      siteId: (json['siteId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      startedAt: json['startedAt']?.toString(),
      expiresAt: json['expiresAt']?.toString(),
      trueSuspectId: (json['trueSuspectId'] ?? mystery['trueSuspectId'] ?? '').toString(),
      trueMotiveId: (json['trueMotiveId'] ?? mystery['trueMotiveId'] ?? '').toString(),
      suspectByPlace: _readNullableStringMap(
        json['suspectByPlace'] ?? mystery['suspectByPlace'] ?? runtime['suspectByPlace'],
      ),
      motiveByPlace: _readNullableStringMap(
        json['motiveByPlace'] ?? mystery['motiveByPlace'] ?? runtime['motiveByPlace'],
      ),
      playerMarkedSuspectIds: Set<String>.from(
        (json['playerMarkedSuspectIds'] ??
                selections['markedSuspectIds'] ??
                runtime['playerMarkedSuspectIds'] ??
                const <dynamic>[]) as List<dynamic>,
      ),
      playerMarkedMotiveIds: Set<String>.from(
        (json['playerMarkedMotiveIds'] ??
                selections['markedMotiveIds'] ??
                runtime['playerMarkedMotiveIds'] ??
                const <dynamic>[]) as List<dynamic>,
      ),
    );
  }

  static Map<String, String?> _readNullableStringMap(dynamic raw) {
    if (raw is! Map) return <String, String?>{};
    return raw.map((key, value) => MapEntry(key.toString(), value?.toString()));
  }
}
