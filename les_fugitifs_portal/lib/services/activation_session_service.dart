import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/site_readiness/site_readiness_service.dart';
import 'site_route_analyzer.dart';

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

    final estimatedDistanceMeters = await _estimateSiteDistanceMeters(siteId);

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

        final now = DateTime.now().toUtc();
        final nowIso = now.toIso8601String();
        final expiresAtDate = now.add(const Duration(hours: 5));
        final expiresAt = expiresAtDate.toIso8601String();

        transaction.set(sessionRef, {
          'id': sessionRef.id,
          'status': 'active',
          'active': true,
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
          'baseDurationHours': 5,
          'extraDurationHours': 0,
          'effectiveEndsAt': expiresAt,
          'estimatedDistanceMeters': estimatedDistanceMeters,
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
          message: 'Code émis avec succès.',
          code: selectedCodeId,
          gameSessionId: sessionRef.id,
          lockedScenarioId: lockedScenarioId,
        );
      },
    );

    return result;
  }



  Future<void> markSessionCodeAsUsed({
    required String gameSessionId,
    required String activationCode,
    String? usedBy,
  }) async {
    final sessionRef = _firestore.collection('gameSessions').doc(gameSessionId);

    final codeQuery = await _firestore
        .collectionGroup('codes')
        .where(FieldPath.documentId, isEqualTo: activationCode)
        .limit(1)
        .get();

    if (codeQuery.docs.isEmpty) {
      throw Exception('Code d’activation introuvable.');
    }

    final codeRef = codeQuery.docs.first.reference;
    final batchRef = codeRef.parent.parent;

    if (batchRef == null) {
      throw Exception('Batch parent introuvable pour ce code.');
    }

    await _firestore.runTransaction<void>((transaction) async {
      final sessionSnapshot = await transaction.get(sessionRef);
      final codeSnapshot = await transaction.get(codeRef);
      final batchSnapshot = await transaction.get(batchRef);

      if (!sessionSnapshot.exists) {
        throw Exception('Session de jeu introuvable.');
      }
      if (!codeSnapshot.exists) {
        throw Exception('Code d’activation introuvable.');
      }
      if (!batchSnapshot.exists) {
        throw Exception('Batch introuvable.');
      }

      final sessionData = sessionSnapshot.data() ?? <String, dynamic>{};
      final codeData = codeSnapshot.data() ?? <String, dynamic>{};
      final batchData = batchSnapshot.data() ?? <String, dynamic>{};

      final sessionActivationCode =
          (sessionData['activationCode'] ?? '').toString().trim();
      if (sessionActivationCode != activationCode) {
        throw Exception('Le code ne correspond pas à la session.');
      }

      final linkedGameSessionId =
          (codeData['gameSessionId'] ?? '').toString().trim();
      if (linkedGameSessionId.isNotEmpty && linkedGameSessionId != gameSessionId) {
        throw Exception('Le code est déjà lié à une autre session.');
      }

      final currentStatus = (codeData['status'] ?? '').toString().trim();
      if (currentStatus == 'used') {
        return;
      }
      if (currentStatus != 'reserved') {
        throw Exception('Le code doit être émis avant de pouvoir être utilisé.');
      }

      final currentReserved = _readInt(batchData['countReserved']);
      final currentUsed = _readInt(batchData['countUsed']);
      final nowIso = DateTime.now().toIso8601String();

      transaction.update(codeRef, {
        'status': 'used',
        'usedAt': nowIso,
        'usedBy': (usedBy ?? '').trim(),
        'gameSessionId': gameSessionId,
      });

      transaction.update(batchRef, {
        'countReserved': currentReserved > 0 ? currentReserved - 1 : 0,
        'countUsed': currentUsed + 1,
      });

      final sessionStatus = (sessionData['status'] ?? '').toString().trim();
      if (sessionStatus.isEmpty || sessionStatus == 'reserved') {
        transaction.update(sessionRef, {
          'status': 'active',
          'active': true,
        });
      }
    });
  }


  Future<double?> _estimateSiteDistanceMeters(String siteId) async {
    try {
      final sitePlacesSnap = await _firestore
          .collection('sites')
          .doc(siteId)
          .collection('places')
          .get();

      final places = <Place>[];

      for (final doc in sitePlacesSnap.docs) {
        final data = doc.data();
        final lat = _readDouble(data['lat']);
        final lng = _readDouble(data['lng']);

        if (lat == null || lng == null) {
          continue;
        }

        places.add(
          Place(
            id: (data['id'] ?? doc.id).toString().trim(),
            lat: lat,
            lng: lng,
          ),
        );
      }

      final analysis = SiteRouteAnalyzer.analyze(places);
      return analysis.avgDistance;
    } catch (_) {
      return null;
    }
  }

  static double? _readDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
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
