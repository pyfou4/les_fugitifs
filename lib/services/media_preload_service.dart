
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../media/repository/firestore_media_repository.dart';
import '../media/repository/media_repository.dart';

class MediaPreloadService {
  MediaPreloadService({
    MediaRepository? mediaRepository,
  }) : _mediaRepository = mediaRepository ?? FirestoreMediaRepository();

  static const String scenarioId = 'les_fugitifs';
  static const String introRulesSlotKey = 'intro_regles';
  static const String introBriefingSlotKey = 'intro_briefing';

  final MediaRepository _mediaRepository;

  Future<void> preloadIntroMedia() async {
    await Future.wait([
      getCachedOrFetchVideo(
        slotKey: introRulesSlotKey,
        cacheBasename: 'briefing_regles_backend',
      ),
      getCachedOrFetchVideo(
        slotKey: introBriefingSlotKey,
        cacheBasename: 'briefing_mission_backend',
      ),
    ]);
  }

  Future<File> getCachedOrFetchVideo({
    required String slotKey,
    required String cacheBasename,
  }) async {
    final asset = await _mediaRepository.getActiveMediaForSlot(
      scenarioId: scenarioId,
      slotKey: slotKey,
    );

    final downloadUrl = asset?.downloadUrl.trim() ?? '';
    if (downloadUrl.isEmpty) {
      throw Exception('Aucun média backend actif pour le slot $slotKey.');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$cacheBasename.mp4');
    final metaFile = File('${dir.path}/$cacheBasename.meta.json');

    if (await file.exists() && await metaFile.exists()) {
      try {
        final meta = jsonDecode(await metaFile.readAsString())
            as Map<String, dynamic>;
        final cachedUrl = (meta['downloadUrl'] ?? '').toString().trim();
        if (cachedUrl == downloadUrl && await file.length() > 0) {
          return file;
        }
      } catch (_) {
        // On retélécharge proprement.
      }
    }

    final response = await http
        .get(Uri.parse(downloadUrl))
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Téléchargement impossible (${response.statusCode})');
    }

    if (response.bodyBytes.isEmpty) {
      throw Exception('Téléchargement impossible (fichier vide)');
    }

    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    await file.writeAsBytes(response.bodyBytes, flush: true);
    await metaFile.writeAsString(
      jsonEncode(<String, dynamic>{
        'slotKey': slotKey,
        'downloadUrl': downloadUrl,
        'cachedAt': DateTime.now().toIso8601String(),
      }),
      flush: true,
    );

    return file;
  }
}
