import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'creator_media_slot_card.dart';

class CreatorMediaSlotsGridSection extends StatelessWidget {
  final String scenarioId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> slotDefinitionDocs;
  final Map<String, Map<String, dynamic>> scenarioSlotsById;
  final bool isFrozen;
  final Future<void> Function({
    required String slotId,
    required Map<String, dynamic> slotDefinitionData,
  }) onUploadOrReplaceMedia;
  final Future<void> Function({
    required String slotId,
    required Map<String, dynamic> slotDefinitionData,
  })? onRemoveMedia;
  final Future<void> Function({
    required String slotId,
    required String workflowStatus,
  })? onWorkflowStatusChanged;

  const CreatorMediaSlotsGridSection({
    super.key,
    required this.scenarioId,
    required this.slotDefinitionDocs,
    required this.scenarioSlotsById,
    required this.isFrozen,
    required this.onUploadOrReplaceMedia,
    required this.onRemoveMedia,
    required this.onWorkflowStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final groupedDocs = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in slotDefinitionDocs) {
      final data = doc.data();
      final blockId = (data['blockId'] ?? data['blockKey'] ?? 'misc').toString();
      groupedDocs.putIfAbsent(blockId, () => <QueryDocumentSnapshot<Map<String, dynamic>>>[]).add(doc);
    }

    final orderedBlockIds = groupedDocs.keys.toList()
      ..sort((a, b) => _blockOrder(a).compareTo(_blockOrder(b)));

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 1600 ? 3 : 2;
    final aspectRatio = screenWidth >= 1600 ? 2.45 : 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: orderedBlockIds.map((blockId) {
        final blockDocs = groupedDocs[blockId]!
          ..sort((a, b) {
            final aOrder = _intFrom(a.data()['displayOrder']);
            final bOrder = _intFrom(b.data()['displayOrder']);
            if (aOrder != bOrder) return aOrder.compareTo(bOrder);
            return a.id.compareTo(b.id);
          });

        final blockLabel = _blockLabel(blockId);
        final presentCount = blockDocs.where((doc) {
          final slotData = scenarioSlotsById[doc.id] ?? const <String, dynamic>{};
          return _hasActiveMedia(slotData);
        }).length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF101C31),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF223250)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      blockLabel,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D192C),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF223250)),
                      ),
                      child: Text(
                        '$presentCount/${blockDocs.length}',
                        style: const TextStyle(
                          color: Color(0xFFAED0FF),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: aspectRatio,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: blockDocs.map((definitionDoc) {
                    final definitionData = definitionDoc.data();
                    final slotData =
                        scenarioSlotsById[definitionDoc.id] ?? <String, dynamic>{};

                    final acceptedTypes = _stringListFrom(
                      definitionData['acceptedTypes'] ?? slotData['acceptedTypes'],
                    );
                    final hasMedia = _hasActiveMedia(slotData);

                    return CreatorMediaSlotCard(
                      key: ValueKey(
                        'scenario:$scenarioId|slot:${definitionDoc.id}|media:${slotData['activeMediaId']}|frozen:$isFrozen|workflow:${slotData['workflowStatus']}',
                      ),
                      slotId: definitionDoc.id,
                      title: _slotTitle(definitionDoc),
                      blockLabel: blockLabel,
                      acceptedTypes: acceptedTypes,
                      isRequired: _boolFrom(definitionData['isRequired']),
                      isFrozen: isFrozen,
                      hasMedia: hasMedia,
                      activeMediaTitle: _stringFrom(
                        slotData['activeMediaTitle'] ??
                            slotData['title'] ??
                            slotData['activeTitle'],
                      ),
                      activeFileName: _stringFrom(
                        slotData['activeFileName'] ?? slotData['fileName'],
                      ),
                      activeMimeType: _stringFrom(
                        slotData['activeMimeType'] ?? slotData['mimeType'],
                      ),
                      technicalStatus: _stringFrom(slotData['technicalStatus']),
                      storagePath: _stringFrom(
                        slotData['activeStoragePath'] ?? slotData['storagePath'],
                      ),
                      workflowStatus: _stringFrom(slotData['workflowStatus']) ?? 'test',
                      onWorkflowStatusChanged: !hasMedia || onWorkflowStatusChanged == null
                          ? null
                          : (value) => onWorkflowStatusChanged!(
                                slotId: definitionDoc.id,
                                workflowStatus: value,
                              ),
                      onUploadOrReplace: () => onUploadOrReplaceMedia(
                        slotId: definitionDoc.id,
                        slotDefinitionData: definitionData,
                      ),
                      onRemove: onRemoveMedia == null
                          ? null
                          : () => onRemoveMedia!(
                                slotId: definitionDoc.id,
                                slotDefinitionData: definitionData,
                              ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static bool _hasActiveMedia(Map<String, dynamic> slotData) {
    final activeMediaId = _stringFrom(slotData['activeMediaId']);
    final storagePath = _stringFrom(
      slotData['activeStoragePath'] ?? slotData['storagePath'],
    );
    final fileName = _stringFrom(slotData['activeFileName'] ?? slotData['fileName']);
    return activeMediaId != null || storagePath != null || fileName != null;
  }

  static String _slotTitle(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return (data['label'] ?? data['title'] ?? data['slotKey'] ?? doc.id)
        .toString()
        .trim();
  }

  static List<String> _stringListFrom(dynamic raw) {
    if (raw is Iterable) {
      return raw.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    }
    if (raw == null) return const <String>[];
    final value = raw.toString().trim();
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  static int _intFrom(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static bool _boolFrom(dynamic raw) {
    if (raw is bool) return raw;
    final value = raw?.toString().trim().toLowerCase();
    return value == 'true' || value == '1';
  }

  static String? _stringFrom(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static int _blockOrder(String blockId) {
    final normalized = blockId.trim().toUpperCase();
    if (normalized == 'INTRO') return 0;
    if (normalized == 'ENDING') return 1000;

    final match = RegExp(r'^([A-Z])(\d+)$').firstMatch(normalized);
    if (match != null) {
      final letter = match.group(1)!;
      final number = int.tryParse(match.group(2)!) ?? 0;
      final base = switch (letter) {
        'A' => 100,
        'B' => 200,
        'C' => 300,
        'D' => 400,
        _ => 900,
      };
      return base + number;
    }

    return 950;
  }

  static String _blockLabel(String blockId) {
    final normalized = blockId.trim();
    if (normalized.isEmpty) return 'Bloc';
    if (normalized.toLowerCase() == 'intro') return 'Intro';
    if (normalized.toLowerCase() == 'ending') return 'Ending';
    return normalized.toUpperCase();
  }
}
