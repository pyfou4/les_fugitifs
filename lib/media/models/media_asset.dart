class MediaAsset {
  final String id;
  final String scenarioId;
  final String slotId;
  final String slotKey;
  final String blockId;
  final String type;
  final String title;
  final String status;
  final String storagePath;
  final String downloadUrl;
  final String fileName;
  final String mimeType;
  final String technicalStatus;
  final String workflowStatus;
  final bool needsReplacement;

  const MediaAsset({
    required this.id,
    required this.scenarioId,
    required this.slotId,
    required this.slotKey,
    required this.blockId,
    required this.type,
    required this.title,
    required this.status,
    required this.storagePath,
    required this.downloadUrl,
    required this.fileName,
    required this.mimeType,
    required this.technicalStatus,
    required this.workflowStatus,
    required this.needsReplacement,
  });

  factory MediaAsset.fromMap(Map<String, dynamic> map) {
    return MediaAsset(
      id: (map['id'] ?? '').toString().trim(),
      scenarioId: (map['scenarioId'] ?? '').toString().trim(),
      slotId: (map['slotId'] ?? '').toString().trim(),
      slotKey: (map['slotKey'] ?? '').toString().trim(),
      blockId: (map['blockId'] ?? '').toString().trim(),
      type: (map['type'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString().trim(),
      status: (map['status'] ?? '').toString().trim(),
      storagePath: (map['storagePath'] ?? '').toString().trim(),
      downloadUrl: (map['downloadUrl'] ?? '').toString().trim(),
      fileName: (map['fileName'] ?? '').toString().trim(),
      mimeType: (map['mimeType'] ?? '').toString().trim(),
      technicalStatus: (map['technicalStatus'] ?? '').toString().trim(),
      workflowStatus: (map['workflowStatus'] ?? '').toString().trim(),
      needsReplacement: map['needsReplacement'] == true,
    );
  }

  bool get isActive => status.toLowerCase() == 'active';
  bool get isFinal => workflowStatus.toLowerCase() == 'final';
  bool get hasDownloadUrl => downloadUrl.trim().isNotEmpty;
}