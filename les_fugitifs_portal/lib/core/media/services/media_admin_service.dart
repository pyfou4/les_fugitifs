import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  Future<_PickedMediaFile?> _pickFile() async {
    final input = html.FileUploadInputElement()
      ..accept =
          '.mp4,.mov,.webm,.m4v,.jpg,.jpeg,.png,.webp,.mp3,.wav,.m4a,.ogg,.pdf'
      ..multiple = false;

    final completer = Completer<_PickedMediaFile?>();

    input.onChange.listen((_) async {
      try {
        final files = input.files;
        if (files == null || files.isEmpty) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          return;
        }

        final file = files.first;
        final reader = html.FileReader();

        reader.onError.listen((_) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('Impossible de lire le fichier sélectionné.'),
            );
          }
        });

        reader.onLoadEnd.listen((_) {
          try {
            final bytes = _bytesFromReaderResult(reader.result);
            if (bytes == null || bytes.isEmpty) {
              if (!completer.isCompleted) {
                completer.completeError(
                  Exception('Le fichier sélectionné est vide ou illisible.'),
                );
              }
              return;
            }

            final fileName = file.name.trim();
            if (fileName.isEmpty) {
              if (!completer.isCompleted) {
                completer.completeError(Exception('Nom de fichier invalide.'));
              }
              return;
            }

            if (!completer.isCompleted) {
              completer.complete(
                _PickedMediaFile(
                  fileName: fileName,
                  mimeType: _resolveMimeType(
                    fileName: file.name,
                    browserMimeType: file.type,
                  ),
                  bytes: bytes,
                ),
              );
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(
                Exception('Lecture navigateur impossible : $e'),
              );
            }
          }
        });

        reader.readAsArrayBuffer(file);
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
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
