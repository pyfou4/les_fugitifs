import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceNode {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String type;
  final List<String> keywords;
  final List<String> media;
  final List<String> requiresAllVisited;
  final List<String> requiresAnyVisited;
  final bool revealSuspect;
  final bool revealMotive;

  bool isVisible;
  bool isVisited;

  PlaceNode({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.type = 'observation',
    required this.keywords,
    required this.media,
    required this.requiresAllVisited,
    required this.requiresAnyVisited,
    required this.revealSuspect,
    required this.revealMotive,
    this.isVisible = false,
    this.isVisited = false,
  });

  factory PlaceNode.fromJson(Map<String, dynamic> json) {
    final media = (json['media'] as List<dynamic>)
        .map((e) => e.toString())
        .toList();
    final keywords = (json['keywords'] as List<dynamic>)
        .map((e) => e.toString())
        .toList();

    return PlaceNode(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      type: _normalizePlaceType((json['type'] ?? '').toString(), media: media, keywords: keywords),
      keywords: keywords,
      media: media,
      requiresAllVisited: (json['requiresAllVisited'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      requiresAnyVisited: (json['requiresAnyVisited'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      revealSuspect: (json['revealSuspect'] as bool?) ?? false,
      revealMotive: (json['revealMotive'] as bool?) ?? false,
    );
  }

  factory PlaceNode.fromRuntime({
    required Map<String, dynamic> template,
    required Map<String, dynamic> sitePlace,
  }) {
    final id = (template['id'] ?? sitePlace['id'] ?? '').toString().trim();

    final allVisited = _readStringList(
      template['requiresAllVisited'] ?? template['requiresPlacesVisitedAll'],
    );
    final anyVisited = _readStringList(
      template['requiresAnyVisited'] ?? template['requiresPlacesVisitedAny'],
    );
    final keywords = _readStringList(template['keywords']);
    final media = _readMedia(template);

    return PlaceNode(
      id: id,
      name: (template['title'] ?? template['name'] ?? id).toString().trim(),
      lat: _readDouble(sitePlace['lat']),
      lng: _readDouble(sitePlace['lng']),
      type: _inferRuntimeType(template, keywords: keywords, media: media),
      keywords: keywords,
      media: media,
      requiresAllVisited: allVisited,
      requiresAnyVisited: anyVisited,
      revealSuspect: _revealsCategory(template, 'suspect'),
      revealMotive: _revealsCategory(template, 'motive'),
      isVisible: true,
      isVisited: false,
    );
  }

  static List<String> _readMedia(Map<String, dynamic> template) {
    final direct = _readStringList(template['media']);
    if (direct.isNotEmpty) return direct;

    final contentPayload = template['contentPayload'];
    if (contentPayload is Map) {
      final media = _readStringList(contentPayload['media']);
      if (media.isNotEmpty) return media;
    }

    final interactionConfig = template['interactionConfig'];
    if (interactionConfig is Map) {
      final media = _readStringList(interactionConfig['media']);
      if (media.isNotEmpty) return media;
    }

    return const <String>[];
  }

  static bool _revealsCategory(Map<String, dynamic> template, String category) {
    final lowerCategory = category.toLowerCase();

    bool containsCategory(dynamic raw) {
      if (raw == null) return false;
      if (raw is String) {
        final value = raw.toLowerCase();
        return value.contains(lowerCategory);
      }
      if (raw is Iterable) {
        return raw.any(containsCategory);
      }
      if (raw is Map) {
        return raw.entries.any((entry) =>
            containsCategory(entry.key.toString()) || containsCategory(entry.value));
      }
      return false;
    }

    return containsCategory(template['targetType']) ||
        containsCategory(template['targetTypes']) ||
        containsCategory(template['targets']) ||
        containsCategory(template['revealedInfo']) ||
        containsCategory(template['revealedInfoKeys']) ||
        containsCategory(template['revealConfig']) ||
        containsCategory(template['contentPayload']) ||
        (lowerCategory == 'suspect' &&
            (template['revealSuspect'] == true || template['targetSlot'] == 'pc')) ||
        (lowerCategory == 'motive' &&
            (template['revealMotive'] == true || template['targetSlot'] == 'mo'));
  }

  static List<String> _readStringList(dynamic raw) {
    if (raw == null) return const <String>[];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const <String>[];
      return trimmed
          .split(RegExp(r'[,;|/]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  static double _readDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  static String _inferRuntimeType(
    Map<String, dynamic> template, {
    required List<String> keywords,
    required List<String> media,
  }) {
    final explicitType = (template['type'] ?? template['placeType'] ?? template['nodeType'] ?? '')
        .toString()
        .trim();

    return _normalizePlaceType(explicitType, media: media, keywords: keywords);
  }

  static String _normalizePlaceType(
    String raw, {
    required List<String> media,
    required List<String> keywords,
  }) {
    final value = raw.trim().toLowerCase();
    if (value == 'media' || value == 'observation' || value == 'physical') {
      return value;
    }

    if (media.isNotEmpty) {
      return 'media';
    }

    final joinedKeywords = keywords.map((e) => e.toLowerCase()).join(' ');

    if (
        joinedKeywords.contains('observer') ||
        joinedKeywords.contains('observation') ||
        joinedKeywords.contains('regarder') ||
        joinedKeywords.contains('trace') ||
        joinedKeywords.contains('indice') ||
        joinedKeywords.contains('détail') ||
        joinedKeywords.contains('detail')) {
      return 'observation';
    }

    if (
        joinedKeywords.contains('action') ||
        joinedKeywords.contains('tester') ||
        joinedKeywords.contains('manip') ||
        joinedKeywords.contains('activer') ||
        joinedKeywords.contains('ouvrir')) {
      return 'physical';
    }

    return 'observation';
  }

  LatLng get latLng => LatLng(lat, lng);
}
