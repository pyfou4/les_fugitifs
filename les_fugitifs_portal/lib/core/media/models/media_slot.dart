import 'package:cloud_firestore/cloud_firestore.dart';

class MediaSlot {
  final String id;
  final String scenarioId;
  final String blockId;
  final String slotKey;
  final String label;
  final List<String> acceptedTypes;
  final String? activeMediaId;
  final bool isRequired;
  final bool isImplemented;
  final bool availableInArchives;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MediaSlot({
    required this.id,
    required this.scenarioId,
    required this.blockId,
    required this.slotKey,
    required this.label,
    required this.acceptedTypes,
    required this.activeMediaId,
    required this.isRequired,
    required this.isImplemented,
    required this.availableInArchives,
    required this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory MediaSlot.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MediaSlot.fromMap(data, id: doc.id);
  }

  factory MediaSlot.fromMap(Map<String, dynamic> map, {required String id}) {
    return MediaSlot(
      id: id,
      scenarioId: (map['scenarioId'] ?? '') as String,
      blockId: (map['blockId'] ?? '') as String,
      slotKey: (map['slotKey'] ?? '') as String,
      label: (map['label'] ?? '') as String,
      acceptedTypes: List<String>.from(map['acceptedTypes'] ?? const <String>[]),
      activeMediaId: map['activeMediaId'] as String?,
      isRequired: (map['isRequired'] ?? false) as bool,
      isImplemented: (map['isImplemented'] ?? false) as bool,
      availableInArchives: (map['availableInArchives'] ?? false) as bool,
      notes: (map['notes'] ?? '') as String,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'scenarioId': scenarioId,
      'blockId': blockId,
      'slotKey': slotKey,
      'label': label,
      'acceptedTypes': acceptedTypes,
      'activeMediaId': activeMediaId,
      'isRequired': isRequired,
      'isImplemented': isImplemented,
      'availableInArchives': availableInArchives,
      'notes': notes,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  MediaSlot copyWith({
    String? id,
    String? scenarioId,
    String? blockId,
    String? slotKey,
    String? label,
    List<String>? acceptedTypes,
    String? activeMediaId,
    bool clearActiveMediaId = false,
    bool? isRequired,
    bool? isImplemented,
    bool? availableInArchives,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaSlot(
      id: id ?? this.id,
      scenarioId: scenarioId ?? this.scenarioId,
      blockId: blockId ?? this.blockId,
      slotKey: slotKey ?? this.slotKey,
      label: label ?? this.label,
      acceptedTypes: acceptedTypes ?? this.acceptedTypes,
      activeMediaId: clearActiveMediaId ? null : (activeMediaId ?? this.activeMediaId),
      isRequired: isRequired ?? this.isRequired,
      isImplemented: isImplemented ?? this.isImplemented,
      availableInArchives: availableInArchives ?? this.availableInArchives,
      notes: notes ?? this.notes,
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
