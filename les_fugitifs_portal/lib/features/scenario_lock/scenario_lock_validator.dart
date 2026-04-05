import 'scenario_lock_models.dart';

class ScenarioLockValidator {
  const ScenarioLockValidator();

  ScenarioLockResult validate({
    required ScenarioDraftSnapshot snapshot,
  }) {
    final issues = <ScenarioValidationIssue>[];

    _validateGame(snapshot.game, issues);
    _validatePlaceTemplates(snapshot.placeTemplates, issues);
    _validateSuspects(snapshot.suspects, issues);
    _validateMotives(snapshot.motives, issues);
    _validateCrossRules(snapshot, issues);

    return ScenarioLockResult(
      success: issues.where((issue) => issue.isError).isEmpty,
      issues: issues,
    );
  }

  void _validateGame(
      Map<String, dynamic>? game,
      List<ScenarioValidationIssue> issues,
      ) {
    if (game == null) {
      issues.add(
        const ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'game_missing',
          message: 'Le document principal games/les_fugitifs est introuvable.',
          field: 'game',
        ),
      );
      return;
    }

    final gameId = (game['id'] ?? '').toString().trim();
    final title = (game['title'] ?? '').toString().trim();
    final totalPlaces =
    (game['structureRules']?['totalPlaces'] as num?)?.toInt();
    final suspectsExpected =
    (game['distributionRules']?['suspects']?['totalExpected'] as num?)
        ?.toInt();
    final motivesExpected =
    (game['distributionRules']?['motives']?['totalExpected'] as num?)
        ?.toInt();

