import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';


class ScenarioMediaSyncResult {
  final String scenarioId;
  final String blockId;
  final int definitionsUpserted;
  final int slotsUpserted;
  final int definitionsDisabled;
  final int slotsDisabled;

  const ScenarioMediaSyncResult({
    required this.scenarioId,
    required this.blockId,
    required this.definitionsUpserted,
    required this.slotsUpserted,
    required this.definitionsDisabled,
    required this.slotsDisabled,
  });
}

class MediaAdminUploadResult {
  final bool success;
  final bool cancelled;
  final String? mediaId;
  final String? fileName;
  final String? storagePath;

  const MediaAdminUploadResult({
    required this.success,
    this.cancelled = false,
    this.mediaId,
    this.fileName,
    this.storagePath,
  });

  factory MediaAdminUploadResult.cancelled() {
    return const MediaAdminUploadResult(
      success: false,
      cancelled: true,
    );
  }

  factory MediaAdminUploadResult.completed({
    required String mediaId,
    required String fileName,
    required String storagePath,
  }) {
    return MediaAdminUploadResult(
      success: true,
      cancelled: false,
      mediaId: mediaId,
      fileName: fileName,
      storagePath: storagePath,
    );
  }
}

class MediaAdminService {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  MediaAdminService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _mediaAssetsRef =>
      firestore.collection('media_assets');

  CollectionReference<Map<String, dynamic>> get _mediaSlotsRef =>
      firestore.collection('scenario_media_slots');

  Future<MediaAdminUploadResult> uploadAndAssignMedia({
    required String scenarioId,
    required String slotId,
    required String slotKey,
    required List<String> acceptedTypes,
    String? blockId,
    String actorLabel = 'creator_portal',
  }) async {
    final picked = await _pickFile();
    if (picked == null) {
      return MediaAdminUploadResult.cancelled();
    }

    final effectiveBlockId = (blockId ?? _inferBlockIdFromSlotId(slotId)).trim();
    final inferredType = _inferMediaType(
      fileName: picked.fileName,
      mimeType: picked.mimeType,
    );

    if (!_isAcceptedType(inferredType, acceptedTypes)) {
      throw Exception(
        'Type de média refusé pour ce slot. Attendu: ${acceptedTypes.join(", ")}. Reçu: $inferredType.',
      );
    }

    final slotDoc = await _mediaSlotsRef.doc(slotId).get();
    final slotData = slotDoc.data() ?? <String, dynamic>{};
    final previousMediaId = (slotData['activeMediaId'] ?? '').toString().trim();

    final timestamp = DateTime.now();
    final mediaId = _buildMediaAssetId(slotId: slotId, timestamp: timestamp);
    final safeFileName = _sanitizeFileName(picked.fileName);
    final storagePath = _buildStoragePath(
      scenarioId: scenarioId,
      blockId: effectiveBlockId,
      slotKey: slotKey,
      timestamp: timestamp,
      fileName: safeFileName,
    );

    final ref = storage.ref(storagePath);
    await ref.putData(
      picked.bytes,
      SettableMetadata(
        contentType: picked.mimeType,
        customMetadata: {
          'uploadedBy': actorLabel,
          'scenarioId': scenarioId,
          'slotId': slotId,
          'slotKey': slotKey,
          'blockId': effectiveBlockId,
          'originalFileName': picked.fileName,
        },
      ),
    );

    final downloadUrl = await ref.getDownloadURL();
    final nowIso = DateTime.now().toIso8601String();

    await _mediaAssetsRef.doc(mediaId).set({
      'id': mediaId,
      'scenarioId': scenarioId,
      'slotId': slotId,
      'slotKey': slotKey,
      'blockId': effectiveBlockId,
      'type': inferredType,
      'title': _deriveTitleFromFileName(picked.fileName),
      'status': 'active',
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'fileName': picked.fileName,
      'mimeType': picked.mimeType,
      'fileSizeBytes': picked.bytes.length,
      'width': null,
      'height': null,
      'aspectRatio': null,
      'durationSec': null,
      'resolutionLabel': null,
      'technicalStatus': 'uploaded',
      'technicalWarnings': <String>[],
      'needsReplacement': false,
      'availableInArchives': false,
      'createdAt': nowIso,
      'updatedAt': nowIso,
      'uploadedBy': actorLabel,
    }, SetOptions(merge: true));

    await _mediaSlotsRef.doc(slotId).set({
      'scenarioId': scenarioId,
      'blockId': effectiveBlockId,
      'slotKey': slotKey,
      'activeMediaId': mediaId,
      'updatedAt': nowIso,
      'updatedBy': actorLabel,
    }, SetOptions(merge: true));

    if (previousMediaId.isNotEmpty && previousMediaId != mediaId) {
      await _deleteExistingMedia(previousMediaId);
    }

    return MediaAdminUploadResult.completed(
      mediaId: mediaId,
      fileName: picked.fileName,
      storagePath: storagePath,
    );
  }

