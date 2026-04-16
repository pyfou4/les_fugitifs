import 'package:cloud_firestore/cloud_firestore.dart';

enum RuntimeCallType {
  generic,
  finalPhase,
  scheduled,
  ambient,
  mandatory,
}

enum RuntimeCallRetryPolicy {
  untilAnswered,
  noRetry,
}

enum RuntimeCallUiVariant {
  finalPhaseCall,
  simpleCall,
}

enum RuntimeCallPhase {
  ringing,
  voicePlaying,
  awaitingConfirmation,
  resolved,
}

String runtimeCallTypeToValue(RuntimeCallType value) {
  switch (value) {
    case RuntimeCallType.finalPhase:
      return 'final_phase';
    case RuntimeCallType.scheduled:
      return 'scheduled';
    case RuntimeCallType.ambient:
      return 'ambient';
    case RuntimeCallType.mandatory:
      return 'mandatory';
    case RuntimeCallType.generic:
      return 'generic';
  }
}

String runtimeCallRetryPolicyToValue(RuntimeCallRetryPolicy value) {
  switch (value) {
    case RuntimeCallRetryPolicy.noRetry:
      return 'no_retry';
    case RuntimeCallRetryPolicy.untilAnswered:
      return 'until_answered';
  }
}

String runtimeCallUiVariantToValue(RuntimeCallUiVariant value) {
  switch (value) {
    case RuntimeCallUiVariant.simpleCall:
      return 'simple_call';
    case RuntimeCallUiVariant.finalPhaseCall:
      return 'final_phase_call';
  }
}

String runtimeCallPhaseToValue(RuntimeCallPhase value) {
  switch (value) {
    case RuntimeCallPhase.voicePlaying:
      return 'voice_playing';
    case RuntimeCallPhase.awaitingConfirmation:
      return 'awaiting_confirmation';
    case RuntimeCallPhase.resolved:
      return 'resolved';
    case RuntimeCallPhase.ringing:
      return 'ringing';
  }
}

class RuntimeCallContext {
  final bool active;
  final String phase;
  final int helpAttemptsDuringCall;
  final String callId;
  final String callType;
  final String displayName;
  final String audioUrl;
  final String mediaSlotKey;
  final String backgroundImageUrl;
  final String retryPolicy;
  final String uiVariant;
  final String ringtoneUrl;
  final String sourceEvent;
  final String updatedAt;

  const RuntimeCallContext({
    required this.active,
    required this.phase,
    required this.helpAttemptsDuringCall,
    required this.callId,
    required this.callType,
    required this.displayName,
    required this.audioUrl,
    required this.mediaSlotKey,
    required this.backgroundImageUrl,
    required this.retryPolicy,
    required this.uiVariant,
    required this.ringtoneUrl,
    required this.sourceEvent,
    required this.updatedAt,
  });

