import 'package:cloud_firestore/cloud_firestore.dart';

class MediaAsset {
  final String id;
  final String scenarioId;
  final String slotId;
  final String type;
  final String title;
  final String status;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final int? width;
  final int? height;
  final String? aspectRatio;
  final int? durationSec;
  final String? resolutionLabel;
  final String technicalStatus;
  final List<String> technicalWarnings;
  final bool needsReplacement;
  final bool availableInArchives;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MediaAsset({
    required this.id,
    required this.scenarioId,
    required this.slotId,
    required this.type,
    required this.title,
    required this.status,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    this.width,
    this.height,
    this.aspectRatio,
    this.durationSec,
    this.resolutionLabel,
    required this.technicalStatus,
    required this.technicalWarnings,
    required this.needsReplacement,
    required this.availableInArchives,
    this.createdAt,
    this.updatedAt,
  });

  factory MediaAsset.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MediaAsset.fromMap(data, id: doc.id);
  }

  factory MediaAsset.fromMap(Map<String, dynamic> map, {required String id}) {
    return MediaAsset(
      id: id,
      scenarioId: (map['scenarioId'] ?? '') as String,
      slotId: (map['slotId'] ?? '') as String,
      type: (map['type'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      status: (map['status'] ?? 'test') as String,
      storagePath: (map['storagePath'] ?? '') as String,
      fileName: (map['fileName'] ?? '') as String,
      mimeType: (map['mimeType'] ?? '') as String,
      fileSizeBytes: (map['fileSizeBytes'] ?? 0) as int,
      width: map['width'] as int?,
      height: map['height'] as int?,
      aspectRatio: map['aspectRatio'] as String?,
      durationSec: map['durationSec'] as int?,
      resolutionLabel: map['resolutionLabel'] as String?,
      technicalStatus: (map['technicalStatus'] ?? 'ok') as String,
      technicalWarnings: List<String>.from(map['technicalWarnings'] ?? const <String>[]),
      needsReplacement: (map['needsReplacement'] ?? false) as bool,
      availableInArchives: (map['availableInArchives'] ?? false) as bool,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'scenarioId': scenarioId,
      'slotId': slotId,
      'type': type,
      'title': title,
      'status': status,
      'storagePath': storagePath,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSizeBytes': fileSizeBytes,
      'width': width,
      'height': height,
      'aspectRatio': aspectRatio,
      'durationSec': durationSec,
      'resolutionLabel': resolutionLabel,
      'technicalStatus': technicalStatus,
      'technicalWarnings': technicalWarnings,
      'needsReplacement': needsReplacement,
      'availableInArchives': availableInArchives,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  MediaAsset copyWith({
    String? id,
    String? scenarioId,
    String? slotId,
    String? type,
    String? title,
    String? status,
    String? storagePath,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    int? width,
    int? height,
    String? aspectRatio,
    int? durationSec,
    String? resolutionLabel,
    String? technicalStatus,
    List<String>? technicalWarnings,
    bool? needsReplacement,
    bool? availableInArchives,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaAsset(
      id: id ?? this.id,
      scenarioId: scenarioId ?? this.scenarioId,
      slotId: slotId ?? this.slotId,
      type: type ?? this.type,
      title: title ?? this.title,
      status: status ?? this.status,
      storagePath: storagePath ?? this.storagePath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      durationSec: durationSec ?? this.durationSec,
      resolutionLabel: resolutionLabel ?? this.resolutionLabel,
      technicalStatus: technicalStatus ?? this.technicalStatus,
      technicalWarnings: technicalWarnings ?? this.technicalWarnings,
      needsReplacement: needsReplacement ?? this.needsReplacement,
      availableInArchives: availableInArchives ?? this.availableInArchives,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