  Future<void> removeActiveMediaFromSlot({
    required String slotId,
    String actorLabel = 'creator_portal',
  }) async {
    final slotDoc = await _mediaSlotsRef.doc(slotId).get();
    final slotData = slotDoc.data() ?? <String, dynamic>{};
    final activeMediaId = (slotData['activeMediaId'] ?? '').toString().trim();

    await _mediaSlotsRef.doc(slotId).set({
      'activeMediaId': '',
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': actorLabel,
    }, SetOptions(merge: true));

    if (activeMediaId.isNotEmpty) {
      await _deleteExistingMedia(activeMediaId);
    }
  }


  Future<ScenarioMediaSyncResult> syncDynamicSlotsForPlace({
    required String scenarioId,
    required String blockId,
    required List<Map<String, dynamic>> requirements,
    String actorLabel = 'creator_portal',
  }) async {
    final normalizedScenarioId = scenarioId.trim();
    final normalizedBlockId = blockId.trim().toUpperCase();

    if (normalizedScenarioId.isEmpty) {
      throw ArgumentError('scenarioId ne peut pas être vide.');
    }

    if (normalizedBlockId.isEmpty) {
      throw ArgumentError('blockId ne peut pas être vide.');
    }

    final nowIso = DateTime.now().toIso8601String();

    final definitionQuery = await firestore
        .collection('scenario_media_slot_definitions')
        .where('scenarioId', isEqualTo: normalizedScenarioId)
        .where('blockId', isEqualTo: normalizedBlockId)
        .get();

    final slotQuery = await firestore
        .collection('scenario_media_slots')
        .where('scenarioId', isEqualTo: normalizedScenarioId)
        .where('blockId', isEqualTo: normalizedBlockId)
        .get();

    final existingDefinitionDocs = {
      for (final doc in definitionQuery.docs) doc.id: doc,
    };
    final existingSlotDocs = {
      for (final doc in slotQuery.docs) doc.id: doc,
    };

    final desiredDefinitions = <String, Map<String, dynamic>>{};
    final desiredSlots = <String, Map<String, dynamic>>{};

    for (final rawRequirement in requirements) {
      final requirement = Map<String, dynamic>.from(rawRequirement);
      final slotKey = _sanitizeSlotKey(
        requirement['slotKey']?.toString().trim() ?? '',
      );
      final stepId = requirement['stepId']?.toString().trim() ?? '';
      if (slotKey.isEmpty || stepId.isEmpty) continue;

      final slotId = _buildScenarioSlotId(
        scenarioId: normalizedScenarioId,
        blockId: normalizedBlockId,
        slotKey: slotKey,
      );

      final acceptedTypes = ((requirement['acceptedTypes'] as List?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final definitionLabel =
          _buildDynamicSlotLabel(requirement['title']?.toString().trim() ?? '');

      final existingSlotData =
          existingSlotDocs[slotId]?.data() ?? <String, dynamic>{};

      desiredDefinitions[slotId] = <String, dynamic>{
        'scenarioId': normalizedScenarioId,
        'blockId': normalizedBlockId,
        'slotKey': slotKey,
        'label': definitionLabel,
        'acceptedTypes': acceptedTypes,
        'displayOrder': _intFrom(requirement['displayOrder']),
        'isRequired': true,
        'isEnabled': true,
        'source': 'scenario_creator_dynamic',
        'sourcePlaceId': normalizedBlockId,
        'sourceStepId': stepId,
        'sourceStepType': requirement['stepType']?.toString().trim(),
        'updatedAt': nowIso,
        if (!existingDefinitionDocs.containsKey(slotId)) 'createdAt': nowIso,
      };

      desiredSlots[slotId] = <String, dynamic>{
        'scenarioId': normalizedScenarioId,
        'blockId': normalizedBlockId,
        'slotKey': slotKey,
        'label': definitionLabel,
        'acceptedTypes': acceptedTypes,
        'displayOrder': _intFrom(requirement['displayOrder']),
        'isRequired': true,
        'isImplemented': true,
        'isEnabled': true,
        'workflowStatus':
            (existingSlotData['workflowStatus'] ?? 'test').toString().trim(),
        'notes': (existingSlotData['notes'] ?? '').toString(),
        'updatedAt': nowIso,
        'updatedBy': actorLabel,
        'source': 'scenario_creator_dynamic',
        if (!existingSlotDocs.containsKey(slotId)) 'createdAt': nowIso,
      };
    }

    int definitionsUpserted = 0;
    int slotsUpserted = 0;
    int definitionsDisabled = 0;
    int slotsDisabled = 0;

    WriteBatch batch = firestore.batch();
    int ops = 0;

    Future<void> commitIfNeeded() async {
      if (ops == 0) return;
      await batch.commit();
      batch = firestore.batch();
      ops = 0;
    }

    void queueSet(
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> data,
    ) {
      batch.set(ref, data, SetOptions(merge: true));
      ops += 1;
    }

    for (final entry in desiredDefinitions.entries) {
      queueSet(
        firestore.collection('scenario_media_slot_definitions').doc(entry.key),
        entry.value,
      );
      definitionsUpserted += 1;

      final slotPayload = desiredSlots[entry.key]!;
      queueSet(
        firestore.collection('scenario_media_slots').doc(entry.key),
        slotPayload,
      );
      slotsUpserted += 1;

      if (ops >= 400) {
        await commitIfNeeded();
      }
    }
    await commitIfNeeded();

    batch = firestore.batch();
    ops = 0;

    for (final doc in existingDefinitionDocs.values) {
      final data = doc.data();
      final isDynamic = (data['source'] ?? '').toString().trim() ==
          'scenario_creator_dynamic';
      if (!isDynamic) continue;
      if (desiredDefinitions.containsKey(doc.id)) continue;

      queueSet(doc.reference, <String, dynamic>{
        'isEnabled': false,
        'updatedAt': nowIso,
      });
      definitionsDisabled += 1;

      if (ops >= 400) {
        await commitIfNeeded();
      }
    }

    for (final doc in existingSlotDocs.values) {
      final data = doc.data();
      final isDynamic = (data['source'] ?? '').toString().trim() ==
              'scenario_creator_dynamic' ||
          (!existingDefinitionDocs.containsKey(doc.id) &&
              doc.id.startsWith('${normalizedScenarioId}_${normalizedBlockId}_'));
      if (!isDynamic) continue;
      if (desiredSlots.containsKey(doc.id)) continue;

      queueSet(doc.reference, <String, dynamic>{
        'isEnabled': false,
        'updatedAt': nowIso,
        'updatedBy': actorLabel,
        'source': 'scenario_creator_dynamic',
      });
      slotsDisabled += 1;

      if (ops >= 400) {
        await commitIfNeeded();
      }
    }

    await commitIfNeeded();

    return ScenarioMediaSyncResult(
      scenarioId: normalizedScenarioId,
      blockId: normalizedBlockId,
      definitionsUpserted: definitionsUpserted,
      slotsUpserted: slotsUpserted,
      definitionsDisabled: definitionsDisabled,
      slotsDisabled: slotsDisabled,
    );
  }

  String _buildScenarioSlotId({
    required String scenarioId,
    required String blockId,
    required String slotKey,
  }) {
    return '${scenarioId}_${blockId}_${_sanitizeSlotKey(slotKey)}';
  }

  String _sanitizeSlotKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _buildDynamicSlotLabel(String title) {
    final safeTitle = title.trim();
    if (safeTitle.isEmpty) {
      return 'Média dynamique';
    }
    return safeTitle;
  }

  int _intFrom(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<_PickedMediaFile?> _pickFile() async {
    final input = html.FileUploadInputElement()
      ..accept =
          '.mp4,.mov,.webm,.m4v,.jpg,.jpeg,.png,.webp,.mp3,.wav,.m4a,.ogg,.pdf'
      ..multiple = false
      ..style.display = 'none';

    final completer = Completer<_PickedMediaFile?>();
    StreamSubscription<html.Event>? changeSubscription;
    StreamSubscription<html.Event>? focusSubscription;
    Timer? cancelTimer;

    void cleanup() {
      cancelTimer?.cancel();
      changeSubscription?.cancel();
      focusSubscription?.cancel();
      input.remove();
    }

    void completeWith(_PickedMediaFile? value) {
      if (completer.isCompleted) return;
      cleanup();
      completer.complete(value);
    }

    void completeWithError(Object error) {
      if (completer.isCompleted) return;
      cleanup();
      completer.completeError(error);
    }

    html.document.body?.append(input);

    changeSubscription = input.onChange.listen((_) async {
      try {
        final files = input.files;
        if (files == null || files.isEmpty) {
          completeWith(null);
          return;
        }

        final file = files.first;
        final reader = html.FileReader();

        reader.onError.listen((_) {
          completeWithError(
            Exception('Impossible de lire le fichier sélectionné.'),
          );
        });

        reader.onLoadEnd.listen((_) {
          try {
            final bytes = _bytesFromReaderResult(reader.result);
            if (bytes == null || bytes.isEmpty) {
              completeWithError(
                Exception('Le fichier sélectionné est vide ou illisible.'),
              );
              return;
            }

            final fileName = file.name.trim();
            if (fileName.isEmpty) {
              completeWithError(Exception('Nom de fichier invalide.'));
              return;
            }

            completeWith(
              _PickedMediaFile(
                fileName: fileName,
                mimeType: _resolveMimeType(
                  fileName: file.name,
                  browserMimeType: file.type,
                ),
                bytes: bytes,
              ),
            );
          } catch (e) {
            completeWithError(
              Exception('Lecture navigateur impossible : $e'),
            );
          }
        });

        reader.readAsArrayBuffer(file);
      } catch (e) {
        completeWithError(e);
      }
    });

    focusSubscription = html.window.onFocus.listen((_) {
      cancelTimer?.cancel();
      cancelTimer = Timer(const Duration(milliseconds: 250), () {
        final files = input.files;
        if (files == null || files.isEmpty) {
          completeWith(null);
        }
      });
    });

    input.click();
    return completer.future;
  }

  Uint8List? _bytesFromReaderResult(dynamic result) {
    if (result == null) return null;
    if (result is Uint8List) return result;
    if (result is ByteBuffer) return Uint8List.view(result);
    if (result is ByteData) return result.buffer.asUint8List();
    if (result is List<int>) return Uint8List.fromList(result);

    try {
      final dynamic maybeBuffer = result.buffer;
      if (maybeBuffer is ByteBuffer) {
        final int offset =
            result.offsetInBytes is int ? result.offsetInBytes as int : 0;
        final int length =
            result.lengthInBytes is int ? result.lengthInBytes as int : maybeBuffer.lengthInBytes;
        return Uint8List.view(maybeBuffer, offset, length);
      }
    } catch (_) {
      // On continue vers le fallback final.
    }

    return null;
  }

  Future<void> _deleteExistingMedia(String mediaId) async {
    final mediaDoc = await _mediaAssetsRef.doc(mediaId).get();
    if (!mediaDoc.exists) {
      return;
    }

    final mediaData = mediaDoc.data() ?? <String, dynamic>{};
    final storagePath = (mediaData['storagePath'] ?? '').toString().trim();

    if (storagePath.isNotEmpty) {
      try {
        await storage.ref(storagePath).delete();
      } catch (_) {
        // Firestore reste la source de vérité.
      }
    }

    await _mediaAssetsRef.doc(mediaId).delete();
  }

  String _buildMediaAssetId({
    required String slotId,
    required DateTime timestamp,
  }) {
    final normalizedSlotId = slotId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'media_${normalizedSlotId}_${timestamp.millisecondsSinceEpoch}';
  }

  String _buildStoragePath({
    required String scenarioId,
    required String blockId,
    required String slotKey,
    required DateTime timestamp,
    required String fileName,
  }) {
    final safeScenarioId = _sanitizePathSegment(scenarioId);
    final safeBlockId = _sanitizePathSegment(blockId);
    final safeSlotKey = _sanitizePathSegment(slotKey);
    final safeTimestamp = timestamp.toIso8601String().replaceAll(':', '-');
    return 'scenarios/$safeScenarioId/$safeBlockId/$safeSlotKey/${safeTimestamp}_$fileName';
  }

  String _sanitizePathSegment(String value) {
    return value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  String _sanitizeFileName(String value) {
    final trimmed = value.trim();
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  String _inferBlockIdFromSlotId(String slotId) {
    final parts = slotId.split('_');
    if (parts.length >= 3) {
      return parts[2];
    }
    return 'misc';
  }

  String _inferMediaType({
    required String fileName,
    required String mimeType,
  }) {
    final lowerMime = mimeType.toLowerCase();
    final lowerName = fileName.toLowerCase();

    if (lowerMime.startsWith('video/') ||
        lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.mov') ||
        lowerName.endsWith('.webm') ||
        lowerName.endsWith('.m4v')) {
      return 'video';
    }

    if (lowerMime.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp')) {
      return 'image';
    }

    if (lowerMime.startsWith('audio/') ||
        lowerName.endsWith('.mp3') ||
        lowerName.endsWith('.wav') ||
        lowerName.endsWith('.m4a') ||
        lowerName.endsWith('.ogg')) {
      return 'audio';
    }

    if (lowerMime == 'application/pdf' || lowerName.endsWith('.pdf')) {
      return 'document';
    }

    return 'file';
  }

  bool _isAcceptedType(String inferredType, List<String> acceptedTypes) {
    if (acceptedTypes.isEmpty) return true;

    final normalizedAcceptedTypes = acceptedTypes
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    return normalizedAcceptedTypes.contains(inferredType.toLowerCase());
  }

  String _deriveTitleFromFileName(String fileName) {
    final withoutExtension = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final normalized =
        withoutExtension.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (normalized.isEmpty) return fileName;
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String _resolveMimeType({
    required String fileName,
    required String browserMimeType,
  }) {
    final trimmed = browserMimeType.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.mp4')) return 'video/mp4';
    if (lowerName.endsWith('.mov')) return 'video/quicktime';
    if (lowerName.endsWith('.webm')) return 'video/webm';
    if (lowerName.endsWith('.m4v')) return 'video/x-m4v';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    if (lowerName.endsWith('.mp3')) return 'audio/mpeg';
    if (lowerName.endsWith('.wav')) return 'audio/wav';
    if (lowerName.endsWith('.m4a')) return 'audio/mp4';
    if (lowerName.endsWith('.ogg')) return 'audio/ogg';
    if (lowerName.endsWith('.pdf')) return 'application/pdf';

    return 'application/octet-stream';
  }
}

class _PickedMediaFile {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const _PickedMediaFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });
}
