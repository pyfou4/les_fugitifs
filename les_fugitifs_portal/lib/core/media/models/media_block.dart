import 'package:cloud_firestore/cloud_firestore.dart';

class MediaBlock {
  final String id;
  final String scenarioId;
  final String blockKey;
  final String label;
  final int order;
  final bool isEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MediaBlock({
    required this.id,
    required this.scenarioId,
    required this.blockKey,
    required this.label,
    required this.order,
    required this.isEnabled,
    this.createdAt,
    this.updatedAt,
  });

  factory MediaBlock.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MediaBlock.fromMap(data, id: doc.id);
  }

  factory MediaBlock.fromMap(Map<String, dynamic> map, {required String id}) {
    return MediaBlock(
      id: id,
      scenarioId: (map['scenarioId'] ?? '') as String,
      blockKey: (map['blockKey'] ?? '') as String,
      label: (map['label'] ?? '') as String,
      order: (map['order'] ?? 0) as int,
      isEnabled: (map['isEnabled'] ?? true) as bool,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'scenarioId': scenarioId,
      'blockKey': blockKey,
      'label': label,
      'order': order,
      'isEnabled': isEnabled,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  MediaBlock copyWith({
    String? id,
    String? scenarioId,
    String? blockKey,
    String? label,
    int? order,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaBlock(
      id: id ?? this.id,
      scenarioId: scenarioId ?? this.scenarioId,
      blockKey: blockKey ?? this.blockKey,
      label: label ?? this.label,
      order: order ?? this.order,
      isEnabled: isEnabled ?? this.isEnabled,
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
