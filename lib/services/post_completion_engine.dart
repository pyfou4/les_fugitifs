import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../media/repository/media_repository.dart';
import '../models/game_session.dart';
import '../models/place_node.dart';

class PostCompletionEngine {
  PostCompletionEngine({
    required MediaRepository mediaRepository,
    FirebaseFirestore? firestore,
    Random? random,
  })  : _mediaRepository = mediaRepository,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _random = random ?? Random();

  static const String strengthNone = 'none';
  static const String strengthWeak = 'weak';
  static const String strengthMedium = 'medium';
  static const String strengthStrong = 'strong';

  static const Map<String, String> _audioSlotByStrength = {
    strengthNone: 'post_completion_none',
    strengthWeak: 'post_completion_weak',
    strengthMedium: 'post_completion_medium',
    strengthStrong: 'post_completion_strong',
  };

  final MediaRepository _mediaRepository;
  final FirebaseFirestore _firestore;
  final Random _random;

  Future<PostCompletionResult> build({
    required PlaceNode place,
    required String resultStrength,
    required GameSession session,
    required Map<String, dynamic> runtimeScenarioData,
    required Map<String, dynamic> lockedScenarioData,
  }) async {
    final requestedStrength = _normalizeStrength(resultStrength);

    final scenarioData = await _loadEffectiveScenarioData(
      lockedScenarioId: session.lockedScenarioId,
      runtimeScenarioData: runtimeScenarioData,
      lockedScenarioData: lockedScenarioData,
    );
    final effectiveRuntimeScenarioData = scenarioData.runtimeScenarioData;
    final effectiveLockedScenarioData = scenarioData.lockedScenarioData;

    final targets = _resolveTargets(
      placeId: place.id,
      session: session,
      runtimeScenarioData: effectiveRuntimeScenarioData,
      lockedScenarioData: effectiveLockedScenarioData,
    );

    final usableTargets = targets
        .where((target) => target.hasUsableSignal)
        .toList(growable: false);

    final normalizedStrength =
        usableTargets.isEmpty ? strengthNone : requestedStrength;

    final slotKey = _audioSlotByStrength[normalizedStrength] ??
        _audioSlotByStrength[strengthNone]!;
    final audioUrl = await _loadCompletionAudioUrl(
      scenarioId: session.lockedScenarioId,
      slotKey: slotKey,
    );

    if (normalizedStrength == strengthNone || usableTargets.isEmpty) {
      return PostCompletionResult(
        placeId: place.id,
        strength: normalizedStrength,
        audioSlotKey: slotKey,
        audioUrl: audioUrl,
        displayMode: PostCompletionDisplayMode.none,
        cards: const <PostCompletionCard>[],
        message: 'La conscience du Grid n’extrait aucun signal exploitable de ce poste.',
      );
    }

    final clueSystem = _readClueSystem(
      runtimeScenarioData: effectiveRuntimeScenarioData,
      lockedScenarioData: effectiveLockedScenarioData,
    );
    final revealRule = _readRevealRule(clueSystem, normalizedStrength);
    if (revealRule.optionCount <= 0 || revealRule.trueCount <= 0) {
      return PostCompletionResult(
        placeId: place.id,
        strength: normalizedStrength,
        audioSlotKey: slotKey,
        audioUrl: audioUrl,
        displayMode: PostCompletionDisplayMode.none,
        cards: const <PostCompletionCard>[],
        message: 'La règle de révélation est absente ou incomplète pour ce niveau.',
      );
    }

    final cards = <PostCompletionCard>[];

    for (final target in usableTargets) {
      final targetCards = _buildCardsForTarget(
        target: target,
        revealRule: revealRule,
        clueSystem: clueSystem,
        runtimeScenarioData: effectiveRuntimeScenarioData,
        lockedScenarioData: effectiveLockedScenarioData,
      );

      if (targetCards == null) {
        return PostCompletionResult(
          placeId: place.id,
          strength: normalizedStrength,
          audioSlotKey: slotKey,
          audioUrl: audioUrl,
          displayMode: PostCompletionDisplayMode.none,
          cards: const <PostCompletionCard>[],
          message: 'La cible ${target.targetSlot} n’a pas pu être associée à une entité runtime.',
        );
      }

      cards.addAll(targetCards);
    }

    if (cards.isEmpty) {
      return PostCompletionResult(
        placeId: place.id,
        strength: normalizedStrength,
        audioSlotKey: slotKey,
        audioUrl: audioUrl,
        displayMode: PostCompletionDisplayMode.none,
        cards: const <PostCompletionCard>[],
        message: 'Aucune carte n’a pu être générée pour ce signal.',
      );
    }

    return PostCompletionResult(
      placeId: place.id,
      strength: normalizedStrength,
      audioSlotKey: slotKey,
      audioUrl: audioUrl,
      displayMode: PostCompletionDisplayMode.telegram,
      cards: cards,
      message: _telegramMessageForStrength(normalizedStrength),
    );
  }

