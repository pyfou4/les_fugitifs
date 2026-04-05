import 'package:flutter/foundation.dart';

enum ScenarioValidationSeverity {
  error,
  warning,
}

@immutable
class ScenarioValidationIssue {
  final ScenarioValidationSeverity severity;
  final String code;
  final String message;
  final String? field;
  final String? itemId;

  const ScenarioValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.field,
    this.itemId,
  });

  bool get isError => severity == ScenarioValidationSeverity.error;
  bool get isWarning => severity == ScenarioValidationSeverity.warning;
}

@immutable
class ScenarioLockResult {
  final bool success;
  final String? lockedScenarioId;
  final List<ScenarioValidationIssue> issues;

  const ScenarioLockResult({
    required this.success,
    required this.issues,
    this.lockedScenarioId,
  });

  List<ScenarioValidationIssue> get errors =>
      issues.where((issue) => issue.isError).toList();

  List<ScenarioValidationIssue> get warnings =>
      issues.where((issue) => issue.isWarning).toList();

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

@immutable
class ScenarioDraftSnapshot {
  final Map<String, dynamic>? game;
  final Map<String, Map<String, dynamic>> placeTemplates;
  final Map<String, Map<String, dynamic>> suspects;
  final Map<String, Map<String, dynamic>> motives;

  const ScenarioDraftSnapshot({
    required this.game,
    required this.placeTemplates,
    required this.suspects,
    required this.motives,
  });
}