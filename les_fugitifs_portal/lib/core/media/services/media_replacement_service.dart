import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/media_asset.dart';
import '../models/media_slot.dart';
import '../utils/media_technical_analyzer.dart';

class ReplaceMediaParams {
  final String scenarioId;
  final MediaSlot slot;
  final Uint8List bytes;
  final String fileName;
  final String title;
  final String type;
  final String mimeType;
  final bool availableInArchives;
  final bool needsReplacement;
  final String status;
  final int fileSizeBytes;
  final int? width;
  final int? height;
  final int? durationSec;

  const ReplaceMediaParams({
    required this.scenarioId,
    required this.slot,
    required this.bytes,
    required this.fileName,
    required this.title,
    required this.type,
    required this.mimeType,
    required this.availableInArchives,
    required this.needsReplacement,
    required this.status,
    required this.fileSizeBytes,
    this.width,
    this.height,
    this.durationSec,
  });
}

class MediaReplacementService {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final MediaTechnicalAnalyzer analyzer;

  MediaReplacementService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    MediaTechnicalAnalyzer? analyzer,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        storage = storage ?? FirebaseStorage.instance,
        analyzer = analyzer ?? const MediaTechnicalAnalyzer();

  CollectionReference<Map<String, dynamic>> get _slots =>
      firestore.collection('scenario_media_slots');

  CollectionReference<Map<String, dynamic>> get _assets =>
      firestore.collection('media_assets');

  Future<MediaAsset> replaceMedia(ReplaceMediaParams params) async {
    final previousMediaId = params.slot.activeMediaId;
    MediaAsset? previousAsset;

    if (previousMediaId != null && previousMediaId.isNotEmpty) {
      final previousDoc = await _assets.doc(previousMediaId).get();
      if (previousDoc.exists) {
        previousAsset = MediaAsset.fromFirestore(previousDoc);
      }
    }

    final storagePath = _buildStoragePath(
      scenarioId: params.scenarioId,
      slotKey: params.slot.slotKey,
      fileName: params.fileName,
    );

    final storageRef = storage.ref().child(storagePath);
    final metadata = SettableMetadata(
      contentType: params.mimeType,
      customMetadata: <String, String>{
        'scenarioId': params.scenarioId,
        'slotId': params.slot.id,
        'slotKey': params.slot.slotKey,
        'status': params.status,
      },
    );

    await storageRef.putData(params.bytes, metadata);

    final analysis = analyzer.analyze(
      type: params.type,
      fileSizeBytes: params.fileSizeBytes,
      width: params.width,
      height: params.height,
      durationSec: params.durationSec,
      mimeType: params.mimeType,
    );

    final newAssetRef = _assets.doc();
    final newAsset = MediaAsset(
      id: newAssetRef.id,
      scenarioId: params.scenarioId,
      slotId: params.slot.id,
      type: params.type,
      title: params.title,
      status: params.status,
      storagePath: storagePath,
      fileName: params.fileName,
      mimeType: params.mimeType,
      fileSizeBytes: params.fileSizeBytes,
      width: params.width,
      height: params.height,
      aspectRatio: analysis.aspectRatio,
      durationSec: params.durationSec,
      resolutionLabel: analysis.resolutionLabel,
      technicalStatus: analysis.technicalStatus,
      technicalWarnings: analysis.technicalWarnings,
      needsReplacement: params.needsReplacement,
      availableInArchives: params.availableInArchives,
    );

    await newAssetRef.set(newAsset.toMap());

    await _slots.doc(params.slot.id).update(<String, dynamic>{
      'activeMediaId': newAsset.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (previousAsset != null) {
      await _safeDeletePreviousAsset(previousAsset);
    }

    return newAsset;
  }

  Future<void> _safeDeletePreviousAsset(MediaAsset previousAsset) async {
    try {
      await storage.ref().child(previousAsset.storagePath).delete();
    } catch (_) {
      // Intentionally swallow storage deletion errors to avoid leaving the slot
      // without an active media after a successful replacement.
    }

    try {
      await _assets.doc(previousAsset.id).delete();
    } catch (_) {
      // Same rationale as above: keep the active replacement intact.
    }
  }

  String _buildStoragePath({
    required String scenarioId,
    required String slotKey,
    required String fileName,
  }) {
    final normalizedFileName = fileName.replaceAll('\\', '_').replaceAll('/', '_');
    final blockFolder = _extractBlockFolderFromSlotKey(slotKey);

    return 'scenarios/$scenarioId/$blockFolder/$normalizedFileName';
  }

  String _extractBlockFolderFromSlotKey(String slotKey) {
    if (slotKey.startsWith('intro_')) return 'intro';
    if (slotKey.startsWith('ending_')) return 'ending';

    final separatorIndex = slotKey.indexOf('_');
    if (separatorIndex <= 0) return slotKey;

    return slotKey.substring(0, separatorIndex);
  }
}
