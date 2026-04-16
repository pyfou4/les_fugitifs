import 'package:cloud_firestore/cloud_firestore.dart';

import 'media_preload_service.dart';
import 'runtime_call_context_service.dart';

enum ScheduledCallStatus {
  pending,
  ringing,
  answered,
  missed,
  expired,
}

String scheduledCallStatusToValue(ScheduledCallStatus value) {
  switch (value) {
    case ScheduledCallStatus.pending:
      return 'pending';
    case ScheduledCallStatus.ringing:
      return 'ringing';
    case ScheduledCallStatus.answered:
      return 'answered';
    case ScheduledCallStatus.missed:
      return 'missed';
    case ScheduledCallStatus.expired:
      return 'expired';
  }
}

ScheduledCallStatus scheduledCallStatusFromValue(String value) {
  switch (value.trim()) {
    case 'ringing':
      return ScheduledCallStatus.ringing;
    case 'answered':
      return ScheduledCallStatus.answered;
    case 'missed':
      return ScheduledCallStatus.missed;
    case 'expired':
      return ScheduledCallStatus.expired;
    case 'pending':
    default:
      return ScheduledCallStatus.pending;
  }
}

class ScheduledCallSpec {
  final String id;
  final String displayName;
  final String audioUrl;
  final String mediaSlotKey;
  final String backgroundImageUrl;
  final int triggerAfterSeconds;
  final int windowDurationSeconds;
  final bool allowOnlyWhenOutOfLocatedPost;
  final String popupMessage;
  final String ringtoneUrl;

  const ScheduledCallSpec({
    required this.id,
    required this.displayName,
    required this.audioUrl,
    this.mediaSlotKey = '',
    required this.backgroundImageUrl,
    required this.triggerAfterSeconds,
    required this.windowDurationSeconds,
    this.allowOnlyWhenOutOfLocatedPost = true,
    this.popupMessage = 'Cherry on the Cake a essayé de vous joindre.',
    this.ringtoneUrl = RuntimeCallContextService.defaultRingtoneUrl,
  });

