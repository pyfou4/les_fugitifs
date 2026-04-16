import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'media_preload_service.dart';
import 'scheduled_calls_service.dart';

class ScheduledCallsBootstrapService {
  ScheduledCallsBootstrapService({
    FirebaseFirestore? firestore,
    ScheduledCallsService? scheduledCallsService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _scheduledCallsService = scheduledCallsService ?? ScheduledCallsService();

  final FirebaseFirestore _firestore;
  final ScheduledCallsService _scheduledCallsService;

  static const String _defaultIncomingCallBackgroundUrl =
      'https://firebasestorage.googleapis.com/v0/b/les-fugitifs-6d6f4.firebasestorage.app/o/incoming_call_bg.jpg?alt=media';

  DocumentReference<Map<String, dynamic>> _sessionRef(String sessionId) {
    return _firestore.collection('gameSessions').doc(sessionId.trim());
  }

  Future<bool> ensureInitializedFromSession({
    required String sessionId,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) return false;

    final snapshot = await _sessionRef(normalizedSessionId).get();
    final sessionData = snapshot.data() ?? <String, dynamic>{};

    final existingScheduledCalls = sessionData['scheduledCalls'];
    if (existingScheduledCalls is Map && existingScheduledCalls.isNotEmpty) {
      return false;
    }

    final sessionStartedAt = _readUtcDate(sessionData['startedAt']) ??
        _readUtcDate(sessionData['sessionStartedAt']) ??
        _readUtcDate(sessionData['createdAt']) ??
        DateTime.now().toUtc();

    final config = _readConfig(sessionData);

    await _scheduledCallsService.initializeDefaultCherryCalls(
      sessionId: normalizedSessionId,
      sessionStartedAt: sessionStartedAt,
      cherryCall1MediaSlotKey: MediaPreloadService.introCall1SlotKey,
      cherryCall2MediaSlotKey: MediaPreloadService.introCall2SlotKey,
      backgroundImageUrl: config.backgroundImageUrl,
      displayName: config.displayName,
      popupMessage: config.popupMessage,
    );

    debugPrint(
      'SCHEDULED_CALLS_BOOTSTRAP_OK source=${config.source} session=$normalizedSessionId',
    );
    return true;
  }

  _ScheduledCallsBootstrapConfig _readConfig(Map<String, dynamic> sessionData) {
    final raw = sessionData['scheduledCallsConfig'];
    if (raw is! Map) {
      return const _ScheduledCallsBootstrapConfig();
    }

    final map = Map<String, dynamic>.from(raw);
    final displayName =
        (map['displayName'] ?? 'Cherry on the Cake').toString().trim();
    final popupMessage =
        (map['popupMessage'] ?? 'Cherry on the Cake a essayé de vous joindre.')
            .toString()
            .trim();
    final backgroundImageUrl =
        (map['backgroundImageUrl'] ?? _defaultIncomingCallBackgroundUrl)
            .toString()
            .trim();

    return _ScheduledCallsBootstrapConfig(
      displayName: displayName.isEmpty ? 'Cherry on the Cake' : displayName,
      popupMessage: popupMessage.isEmpty
          ? 'Cherry on the Cake a essayé de vous joindre.'
          : popupMessage,
      backgroundImageUrl: backgroundImageUrl.isEmpty
          ? _defaultIncomingCallBackgroundUrl
          : backgroundImageUrl,
      source: 'scheduledCallsConfig_or_default',
    );
  }

  DateTime? _readUtcDate(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}

class _ScheduledCallsBootstrapConfig {
  final String displayName;
  final String popupMessage;
  final String backgroundImageUrl;
  final String source;

  const _ScheduledCallsBootstrapConfig({
    this.displayName = 'Cherry on the Cake',
    this.popupMessage = 'Cherry on the Cake a essayé de vous joindre.',
    this.backgroundImageUrl =
        'https://firebasestorage.googleapis.com/v0/b/les-fugitifs-6d6f4.firebasestorage.app/o/incoming_call_bg.jpg?alt=media',
    this.source = 'default',
  });
}
