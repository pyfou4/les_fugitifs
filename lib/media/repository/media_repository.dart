import '../models/media_asset.dart';
import '../models/media_slot.dart';

abstract class MediaRepository {
  Future<MediaSlot?> getSlotByKey({
    required String scenarioId,
    required String slotKey,
  });

  Future<MediaAsset?> getActiveMediaForSlot({
    required String scenarioId,
    required String slotKey,
    String preferredWorkflowStatus = '',
  });
}