  Map<String, dynamic> toMap(DateTime sessionStartedAt) {
    final normalizedId = id.trim();
    final windowStartAt = sessionStartedAt
        .toUtc()
        .add(Duration(seconds: triggerAfterSeconds));
    final windowEndAt = windowStartAt.add(
      Duration(seconds: windowDurationSeconds),
    );

    return <String, dynamic>{
      'id': normalizedId,
      'displayName': displayName.trim().isEmpty
          ? 'Appel entrant'
          : displayName.trim(),
      'audioUrl': audioUrl.trim(),
      'mediaSlotKey': mediaSlotKey.trim(),
      'backgroundImageUrl': backgroundImageUrl.trim(),
      'triggerAfterSeconds': triggerAfterSeconds,
      'windowDurationSeconds': windowDurationSeconds,
      'windowStartAt': windowStartAt.toIso8601String(),
      'windowEndAt': windowEndAt.toIso8601String(),
      'status': scheduledCallStatusToValue(ScheduledCallStatus.pending),
      'allowOnlyWhenOutOfLocatedPost': allowOnlyWhenOutOfLocatedPost,
      'popupMessage': popupMessage.trim().isEmpty
          ? 'Appel manqué'
          : popupMessage.trim(),
      'ringtoneUrl': ringtoneUrl.trim().isEmpty
          ? RuntimeCallContextService.defaultRingtoneUrl
          : ringtoneUrl.trim(),
      'triggeredAt': null,
      'answeredAt': null,
      'missedAt': null,
      'expiredAt': null,
      'showMissedPopup': false,
      'missedPopupShownAt': null,
      'lastOutcomeReason': '',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class ScheduledCallRuntimeState {
  final String id;
  final String displayName;
  final String audioUrl;
  final String mediaSlotKey;
  final String backgroundImageUrl;
  final int triggerAfterSeconds;
  final int windowDurationSeconds;
  final DateTime windowStartAt;
  final DateTime windowEndAt;
  final ScheduledCallStatus status;
  final bool allowOnlyWhenOutOfLocatedPost;
  final String popupMessage;
  final String ringtoneUrl;
  final DateTime? triggeredAt;
  final DateTime? answeredAt;
  final DateTime? missedAt;
  final DateTime? expiredAt;
  final bool showMissedPopup;
  final DateTime? missedPopupShownAt;
  final String lastOutcomeReason;
  final DateTime? updatedAt;

  const ScheduledCallRuntimeState({
    required this.id,
    required this.displayName,
    required this.audioUrl,
    this.mediaSlotKey = '',
    required this.backgroundImageUrl,
    required this.triggerAfterSeconds,
    required this.windowDurationSeconds,
    required this.windowStartAt,
    required this.windowEndAt,
    required this.status,
    required this.allowOnlyWhenOutOfLocatedPost,
    required this.popupMessage,
    required this.ringtoneUrl,
    required this.triggeredAt,
    required this.answeredAt,
    required this.missedAt,
    required this.expiredAt,
    required this.showMissedPopup,
    required this.missedPopupShownAt,
    required this.lastOutcomeReason,
    required this.updatedAt,
  });

  factory ScheduledCallRuntimeState.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic raw) {
      final value = raw?.toString().trim() ?? '';
      if (value.isEmpty) return null;
      return DateTime.tryParse(value)?.toUtc();
    }

    final triggerRaw = map['triggerAfterSeconds'];
    final triggerAfterSeconds = triggerRaw is int
        ? triggerRaw
        : triggerRaw is num
            ? triggerRaw.toInt()
            : int.tryParse(triggerRaw?.toString() ?? '') ?? 0;

    final windowRaw = map['windowDurationSeconds'];
    final windowDurationSeconds = windowRaw is int
        ? windowRaw
        : windowRaw is num
            ? windowRaw.toInt()
            : int.tryParse(windowRaw?.toString() ?? '') ?? 0;

    return ScheduledCallRuntimeState(
      id: (map['id'] ?? '').toString().trim(),
      displayName: (map['displayName'] ?? 'Appel entrant').toString().trim(),
      audioUrl: (map['audioUrl'] ?? '').toString().trim(),
      mediaSlotKey: (map['mediaSlotKey'] ?? '').toString().trim(),
      backgroundImageUrl:
          (map['backgroundImageUrl'] ?? '').toString().trim(),
      triggerAfterSeconds: triggerAfterSeconds,
      windowDurationSeconds: windowDurationSeconds,
      windowStartAt: parseDate(map['windowStartAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      windowEndAt: parseDate(map['windowEndAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: scheduledCallStatusFromValue(
        (map['status'] ?? 'pending').toString(),
      ),
      allowOnlyWhenOutOfLocatedPost:
          map['allowOnlyWhenOutOfLocatedPost'] != false,
      popupMessage: (map['popupMessage'] ?? 'Appel manqué').toString().trim(),
      ringtoneUrl: (map['ringtoneUrl'] ??
              RuntimeCallContextService.defaultRingtoneUrl)
          .toString()
          .trim(),
      triggeredAt: parseDate(map['triggeredAt']),
      answeredAt: parseDate(map['answeredAt']),
      missedAt: parseDate(map['missedAt']),
      expiredAt: parseDate(map['expiredAt']),
      showMissedPopup: map['showMissedPopup'] == true,
      missedPopupShownAt: parseDate(map['missedPopupShownAt']),
      lastOutcomeReason: (map['lastOutcomeReason'] ?? '').toString().trim(),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'displayName': displayName,
      'audioUrl': audioUrl,
      'mediaSlotKey': mediaSlotKey,
      'backgroundImageUrl': backgroundImageUrl,
      'triggerAfterSeconds': triggerAfterSeconds,
      'windowDurationSeconds': windowDurationSeconds,
      'windowStartAt': windowStartAt.toUtc().toIso8601String(),
      'windowEndAt': windowEndAt.toUtc().toIso8601String(),
      'status': scheduledCallStatusToValue(status),
      'allowOnlyWhenOutOfLocatedPost': allowOnlyWhenOutOfLocatedPost,
      'popupMessage': popupMessage,
      'ringtoneUrl': ringtoneUrl,
      'triggeredAt': triggeredAt?.toUtc().toIso8601String(),
      'answeredAt': answeredAt?.toUtc().toIso8601String(),
      'missedAt': missedAt?.toUtc().toIso8601String(),
      'expiredAt': expiredAt?.toUtc().toIso8601String(),
      'showMissedPopup': showMissedPopup,
      'missedPopupShownAt': missedPopupShownAt?.toUtc().toIso8601String(),
      'lastOutcomeReason': lastOutcomeReason,
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }

  bool get isResolved {
    return status == ScheduledCallStatus.answered ||
        status == ScheduledCallStatus.missed ||
        status == ScheduledCallStatus.expired;
  }

  bool isWithinWindow(DateTime nowUtc) {
    return !nowUtc.isBefore(windowStartAt) && nowUtc.isBefore(windowEndAt);
  }

  bool isPastWindow(DateTime nowUtc) {
    return !nowUtc.isBefore(windowEndAt);
  }

  ScheduledCallRuntimeState copyWith({
    ScheduledCallStatus? status,
    DateTime? triggeredAt,
    DateTime? answeredAt,
    DateTime? missedAt,
    DateTime? expiredAt,
    bool? showMissedPopup,
    DateTime? missedPopupShownAt,
    String? lastOutcomeReason,
    DateTime? updatedAt,
  }) {
    return ScheduledCallRuntimeState(
      id: id,
      displayName: displayName,
      audioUrl: audioUrl,
      mediaSlotKey: mediaSlotKey,
      backgroundImageUrl: backgroundImageUrl,
      triggerAfterSeconds: triggerAfterSeconds,
      windowDurationSeconds: windowDurationSeconds,
      windowStartAt: windowStartAt,
      windowEndAt: windowEndAt,
      status: status ?? this.status,
      allowOnlyWhenOutOfLocatedPost: allowOnlyWhenOutOfLocatedPost,
      popupMessage: popupMessage,
      ringtoneUrl: ringtoneUrl,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      answeredAt: answeredAt ?? this.answeredAt,
      missedAt: missedAt ?? this.missedAt,
      expiredAt: expiredAt ?? this.expiredAt,
      showMissedPopup: showMissedPopup ?? this.showMissedPopup,
      missedPopupShownAt: missedPopupShownAt ?? this.missedPopupShownAt,
      lastOutcomeReason: lastOutcomeReason ?? this.lastOutcomeReason,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ScheduledCallsService {
  ScheduledCallsService({
    FirebaseFirestore? firestore,
    RuntimeCallContextService? runtimeCallContextService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _runtimeCallContextService =
            runtimeCallContextService ?? RuntimeCallContextService();

  final FirebaseFirestore _firestore;
  final RuntimeCallContextService _runtimeCallContextService;

  DocumentReference<Map<String, dynamic>> _sessionRef(String sessionId) {
    return _firestore.collection('gameSessions').doc(sessionId.trim());
  }

  Future<void> initializeCalls({
    required String sessionId,
    required DateTime sessionStartedAt,
    required List<ScheduledCallSpec> calls,
    bool overwriteExisting = false,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty || calls.isEmpty) return;

    final snapshot = await _sessionRef(normalizedSessionId).get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final existingRaw = data['scheduledCalls'];
    final existing = existingRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(existingRaw)
        : <String, dynamic>{};

    final next = <String, dynamic>{...existing};
    for (final call in calls) {
      final id = call.id.trim();
      if (id.isEmpty) continue;
      if (!overwriteExisting && next.containsKey(id)) {
        continue;
      }
      next[id] = call.toMap(sessionStartedAt);
    }

    await _sessionRef(normalizedSessionId).set(
      <String, dynamic>{'scheduledCalls': next},
      SetOptions(merge: true),
    );
  }

  Future<void> initializeDefaultCherryCalls({
    required String sessionId,
    required DateTime sessionStartedAt,
    String cherryCall1AudioUrl = '',
    String cherryCall2AudioUrl = '',
    String cherryCall1MediaSlotKey = MediaPreloadService.introCall1SlotKey,
    String cherryCall2MediaSlotKey = MediaPreloadService.introCall2SlotKey,
    required String backgroundImageUrl,
    String displayName = 'Cherry on the Cake',
    String popupMessage = 'Cherry on the Cake a essayé de vous joindre.',
    bool overwriteExisting = false,
  }) async {
    await initializeCalls(
      sessionId: sessionId,
      sessionStartedAt: sessionStartedAt,
      overwriteExisting: overwriteExisting,
      calls: <ScheduledCallSpec>[
        ScheduledCallSpec(
          id: 'scheduled_cherry_call_1',
          displayName: displayName,
          audioUrl: cherryCall1AudioUrl,
          mediaSlotKey: cherryCall1MediaSlotKey,
          backgroundImageUrl: backgroundImageUrl,
          triggerAfterSeconds: 3600,
          windowDurationSeconds: 1800,
          popupMessage: popupMessage,
        ),
        ScheduledCallSpec(
          id: 'scheduled_cherry_call_2',
          displayName: displayName,
          audioUrl: cherryCall2AudioUrl,
          mediaSlotKey: cherryCall2MediaSlotKey,
          backgroundImageUrl: backgroundImageUrl,
          triggerAfterSeconds: 9000,
          windowDurationSeconds: 1800,
          popupMessage: popupMessage,
        ),
      ],
    );
  }

  Future<List<ScheduledCallRuntimeState>> loadCalls(String sessionId) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) return const <ScheduledCallRuntimeState>[];

    final snapshot = await _sessionRef(normalizedSessionId).get();
    final data = snapshot.data();
    if (data == null) return const <ScheduledCallRuntimeState>[];

    return _deserializeCalls(data['scheduledCalls']);
  }

  Future<ScheduledCallRuntimeState?> loadCall({
    required String sessionId,
    required String callId,
  }) async {
    final calls = await loadCalls(sessionId);
    final normalizedCallId = callId.trim();
    for (final call in calls) {
      if (call.id == normalizedCallId) return call;
    }
    return null;
  }

  Future<void> evaluate({
    required String sessionId,
    required bool isOutOfLocatedPost,
    bool isUiSafe = true,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) return;

    final snapshot = await _sessionRef(normalizedSessionId).get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final scheduledCalls = _deserializeCalls(data['scheduledCalls']);
    if (scheduledCalls.isEmpty) return;

    final activeCallContext = await _runtimeCallContextService.load(normalizedSessionId);
    if (activeCallContext != null && activeCallContext.active) {
      return;
    }

    final nowUtc = DateTime.now().toUtc();

    for (final call in scheduledCalls) {
      if (call.status == ScheduledCallStatus.pending && call.isPastWindow(nowUtc)) {
        await _writeCallState(
          sessionId: normalizedSessionId,
          state: call.copyWith(
            status: ScheduledCallStatus.expired,
            expiredAt: nowUtc,
            showMissedPopup: true,
            lastOutcomeReason: 'window_expired',
            updatedAt: nowUtc,
          ),
        );
        continue;
      }

      if (call.status != ScheduledCallStatus.pending) {
        continue;
      }

      if (!call.isWithinWindow(nowUtc)) {
        continue;
      }

      if (call.allowOnlyWhenOutOfLocatedPost && !isOutOfLocatedPost) {
        continue;
      }

      if (!isUiSafe) {
        continue;
      }

      if (call.audioUrl.trim().isEmpty && call.mediaSlotKey.trim().isEmpty) {
        await _writeCallState(
          sessionId: normalizedSessionId,
          state: call.copyWith(
            status: ScheduledCallStatus.expired,
            expiredAt: nowUtc,
            showMissedPopup: true,
            lastOutcomeReason: 'audio_missing',
            updatedAt: nowUtc,
          ),
        );
        return;
      }

      await _runtimeCallContextService.activateScheduledCall(
        sessionId: normalizedSessionId,
        callId: call.id,
        displayName: call.displayName,
        audioUrl: call.audioUrl,
        mediaSlotKey: call.mediaSlotKey,
        backgroundImageUrl: call.backgroundImageUrl,
        ringtoneUrl: call.ringtoneUrl,
      );

      await _writeCallState(
        sessionId: normalizedSessionId,
        state: call.copyWith(
          status: ScheduledCallStatus.ringing,
          triggeredAt: nowUtc,
          lastOutcomeReason: 'triggered',
          updatedAt: nowUtc,
        ),
      );
      return;
    }
  }

  Future<void> markAnswered({
    required String sessionId,
    required String callId,
  }) async {
    final call = await loadCall(sessionId: sessionId, callId: callId);
    if (call == null) return;

    final nowUtc = DateTime.now().toUtc();
    await _writeCallState(
      sessionId: sessionId,
      state: call.copyWith(
        status: ScheduledCallStatus.answered,
        answeredAt: nowUtc,
        showMissedPopup: false,
        lastOutcomeReason: 'answered',
        updatedAt: nowUtc,
      ),
    );
  }

  Future<void> markMissed({
    required String sessionId,
    required String callId,
    String reason = 'missed',
  }) async {
    final call = await loadCall(sessionId: sessionId, callId: callId);
    if (call == null) return;

    final nowUtc = DateTime.now().toUtc();
    await _writeCallState(
      sessionId: sessionId,
      state: call.copyWith(
        status: ScheduledCallStatus.missed,
        missedAt: nowUtc,
        showMissedPopup: true,
        lastOutcomeReason: reason.trim().isEmpty ? 'missed' : reason.trim(),
        updatedAt: nowUtc,
      ),
    );
  }

  Future<void> markExpired({
    required String sessionId,
    required String callId,
    String reason = 'expired',
  }) async {
    final call = await loadCall(sessionId: sessionId, callId: callId);
    if (call == null) return;

    final nowUtc = DateTime.now().toUtc();
    await _writeCallState(
      sessionId: sessionId,
      state: call.copyWith(
        status: ScheduledCallStatus.expired,
        expiredAt: nowUtc,
        showMissedPopup: true,
        lastOutcomeReason: reason.trim().isEmpty ? 'expired' : reason.trim(),
        updatedAt: nowUtc,
      ),
    );
  }

  Future<ScheduledCallRuntimeState?> findPendingMissedPopup(String sessionId) async {
    final calls = await loadCalls(sessionId);
    for (final call in calls) {
      if (call.showMissedPopup && call.missedPopupShownAt == null) {
        return call;
      }
    }
    return null;
  }

  Future<void> dismissMissedPopup({
    required String sessionId,
    required String callId,
  }) async {
    final call = await loadCall(sessionId: sessionId, callId: callId);
    if (call == null) return;

    final nowUtc = DateTime.now().toUtc();
    await _writeCallState(
      sessionId: sessionId,
      state: call.copyWith(
        showMissedPopup: false,
        missedPopupShownAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
  }

  Future<void> syncFromResolvedCallContext({
    required String sessionId,
    required String callId,
    required String sourceEvent,
  }) async {
    final normalizedEvent = sourceEvent.trim();
    if (normalizedEvent.isEmpty) return;

    if (normalizedEvent == 'incoming_call_accepted') {
      await markAnswered(sessionId: sessionId, callId: callId);
      return;
    }

    if (normalizedEvent == 'incoming_call_rejected') {
      await markMissed(
        sessionId: sessionId,
        callId: callId,
        reason: 'rejected',
      );
      return;
    }

    if (normalizedEvent == 'incoming_call_voice_finished') {
      final call = await loadCall(sessionId: sessionId, callId: callId);
      if (call != null && call.status == ScheduledCallStatus.ringing) {
        await markAnswered(sessionId: sessionId, callId: callId);
      }
    }
  }

  List<ScheduledCallRuntimeState> _deserializeCalls(dynamic raw) {
    if (raw is! Map) return const <ScheduledCallRuntimeState>[];

    final map = Map<String, dynamic>.from(raw as Map);
    final calls = <ScheduledCallRuntimeState>[];
    for (final entry in map.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final parsed = ScheduledCallRuntimeState.fromMap(
        Map<String, dynamic>.from(value as Map),
      );
      if (parsed.id.trim().isEmpty) continue;
      calls.add(parsed);
    }

    calls.sort((a, b) {
      final dateCompare = a.windowStartAt.compareTo(b.windowStartAt);
      if (dateCompare != 0) return dateCompare;
      return a.id.compareTo(b.id);
    });
    return calls;
  }

  Future<void> _writeCallState({
    required String sessionId,
    required ScheduledCallRuntimeState state,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty || state.id.trim().isEmpty) return;

    await _sessionRef(normalizedSessionId).set(
      <String, dynamic>{
        'scheduledCalls': <String, dynamic>{
          state.id: state.toMap(),
        },
      },
      SetOptions(merge: true),
    );
  }
}