  List<PostCompletionCard>? _buildCardsForTarget({
    required _ResolvedTarget target,
    required _RevealRule revealRule,
    required Map<String, dynamic> clueSystem,
    required Map<String, dynamic> runtimeScenarioData,
    required Map<String, dynamic> lockedScenarioData,
  }) {
    final entities = _readEntities(
      targetType: target.targetType,
      runtimeScenarioData: runtimeScenarioData,
      lockedScenarioData: lockedScenarioData,
    );
    if (entities.isEmpty) return null;

    final trueEntity = _resolveTrueEntity(
      target: target,
      entities: entities,
    );
    if (trueEntity == null) return null;

    final targetCards = <PostCompletionCard>[
      _buildCard(
        entity: trueEntity,
        targetType: target.targetType,
        isTrue: true,
        clueSystem: clueSystem,
      ),
    ];

    final falseNeeded = max(0, revealRule.optionCount - 1);
    final falseEntities = entities
        .where((entity) => entity.id != trueEntity.id)
        .toList(growable: true)
      ..shuffle(_random);

    for (final entity in falseEntities.take(falseNeeded)) {
      targetCards.add(
        _buildCard(
          entity: entity,
          targetType: target.targetType,
          isTrue: false,
          clueSystem: clueSystem,
        ),
      );
    }

    targetCards.shuffle(_random);
    return targetCards;
  }

  Future<String?> _loadCompletionAudioUrl({
    required String scenarioId,
    required String slotKey,
  }) async {
    final asset = await _mediaRepository.getActiveMediaForSlot(
      scenarioId: scenarioId,
      slotKey: slotKey,
    );
    final url = asset?.downloadUrl.trim() ?? '';
    return url.isEmpty ? null : url;
  }

