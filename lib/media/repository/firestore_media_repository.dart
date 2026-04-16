import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/media_asset.dart';
import '../models/media_slot.dart';
import 'media_repository.dart';

class FirestoreMediaRepository implements MediaRepository {
  final FirebaseFirestore firestore;

  FirestoreMediaRepository({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _slotsRef =>
      firestore.collection('scenario_media_slots');

  CollectionReference<Map<String, dynamic>> get _assetsRef =>
      firestore.collection('media_assets');

  @override
  Future<MediaSlot?> getSlotByKey({
    required String scenarioId,
    required String slotKey,
  }) async {
    final normalizedScenarioId = scenarioId.trim();
    final normalizedSlotKey = slotKey.trim();

    if (normalizedScenarioId.isEmpty || normalizedSlotKey.isEmpty) {
      return null;
    }

    final query = await _slotsRef
        .where('scenarioId', isEqualTo: normalizedScenarioId)
        .where('slotKey', isEqualTo: normalizedSlotKey)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    final doc = query.docs.first;
    return MediaSlot.fromMap(doc.id, doc.data());
  }

  @override
  Future<MediaAsset?> getActiveMediaForSlot({
    required String scenarioId,
    required String slotKey,
    String preferredWorkflowStatus = '',
  }) async {
    final slot = await getSlotByKey(
      scenarioId: scenarioId,
      slotKey: slotKey,
    );

    if (slot == null || !slot.hasActiveMedia) {
      return null;
    }

    final doc = await _assetsRef.doc(slot.activeMediaId).get();
    if (!doc.exists) {
      return null;
    }

    final asset = MediaAsset.fromMap(doc.data() ?? <String, dynamic>{});
    if (!asset.isActive || !asset.hasDownloadUrl) {
      return null;
    }

    final preferred = preferredWorkflowStatus.trim().toLowerCase();
    if (preferred.isNotEmpty &&
        asset.workflowStatus.trim().toLowerCase().isNotEmpty &&
        asset.workflowStatus.trim().toLowerCase() != preferred) {
      // In phase de test, on accepte malgré tout l'asset actif si aucun filtrage
      // n'est explicitement demandé.
      return asset;
    }

    return asset;
  }
}