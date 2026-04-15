import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/media_asset.dart';
import '../models/media_block.dart';
import '../models/media_slot.dart';
import 'media_repository.dart';

class FirestoreMediaRepository implements MediaRepository {
  final FirebaseFirestore firestore;

  FirestoreMediaRepository({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _blocks =>
      firestore.collection('scenario_media_blocks');

  CollectionReference<Map<String, dynamic>> get _slots =>
      firestore.collection('scenario_media_slots');

  CollectionReference<Map<String, dynamic>> get _assets =>
      firestore.collection('media_assets');

  @override
  Future<List<MediaBlock>> getBlocksForScenario(String scenarioId) async {
    final query = await _blocks
        .where('scenarioId', isEqualTo: scenarioId)
        .where('isEnabled', isEqualTo: true)
        .orderBy('order')
        .get();

    return query.docs.map(MediaBlock.fromFirestore).toList();
  }

  @override
  Future<MediaBlock?> getBlockByKey({
    required String scenarioId,
    required String blockKey,
  }) async {
    final query = await _blocks
        .where('scenarioId', isEqualTo: scenarioId)
        .where('blockKey', isEqualTo: blockKey)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return MediaBlock.fromFirestore(query.docs.first);
  }

  @override
  Future<List<MediaSlot>> getSlotsForBlock({
    required String scenarioId,
    required String blockId,
  }) async {
    final query = await _slots
        .where('scenarioId', isEqualTo: scenarioId)
        .where('blockId', isEqualTo: blockId)
        .get();

    final slots = query.docs.map(MediaSlot.fromFirestore).toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return slots;
  }

  @override
  Future<MediaSlot?> getSlotByKey({
    required String scenarioId,
    required String slotKey,
  }) async {
    final query = await _slots
        .where('scenarioId', isEqualTo: scenarioId)
        .where('slotKey', isEqualTo: slotKey)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return MediaSlot.fromFirestore(query.docs.first);
  }

  @override
  Future<MediaAsset?> getActiveMediaForSlot({
    required String scenarioId,
    required String slotKey,
  }) async {
    final slot = await getSlotByKey(
      scenarioId: scenarioId,
      slotKey: slotKey,
    );

    final mediaId = slot?.activeMediaId;
    if (slot == null || mediaId == null || mediaId.isEmpty) {
      return null;
    }

    return getMediaAssetById(mediaId);
  }

  @override
  Future<MediaAsset?> getMediaAssetById(String mediaId) async {
    final doc = await _assets.doc(mediaId).get();
    if (!doc.exists) return null;
    return MediaAsset.fromFirestore(doc);
  }
}
