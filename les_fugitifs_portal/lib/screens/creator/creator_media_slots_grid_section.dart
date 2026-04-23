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
    return FutureBuilder<_BlockPresentationConfig>(
      future: _loadBlockPresentationConfig(scenarioId),
      builder: (context, snapshot) {
        final config = snapshot.data ?? const _BlockPresentationConfig();

        final groupedDocs =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final doc in slotDefinitionDocs) {
          final data = doc.data();
          final blockId =
              (data['blockId'] ?? data['blockKey'] ?? 'misc').toString().trim();
          groupedDocs
              .putIfAbsent(
                blockId,
                () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
              )
              .add(doc);
        }

        final orderedBlockIds = groupedDocs.keys.toList()
          ..sort((a, b) {
            final aOrder = config.orderForBlock(a);
            final bOrder = config.orderForBlock(b);
            if (aOrder != bOrder) return aOrder.compareTo(bOrder);

            final aLabel = config.labelForBlock(a);
            final bLabel = config.labelForBlock(b);
            final labelCompare = aLabel.compareTo(bLabel);
            if (labelCompare != 0) return labelCompare;

            return a.compareTo(b);
          });

        final screenWidth = MediaQuery.of(context).size.width;
        final crossAxisCount = screenWidth >= 1850
            ? 4
            : (screenWidth >= 1450 ? 3 : 2);
        final aspectRatio = screenWidth >= 1850
            ? 2.72
            : (screenWidth >= 1450 ? 2.48 : 2.08);

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

            final blockLabel = config.labelForBlock(blockId);
            final presentCount = blockDocs.where((doc) {
              final slotData =
                  scenarioSlotsById[doc.id] ?? const <String, dynamic>{};
              return _hasActiveMedia(slotData);
            }).length;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
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
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: aspectRatio,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: blockDocs.map((definitionDoc) {
                        final definitionData = definitionDoc.data();
                        final slotData = scenarioSlotsById[definitionDoc.id] ??
                            <String, dynamic>{};

                        final acceptedTypes = _stringListFrom(
                          definitionData['acceptedTypes'] ??
                              slotData['acceptedTypes'],
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
                          technicalStatus:
                              _stringFrom(slotData['technicalStatus']),
                          storagePath: _stringFrom(
                            slotData['activeStoragePath'] ??
                                slotData['storagePath'],
                          ),
                          workflowStatus:
                              _stringFrom(slotData['workflowStatus']) ?? 'test',
                          onWorkflowStatusChanged: !hasMedia ||
                                  onWorkflowStatusChanged == null
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
      },
    );
  }

  static Future<_BlockPresentationConfig> _loadBlockPresentationConfig(
    String scenarioId,
  ) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('scenario_media_blocks')
          .where('scenarioId', isEqualTo: scenarioId)
          .where('isEnabled', isEqualTo: true)
          .orderBy('order')
          .get();

      final orderByBlockId = <String, int>{};
      final labelByBlockId = <String, String>{};

      for (final doc in query.docs) {
        final data = doc.data();
        final order = _intFrom(data['order']);
        final blockKey = _stringFrom(data['blockKey']);
        final rawLabel =
            _stringFrom(data['label']) ?? _stringFrom(data['title']) ?? blockKey;

        orderByBlockId[doc.id] = order;
        if (blockKey != null) {
          orderByBlockId[blockKey] = order;
          orderByBlockId[blockKey.toUpperCase()] = order;
        }

        if (rawLabel != null) {
          labelByBlockId[doc.id] = rawLabel;
          if (blockKey != null) {
            labelByBlockId[blockKey] = rawLabel;
            labelByBlockId[blockKey.toUpperCase()] = rawLabel;
          }
        }
      }

      return _BlockPresentationConfig(
        orderByBlockId: orderByBlockId,
        labelByBlockId: labelByBlockId,
      );
    } catch (_) {
      return const _BlockPresentationConfig();
    }
  }

  static bool _hasActiveMedia(Map<String, dynamic> slotData) {
    final activeMediaId = _stringFrom(slotData['activeMediaId']);
    final storagePath = _stringFrom(
      slotData['activeStoragePath'] ?? slotData['storagePath'],
    );
    final fileName =
        _stringFrom(slotData['activeFileName'] ?? slotData['fileName']);
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
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
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

  static int _fallbackBlockOrder(String blockId) {
    final normalized = blockId.trim().toUpperCase();
    if (normalized == 'INTRO') return 0;
    if (normalized == 'ENDING' || normalized == 'FIN') return 1000;

    final compact = normalized.contains('_')
        ? normalized.split('_').last
        : normalized;
    if (compact == 'INTRO') return 0;
    if (compact == 'ENDING' || compact == 'FIN') return 1000;

    final match = RegExp(r'^([A-Z])(\d+)$').firstMatch(compact);
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

  static String _fallbackBlockLabel(String blockId) {
    final normalized = blockId.trim();
    if (normalized.isEmpty) return 'Bloc';

    final compact = normalized.contains('_')
        ? normalized.split('_').last
        : normalized;
    if (compact.toLowerCase() == 'intro') return 'Intro';
    if (compact.toLowerCase() == 'ending' || compact.toLowerCase() == 'fin') {
      return 'Fin';
    }
    return compact.toUpperCase();
  }
}

class _BlockPresentationConfig {
  final Map<String, int> orderByBlockId;
  final Map<String, String> labelByBlockId;

  const _BlockPresentationConfig({
    this.orderByBlockId = const <String, int>{},
    this.labelByBlockId = const <String, String>{},
  });

  int orderForBlock(String blockId) {
    return orderByBlockId[blockId] ??
        orderByBlockId[blockId.toUpperCase()] ??
        CreatorMediaSlotsGridSection._fallbackBlockOrder(blockId);
  }

  String labelForBlock(String blockId) {
    return labelByBlockId[blockId] ??
        labelByBlockId[blockId.toUpperCase()] ??
        CreatorMediaSlotsGridSection._fallbackBlockLabel(blockId);
  }
}
