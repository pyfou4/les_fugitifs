class MediaSlot {
  final String id;
  final String scenarioId;
  final String blockId;
  final String slotKey;
  final String activeMediaId;
  final String workflowStatus;
  final bool isRequired;

  const MediaSlot({
    required this.id,
    required this.scenarioId,
    required this.blockId,
    required this.slotKey,
    required this.activeMediaId,
    required this.workflowStatus,
    required this.isRequired,
  });

  factory MediaSlot.fromMap(String documentId, Map<String, dynamic> map) {
    return MediaSlot(
      id: documentId,
      scenarioId: (map['scenarioId'] ?? '').toString().trim(),
      blockId: (map['blockId'] ?? '').toString().trim(),
      slotKey: (map['slotKey'] ?? '').toString().trim(),
      activeMediaId: (map['activeMediaId'] ?? '').toString().trim(),
      workflowStatus: (map['workflowStatus'] ?? '').toString().trim(),
      isRequired: map['isRequired'] == true,
    );
  }

  bool get hasActiveMedia => activeMediaId.trim().isNotEmpty;
}