import '../models/media_asset.dart';
import '../models/media_block.dart';
import '../models/media_slot.dart';

abstract class MediaRepository {
  Future<List<MediaBlock>> getBlocksForScenario(String scenarioId);

  Future<MediaBlock?> getBlockByKey({
    required String scenarioId,
    required String blockKey,
  });

  Future<List<MediaSlot>> getSlotsForBlock({
    required String scenarioId,
    required String blockId,
  });

  Future<MediaSlot?> getSlotByKey({
    required String scenarioId,
    required String slotKey,
  });

  Future<MediaAsset?> getActiveMediaForSlot({
    required String scenarioId,
    required String slotKey,
  });

  Future<MediaAsset?> getMediaAssetById(String mediaId);
}