  String _normalizeStrength(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == strengthStrong ||
        value == strengthMedium ||
        value == strengthWeak ||
        value == strengthNone) {
      return value;
    }
    if (value == 'confirmed') return strengthStrong;
    return strengthNone;
  }

  Future<_EffectiveScenarioData> _loadEffectiveScenarioData({
    required String lockedScenarioId,
    required Map<String, dynamic> runtimeScenarioData,
    required Map<String, dynamic> lockedScenarioData,
  }) async {
    var effectiveRuntime = _normalizeScenarioMap(runtimeScenarioData);
    var effectiveLocked = _normalizeScenarioMap(lockedScenarioData);

    if (_hasCompletionContract(effectiveRuntime, effectiveLocked)) {
      return _EffectiveScenarioData(
        runtimeScenarioData: effectiveRuntime,
        lockedScenarioData: effectiveLocked,
      );
    }

    try {
      final lockedSnapshot = await _firestore
          .collection('lockedScenarios')
          .doc(lockedScenarioId)
          .get();
      final fetchedLocked = lockedSnapshot.data();
      if (fetchedLocked != null) {
        effectiveLocked = _normalizeScenarioMap(
          fetchedLocked,
          fallbackScenarioData: effectiveLocked,
        );
      }
    } catch (_) {
      // Le moteur reste tolérant : si la lecture du lockedScenario échoue,
      // on poursuit avec les données déjà transmises par le runtime.
    }

    if (_hasCompletionContract(effectiveRuntime, effectiveLocked)) {
      return _EffectiveScenarioData(
        runtimeScenarioData: effectiveRuntime,
        lockedScenarioData: effectiveLocked,
      );
    }

    final runtimeCandidates = <Map<String, dynamic>>[];

    Future<void> addRuntimeById(String? runtimeId) async {
      final id = runtimeId?.trim();
      if (id == null || id.isEmpty) return;
      try {
        final snapshot = await _firestore.collection('runtime_scenarios').doc(id).get();
        final data = snapshot.data();
        if (snapshot.exists && data != null) {
          runtimeCandidates.add(<String, dynamic>{...data, 'id': snapshot.id});
        }
      } catch (_) {}
    }

    Future<void> addRuntimeQuery(Query<Map<String, dynamic>> query) async {
      try {
        final snapshot = await query.get();
        for (final doc in snapshot.docs) {
          runtimeCandidates.add(<String, dynamic>{...doc.data(), 'id': doc.id});
        }
      } catch (_) {}
    }

    await addRuntimeById(effectiveRuntime['id']?.toString());

    if (lockedScenarioId.trim().isNotEmpty) {
      await addRuntimeQuery(
        _firestore
            .collection('runtime_scenarios')
            .where('sourceLockedScenarioId', isEqualTo: lockedScenarioId)
            .limit(20),
      );
    }

    try {
      final gameSnapshot = await _firestore.collection('games').doc('les_fugitifs').get();
      final gameData = gameSnapshot.data();
      await addRuntimeById(gameData?['lastRuntimeScenarioId']?.toString());
    } catch (_) {}

    await addRuntimeQuery(
      _firestore
          .collection('runtime_scenarios')
          .where('gameId', isEqualTo: 'les_fugitifs')
          .limit(20),
    );

    if (runtimeCandidates.isNotEmpty) {
      runtimeCandidates.sort((a, b) {
        final aScore = _runtimeCandidateScore(a, lockedScenarioId);
        final bScore = _runtimeCandidateScore(b, lockedScenarioId);
        if (aScore != bScore) return bScore.compareTo(aScore);

        final aGeneratedAt = (a['generatedAt'] ?? '').toString();
        final bGeneratedAt = (b['generatedAt'] ?? '').toString();
        return bGeneratedAt.compareTo(aGeneratedAt);
      });

      for (final candidate in runtimeCandidates) {
        final normalizedCandidate = _normalizeScenarioMap(
          candidate,
          fallbackScenarioData: effectiveLocked,
        );
        if (_hasCompletionContract(normalizedCandidate, effectiveLocked)) {
          effectiveRuntime = normalizedCandidate;
          break;
        }
      }
    }

    effectiveRuntime = _normalizeScenarioMap(
      effectiveRuntime,
      fallbackScenarioData: effectiveLocked,
    );

    return _EffectiveScenarioData(
      runtimeScenarioData: effectiveRuntime,
      lockedScenarioData: effectiveLocked,
    );
  }

  bool _hasCompletionContract(
    Map<String, dynamic> runtimeScenarioData,
    Map<String, dynamic> lockedScenarioData,
  ) {
    final clueSystem = _readClueSystem(
      runtimeScenarioData: runtimeScenarioData,
      lockedScenarioData: lockedScenarioData,
    );
    if (_readRevealRule(clueSystem, strengthStrong).optionCount <= 0) {
      return false;
    }
    if (_readEntities(
      targetType: 'suspect',
      runtimeScenarioData: runtimeScenarioData,
      lockedScenarioData: lockedScenarioData,
    ).isEmpty) {
      return false;
    }
    if (_readEntities(
      targetType: 'motive',
      runtimeScenarioData: runtimeScenarioData,
      lockedScenarioData: lockedScenarioData,
    ).isEmpty) {
      return false;
    }
    return true;
  }

  int _runtimeCandidateScore(
    Map<String, dynamic> candidate,
    String lockedScenarioId,
  ) {
    var score = 0;
    final sourceLockedScenarioId =
        (candidate['sourceLockedScenarioId'] ?? '').toString().trim();
    if (sourceLockedScenarioId.isNotEmpty &&
        sourceLockedScenarioId == lockedScenarioId.trim()) {
      score += 100;
    }
    if (_readClueSystem(
      runtimeScenarioData: candidate,
      lockedScenarioData: const <String, dynamic>{},
    ).isNotEmpty) {
      score += 20;
    }
    if (_extractEntityMaps(candidate['suspects']).isNotEmpty) score += 10;
    if (_extractEntityMaps(candidate['motives']).isNotEmpty) score += 10;
    return score;
  }

  Map<String, dynamic> _normalizeScenarioMap(
    Map<String, dynamic> source, {
    Map<String, dynamic>? fallbackScenarioData,
  }) {
    final normalized = Map<String, dynamic>.from(source);
    final data = _asStringKeyMap(normalized['data']);
    final fallback = fallbackScenarioData ?? const <String, dynamic>{};

    void hoist(String key) {
      if (_hasUsefulValue(normalized[key])) return;
      if (_hasUsefulValue(data[key])) {
        normalized[key] = data[key];
        return;
      }
      if (_hasUsefulValue(fallback[key])) {
        normalized[key] = fallback[key];
        return;
      }
      final deepValue = _findDeepValueByKey(normalized, key);
      if (_hasUsefulValue(deepValue)) {
        normalized[key] = deepValue;
        return;
      }
      final fallbackDeepValue = _findDeepValueByKey(fallback, key);
      if (_hasUsefulValue(fallbackDeepValue)) {
        normalized[key] = fallbackDeepValue;
      }
    }

    hoist('clueSystem');
    hoist('suspects');
    hoist('motives');
    hoist('places');
    hoist('placeTemplates');

    return normalized;
  }

  bool _hasUsefulValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    return true;
  }

  Map<String, dynamic> _readClueSystem({
    required Map<String, dynamic> runtimeScenarioData,
    required Map<String, dynamic> lockedScenarioData,
  }) {
    final runtimeClue = _findNestedMap(
      runtimeScenarioData,
      const [
        ['clueSystem'],
        ['data', 'clueSystem'],
        ['snapshot', 'clueSystem'],
        ['payload', 'clueSystem'],
        ['lockedData', 'clueSystem'],
      ],
    );
    if (runtimeClue.isNotEmpty) return runtimeClue;

    final lockedClue = _findNestedMap(
      lockedScenarioData,
      const [
        ['clueSystem'],
        ['data', 'clueSystem'],
        ['snapshot', 'clueSystem'],
        ['payload', 'clueSystem'],
        ['lockedData', 'clueSystem'],
      ],
    );
    if (lockedClue.isNotEmpty) return lockedClue;

    final runtimeDeep = _asStringKeyMap(
      _findDeepValueByKey(runtimeScenarioData, 'clueSystem'),
    );
    if (runtimeDeep.isNotEmpty) return runtimeDeep;

    return _asStringKeyMap(
      _findDeepValueByKey(lockedScenarioData, 'clueSystem'),
    );
  }

  _RevealRule _readRevealRule(Map<String, dynamic> clueSystem, String strength) {
    final revealRules = _asStringKeyMap(clueSystem['revealRules']);
    final rule = _asStringKeyMap(revealRules[strength]);
    return _RevealRule(
      trueCount: _readInt(rule['trueCount']),
      optionCount: _readInt(rule['optionCount']),
    );
  }

  List<_ResolvedTarget> _resolveTargets({
    required String placeId,
    required GameSession session,
    required Map<String, dynamic> runtimeScenarioData,
    required Map<String, dynamic> lockedScenarioData,
  }) {
    final runtimePlace = _findRuntimePlace(runtimeScenarioData, placeId);
    final lockedPlace = _findLockedPlace(lockedScenarioData, placeId);

    final reward = _asStringKeyMap(runtimePlace?['reward']);
    final runtimeTargetType = _firstNonEmpty([
      reward['targetType']?.toString(),
      runtimePlace?['targetType']?.toString(),
    ]);
    final runtimeTargetSlot = _firstNonEmpty([
      reward['targetSlot']?.toString(),
      runtimePlace?['targetSlot']?.toString(),
    ]);

    final targets = <_ResolvedTarget>[];
    final seen = <String>{};

    void addTarget({
      required String? rawTargetType,
      required String? rawTargetSlot,
    }) {
      final slot = rawTargetSlot?.trim();
      final slotType = _targetTypeFromSlot(slot);
      final type = slotType ?? _normalizeTargetType(rawTargetType ?? '');
      if (type.isEmpty) return;

      final normalizedSlot = slot == null || slot.isEmpty ? null : slot;
      final key = '${type}:${(normalizedSlot ?? '').toUpperCase()}';
      if (!seen.add(key)) return;

      final entityIdFromSession = type == 'suspect'
          ? session.suspectByPlace[placeId]
          : type == 'motive'
              ? session.motiveByPlace[placeId]
              : null;

      targets.add(
        _ResolvedTarget(
          targetType: type,
          targetSlot: normalizedSlot,
          entityId: entityIdFromSession,
        ),
      );
    }

    final lockedTargets = _targetsFromLockedPlace(lockedPlace);

    // Source prioritaire quand le runtime contient une cible unique explicite.
    // Si le runtime ne transporte qu'un targetType sans targetSlot, on laisse les
    // targets du lockedScenario décider, sinon les postes mixtes perdraient le
    // deuxième volet suspect/mobile.
    if ((runtimeTargetSlot ?? '').trim().isNotEmpty || lockedTargets.isEmpty) {
      addTarget(
        rawTargetType: runtimeTargetType,
        rawTargetSlot: runtimeTargetSlot,
      );
    }

    // Source complète pour les postes mixtes : suspect ET mobile.
    for (final target in lockedTargets) {
      addTarget(
        rawTargetType: target['targetType']?.toString(),
        rawTargetSlot: target['targetSlot']?.toString(),
      );
    }

    if (targets.isNotEmpty) {
      targets.sort((a, b) {
        final aRank = a.targetType == 'suspect' ? 0 : 1;
        final bRank = b.targetType == 'suspect' ? 0 : 1;
        if (aRank != bRank) return aRank.compareTo(bRank);
        return (a.targetSlot ?? '').compareTo(b.targetSlot ?? '');
      });
      return targets;
    }

    final lockedTargetType = _firstNonEmpty([
      lockedPlace?['targetType']?.toString(),
      _lockedChallengeTargetType(lockedPlace),
    ]);
    final lockedTargetSlot = _firstNonEmpty([
      lockedPlace?['targetSlot']?.toString(),
      _firstTargetSlotFromLockedTargets(lockedPlace, runtimeTargetType ?? lockedTargetType),
    ]);

    addTarget(
      rawTargetType: runtimeTargetType ?? lockedTargetType,
      rawTargetSlot: runtimeTargetSlot ?? lockedTargetSlot,
    );

    return targets;
  }

  List<Map<String, dynamic>> _targetsFromLockedPlace(
    Map<String, dynamic>? lockedPlace,
  ) {
    final targets = lockedPlace?['targets'];
    if (targets is! List) return const <Map<String, dynamic>>[];

    return targets
        .whereType<Map>()
        .map(_asStringKeyMap)
        .where((target) {
          final slot = target['targetSlot']?.toString().trim() ?? '';
          final type = target['targetType']?.toString().trim() ?? '';
          return slot.isNotEmpty || type.isNotEmpty;
        })
        .toList(growable: false);
  }

  String? _lockedChallengeTargetType(Map<String, dynamic>? lockedPlace) {
    final challenge = _asStringKeyMap(lockedPlace?['challenge']);
    final params = _asStringKeyMap(challenge['params']);
    final clue = _asStringKeyMap(params['clue']);
    return clue['target']?.toString();
  }

  String? _firstTargetSlotFromLockedTargets(
    Map<String, dynamic>? lockedPlace,
    String? targetType,
  ) {
    final targets = lockedPlace?['targets'];
    if (targets is! List) return null;

    final normalizedType = _normalizeTargetType(targetType ?? '');
    for (final rawTarget in targets) {
      final target = _asStringKeyMap(rawTarget);
      final type = _normalizeTargetType(target['targetType']?.toString() ?? '');
      if (normalizedType.isNotEmpty && type != normalizedType) continue;
      final slot = target['targetSlot']?.toString().trim();
      if (slot != null && slot.isNotEmpty) return slot;
    }

    for (final rawTarget in targets) {
      final target = _asStringKeyMap(rawTarget);
      final slot = target['targetSlot']?.toString().trim();
      if (slot != null && slot.isNotEmpty) return slot;
    }

    return null;
  }

  List<_RuntimeEntity> _readEntities({
    required String targetType,
    required Map<String, dynamic> runtimeScenarioData,
    required Map<String, dynamic> lockedScenarioData,
  }) {
    final key = targetType == 'motive' ? 'motives' : 'suspects';
    final runtimeEntities = _extractEntityMaps(runtimeScenarioData[key]);
    final source = runtimeEntities.isNotEmpty
        ? runtimeEntities
        : _extractEntityMaps(lockedScenarioData[key]).isNotEmpty
            ? _extractEntityMaps(lockedScenarioData[key])
            : _extractEntityMaps(_asStringKeyMap(lockedScenarioData['data'])[key]);

    return source
        .map((entity) => _RuntimeEntity.fromMap(entity))
        .where((entity) => entity.id.isNotEmpty)
        .toList(growable: false);
  }

  _RuntimeEntity? _resolveTrueEntity({
    required _ResolvedTarget target,
    required List<_RuntimeEntity> entities,
  }) {
    final entityId = target.entityId?.trim();
    if (entityId != null && entityId.isNotEmpty) {
      for (final entity in entities) {
        if (entity.id == entityId) return entity;
      }
    }

    final targetSlot = target.targetSlot?.trim().toUpperCase() ?? '';
    final index = _slotIndex(targetSlot);
    if (index != null && index >= 0 && index < entities.length) {
      return entities[index];
    }

    return null;
  }

  PostCompletionCard _buildCard({
    required _RuntimeEntity entity,
    required String targetType,
    required bool isTrue,
    required Map<String, dynamic> clueSystem,
  }) {
    final contentMode = _chooseContentMode(targetType, clueSystem);
    final attribute = entity.attributes.isEmpty
        ? ''
        : entity.attributes[_random.nextInt(entity.attributes.length)];
    final text = contentMode == PostCompletionCardContentMode.attribute &&
            attribute.trim().isNotEmpty
        ? attribute
        : entity.title;

    return PostCompletionCard(
      id: entity.id,
      targetType: targetType,
      title: entity.title,
      text: text,
      imageKey: entity.imageKey,
      isTrue: isTrue,
      contentMode: contentMode,
      imageFocus: contentMode == PostCompletionCardContentMode.name
          ? PostCompletionImageFocus.identity
          : PostCompletionImageFocus.detail,
    );
  }

  PostCompletionCardContentMode _chooseContentMode(
    String targetType,
    Map<String, dynamic> clueSystem,
  ) {
    final contentRules = _asStringKeyMap(clueSystem['contentRules']);
    final typeRules = _asStringKeyMap(contentRules[targetType]);
    final attributeWeight = max(0, _readInt(typeRules['attributeWeight']));
    final nameWeight = max(0, _readInt(typeRules['nameWeight']));
    final total = attributeWeight + nameWeight;

    if (total <= 0) return PostCompletionCardContentMode.attribute;
    final draw = _random.nextInt(total);
    return draw < attributeWeight
        ? PostCompletionCardContentMode.attribute
        : PostCompletionCardContentMode.name;
  }

  String _telegramMessageForStrength(String strength) {
    switch (strength) {
      case strengthStrong:
        return 'Signal fort : le Grid isole une vérité nette.';
      case strengthMedium:
        return 'Signal partiel : le Grid hésite entre plusieurs traces.';
      case strengthWeak:
        return 'Signal faible : le Grid laisse filtrer une piste fragile.';
      default:
        return 'Signal nul : aucune donnée exploitable.';
    }
  }

  Map<String, dynamic>? _findRuntimePlace(
    Map<String, dynamic> runtimeScenarioData,
    String placeId,
  ) {
    final places = runtimeScenarioData['places'];
    if (places is! List) return null;
    for (final rawPlace in places) {
      final place = _asStringKeyMap(rawPlace);
      if ((place['id'] ?? '').toString().trim() == placeId) return place;
    }
    return null;
  }

  Map<String, dynamic>? _findLockedPlace(
    Map<String, dynamic> lockedScenarioData,
    String placeId,
  ) {
    final directPlace = _findPlaceInRawMap(lockedScenarioData['placeTemplates'], placeId) ??
        _findPlaceInRawMap(lockedScenarioData['places'], placeId);
    if (directPlace != null) return directPlace;

    final data = _asStringKeyMap(lockedScenarioData['data']);
    return _findPlaceInRawMap(data['placeTemplates'], placeId) ??
        _findPlaceInRawMap(data['places'], placeId);
  }

  Map<String, dynamic>? _findPlaceInRawMap(dynamic raw, String placeId) {
    if (raw is Map) {
      final byKey = raw[placeId];
      if (byKey is Map) return _asStringKeyMap(byKey);
      for (final value in raw.values) {
        final place = _asStringKeyMap(value);
        if ((place['id'] ?? '').toString().trim() == placeId) return place;
      }
    }

    if (raw is List) {
      for (final value in raw) {
        final place = _asStringKeyMap(value);
        if ((place['id'] ?? '').toString().trim() == placeId) return place;
      }
    }

    return null;
  }

  static String _normalizeTargetType(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'suspect' || value == 'pc') return 'suspect';
    if (value == 'motive' || value == 'mobile' || value == 'mo') return 'motive';
    return '';
  }

  static String? _targetTypeFromSlot(String? rawSlot) {
    final slot = rawSlot?.trim().toUpperCase() ?? '';
    if (slot.startsWith('PC')) return 'suspect';
    if (slot.startsWith('MO')) return 'motive';
    return null;
  }

  static int? _slotIndex(String slot) {
    final match = RegExp(r'(?:PC|MO)(\d+)', caseSensitive: false).firstMatch(slot);
    if (match == null) return null;
    final number = int.tryParse(match.group(1) ?? '');
    if (number == null) return null;
    return number - 1;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static int _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static dynamic _findDeepValueByKey(dynamic raw, String wantedKey) {
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key.toString() == wantedKey) return entry.value;
      }
      for (final entry in raw.entries) {
        final found = _findDeepValueByKey(entry.value, wantedKey);
        if (found != null) return found;
      }
    }

    if (raw is Iterable) {
      for (final value in raw) {
        final found = _findDeepValueByKey(value, wantedKey);
        if (found != null) return found;
      }
    }

    return null;
  }

  static Map<String, dynamic> _findNestedMap(
    Map<String, dynamic> root,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      dynamic current = root;
      for (final key in path) {
        final map = _asStringKeyMap(current);
        if (map.isEmpty || !map.containsKey(key)) {
          current = null;
          break;
        }
        current = map[key];
      }

      final result = _asStringKeyMap(current);
      if (result.isNotEmpty) return result;
    }

    return const <String, dynamic>{};
  }

  static Map<String, dynamic> _asStringKeyMap(dynamic raw) {
    if (raw is! Map) return const <String, dynamic>{};
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Map<String, dynamic>> _extractEntityMaps(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((entry) => entry.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .toList(growable: false);
    }

    if (raw is Map) {
      return raw.entries.where((entry) => entry.value is Map).map((entry) {
        final value = (entry.value as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        );
        if ((value['id'] ?? '').toString().trim().isEmpty) {
          return {
            'id': entry.key.toString(),
            ...value,
          };
        }
        return value;
      }).toList(growable: false);
    }

    return const <Map<String, dynamic>>[];
  }
}