  factory RuntimeCallContext.fromMap(Map<String, dynamic> map) {
    final attemptsRaw = map['helpAttemptsDuringCall'];
    final attempts = attemptsRaw is int
        ? attemptsRaw
        : attemptsRaw is num
            ? attemptsRaw.toInt()
            : int.tryParse(attemptsRaw?.toString() ?? '') ?? 0;

    return RuntimeCallContext(
      active: map['active'] == true,
      phase: (map['phase'] ?? 'resolved').toString().trim(),
      helpAttemptsDuringCall: attempts,
      callId: (map['callId'] ?? '').toString().trim(),
      callType: (map['callType'] ?? 'generic').toString().trim(),
      displayName: (map['displayName'] ?? 'Appel entrant').toString().trim(),
      audioUrl: (map['audioUrl'] ?? '').toString().trim(),
      mediaSlotKey: (map['mediaSlotKey'] ?? '').toString().trim(),
      backgroundImageUrl:
          (map['backgroundImageUrl'] ?? '').toString().trim(),
      retryPolicy:
          (map['retryPolicy'] ?? 'until_answered').toString().trim(),
      uiVariant:
          (map['uiVariant'] ?? 'final_phase_call').toString().trim(),
      ringtoneUrl: (map['ringtoneUrl'] ??
              'https://actions.google.com/sounds/v1/alarms/phone_alerts_and_rings.ogg')
          .toString()
          .trim(),
      sourceEvent: (map['sourceEvent'] ?? '').toString().trim(),
      updatedAt: (map['updatedAt'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'active': active,
      'phase': phase,
      'helpAttemptsDuringCall': helpAttemptsDuringCall,
      'callId': callId,
      'callType': callType,
      'displayName': displayName,
      'audioUrl': audioUrl,
      'mediaSlotKey': mediaSlotKey,
      'backgroundImageUrl': backgroundImageUrl,
      'retryPolicy': retryPolicy,
      'uiVariant': uiVariant,
      'ringtoneUrl': ringtoneUrl,
      'sourceEvent': sourceEvent,
      'updatedAt': updatedAt,
    };
  }

  RuntimeCallContext copyWith({
    bool? active,
    String? phase,
    int? helpAttemptsDuringCall,
    String? callId,
    String? callType,
    String? displayName,
    String? audioUrl,
    String? mediaSlotKey,
    String? backgroundImageUrl,
    String? retryPolicy,
    String? uiVariant,
    String? ringtoneUrl,
    String? sourceEvent,
    String? updatedAt,
  }) {
    return RuntimeCallContext(
      active: active ?? this.active,
      phase: phase ?? this.phase,
      helpAttemptsDuringCall:
          helpAttemptsDuringCall ?? this.helpAttemptsDuringCall,
      callId: callId ?? this.callId,
      callType: callType ?? this.callType,
      displayName: displayName ?? this.displayName,
      audioUrl: audioUrl ?? this.audioUrl,
      mediaSlotKey: mediaSlotKey ?? this.mediaSlotKey,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      retryPolicy: retryPolicy ?? this.retryPolicy,
      uiVariant: uiVariant ?? this.uiVariant,
      ringtoneUrl: ringtoneUrl ?? this.ringtoneUrl,
      sourceEvent: sourceEvent ?? this.sourceEvent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RuntimeCallContextService {
  RuntimeCallContextService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String defaultRingtoneUrl =
      'https://actions.google.com/sounds/v1/alarms/phone_alerts_and_rings.ogg';

  DocumentReference<Map<String, dynamic>> _sessionRef(String sessionId) {
    return _firestore.collection('gameSessions').doc(sessionId.trim());
  }

  Future<RuntimeCallContext?> load(String sessionId) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) return null;

    final snapshot = await _sessionRef(normalizedSessionId).get();
    final data = snapshot.data();
    if (data == null) return null;

    final raw = data['callContext'];
    if (raw is! Map) return null;

    return RuntimeCallContext.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> activateFinalPhaseCall({
    required String sessionId,
    required String callId,
    required String displayName,
    String audioUrl = '',
    String mediaSlotKey = '',
    required String backgroundImageUrl,
    String ringtoneUrl = defaultRingtoneUrl,
    String sourceEvent = 'incoming_call_triggered',
  }) async {
    await upsertCallContext(
      sessionId: sessionId,
      callId: callId,
      callType: RuntimeCallType.finalPhase,
      phase: RuntimeCallPhase.ringing,
      displayName: displayName,
      audioUrl: audioUrl,
      mediaSlotKey: mediaSlotKey,
      backgroundImageUrl: backgroundImageUrl,
      retryPolicy: RuntimeCallRetryPolicy.untilAnswered,
      uiVariant: RuntimeCallUiVariant.finalPhaseCall,
      ringtoneUrl: ringtoneUrl,
      sourceEvent: sourceEvent,
      active: true,
      resetHelpAttempts: true,
    );
  }

  Future<void> activateScheduledCall({
    required String sessionId,
    required String callId,
    required String displayName,
    String audioUrl = '',
    String mediaSlotKey = '',
    required String backgroundImageUrl,
    String ringtoneUrl = defaultRingtoneUrl,
    String sourceEvent = 'scheduled_call_triggered',
  }) async {
    await upsertCallContext(
      sessionId: sessionId,
      callId: callId,
      callType: RuntimeCallType.scheduled,
      phase: RuntimeCallPhase.ringing,
      displayName: displayName,
      audioUrl: audioUrl,
      mediaSlotKey: mediaSlotKey,
      backgroundImageUrl: backgroundImageUrl,
      retryPolicy: RuntimeCallRetryPolicy.noRetry,
      uiVariant: RuntimeCallUiVariant.simpleCall,
      ringtoneUrl: ringtoneUrl,
      sourceEvent: sourceEvent,
      active: true,
      resetHelpAttempts: true,
    );
  }

  Future<void> activateAmbientCall({
    required String sessionId,
    required String callId,
    required String displayName,
    String audioUrl = '',
    String mediaSlotKey = '',
    required String backgroundImageUrl,
    RuntimeCallRetryPolicy retryPolicy = RuntimeCallRetryPolicy.noRetry,
    RuntimeCallUiVariant uiVariant = RuntimeCallUiVariant.simpleCall,
    String ringtoneUrl = defaultRingtoneUrl,
    String sourceEvent = 'ambient_call_triggered',
  }) async {
    await upsertCallContext(
      sessionId: sessionId,
      callId: callId,
      callType: RuntimeCallType.ambient,
      phase: RuntimeCallPhase.ringing,
      displayName: displayName,
      audioUrl: audioUrl,
      mediaSlotKey: mediaSlotKey,
      backgroundImageUrl: backgroundImageUrl,
      retryPolicy: retryPolicy,
      uiVariant: uiVariant,
      ringtoneUrl: ringtoneUrl,
      sourceEvent: sourceEvent,
      active: true,
      resetHelpAttempts: true,
    );
  }

  Future<void> incrementHelpAttempts(String sessionId) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) return;

    final existing = await load(normalizedSessionId);
    if (existing == null || !existing.active) return;

    final updated = existing.copyWith(
      helpAttemptsDuringCall: existing.helpAttemptsDuringCall + 1,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await _sessionRef(normalizedSessionId).set(
      <String, dynamic>{'callContext': updated.toMap()},
      SetOptions(merge: true),
    );
  }

  Future<void> resolveCall({
    required String sessionId,
    String sourceEvent = 'call_resolved',
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) return;

    final existing = await load(normalizedSessionId);
    if (existing == null) return;

    final updated = existing.copyWith(
      active: false,
      phase: runtimeCallPhaseToValue(RuntimeCallPhase.resolved),
      sourceEvent: sourceEvent,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await _sessionRef(normalizedSessionId).set(
      <String, dynamic>{'callContext': updated.toMap()},
      SetOptions(merge: true),
    );
  }

  Future<void> upsertCallContext({
    required String sessionId,
    required String callId,
    required RuntimeCallType callType,
    required RuntimeCallPhase phase,
    required String displayName,
    required String audioUrl,
    required String mediaSlotKey,
    required String backgroundImageUrl,
    required RuntimeCallRetryPolicy retryPolicy,
    required RuntimeCallUiVariant uiVariant,
    required String ringtoneUrl,
    required String sourceEvent,
    required bool active,
    bool resetHelpAttempts = false,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) return;

    final existing = await load(normalizedSessionId);
    final nextHelpAttempts = resetHelpAttempts
        ? 0
        : (existing?.helpAttemptsDuringCall ?? 0);

    final context = RuntimeCallContext(
      active: active,
      phase: runtimeCallPhaseToValue(phase),
      helpAttemptsDuringCall: nextHelpAttempts,
      callId: callId.trim(),
      callType: runtimeCallTypeToValue(callType),
      displayName: displayName.trim().isEmpty
          ? 'Appel entrant'
          : displayName.trim(),
      audioUrl: audioUrl.trim(),
      mediaSlotKey: mediaSlotKey.trim(),
      backgroundImageUrl: backgroundImageUrl.trim(),
      retryPolicy: runtimeCallRetryPolicyToValue(retryPolicy),
      uiVariant: runtimeCallUiVariantToValue(uiVariant),
      ringtoneUrl: ringtoneUrl.trim().isEmpty
          ? defaultRingtoneUrl
          : ringtoneUrl.trim(),
      sourceEvent: sourceEvent.trim(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await _sessionRef(normalizedSessionId).set(
      <String, dynamic>{'callContext': context.toMap()},
      SetOptions(merge: true),
    );
  }
}
