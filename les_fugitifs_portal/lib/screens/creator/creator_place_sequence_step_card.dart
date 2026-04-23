import 'package:flutter/material.dart';

import 'utils/place_sequence_factories.dart';

class CreatorPlaceSequenceStepCard extends StatelessWidget {
  final Map<String, dynamic> step;
  final int index;
  final List<Map<String, dynamic>> availableSteps;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const CreatorPlaceSequenceStepCard({
    super.key,
    required this.step,
    required this.index,
    required this.availableSteps,
    required this.onDelete,
    required this.onChanged,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final stepType = (step['type'] ?? 'popup').toString();
    final title = (step['title'] ?? '').toString();
    final description = (step['description'] ?? '').toString();
    final stepId = (step['id'] ?? '').toString();

    final rawParams = step['params'];
    final params = rawParams is Map
        ? Map<String, dynamic>.from(rawParams as Map)
        : <String, dynamic>{};

    final rawRuntime = step['runtime'];
    final runtime = rawRuntime is Map
        ? normalizeStepRuntime(Map<String, dynamic>.from(rawRuntime as Map))
        : buildDefaultStepRuntime();

    final popupText = (params['text'] ?? '').toString();
    final confirmLabel = (params['confirmLabel'] ?? "D'accord").toString();
    final callerLabel = (params['callerLabel'] ?? '').toString();
    final displayMode = (params['displayMode'] ?? 'standard').toString();

    final startMode = (runtime['startMode'] ?? 'after_previous').toString();
    final referenceStepId = runtime['referenceStepId']?.toString();
    final delayMs = _readInt(runtime['delayMs'], fallback: 0);
    final delaySeconds = (delayMs / 1000).round();

    final closeMode = (runtime['closeMode'] ?? 'manual').toString();
    final closeGate = (runtime['closeGate'] ?? 'none').toString();
    final closeBlockedUntilStepId =
        runtime['closeBlockedUntilStepId']?.toString();

    final referenceCandidates = availableSteps
        .where((candidate) => (candidate['id'] ?? '').toString() != stepId)
        .toList();

    final hasReferenceValue = referenceCandidates.any(
      (candidate) => (candidate['id'] ?? '').toString() == referenceStepId,
    );

    final hasCloseReferenceValue = referenceCandidates.any(
      (candidate) =>
          (candidate['id'] ?? '').toString() == closeBlockedUntilStepId,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Étape ${index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Monter',
                  onPressed: onMoveUp,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Descendre',
                  onPressed: onMoveDown,
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: allowedSequenceStepTypes().contains(stepType)
                  ? stepType
                  : 'popup',
              decoration: const InputDecoration(
                labelText: 'Type d’étape',
                border: OutlineInputBorder(),
              ),
              items: allowedSequenceStepTypes()
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(_displayStepType(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                final nextType = value ?? 'popup';
                final rebuilt = buildSequenceStepForType(
                  nextType,
                  id: stepId.isEmpty ? null : stepId,
                  description: description,
                );
                onChanged(rebuilt);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('step_title_${stepId}_$stepType'),
              initialValue: title,
              decoration: const InputDecoration(
                labelText: 'Titre de l’étape',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                onChanged(_copyWith(
                  step,
                  title: value,
                  description: description,
                  params: params,
                  runtime: runtime,
                ));
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('step_description_${stepId}_$stepType'),
              initialValue: description,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description / intention de l’étape',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (value) {
                onChanged(_copyWith(
                  step,
                  title: title,
                  description: value,
                  params: params,
                  runtime: runtime,
                ));
              },
            ),
            const SizedBox(height: 12),
            if (stepType == 'image') ...[
              DropdownButtonFormField<String>(
                value: displayMode == 'exploration_window'
                    ? 'exploration_window'
                    : 'standard',
                decoration: const InputDecoration(
                  labelText: 'Mode d’affichage de l’image',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFF121A2A),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'standard',
                    child: Text('Image fixe'),
                  ),
                  DropdownMenuItem(
                    value: 'exploration_window',
                    child: Text('Image exploratoire'),
                  ),
                ],
                onChanged: (value) {
                  final nextParams = <String, dynamic>{
                    'displayMode': value == 'exploration_window'
                        ? 'exploration_window'
                        : 'standard',
                  };
                  onChanged(_copyWith(
                    step,
                    title: title,
                    description: description,
                    params: nextParams,
                    runtime: runtime,
                  ));
                },
              ),
              const SizedBox(height: 8),
              Text(
                displayMode == 'exploration_window'
                    ? 'La tablette agit comme une fenêtre mobile qui ne montre qu’une partie de l’image.'
                    : 'L’image est affichée normalement, en une seule vue.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text(
                'Comportement de l’étape',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Début, délai et conditions de fermeture',
                style: TextStyle(fontSize: 12),
              ),
              children: [
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: allowedStepStartModes().contains(startMode)
                      ? startMode
                      : 'after_previous',
                  decoration: const InputDecoration(
                    labelText: 'Début de l’étape',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'after_previous',
                      child: Text('À la suite de l’étape précédente'),
                    ),
                    DropdownMenuItem(
                      value: 'parallel',
                      child: Text('En parallèle d’une autre étape'),
                    ),
                    DropdownMenuItem(
                      value: 'after_delay',
                      child: Text('Après un délai'),
                    ),
                  ],
                  onChanged: (value) {
                    final nextStartMode = value ?? 'after_previous';
                    final nextRuntime = Map<String, dynamic>.from(runtime)
                      ..['startMode'] = nextStartMode;

                    if (nextStartMode == 'after_previous') {
                      nextRuntime['referenceStepId'] = null;
                      nextRuntime['delayMs'] = 0;
                    } else if (nextStartMode == 'after_delay') {
                      nextRuntime['referenceStepId'] = null;
                    }

                    onChanged(_copyWith(
                      step,
                      title: title,
                      description: description,
                      params: params,
                      runtime: nextRuntime,
                    ));
                  },
                ),
                const SizedBox(height: 12),
                if (startMode == 'parallel') ...[
                  DropdownButtonFormField<String>(
                    value: hasReferenceValue ? referenceStepId : null,
                    decoration: const InputDecoration(
                      labelText: 'Étape de référence',
                      border: OutlineInputBorder(),
                    ),
                    items: referenceCandidates
                        .map(
                          (candidate) => DropdownMenuItem<String>(
                            value: (candidate['id'] ?? '').toString(),
                            child: Text(
                              (candidate['title'] ?? 'Étape sans titre')
                                  .toString(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final nextRuntime = Map<String, dynamic>.from(runtime)
                        ..['referenceStepId'] = value;
                      onChanged(_copyWith(
                        step,
                        title: title,
                        description: description,
                        params: params,
                        runtime: nextRuntime,
                      ));
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (startMode == 'parallel' || startMode == 'after_delay') ...[
                  TextFormField(
                    key: ValueKey('delay_seconds_${stepId}_$startMode'),
                    initialValue: delaySeconds.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: startMode == 'parallel'
                          ? 'Délai après le début de l’étape de référence (secondes)'
                          : 'Délai avant démarrage (secondes)',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final nextRuntime = Map<String, dynamic>.from(runtime)
                        ..['delayMs'] = _readInt(value, fallback: 0) * 1000;
                      onChanged(_copyWith(
                        step,
                        title: title,
                        description: description,
                        params: params,
                        runtime: nextRuntime,
                      ));
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  value: allowedStepCloseModes().contains(closeMode)
                      ? closeMode
                      : 'manual',
                  decoration: const InputDecoration(
                    labelText: 'Fin de l’étape',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'manual',
                      child: Text('Fermeture manuelle'),
                    ),
                    DropdownMenuItem(
                      value: 'auto',
                      child: Text('Fermeture automatique'),
                    ),
                  ],
                  onChanged: (value) {
                    final nextCloseMode = value ?? 'manual';
                    final nextRuntime = Map<String, dynamic>.from(runtime)
                      ..['closeMode'] = nextCloseMode;

                    onChanged(_copyWith(
                      step,
                      title: title,
                      description: description,
                      params: params,
                      runtime: nextRuntime,
                    ));
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: allowedStepCloseGates().contains(closeGate)
                      ? closeGate
                      : 'none',
                  decoration: const InputDecoration(
                    labelText: 'Autorisation de fermeture',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text('Aucune contrainte'),
                    ),
                    DropdownMenuItem(
                      value: 'until_step',
                      child: Text('Déverrouillée après une autre étape'),
                    ),
                  ],
                  onChanged: (value) {
                    final nextCloseGate = value ?? 'none';
                    final nextRuntime = Map<String, dynamic>.from(runtime)
                      ..['closeGate'] = nextCloseGate;

                    if (nextCloseGate != 'until_step') {
                      nextRuntime['closeBlockedUntilStepId'] = null;
                    }

                    onChanged(_copyWith(
                      step,
                      title: title,
                      description: description,
                      params: params,
                      runtime: nextRuntime,
                    ));
                  },
                ),
                const SizedBox(height: 12),
                if (closeGate == 'until_step') ...[
                  DropdownButtonFormField<String>(
                    value: hasCloseReferenceValue ? closeBlockedUntilStepId : null,
                    decoration: const InputDecoration(
                      labelText: 'Étape qui déverrouille la fermeture',
                      border: OutlineInputBorder(),
                    ),
                    items: referenceCandidates
                        .map(
                          (candidate) => DropdownMenuItem<String>(
                            value: (candidate['id'] ?? '').toString(),
                            child: Text(
                              (candidate['title'] ?? 'Étape sans titre')
                                  .toString(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final nextRuntime = Map<String, dynamic>.from(runtime)
                        ..['closeBlockedUntilStepId'] = value;
                      onChanged(_copyWith(
                        step,
                        title: title,
                        description: description,
                        params: params,
                        runtime: nextRuntime,
                      ));
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
            if (stepType == 'popup') ...[
              TextFormField(
                key: ValueKey('popup_text_${stepId}'),
                initialValue: popupText,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Texte de la fenêtre',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final nextParams = <String, dynamic>{
                    'text': value,
                    'confirmLabel':
                        confirmLabel.isEmpty ? "D'accord" : confirmLabel,
                  };
                  onChanged(_copyWith(
                    step,
                    title: title,
                    description: description,
                    params: nextParams,
                    runtime: runtime,
                  ));
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('popup_confirm_${stepId}'),
                initialValue: confirmLabel,
                decoration: const InputDecoration(
                  labelText: 'Texte du bouton',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final nextParams = <String, dynamic>{
                    'text': popupText,
                    'confirmLabel': value.isEmpty ? "D'accord" : value,
                  };
                  onChanged(_copyWith(
                    step,
                    title: title,
                    description: description,
                    params: nextParams,
                    runtime: runtime,
                  ));
                },
              ),
            ],
            if (stepType == 'call') ...[
              TextFormField(
                key: ValueKey('call_label_${stepId}'),
                initialValue: callerLabel,
                decoration: const InputDecoration(
                  labelText: 'Nom de l’appelant',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final nextParams = <String, dynamic>{
                    'callerLabel': value,
                  };
                  onChanged(_copyWith(
                    step,
                    title: title,
                    description: description,
                    params: nextParams,
                    runtime: runtime,
                  ));
                },
              ),
            ],
            if (stepType == 'video' || stepType == 'audio')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  stepType == 'video'
                      ? 'Décris ici ce que raconte la vidéo et ce qu’elle doit provoquer chez les joueurs.'
                      : 'Décris ici ce que dit ou fait entendre l’audio et l’effet attendu côté joueurs.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _copyWith(
    Map<String, dynamic> original, {
    String? title,
    String? description,
    Map<String, dynamic>? params,
    Map<String, dynamic>? runtime,
  }) {
    final originalId = (original['id'] ?? '').toString();
    final originalType = (original['type'] ?? 'popup').toString();

    return <String, dynamic>{
      'id': originalId.isEmpty ? buildStableStepId() : originalId,
      'type': originalType,
      'title': title ?? (original['title'] ?? '').toString(),
      'description':
          description ?? (original['description'] ?? '').toString(),
      'blocking': true,
      'params': params ?? <String, dynamic>{},
      'runtime': normalizeStepRuntime(runtime),
    };
  }

  int _readInt(dynamic raw, {required int fallback}) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static String _displayStepType(String type) {
    switch (type) {
      case 'popup':
        return 'Popup';
      case 'call':
        return 'Appel';
      case 'video':
        return 'Vidéo';
      case 'audio':
        return 'Audio';
      case 'image':
        return 'Image';
      default:
        return 'Inconnu';
    }
  }
}