class _EffectiveScenarioData {
  final Map<String, dynamic> runtimeScenarioData;
  final Map<String, dynamic> lockedScenarioData;

  const _EffectiveScenarioData({
    required this.runtimeScenarioData,
    required this.lockedScenarioData,
  });
}

enum PostCompletionDisplayMode { none, telegram }

enum PostCompletionCardContentMode { name, attribute }

enum PostCompletionImageFocus { identity, detail }

class PostCompletionResult {
  final String placeId;
  final String strength;
  final String audioSlotKey;
  final String? audioUrl;
  final PostCompletionDisplayMode displayMode;
  final List<PostCompletionCard> cards;
  final String message;

  const PostCompletionResult({
    required this.placeId,
    required this.strength,
    required this.audioSlotKey,
    required this.audioUrl,
    required this.displayMode,
    required this.cards,
    required this.message,
  });

  bool get hasTelegram => displayMode == PostCompletionDisplayMode.telegram;
  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;
}

class PostCompletionCard {
  final String id;
  final String targetType;
  final String title;
  final String text;
  final String imageKey;
  final bool isTrue;
  final PostCompletionCardContentMode contentMode;
  final PostCompletionImageFocus imageFocus;

  const PostCompletionCard({
    required this.id,
    required this.targetType,
    required this.title,
    required this.text,
    required this.imageKey,
    required this.isTrue,
    required this.contentMode,
    required this.imageFocus,
  });
}

