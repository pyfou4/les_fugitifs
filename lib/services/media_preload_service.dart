import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  // Important: the media repository resolves logical slot keys (without scenario prefix).
  static const String introCall1SlotKey = 'intro_call_1';
  static const String introCall2SlotKey = 'intro_call_2';
  static const String d0FinalCallSlotKey = 'd0_final_call';

  static const List<String> _introRulesFallbackSlotKeys = <String>[
    'intro_regles',
    'intro_rules',
    'regles_intro',
    'rules_intro',
    'regles',
    'rules',
  ];

  static const List<String> _introBriefingFallbackSlotKeys = <String>[
    'intro_briefing',
    'intro_mission',
    'briefing_intro',
    'mission_intro',
    'briefing',
    'mission',
  ];

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

  Future<String> getActiveMediaDownloadUrl({
    required String slotKey,
  }) async {
    final candidateSlotKeys = _slotCandidatesFor(slotKey);
    Object? lastError;

    for (final candidate in candidateSlotKeys) {
      try {
        debugPrint(
          '[MediaPreloadService] Recherche média actif pour scenario='
          '$scenarioId slot=$candidate',
        );

        final asset = await _mediaRepository.getActiveMediaForSlot(
          scenarioId: scenarioId,
          slotKey: candidate,
        );

        final downloadUrl = asset?.downloadUrl.trim() ?? '';
        if (downloadUrl.isNotEmpty) {
          debugPrint(
            '[MediaPreloadService] Média trouvé pour slot=$candidate',
          );
          return downloadUrl;
        }

        debugPrint(
          '[MediaPreloadService] Aucun média actif pour slot=$candidate',
        );
      } catch (e) {
        lastError = e;
        debugPrint(
          '[MediaPreloadService] Erreur pendant la recherche du slot='
          '$candidate : $e',
        );
      }
    }

    final candidatesText = candidateSlotKeys.join(', ');
    if (lastError != null) {
      throw Exception(
        'Aucun média backend actif trouvé pour les slots [$candidatesText]. '
        'Dernière erreur: $lastError',
      );
    }

    throw Exception(
      'Aucun média backend actif trouvé pour les slots [$candidatesText].',
    );
  }

  Future<File> getCachedOrFetchVideo({
    required String slotKey,
    required String cacheBasename,
  }) async {
    final downloadUrl = await getActiveMediaDownloadUrl(slotKey: slotKey);
    return _getCachedOrFetchBinary(
      slotKey: slotKey,
      cacheBasename: cacheBasename,
      extension: 'mp4',
      downloadUrl: downloadUrl,
    );
  }

  Future<File> getCachedOrFetchAudio({
    required String slotKey,
    required String cacheBasename,
  }) async {
    final downloadUrl = await getActiveMediaDownloadUrl(slotKey: slotKey);
    final extension = _guessAudioExtension(downloadUrl);
    return _getCachedOrFetchBinary(
      slotKey: slotKey,
      cacheBasename: cacheBasename,
      extension: extension,
      downloadUrl: downloadUrl,
    );
  }

  Future<File> _getCachedOrFetchBinary({
    required String slotKey,
    required String cacheBasename,
    required String extension,
    required String downloadUrl,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeExtension = extension.trim().isEmpty ? 'bin' : extension.trim();
    final file = File('${dir.path}/$cacheBasename.$safeExtension');
    final metaFile = File('${dir.path}/$cacheBasename.meta.json');

    if (await file.exists() && await metaFile.exists()) {
      try {
        final meta = jsonDecode(await metaFile.readAsString())
            as Map<String, dynamic>;
        final cachedUrl = (meta['downloadUrl'] ?? '').toString().trim();
        if (cachedUrl == downloadUrl && await file.length() > 0) {
          debugPrint(
            '[MediaPreloadService] Cache utilisé pour slot=$slotKey '
            '($cacheBasename.$safeExtension)',
          );
          return file;
        }
      } catch (_) {
        // On retélécharge proprement.
      }
    }

    debugPrint(
      '[MediaPreloadService] Téléchargement du média slot=$slotKey',
    );

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

  List<String> _slotCandidatesFor(String slotKey) {
    switch (slotKey) {
      case introRulesSlotKey:
        return _introRulesFallbackSlotKeys;
      case introBriefingSlotKey:
        return _introBriefingFallbackSlotKeys;
      default:
        return <String>[slotKey];
    }
  }

  String _guessAudioExtension(String downloadUrl) {
    final lower = downloadUrl.toLowerCase();
    if (lower.contains('.wav')) return 'wav';
    if (lower.contains('.m4a')) return 'm4a';
    if (lower.contains('.aac')) return 'aac';
    if (lower.contains('.ogg')) return 'ogg';
    return 'mp3';
  }
}
