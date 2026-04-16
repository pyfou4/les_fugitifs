import 'package:cloud_firestore/cloud_firestore.dart';

import 'media_schema.dart';

class MediaSeedReport {
  final int blocksCreated;
  final int blocksUpdated;
  final int slotDefinitionsCreated;
  final int slotDefinitionsUpdated;
  final int slotsCreated;
  final int slotsUpdated;

  const MediaSeedReport({
    required this.blocksCreated,
    required this.blocksUpdated,
    required this.slotDefinitionsCreated,
    required this.slotDefinitionsUpdated,
    required this.slotsCreated,
    required this.slotsUpdated,
  });

  int get totalTouched =>
      blocksCreated +
      blocksUpdated +
      slotDefinitionsCreated +
      slotDefinitionsUpdated +
      slotsCreated +
      slotsUpdated;

  @override
  String toString() {
    return 'MediaSeedReport('
        'blocksCreated: $blocksCreated, '
        'blocksUpdated: $blocksUpdated, '
        'slotDefinitionsCreated: $slotDefinitionsCreated, '
        'slotDefinitionsUpdated: $slotDefinitionsUpdated, '
        'slotsCreated: $slotsCreated, '
        'slotsUpdated: $slotsUpdated)';
  }
}

class MediaSeedService {
  final FirebaseFirestore firestore;

