import 'package:cloud_firestore/cloud_firestore.dart';

class ScenarioMediaSeedResult {
  final String scenarioId;
  final int blocksCreated;
  final int slotDefinitionsCreated;
  final int slotsCreated;
  final int blocksSkipped;
  final int slotDefinitionsSkipped;
  final int slotsSkipped;

  const ScenarioMediaSeedResult({
    required this.scenarioId,
    required this.blocksCreated,
    required this.slotDefinitionsCreated,
    required this.slotsCreated,
    required this.blocksSkipped,
    required this.slotDefinitionsSkipped,
    required this.slotsSkipped,
  });
}

class ScenarioMediaStructureSeedService {
  final FirebaseFirestore firestore;

  ScenarioMediaStructureSeedService({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _blocksRef =>
      firestore.collection('scenario_media_blocks');

  CollectionReference<Map<String, dynamic>> get _slotDefinitionsRef =>
      firestore.collection('scenario_media_slot_definitions');

  CollectionReference<Map<String, dynamic>> get _slotsRef =>
      firestore.collection('scenario_media_slots');

  Future<ScenarioMediaSeedResult> seedScenario({
    required String scenarioId,
    String actorLabel = 'creator_portal',
    bool overwriteExisting = false,
    bool createScenarioSlots = true,
  }) async {
    final normalizedScenarioId = scenarioId.trim();
    if (normalizedScenarioId.isEmpty) {
      throw ArgumentError('scenarioId ne peut pas être vide.');
    }

    final nowIso = DateTime.now().toIso8601String();

    final blockSpecs = _buildBlockSpecs(normalizedScenarioId);
    final slotDefinitionSpecs = _buildKnownSlotDefinitionSpecs(normalizedScenarioId);
    final slotSpecs = _buildKnownScenarioSlotSpecs(
      scenarioId: normalizedScenarioId,
      actorLabel: actorLabel,
      nowIso: nowIso,
    );

    int blocksCreated = 0;
    int slotDefinitionsCreated = 0;
    int slotsCreated = 0;
    int blocksSkipped = 0;
    int slotDefinitionsSkipped = 0;
    int slotsSkipped = 0;

    final writes = <_PendingWrite>[];

    for (final spec in blockSpecs) {
      final docRef = _blocksRef.doc(spec.id);
      final exists = await docRef.get();
      if (exists.exists && !overwriteExisting) {
        blocksSkipped += 1;
        continue;
      }

      final payload = <String, dynamic>{
        ...spec.data,
        'updatedAt': nowIso,
        if (!exists.exists) 'createdAt': nowIso,
      };

      writes.add(
        _PendingWrite(
          docRef: docRef,
          data: payload,
          merge: true,
        ),
      );
      blocksCreated += 1;
    }

    for (final spec in slotDefinitionSpecs) {
      final docRef = _slotDefinitionsRef.doc(spec.id);
      final exists = await docRef.get();
      if (exists.exists && !overwriteExisting) {
        slotDefinitionsSkipped += 1;
        continue;
      }

      final payload = <String, dynamic>{
        ...spec.data,
        'updatedAt': nowIso,
        if (!exists.exists) 'createdAt': nowIso,
      };

      writes.add(
        _PendingWrite(
          docRef: docRef,
          data: payload,
          merge: true,
        ),
      );
      slotDefinitionsCreated += 1;
    }

    if (createScenarioSlots) {
      for (final spec in slotSpecs) {
        final docRef = _slotsRef.doc(spec.id);
        final exists = await docRef.get();
        if (exists.exists && !overwriteExisting) {
          slotsSkipped += 1;
          continue;
        }

        final payload = <String, dynamic>{
          ...spec.data,
          'updatedAt': nowIso,
          if (!exists.exists) 'createdAt': nowIso,
        };

        writes.add(
          _PendingWrite(
            docRef: docRef,
            data: payload,
            merge: true,
          ),
        );
        slotsCreated += 1;
      }
    }

    await _commitInChunks(writes);

    return ScenarioMediaSeedResult(
      scenarioId: normalizedScenarioId,
      blocksCreated: blocksCreated,
      slotDefinitionsCreated: slotDefinitionsCreated,
      slotsCreated: slotsCreated,
      blocksSkipped: blocksSkipped,
      slotDefinitionsSkipped: slotDefinitionsSkipped,
      slotsSkipped: slotsSkipped,
    );
  }

  Future<void> _commitInChunks(List<_PendingWrite> writes) async {
    if (writes.isEmpty) return;

    const maxWritesPerBatch = 450;
    for (int start = 0; start < writes.length; start += maxWritesPerBatch) {
      final end = (start + maxWritesPerBatch < writes.length)
          ? start + maxWritesPerBatch
          : writes.length;
      final batch = firestore.batch();

      for (final write in writes.sublist(start, end)) {
        batch.set(write.docRef, write.data, SetOptions(merge: write.merge));
      }

      await batch.commit();
    }
  }

  List<_SeedSpec> _buildBlockSpecs(String scenarioId) {
    const blockBlueprints = <Map<String, dynamic>>[
      {
        'blockKey': 'INTRO',
        'label': 'Intro',
        'order': 0,
        'blockType': 'intro',
      },
      {
        'blockKey': 'A0',
        'label': 'Poste pivot A0',
        'order': 100,
        'blockType': 'pivot',
      },
      {
        'blockKey': 'A1',
        'label': 'Poste annexe A1',
        'order': 110,
        'blockType': 'annex',
      },
      {
        'blockKey': 'A2',
        'label': 'Poste annexe A2',
        'order': 120,
        'blockType': 'annex',
      },
      {
        'blockKey': 'A3',
        'label': 'Poste annexe A3',
        'order': 130,
        'blockType': 'annex',
      },
      {
        'blockKey': 'A4',
        'label': 'Poste annexe A4',
        'order': 140,
        'blockType': 'annex',
      },
      {
        'blockKey': 'A5',
        'label': 'Poste annexe A5',
        'order': 150,
        'blockType': 'annex',
      },
      {
        'blockKey': 'A6',
        'label': 'Poste annexe A6',
        'order': 160,
        'blockType': 'annex',
      },
      {
        'blockKey': 'B0',
        'label': 'Poste pivot B0',
        'order': 200,
        'blockType': 'pivot',
      },
      {
        'blockKey': 'B1',
        'label': 'Poste annexe B1',
        'order': 210,
        'blockType': 'annex',
      },
      {
        'blockKey': 'B2',
        'label': 'Poste annexe B2',
        'order': 220,
        'blockType': 'annex',
      },
      {
        'blockKey': 'B3',
        'label': 'Poste annexe B3',
        'order': 230,
        'blockType': 'annex',
      },
      {
        'blockKey': 'B4',
        'label': 'Poste annexe B4',
        'order': 240,
        'blockType': 'annex',
      },
      {
        'blockKey': 'B5',
        'label': 'Poste annexe B5',
        'order': 250,
        'blockType': 'annex',
      },
      {
        'blockKey': 'C0',
        'label': 'Poste pivot C0',
        'order': 300,
        'blockType': 'pivot',
      },
      {
        'blockKey': 'C1',
        'label': 'Poste annexe C1',
        'order': 310,
        'blockType': 'annex',
      },
      {
        'blockKey': 'C2',
        'label': 'Poste annexe C2',
        'order': 320,
        'blockType': 'annex',
      },
      {
        'blockKey': 'C3',
        'label': 'Poste annexe C3',
        'order': 330,
        'blockType': 'annex',
      },
      {
        'blockKey': 'C4',
        'label': 'Poste annexe C4',
        'order': 340,
        'blockType': 'annex',
      },
      {
        'blockKey': 'D0',
        'label': 'Poste pivot D0',
        'order': 400,
        'blockType': 'pivot',
      },
      {
        'blockKey': 'FIN',
        'label': 'Fin',
        'order': 999,
        'blockType': 'ending',
      },
    ];

    return blockBlueprints.map((blueprint) {
      final blockKey = blueprint['blockKey'] as String;
      return _SeedSpec(
        id: '${scenarioId}_$blockKey',
        data: <String, dynamic>{
          'scenarioId': scenarioId,
          'blockKey': blockKey,
          'label': blueprint['label'],
          'order': blueprint['order'],
          'blockType': blueprint['blockType'],
          'isEnabled': true,
        },
      );
    }).toList();
  }

  List<_SeedSpec> _buildKnownSlotDefinitionSpecs(String scenarioId) {
    const slotBlueprints = <Map<String, dynamic>>[
      {
        'blockId': 'INTRO',
        'slotKey': 'video_regles',
        'label': 'Vidéo règles',
        'acceptedTypes': <String>['video'],
        'displayOrder': 1,
        'isRequired': true,
      },
      {
        'blockId': 'INTRO',
        'slotKey': 'video_briefing',
        'label': 'Vidéo briefing',
        'acceptedTypes': <String>['video'],
        'displayOrder': 2,
        'isRequired': true,
      },
      {
        'blockId': 'INTRO',
        'slotKey': 'telephone_1',
        'label': 'Téléphone 1',
        'acceptedTypes': <String>['audio', 'video'],
        'displayOrder': 3,
        'isRequired': true,
      },
      {
        'blockId': 'INTRO',
        'slotKey': 'telephone_2',
        'label': 'Téléphone 2',
        'acceptedTypes': <String>['audio', 'video'],
        'displayOrder': 4,
        'isRequired': true,
      },
      {
        'blockId': 'D0',
        'slotKey': 'telephone_cherryonthecake',
        'label': 'Téléphone Cherry on the Cake',
        'acceptedTypes': <String>['audio', 'video'],
        'displayOrder': 1,
        'isRequired': true,
      },
      {
        'blockId': 'FIN',
        'slotKey': 'video_succes',
        'label': 'Vidéo succès',
        'acceptedTypes': <String>['video'],
        'displayOrder': 1,
        'isRequired': true,
      },
      {
        'blockId': 'FIN',
        'slotKey': 'video_echec',
        'label': 'Vidéo échec',
        'acceptedTypes': <String>['video'],
        'displayOrder': 2,
        'isRequired': true,
      },
    ];

    return slotBlueprints.map((blueprint) {
      final blockId = blueprint['blockId'] as String;
      final slotKey = blueprint['slotKey'] as String;

      return _SeedSpec(
        id: '${scenarioId}_${blockId}_$slotKey',
        data: <String, dynamic>{
          'scenarioId': scenarioId,
          'blockId': blockId,
          'slotKey': slotKey,
          'label': blueprint['label'],
          'acceptedTypes': blueprint['acceptedTypes'],
          'displayOrder': blueprint['displayOrder'],
          'isRequired': blueprint['isRequired'],
          'isEnabled': true,
        },
      );
    }).toList();
  }

  List<_SeedSpec> _buildKnownScenarioSlotSpecs({
    required String scenarioId,
    required String actorLabel,
    required String nowIso,
  }) {
    const slotBlueprints = <Map<String, dynamic>>[
      {
        'blockId': 'INTRO',
        'slotKey': 'video_regles',
        'label': 'Vidéo règles',
        'acceptedTypes': <String>['video'],
        'displayOrder': 1,
        'isRequired': true,
      },
      {
        'blockId': 'INTRO',
        'slotKey': 'video_briefing',
        'label': 'Vidéo briefing',
        'acceptedTypes': <String>['video'],
        'displayOrder': 2,
        'isRequired': true,
      },
      {
        'blockId': 'INTRO',
        'slotKey': 'telephone_1',
        'label': 'Téléphone 1',
        'acceptedTypes': <String>['audio', 'video'],
        'displayOrder': 3,
        'isRequired': true,
      },
      {
        'blockId': 'INTRO',
        'slotKey': 'telephone_2',
        'label': 'Téléphone 2',
        'acceptedTypes': <String>['audio', 'video'],
        'displayOrder': 4,
        'isRequired': true,
      },
      {
        'blockId': 'D0',
        'slotKey': 'telephone_cherryonthecake',
        'label': 'Téléphone Cherry on the Cake',
        'acceptedTypes': <String>['audio', 'video'],
        'displayOrder': 1,
        'isRequired': true,
      },
      {
        'blockId': 'FIN',
        'slotKey': 'video_succes',
        'label': 'Vidéo succès',
        'acceptedTypes': <String>['video'],
        'displayOrder': 1,
        'isRequired': true,
      },
      {
        'blockId': 'FIN',
        'slotKey': 'video_echec',
        'label': 'Vidéo échec',
        'acceptedTypes': <String>['video'],
        'displayOrder': 2,
        'isRequired': true,
      },
    ];

    return slotBlueprints.map((blueprint) {
      final blockId = blueprint['blockId'] as String;
      final slotKey = blueprint['slotKey'] as String;
      final slotId = '${scenarioId}_${blockId}_$slotKey';

      return _SeedSpec(
        id: slotId,
        data: <String, dynamic>{
          'scenarioId': scenarioId,
          'blockId': blockId,
          'slotKey': slotKey,
          'label': blueprint['label'],
          'acceptedTypes': blueprint['acceptedTypes'],
          'displayOrder': blueprint['displayOrder'],
          'isRequired': blueprint['isRequired'],
          'isImplemented': true,
          'activeMediaId': '',
          'workflowStatus': 'test',
          'notes': '',
          'updatedBy': actorLabel,
        },
      );
    }).toList();
  }
}

class _SeedSpec {
  final String id;
  final Map<String, dynamic> data;

  const _SeedSpec({
    required this.id,
    required this.data,
  });
}

class _PendingWrite {
  final DocumentReference<Map<String, dynamic>> docRef;
  final Map<String, dynamic> data;
  final bool merge;

  const _PendingWrite({
    required this.docRef,
    required this.data,
    required this.merge,
  });
}
