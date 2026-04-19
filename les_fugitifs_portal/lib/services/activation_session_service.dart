import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/site_readiness/site_readiness_service.dart';

class ActivationSessionResult {
  final bool success;
  final String message;
  final String? code;
  final String? gameSessionId;
  final String? lockedScenarioId;

  const ActivationSessionResult({
    required this.success,
    required this.message,
    this.code,
    this.gameSessionId,
    this.lockedScenarioId,
  });
}

class ActivationSessionService {
  final FirebaseFirestore _firestore;
  final SiteReadinessService _siteReadinessService;

  ActivationSessionService({
    FirebaseFirestore? firestore,
    SiteReadinessService? siteReadinessService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _siteReadinessService =
            siteReadinessService ??
                SiteReadinessService(firestore: firestore);

  Future<ActivationSessionResult> assignCodeAndCreateSession({
    required String lockedScenarioId,
    required String siteId,
    required String cashierUserId,
  }) async {
    final readiness = await _siteReadinessService.validateSite(siteId);
    if (!readiness.isReady) {
      return ActivationSessionResult(
        success: false,
        message: readiness.errors.isNotEmpty
            ? readiness.errors.join('\n')
            : 'Le site sélectionné n’est pas prêt.',
      );
    }

    final lockedScenarioRef = _firestore
        .collection('lockedScenarios')
        .doc(lockedScenarioId);
    final lockedScenarioSnap = await lockedScenarioRef.get();

    if (!lockedScenarioSnap.exists) {
      return const ActivationSessionResult(
        success: false,
        message: 'Scénario verrouillé introuvable.',
      );
    }

    final lockedData = lockedScenarioSnap.data() ?? <String, dynamic>{};
    final lockedStatus = (lockedData['status'] ?? '').toString().trim();
    if (lockedStatus != 'locked') {
      return const ActivationSessionResult(
        success: false,
        message: 'Le scénario sélectionné n’est pas verrouillé.',
      );
    }

    try {
      final result = await _firestore.runTransaction((transaction) async {
        QuerySnapshot<Map<String, dynamic>> batchQuery = await _firestore
            .collection('activationBatches')
            .where('status', isEqualTo: 'active')
            .where('countUnused', isGreaterThan: 0)
            .limit(20)
            .get();

        if (batchQuery.docs.isEmpty) {
          throw Exception('Aucun batch actif avec codes disponibles.');
        }

        DocumentReference<Map<String, dynamic>>? selectedBatchRef;
        QueryDocumentSnapshot<Map<String, dynamic>>? selectedBatchDoc;
        QuerySnapshot<Map<String, dynamic>>? selectedCodesQuery;

        for (final batchDoc in batchQuery.docs) {
          final candidateBatchRef = batchDoc.reference;
          final candidateCodesQuery = await candidateBatchRef
              .collection('codes')
              .where('status', isEqualTo: 'unused')
              .limit(1)
              .get();

          if (candidateCodesQuery.docs.isNotEmpty) {
            selectedBatchRef = candidateBatchRef;
            selectedBatchDoc = batchDoc;
            selectedCodesQuery = candidateCodesQuery;
            break;
          }
        }

        if (selectedBatchRef == null ||
            selectedBatchDoc == null ||
            selectedCodesQuery == null ||
            selectedCodesQuery.docs.isEmpty) {
          throw Exception('Aucun code inutilisé disponible.');
        }

        final selectedCodeDoc = selectedCodesQuery.docs.first;
        final selectedCodeRef = selectedCodeDoc.reference;
        final selectedCodeId = selectedCodeDoc.id;

        final codeSnapshot = await transaction.get(selectedCodeRef);
        if (!codeSnapshot.exists) {
          throw Exception('Code introuvable.');
        }

        final codeData = codeSnapshot.data();
        if (codeData == null) {
          throw Exception('Données du code introuvables.');
        }

        final codeStatus = (codeData['status'] ?? '').toString().trim();
        if (codeStatus != 'unused') {
          throw Exception('Le code n’est plus disponible.');
        }

        final batchSnapshot = await transaction.get(selectedBatchRef);
        if (!batchSnapshot.exists) {
          throw Exception('Batch introuvable.');
        }

        final batchData = batchSnapshot.data();
        if (batchData == null) {
          throw Exception('Données du batch introuvables.');
        }

        final lockedSnapshot = await transaction.get(lockedScenarioRef);
        if (!lockedSnapshot.exists) {
          throw Exception('Scénario verrouillé introuvable.');
        }

        final lockedData = lockedSnapshot.data();
        if (lockedData == null) {
          throw Exception('Données du scénario verrouillé introuvables.');
        }

        final lockedStatus = (lockedData['status'] ?? '').toString().trim();
        if (lockedStatus != 'locked') {
          throw Exception('Le scénario sélectionné n’est pas verrouillé.');
        }

        final sessionRef = _firestore.collection('gameSessions').doc();

        final currentUnused = _readInt(batchData['countUnused']);
        final currentReserved = _readInt(batchData['countReserved']);

        if (currentUnused <= 0) {
          throw Exception('Aucun code inutilisé dans ce batch.');
        }

        final now = DateTime.now().toUtc();
        final nowIso = now.toIso8601String();
        final expiresAtDate = now.add(const Duration(hours: 5));
        final expiresAt = expiresAtDate.toIso8601String();

        transaction.set(sessionRef, {
          'id': sessionRef.id,
          'status': 'active',
          'active': true,
          'activationCode': selectedCodeId,
          'activationBatchId': selectedBatchRef.id,
          'lockedScenarioId': lockedScenarioId,
          'siteId': siteId,
          'gameId': (lockedData['gameId'] ?? 'les_fugitifs').toString(),
          'title': (lockedData['title'] ?? 'Les Fugitifs').toString(),
          'startedAt': nowIso,
          'expiresAt': expiresAt,
          'createdAt': nowIso,
          'createdBy': cashierUserId,
          'baseDurationHours': 5,
          'extraDurationHours': 0,
          'effectiveEndsAt': expiresAt,
          'runtime': {
            'visitedPlaces': <String>[],
            'foundKeywords': <String>[],
            'revealedSuspects': <String>[],
            'revealedMotives': <String>[],
            'flags': <String, dynamic>{},
          },
        });

        transaction.update(selectedCodeRef, {
          'status': 'reserved',
          'reservedAt': nowIso,
          'reservedBy': cashierUserId,
          'issuedSiteId': siteId,
          'issuedScenarioId': lockedScenarioId,
          'issuedLockedScenarioId': lockedScenarioId,
          'gameSessionId': sessionRef.id,
          'expiresAt': expiresAt,
        });

        transaction.update(selectedBatchRef, {
          'countUnused': currentUnused - 1,
          'countReserved': currentReserved + 1,
        });

        return ActivationSessionResult(
          success: true,
          message: 'Code émis avec succès.',
          code: selectedCodeId,
          gameSessionId: sessionRef.id,
          lockedScenarioId: lockedScenarioId,
        );
      });

      return result;
    } catch (e) {
      return ActivationSessionResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<ActivationSessionResult> extendSessionDuration({
    required String sessionId,
    required int extraHours,
    required String actorUserId,
  }) async {
    if (extraHours <= 0) {
      return const ActivationSessionResult(
        success: false,
        message: 'La durée supplémentaire doit être positive.',
      );
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final sessionRef = _firestore.collection('gameSessions').doc(sessionId);
        final sessionSnap = await transaction.get(sessionRef);

        if (!sessionSnap.exists) {
          throw Exception('Session introuvable.');
        }

        final data = sessionSnap.data() ?? <String, dynamic>{};

        final baseDurationHours = _readInt(data['baseDurationHours']);
        final currentExtraHours = _readInt(data['extraDurationHours']);
        final startedAtRaw = (data['startedAt'] ?? '').toString().trim();

        if (startedAtRaw.isEmpty) {
          throw Exception('Heure de départ introuvable.');
        }

        final startedAt = DateTime.tryParse(startedAtRaw)?.toUtc();
        if (startedAt == null) {
          throw Exception('Heure de départ invalide.');
        }

        final newExtraHours = currentExtraHours + extraHours;
        final effectiveEndsAt = startedAt
            .add(Duration(hours: baseDurationHours + newExtraHours))
            .toIso8601String();

        transaction.update(sessionRef, {
          'extraDurationHours': newExtraHours,
          'effectiveEndsAt': effectiveEndsAt,
          'expiresAt': effectiveEndsAt,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'updatedBy': actorUserId,
        });
      });

      return const ActivationSessionResult(
        success: true,
        message: 'Durée de session prolongée avec succès.',
      );
    } catch (e) {
      return ActivationSessionResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<ActivationSessionResult> closeSession({
    required String sessionId,
    required String actorUserId,
  }) async {
    try {
      await _firestore.collection('gameSessions').doc(sessionId).update({
        'status': 'closed',
        'active': false,
        'closedAt': DateTime.now().toUtc().toIso8601String(),
        'closedBy': actorUserId,
      });

      return const ActivationSessionResult(
        success: true,
        message: 'Session clôturée avec succès.',
      );
    } catch (e) {
      return ActivationSessionResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}