class _RevealRule {
  final int trueCount;
  final int optionCount;

  const _RevealRule({
    required this.trueCount,
    required this.optionCount,
  });
}

class _ResolvedTarget {
  final String targetType;
  final String? targetSlot;
  final String? entityId;

  const _ResolvedTarget({
    required this.targetType,
    required this.targetSlot,
    required this.entityId,
  });

  bool get hasUsableSignal {
    if (targetType.isEmpty) return false;
    final slot = targetSlot?.trim().toLowerCase() ?? '';
    final entity = entityId?.trim() ?? '';
    if (entity.isNotEmpty) return true;
    if (slot.isEmpty || slot == 'none' || slot == 'null') return false;
    return true;
  }
}

class _RuntimeEntity {
  final String id;
  final String title;
  final List<String> attributes;
  final String imageKey;

  const _RuntimeEntity({
    required this.id,
    required this.title,
    required this.attributes,
    required this.imageKey,
  });

  factory _RuntimeEntity.fromMap(Map<String, dynamic> map) {
    final identityVisual = PostCompletionEngine._asStringKeyMap(
      map['identityVisual'],
    );
    return _RuntimeEntity(
      id: (map['id'] ?? '').toString().trim(),
      title: (map['title'] ?? map['name'] ?? '').toString().trim(),
      attributes: _readStringList(map['attributes']),
      imageKey: (identityVisual['mediaKey'] ??
              map['imageKey'] ??
              map['imagePath'] ??
              map['image'] ??
              '')
          .toString()
          .trim(),
    );
  }

  static List<String> _readStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(RegExp(r'[,;|]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}
