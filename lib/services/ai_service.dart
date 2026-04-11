import 'dart:convert';

import 'package:http/http.dart' as http;

class AiHelpPlaceContext {
  final String id;
  final String name;
  final String type;
  final List<String> keywords;
  final List<String> media;
  final List<String> requiresAllVisited;
  final List<String> requiresAnyVisited;
  final bool revealSuspect;
  final bool revealMotive;
  final int mediaCount;

  const AiHelpPlaceContext({
    required this.id,
    required this.name,
    this.type = 'observation',
    required this.keywords,
    this.media = const <String>[],
    required this.requiresAllVisited,
    required this.requiresAnyVisited,
    required this.revealSuspect,
    required this.revealMotive,
    required this.mediaCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'keywords': keywords,
      'media': media,
      'requiresAllVisited': requiresAllVisited,
      'requiresAnyVisited': requiresAnyVisited,
      'revealSuspect': revealSuspect,
      'revealMotive': revealMotive,
      'mediaCount': mediaCount,
    };
  }
}

class AiHelpCallContext {
  final bool active;
  final String phase;
  final int helpAttemptsDuringCall;
  final String callId;
  final String sourceEvent;

  const AiHelpCallContext({
    required this.active,
    required this.phase,
    this.helpAttemptsDuringCall = 0,
    this.callId = '',
    this.sourceEvent = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'active': active,
      'phase': phase,
      'helpAttemptsDuringCall': helpAttemptsDuringCall,
      'callId': callId,
      'sourceEvent': sourceEvent,
    };
  }
}

class AiHelpResponse {
  final String message;
  final String hintLevel;
  final String nextAction;
  final double confidence;
  final String responseMode;
  final bool shouldEscalate;
  final String reasonTag;

  const AiHelpResponse({
    required this.message,
    required this.hintLevel,
    required this.nextAction,
    required this.confidence,
    required this.responseMode,
    required this.shouldEscalate,
    required this.reasonTag,
  });

  factory AiHelpResponse.fromJson(Map<dynamic, dynamic> json) {
    final confidenceRaw = json['confidence'];
    final confidence = confidenceRaw is num
        ? confidenceRaw.toDouble()
        : double.tryParse(confidenceRaw?.toString() ?? '') ?? 0.0;

    return AiHelpResponse(
      message: (json['message'] ?? '').toString().trim(),
      hintLevel: (json['hintLevel'] ?? 'low').toString().trim(),
      nextAction: (json['nextAction'] ?? '').toString().trim(),
      confidence: confidence.clamp(0.0, 1.0),
      responseMode: (json['responseMode'] ?? 'reframe').toString().trim(),
      shouldEscalate: json['shouldEscalate'] == true,
      reasonTag: (json['reasonTag'] ?? 'general_block').toString().trim(),
    );
  }
}

class AiService {
  AiService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _endpoint =
      'https://europe-west1-les-fugitifs.cloudfunctions.net/getStructuredAiHelp';

  Future<AiHelpResponse> getStructuredHelp({
    required String sessionId,
    required String scenarioTitle,
    required int progress,
    required int aiHelpCount,
    required String currentBlockageLevel,
    required bool humanHelpEnabled,
    required List<String> visitedPlaces,
    required List<String> blockedPrerequisites,
    AiHelpPlaceContext? place,
    AiHelpCallContext? callContext,
    String playerQuestion = '',
  }) async {
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'scenarioTitle': scenarioTitle,
      'progress': progress,
      'aiHelpCount': aiHelpCount,
      'currentBlockageLevel': currentBlockageLevel,
      'humanHelpEnabled': humanHelpEnabled,
      'visitedPlaces': visitedPlaces,
      'blockedPrerequisites': blockedPrerequisites,
      'playerQuestion': playerQuestion,
      if (place != null) 'place': place.toJson(),
      if (callContext != null) 'callContext': callContext.toJson(),
    };

    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Erreur IA HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception('Réponse IA invalide.');
    }

    final root = Map<String, dynamic>.from(decoded);

    if (root['ok'] != true) {
      throw Exception(
        'Réponse IA en erreur: ${root['error'] ?? 'erreur inconnue'}',
      );
    }

    final data = root['data'];
    if (data is! Map) {
      throw Exception('Bloc data absent dans la réponse IA.');
    }

    return AiHelpResponse.fromJson(data);
  }
}
