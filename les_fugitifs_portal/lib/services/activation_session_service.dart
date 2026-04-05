import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/site_readiness/site_readiness_service.dart';

class ActivationSessionResult {
  final bool success;
  final String? code;
  final String? gameSessionId;
  final String? lockedScenarioId;
  final String message;

  const ActivationSessionResult({
    required this.success,
    required this.message,
    this.code,
    this.gameSessionId,
    this.lockedScenarioId,
  });
}

class ActivationSessionService {
  ActivationSessionService({
    FirebaseFirestore? firestore,
    SiteReadinessService? siteReadinessService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _siteReadinessService =
            siteReadinessService ?? SiteReadinessService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final SiteReadinessService _siteReadinessService;

  Future<ActivationSessionResult> assignCodeAndCreateSession({
    required String lockedScenarioId,
    required String siteId,
    required String cashierUserId,
  }) async {
    final siteReadiness = await _siteReadinessService.validateSite(siteId);

    if (!siteReadiness.isReady) {
      return ActivationSessionResult(
        success: false,
        message:
            'Le site sélectionné n’est pas prêt à jouer (${siteReadiness.errors.length} erreur(s)).',
      );
    }

    final lockedScenarioRef =
        _firestore.collection('lockedScenarios').doc(lockedScenarioId);
    final lockedScenarioSnap = await lockedScenarioRef.get();

    if (!lockedScenarioSnap.exists) {
      return const ActivationSessionResult(
        success: false,
        message: 'Le scénario verrouillé sélectionné est introuvable.',
      );
    }

    final lockedScenarioData = lockedScenarioSnap.data() ?? <String, dynamic>{};
    final lockedScenarioStatus =
        (lockedScenarioData['status'] ?? '').toString().trim();

    if (lockedScenarioStatus != 'locked') {
      return const ActivationSessionResult(
        success: false,
        message: 'Le scénario sélectionné n’est pas dans un état verrouillé.',
      );
    }

    final batchSnap = await _firestore
        .collection('activationBatches')
        .where('status', isEqualTo: 'active')
        .get();

    if (batchSnap.docs.isEmpty) {
      return const ActivationSessionResult(
        success: false,
        message: 'Aucun batch actif disponible.',
      );
    }

    final sortedBatchDocs = [...batchSnap.docs]
      ..sort(
        (a, b) => _parseCreatedAt(
          b.data()['createdAt'],
        ).compareTo(_parseCreatedAt(a.data()['createdAt'])),
      );

    DocumentReference<Map<String, dynamic>>? selectedBatchRef;
    DocumentReference<Map<String, dynamic>>? selectedCodeRef;
    String? selectedCodeId;

    for (final batchDoc in sortedBatchDocs) {
      final batchRef = batchDoc.reference;

      final codeQuery = await batchRef
          .collection('codes')
          .where('status', isEqualTo: 'unused')
          .limit(1)
          .get();

      if (codeQuery.docs.isNotEmpty) {
        selectedBatchRef = batchRef;
        selectedCodeRef = codeQuery.docs.first.reference;
        selectedCodeId = codeQuery.docs.first.id;
        break;
      }
    }

    if (selectedBatchRef == null ||
        selectedCodeRef == null ||
        selectedCodeId == null) {
      return const ActivationSessionResult(
        success: false,
        message: 'Plus de codes disponibles dans le pool global.',
      );
    }

    final gameSessionsRef = _firestore.collection('gameSessions');
    final sessionRef = gameSessionsRef.doc();

    final result = await _firestore.runTransaction<ActivationSessionResult>(
      (transaction) async {
        final batchSnapshot = await transaction.get(selectedBatchRef!);
        final codeSnapshot = await transaction.get(selectedCodeRef!);
        final lockedSnapshot = await transaction.get(lockedScenarioRef);

        if (!batchSnapshot.exists) {
          throw Exception('Batch introuvable.');
        }
        if (!codeSnapshot.exists) {
          throw Exception('Code introuvable.');
        }
        if (!lockedSnapshot.exists) {
          throw Exception('Scénario verrouillé introuvable.');
        }

        final batchData = batchSnapshot.data() ?? <String, dynamic>{};
        final codeData = codeSnapshot.data() ?? <String, dynamic>{};
        final lockedData = lockedSnapshot.data() ?? <String, dynamic>{};

        final currentStatus = (codeData['status'] ?? '').toString().trim();
        if (currentStatus != 'unused') {
          throw Exception('Code déjà attribué.');
        }

        final lockedStatus = (lockedData['status'] ?? '').toString().trim();
        if (lockedStatus != 'locked') {
          throw Exception('Scénario non verrouillé.');
        }

        final currentUnused = _readInt(batchData['countUnused']);
        final currentReserved = _readInt(batchData['countReserved']);

        if (currentUnused <= 0) {
          throw Exception('Aucun code inutilisé dans ce batch.');
        }

        final now = DateTime.now();
        final nowIso = now.toIso8601String();
        final expiresAt = now.add(const Duration(hours: 5)).toIso8601String();

        transaction.set(sessionRef, {
          'id': sessionRef.id,
          'status': 'active',
          'activationCode': selectedCodeId,
          'activationBatchId': selectedBatchRef!.id,
          'lockedScenarioId': lockedScenarioId,
          'siteId': siteId,
          'gameId': (lockedData['gameId'] ?? 'les_fugitifs').toString(),
          'title': (lockedData['title'] ?? 'Les Fugitifs').toString(),
          'startedAt': nowIso,
          'expiresAt': expiresAt,
          'createdAt': nowIso,
          'createdBy': cashierUserId,
          'runtime': {
            'visitedPlaces': <String>[],
            'foundKeywords': <String>[],
            'revealedSuspects': <String>[],
            'revealedMotives': <String>[],
            'flags': <String, dynamic>{},
          },
        });

        transaction.update(selectedCodeRef!, {
          'status': 'reserved',
          'reservedAt': nowIso,
          'reservedBy': cashierUserId,
          'issuedSiteId': siteId,
          'issuedScenarioId': lockedScenarioId,
          'issuedLockedScenarioId': lockedScenarioId,
          'gameSessionId': sessionRef.id,
          'expiresAt': expiresAt,
        });

        transaction.update(selectedBatchRef!, {
          'countUnused': currentUnused - 1,
          'countReserved': currentReserved + 1,
        });

        return ActivationSessionResult(
          success: true,
          message: 'Code attribué avec succès.',
          code: selectedCodeId,
          gameSessionId: sessionRef.id,
          lockedScenarioId: lockedScenarioId,
        );
      },
    );

    return result;
  }

  static DateTime _parseCreatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