  MediaSeedService({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _blocksRef =>
      firestore.collection('scenario_media_blocks');

  CollectionReference<Map<String, dynamic>> get _slotDefinitionsRef =>
      firestore.collection('scenario_media_slot_definitions');

  CollectionReference<Map<String, dynamic>> get _slotsRef =>
      firestore.collection('scenario_media_slots');

  Future<MediaSeedReport> seedLesFugitifs({
    bool dryRun = false,
    bool allowScenarioIdOverride = false,
    String scenarioId = LesFugitifsMediaSchema.scenarioId,
    String actorLabel = 'media_seed_service',
  }) async {
    if (!allowScenarioIdOverride &&
        scenarioId != LesFugitifsMediaSchema.scenarioId) {
      throw ArgumentError(
        'Ce seed est verrouillé sur le scénario canonique '
        '"${LesFugitifsMediaSchema.scenarioId}".',
      );
    }

    final normalizedScenarioId = scenarioId.trim();
    if (normalizedScenarioId.isEmpty) {
      throw ArgumentError('scenarioId vide.');
    }

    final existingBlocks = await _fetchExistingByScenario(
      ref: _blocksRef,
      scenarioId: normalizedScenarioId,
      keyField: 'blockKey',
    );

    final existingSlotDefinitions = await _fetchExistingByScenario(
      ref: _slotDefinitionsRef,
      scenarioId: normalizedScenarioId,
      keyField: 'slotKey',
    );

    final existingSlots = await _fetchExistingByScenario(
      ref: _slotsRef,
      scenarioId: normalizedScenarioId,
      keyField: 'slotKey',
    );

    var blocksCreated = 0;
    var blocksUpdated = 0;
    var slotDefinitionsCreated = 0;
    var slotDefinitionsUpdated = 0;
    var slotsCreated = 0;
    var slotsUpdated = 0;

    WriteBatch? batch = dryRun ? null : firestore.batch();
    var operationsInBatch = 0;

    Future<void> flushBatchIfNeeded({bool force = false}) async {
      if (dryRun || batch == null) return;
      if (!force && operationsInBatch < 400) return;
      await batch!.commit();
      batch = firestore.batch();
      operationsInBatch = 0;
    }

    Future<void> setDoc(
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> data,
    ) async {
      if (dryRun) return;
      batch!.set(ref, data, SetOptions(merge: true));
      operationsInBatch += 1;
      await flushBatchIfNeeded();
    }

    final nowIso = DateTime.now().toIso8601String();

    for (final block in LesFugitifsMediaSchema.blocks) {
      final blockId = _blockDocId(
        scenarioId: normalizedScenarioId,
        blockKey: block.blockKey,
      );
      final blockExists = existingBlocks.containsKey(block.blockKey);

      final blockPayload = <String, dynamic>{
        'id': blockId,
        'scenarioId': normalizedScenarioId,
        'blockKey': block.blockKey,
        'label': block.label,
        'title': block.label,
        'order': block.order,
        'isEnabled': block.isEnabled,
        'isPivot': block.isPivot,
        'isFinalBlock': block.isFinalBlock,
        'createdAt': blockExists
            ? existingBlocks[block.blockKey]!['createdAt'] ?? nowIso
            : nowIso,
        'updatedAt': nowIso,
        'updatedBy': actorLabel,
      };

      await setDoc(_blocksRef.doc(blockId), blockPayload);
      if (blockExists) {
        blocksUpdated += 1;
      } else {
        blocksCreated += 1;
      }

      for (final slot in block.slots) {
        final slotDefinitionId = _slotDefinitionDocId(
          scenarioId: normalizedScenarioId,
          slotKey: slot.slotKey,
        );
        final slotId = _slotDocId(
          scenarioId: normalizedScenarioId,
          slotKey: slot.slotKey,
        );

        final slotDefinitionExists =
            existingSlotDefinitions.containsKey(slot.slotKey);
        final slotExists = existingSlots.containsKey(slot.slotKey);

        final slotDefinitionPayload = <String, dynamic>{
          'id': slotDefinitionId,
          'scenarioId': normalizedScenarioId,
          'blockId': blockId,
          'blockKey': block.blockKey,
          'slotKey': slot.slotKey,
          'label': slot.label,
          'title': slot.label,
          'order': slot.order,
          'isEnabled': slot.isEnabled,
          'isRequired': slot.isRequired,
          'acceptedTypes': slot.acceptedTypes,
          'notes': slot.notes,
          'workflowStatus': slot.workflowStatus,
          'createdAt': slotDefinitionExists
              ? existingSlotDefinitions[slot.slotKey]!['createdAt'] ?? nowIso
              : nowIso,
          'updatedAt': nowIso,
          'updatedBy': actorLabel,
        };

        await setDoc(_slotDefinitionsRef.doc(slotDefinitionId), slotDefinitionPayload);
        if (slotDefinitionExists) {
          slotDefinitionsUpdated += 1;
        } else {
          slotDefinitionsCreated += 1;
        }

        final previousSlot = existingSlots[slot.slotKey] ?? <String, dynamic>{};
        final slotPayload = <String, dynamic>{
          'id': slotId,
          'scenarioId': normalizedScenarioId,
          'blockId': blockId,
          'blockKey': block.blockKey,
          'slotKey': slot.slotKey,
          'label': slot.label,
          'title': slot.label,
          'activeMediaId': previousSlot['activeMediaId'] ?? '',
          'workflowStatus': previousSlot['workflowStatus'] ?? slot.workflowStatus,
          'acceptedTypes': slot.acceptedTypes,
          'isRequired': slot.isRequired,
          'createdAt': slotExists
              ? previousSlot['createdAt'] ?? nowIso
              : nowIso,
          'updatedAt': nowIso,
          'updatedBy': actorLabel,
        };

        await setDoc(_slotsRef.doc(slotId), slotPayload);
        if (slotExists) {
          slotsUpdated += 1;
        } else {
          slotsCreated += 1;
        }
      }
    }

    await flushBatchIfNeeded(force: true);

    return MediaSeedReport(
      blocksCreated: blocksCreated,
      blocksUpdated: blocksUpdated,
      slotDefinitionsCreated: slotDefinitionsCreated,
      slotDefinitionsUpdated: slotDefinitionsUpdated,
      slotsCreated: slotsCreated,
      slotsUpdated: slotsUpdated,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchExistingByScenario({
    required CollectionReference<Map<String, dynamic>> ref,
    required String scenarioId,
    required String keyField,
  }) async {
    final query = await ref.where('scenarioId', isEqualTo: scenarioId).get();
    final result = <String, Map<String, dynamic>>{};

    for (final doc in query.docs) {
      final data = doc.data();
      final key = (data[keyField] ?? '').toString().trim();
      if (key.isEmpty) continue;
      result[key] = <String, dynamic>{
        ...data,
        '_docId': doc.id,
      };
    }

    return result;
  }

  String _blockDocId({
    required String scenarioId,
    required String blockKey,
  }) {
    return '${scenarioId}_${_sanitize(blockKey)}';
  }

  String _slotDefinitionDocId({
    required String scenarioId,
    required String slotKey,
  }) {
    return '${scenarioId}_${_sanitize(slotKey)}';
  }

  String _slotDocId({
    required String scenarioId,
    required String slotKey,
  }) {
    return '${scenarioId}_${_sanitize(slotKey)}';
  }

  String _sanitize(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }
}