    if (gameId.isEmpty) {
      issues.add(
        const ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'game_id_missing',
          message: 'Le jeu n’a pas de champ id.',
          field: 'game.id',
        ),
      );
    }

    if (title.isEmpty) {
      issues.add(
        const ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'game_title_missing',
          message: 'Le jeu n’a pas de titre.',
          field: 'game.title',
        ),
      );
    }

    if (totalPlaces == null) {
      issues.add(
        const ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'game_total_places_missing',
          message: 'Le nombre total de lieux attendu est absent.',
          field: 'game.structureRules.totalPlaces',
        ),
      );
    }

    if (suspectsExpected == null) {
      issues.add(
        const ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'game_suspects_expected_missing',
          message: 'Le nombre attendu de suspects est absent.',
          field: 'game.distributionRules.suspects.totalExpected',
        ),
      );
    }

    if (motivesExpected == null) {
      issues.add(
        const ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'game_motives_expected_missing',
          message: 'Le nombre attendu de mobiles est absent.',
          field: 'game.distributionRules.motives.totalExpected',
        ),
      );
    }
  }

  void _validatePlaceTemplates(
      Map<String, Map<String, dynamic>> placeTemplates,
      List<ScenarioValidationIssue> issues,
      ) {
    if (placeTemplates.isEmpty) {
      issues.add(
        const ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'place_templates_empty',
          message: 'Aucun placeTemplate n’a été trouvé.',
          field: 'placeTemplates',
        ),
      );
      return;
    }

    if (placeTemplates.length != 19) {
      issues.add(
        ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'place_templates_count_invalid',
          message:
          'Le scénario doit contenir exactement 19 lieux. Actuellement: ${placeTemplates.length}.',
          field: 'placeTemplates',
        ),
      );
    }

    final requiredIds = <String>{
      'A0',
      'A1',
      'A2',
      'A3',
      'A4',
      'A5',
      'A6',
      'B0',
      'B1',
      'B2',
      'B3',
      'B4',
      'B5',
      'C0',
      'C1',
      'C2',
      'C3',
      'C4',
      'D0',
    };

    for (final requiredId in requiredIds) {
      if (!placeTemplates.containsKey(requiredId)) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'place_template_missing',
            message: 'Le lieu $requiredId est manquant dans les placeTemplates.',
            itemId: requiredId,
            field: 'placeTemplates.$requiredId',
          ),
        );
      }
    }

    for (final entry in placeTemplates.entries) {
      final placeId = entry.key;
      final data = entry.value;

      final id = (data['id'] ?? '').toString().trim();
      final phase = (data['phase'] ?? '').toString().trim();
      final experienceType =
      (data['experienceType'] ?? data['type'] ?? '').toString().trim();
      final synopsis =
      (data['storySynopsis'] ?? data['synopsis'] ?? '').toString().trim();
      final name = (data['title'] ?? data['name'] ?? '').toString().trim();
      final isActive = data['isActive'] == true;

      if (id.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'place_id_missing',
            message: 'Le lieu $placeId n’a pas de champ id.',
            itemId: placeId,
            field: 'placeTemplates.$placeId.id',
          ),
        );
      }

      if (phase.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'place_phase_missing',
            message: 'Le lieu $placeId n’a pas de phase.',
            itemId: placeId,
            field: 'placeTemplates.$placeId.phase',
          ),
        );
      }

      if (experienceType.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'place_experience_type_missing',
            message: 'Le lieu $placeId n’a pas de type d’expérience.',
            itemId: placeId,
            field: 'placeTemplates.$placeId.experienceType',
          ),
        );
      }

      if (synopsis.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.warning,
            code: 'place_synopsis_missing',
            message: 'Le lieu $placeId n’a pas de synopsis.',
            itemId: placeId,
            field: 'placeTemplates.$placeId.storySynopsis',
          ),
        );
      }

      if (isActive && name.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'active_place_name_missing',
            message: 'Le lieu actif $placeId n’a pas de nom.',
            itemId: placeId,
            field: 'placeTemplates.$placeId.name',
          ),
        );
      }

      final hasSingleTargetType =
          (data['targetType'] ?? '').toString().trim().isNotEmpty;
      final hasSingleTargetSlot =
          (data['targetSlot'] ?? '').toString().trim().isNotEmpty;
      final rawTargets = data['targets'];
      final hasTargets = rawTargets is Iterable && rawTargets.isNotEmpty;
      final targetSelectionMode =
      (data['targetSelectionMode'] ?? '').toString().trim();

      if (targetSelectionMode.isNotEmpty && !hasTargets) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'place_target_selection_without_targets',
            message:
            'Le lieu $placeId déclare un targetSelectionMode sans targets.',
            itemId: placeId,
            field: 'placeTemplates.$placeId.targets',
          ),
        );
      }

      final shouldTargetSomething =
          placeId != 'A0' && placeId != 'D0' && placeId != 'B0' && placeId != 'C0';

      if (shouldTargetSomething && !hasTargets && !(hasSingleTargetType && hasSingleTargetSlot)) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'place_target_missing',
            message:
            'Le lieu $placeId ne définit aucune cible exploitable pour le runtime.',
            itemId: placeId,
            field: 'placeTemplates.$placeId.targets',
          ),
        );
      }

      final keywords = data['keywords'];
      if (keywords is! Iterable || keywords.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.warning,
            code: 'place_keywords_missing',
            message: 'Le lieu $placeId n’a pas de mots-clés vocaux.',
            itemId: placeId,
            field: 'placeTemplates.$placeId.keywords',
          ),
        );
      }
    }
  }

  void _validateSuspects(
      Map<String, Map<String, dynamic>> suspects,
      List<ScenarioValidationIssue> issues,
      ) {
    if (suspects.isEmpty) {
      issues.add(
        const ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'suspects_empty',
          message: 'Aucun suspect n’a été trouvé.',
          field: 'suspects',
        ),
      );
      return;
    }

    for (final entry in suspects.entries) {
      final suspectId = entry.key;
      final data = entry.value;

      final id = (data['id'] ?? '').toString().trim();
      final name = (data['name'] ?? '').toString().trim();
      final imagePath = (data['imagePath'] ?? data['image'] ?? '')
          .toString()
          .trim();

      if (id.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'suspect_id_missing',
            message: 'Le suspect $suspectId n’a pas de champ id.',
            itemId: suspectId,
            field: 'suspects.$suspectId.id',
          ),
        );
      }

      if (name.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'suspect_name_missing',
            message: 'Le suspect $suspectId n’a pas de nom.',
            itemId: suspectId,
            field: 'suspects.$suspectId.name',
          ),
        );
      }

      if (imagePath.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'suspect_image_missing',
            message:
            'Le suspect $suspectId n’a pas d’image. Le lock exige une image runtime.',
            itemId: suspectId,
            field: 'suspects.$suspectId.imagePath',
          ),
        );
      } else if (!imagePath.startsWith('games/les_fugitifs/assets/suspects/')) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'suspect_image_path_invalid',
            message:
            'Le suspect $suspectId a une image hors du dossier Storage attendu.',
            itemId: suspectId,
            field: 'suspects.$suspectId.imagePath',
          ),
        );
      }
    }
  }

  void _validateMotives(
      Map<String, Map<String, dynamic>> motives,
      List<ScenarioValidationIssue> issues,
      ) {
    if (motives.isEmpty) {
      issues.add(
        const ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'motives_empty',
          message: 'Aucun mobile n’a été trouvé.',
          field: 'motives',
        ),
      );
      return;
    }

    for (final entry in motives.entries) {
      final motiveId = entry.key;
      final data = entry.value;

      final id = (data['id'] ?? '').toString().trim();
      final name = (data['name'] ?? '').toString().trim();
      final imagePath = (data['imagePath'] ?? data['image'] ?? '')
          .toString()
          .trim();

      if (id.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'motive_id_missing',
            message: 'Le mobile $motiveId n’a pas de champ id.',
            itemId: motiveId,
            field: 'motives.$motiveId.id',
          ),
        );
      }

      if (name.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'motive_name_missing',
            message: 'Le mobile $motiveId n’a pas de nom.',
            itemId: motiveId,
            field: 'motives.$motiveId.name',
          ),
        );
      }

      if (imagePath.isEmpty) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'motive_image_missing',
            message:
            'Le mobile $motiveId n’a pas d’image. Le lock exige une image runtime.',
            itemId: motiveId,
            field: 'motives.$motiveId.imagePath',
          ),
        );
      } else if (!imagePath.startsWith('games/les_fugitifs/assets/motives/')) {
        issues.add(
          ScenarioValidationIssue(
            severity: ScenarioValidationSeverity.error,
            code: 'motive_image_path_invalid',
            message:
            'Le mobile $motiveId a une image hors du dossier Storage attendu.',
            itemId: motiveId,
            field: 'motives.$motiveId.imagePath',
          ),
        );
      }
    }
  }

  void _validateCrossRules(
      ScenarioDraftSnapshot snapshot,
      List<ScenarioValidationIssue> issues,
      ) {
    final game = snapshot.game;
    if (game == null) return;

    final expectedPlaces =
    (game['structureRules']?['totalPlaces'] as num?)?.toInt();
    final expectedSuspects =
    (game['distributionRules']?['suspects']?['totalExpected'] as num?)
        ?.toInt();
    final expectedMotives =
    (game['distributionRules']?['motives']?['totalExpected'] as num?)
        ?.toInt();

    if (expectedPlaces != null &&
        snapshot.placeTemplates.length != expectedPlaces) {
      issues.add(
        ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'place_count_mismatch',
          message:
          'Le jeu attend $expectedPlaces lieux, mais ${snapshot.placeTemplates.length} ont été trouvés.',
          field: 'placeTemplates',
        ),
      );
    }

    if (expectedSuspects != null &&
        snapshot.suspects.length != expectedSuspects) {
      issues.add(
        ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'suspects_count_mismatch',
          message:
          'Le jeu attend $expectedSuspects suspects, mais ${snapshot.suspects.length} ont été trouvés.',
          field: 'suspects',
        ),
      );
    }

    if (expectedMotives != null &&
        snapshot.motives.length != expectedMotives) {
      issues.add(
        ScenarioValidationIssue(
          severity: ScenarioValidationSeverity.error,
          code: 'motives_count_mismatch',
          message:
          'Le jeu attend $expectedMotives mobiles, mais ${snapshot.motives.length} ont été trouvés.',
          field: 'motives',
        ),
      );
    }
  }
}