class GameSession {
  final String id;
  final String activationCode;
  final String lockedScenarioId;
  final String siteId;
  final String status;
  final String? startedAt;
  final String? expiresAt;
  final double? estimatedDistanceMeters;

  final String trueSuspectId;
  final String trueMotiveId;
  final Map<String, String?> suspectByPlace;
  final Map<String, String?> motiveByPlace;
  final Set<String> playerMarkedSuspectIds;
  final Set<String> playerMarkedMotiveIds;

  final bool humanHelpEnabled;
  final bool humanEscalationRequired;
  final String humanEscalationStatus;
  final int aiHelpCount;
  final String currentBlockageLevel;
  final String? lastHelpRequestAt;

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
    this.estimatedDistanceMeters,
    Set<String>? playerMarkedSuspectIds,
    Set<String>? playerMarkedMotiveIds,
    this.humanHelpEnabled = false,
    this.humanEscalationRequired = false,
    this.humanEscalationStatus = '',
    this.aiHelpCount = 0,
    this.currentBlockageLevel = '',
    this.lastHelpRequestAt,
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
      'estimatedDistanceMeters': estimatedDistanceMeters,
      'trueSuspectId': trueSuspectId,
      'trueMotiveId': trueMotiveId,
      'suspectByPlace': suspectByPlace,
      'motiveByPlace': motiveByPlace,
      'playerMarkedSuspectIds': playerMarkedSuspectIds.toList(),
      'playerMarkedMotiveIds': playerMarkedMotiveIds.toList(),
      'humanHelpEnabled': humanHelpEnabled,
      'humanEscalationRequired': humanEscalationRequired,
      'humanEscalationStatus': humanEscalationStatus,
      'aiHelpCount': aiHelpCount,
      'currentBlockageLevel': currentBlockageLevel,
      'lastHelpRequestAt': lastHelpRequestAt,
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
      estimatedDistanceMeters: _readNullableDouble(json['estimatedDistanceMeters']),
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
      humanHelpEnabled: _readBool(json['humanHelpEnabled']),
      humanEscalationRequired: _readBool(json['humanEscalationRequired']),
      humanEscalationStatus: (json['humanEscalationStatus'] ?? '').toString(),
      aiHelpCount: _readInt(json['aiHelpCount']),
      currentBlockageLevel: (json['currentBlockageLevel'] ?? '').toString(),
      lastHelpRequestAt: json['lastHelpRequestAt']?.toString(),
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
      estimatedDistanceMeters: _readNullableDouble(
        json['estimatedDistanceMeters'] ?? runtime['estimatedDistanceMeters'],
      ),
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
      humanHelpEnabled: _readBool(
        json['humanHelpEnabled'] ?? runtime['humanHelpEnabled'],
      ),
      humanEscalationRequired: _readBool(
        json['humanEscalationRequired'] ?? runtime['humanEscalationRequired'],
      ),
      humanEscalationStatus: (
        json['humanEscalationStatus'] ?? runtime['humanEscalationStatus'] ?? ''
      ).toString(),
      aiHelpCount: _readInt(
        json['aiHelpCount'] ?? runtime['aiHelpCount'],
      ),
      currentBlockageLevel: (
        json['currentBlockageLevel'] ?? runtime['currentBlockageLevel'] ?? ''
      ).toString(),
      lastHelpRequestAt: (
        json['lastHelpRequestAt'] ?? runtime['lastHelpRequestAt']
      )?.toString(),
    );
  }

  static Map<String, String?> _readNullableStringMap(dynamic raw) {
    if (raw is! Map) return <String, String?>{};
    return raw.map((key, value) => MapEntry(key.toString(), value?.toString()));
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return false;
  }

  static double? _readNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
