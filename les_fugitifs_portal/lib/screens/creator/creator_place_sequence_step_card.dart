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

    final mediaUsages = normalizeMediaUsages(
      step['mediaUsages'],
      stepType: stepType,
      stepId: stepId.isEmpty ? buildStableStepId() : stepId,
      params: params,
    );

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
                  mediaUsages: mediaUsages,
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
                  mediaUsages: mediaUsages,
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
                  final nextDisplayMode = value == 'exploration_window'
                      ? 'exploration_window'
                      : 'standard';
                  final nextParams = <String, dynamic>{
                    'displayMode': nextDisplayMode,
                  };
                  final nextMediaUsages = mediaUsages.isEmpty
                      ? buildDefaultMediaUsagesForStepType(
                          stepType,
                          stepId: stepId.isEmpty ? buildStableStepId() : stepId,
                          params: nextParams,
                        )
                      : _copyMediaUsageAt(
                          mediaUsages,
                          0,
                          runtimeMode: nextDisplayMode == 'exploration_window'
                              ? 'dynamic_pan_zoom'
                              : 'standard_image',
                          archiveEnabled: mediaUsages.first['archive'] is Map
                              ? mediaUsages.first['archive']['enabled'] == true
                              : false,
                          archiveMode: mediaUsages.first['archive'] is Map &&
                                  mediaUsages.first['archive']['enabled'] == true
                              ? defaultArchiveModeForRuntimeMode(
                                  nextDisplayMode == 'exploration_window'
                                      ? 'dynamic_pan_zoom'
                                      : 'standard_image',
                                )
                              : 'none',
                        );
                  onChanged(_copyWith(
                    step,
                    title: title,
                    description: description,
                    params: nextParams,
                    runtime: runtime,
                    mediaUsages: nextMediaUsages,
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

            if (stepTypeRequiresMedia(stepType)) ...[
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: true,
                title: const Text(
                  'Archivage du média',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Définit si le média reste consultable dans les archives après la visite du poste.',
                  style: TextStyle(fontSize: 12),
                ),
                children: [
                  const SizedBox(height: 8),
                  ...mediaUsages.asMap().entries.expand((entry) {
                    final mediaIndex = entry.key;
                    final usage = entry.value;
                    final runtimeMode =
                        (usage['runtimeMode'] ?? '').toString().trim();
                    final archive = usage['archive'] is Map
                        ? Map<String, dynamic>.from(usage['archive'] as Map)
                        : <String, dynamic>{};
                    final archiveEnabled = archive['enabled'] == true;
                    final archiveMode = archiveEnabled
                        ? (archive['mode'] ?? 'none').toString()
                        : 'none';

                    final archiveModeItems =
                        _archiveModeItemsForRuntimeMode(runtimeMode);

                    return <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111A2B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2A3445)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile.adaptive(
                              value: archiveEnabled,
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFFFF8A3D),
                              title: const Text(
                                'Conserver ce média dans les archives',
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                archiveEnabled
                                    ? 'Ce média restera consultable plus tard dans les archives.'
                                    : 'Ce média ne sera visible que pendant le poste.',
                                style: const TextStyle(color: Color(0xFFB8C1D1)),
                              ),
                              onChanged: (enabled) {
                                final nextArchiveMode = enabled
                                    ? defaultArchiveModeForRuntimeMode(runtimeMode)
                                    : 'none';
                                onChanged(_copyWith(
                                  step,
                                  title: title,
                                  description: description,
                                  params: params,
                                  runtime: runtime,
                                  mediaUsages: _copyMediaUsageAt(
                                    mediaUsages,
                                    mediaIndex,
                                    archiveEnabled: enabled,
                                    archiveMode: nextArchiveMode,
                                  ),
                                ));
                              },
                            ),
                            if (archiveEnabled) ...[
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: archiveModeItems.any(
                                  (item) => item.value == archiveMode,
                                )
                                    ? archiveMode
                                    : defaultArchiveModeForRuntimeMode(runtimeMode),
                                decoration: const InputDecoration(
                                  labelText: 'Comportement dans les archives',
                                  border: OutlineInputBorder(),
                                ),
                                items: archiveModeItems,
                                onChanged: (value) {
                                  final nextArchiveMode = value ??
                                      defaultArchiveModeForRuntimeMode(
                                        runtimeMode,
                                      );
                                  onChanged(_copyWith(
                                    step,
                                    title: title,
                                    description: description,
                                    params: params,
                                    runtime: runtime,
                                    mediaUsages: _copyMediaUsageAt(
                                      mediaUsages,
                                      mediaIndex,
                                      archiveEnabled: true,
                                      archiveMode: nextArchiveMode,
                                    ),
                                  ));
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _archiveModeDescription(archiveMode),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB8C1D1),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ];
                  }),
                ],
              ),
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
                      mediaUsages: mediaUsages,
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
                        mediaUsages: mediaUsages,
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
                        mediaUsages: mediaUsages,
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
                      mediaUsages: mediaUsages,
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
                      mediaUsages: mediaUsages,
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
                        mediaUsages: mediaUsages,
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
                    mediaUsages: mediaUsages,
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
                    mediaUsages: mediaUsages,
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
                    mediaUsages: mediaUsages,
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
    List<Map<String, dynamic>>? mediaUsages,
  }) {
    final originalId = (original['id'] ?? '').toString();
    final originalType = (original['type'] ?? 'popup').toString();
    final safeId = originalId.isEmpty ? buildStableStepId() : originalId;
    final nextParams = params ?? <String, dynamic>{};

    return <String, dynamic>{
      'id': safeId,
      'type': originalType,
      'title': title ?? (original['title'] ?? '').toString(),
      'description':
          description ?? (original['description'] ?? '').toString(),
      'blocking': true,
      'params': nextParams,
      'runtime': normalizeStepRuntime(runtime),
      'mediaUsages': mediaUsages ??
          normalizeMediaUsages(
            original['mediaUsages'],
            stepType: originalType,
            stepId: safeId,
            params: nextParams,
          ),
    };
  }

  List<Map<String, dynamic>> _copyMediaUsageAt(
    List<Map<String, dynamic>> mediaUsages,
    int index, {
    String? runtimeMode,
    bool? archiveEnabled,
    String? archiveMode,
  }) {
    final next = mediaUsages
        .map((usage) => Map<String, dynamic>.from(usage))
        .toList(growable: false);

    if (index < 0 || index >= next.length) {
      return next;
    }

    final current = Map<String, dynamic>.from(next[index]);
    final currentArchive = current['archive'] is Map
        ? Map<String, dynamic>.from(current['archive'] as Map)
        : <String, dynamic>{};

    final nextRuntimeMode = runtimeMode ?? (current['runtimeMode'] ?? '').toString();
    final nextArchiveEnabled = archiveEnabled ?? (currentArchive['enabled'] == true);
    final nextArchiveMode = nextArchiveEnabled
        ? (archiveMode ?? defaultArchiveModeForRuntimeMode(nextRuntimeMode))
        : 'none';

    current['runtimeMode'] = nextRuntimeMode;
    current['archive'] = <String, dynamic>{
      'enabled': nextArchiveEnabled,
      'mode': nextArchiveMode,
    };
    next[index] = current;
    return next;
  }

  List<DropdownMenuItem<String>> _runtimeModeItemsForStepType(String stepType) {
    switch (stepType) {
      case 'image':
        return const [
          DropdownMenuItem(
            value: 'standard_image',
            child: Text('Image standard'),
          ),
          DropdownMenuItem(
            value: 'dynamic_pan_zoom',
            child: Text('Fenêtre exploratoire'),
          ),
          DropdownMenuItem(
            value: 'masked_view',
            child: Text('Image cadrée / masquée'),
          ),
        ];
      case 'video':
        return const [
          DropdownMenuItem(
            value: 'standard_video',
            child: Text('Vidéo standard'),
          ),
        ];
      case 'audio':
      case 'call':
        return const [
          DropdownMenuItem(
            value: 'standard_audio',
            child: Text('Audio standard'),
          ),
        ];
      default:
        return allowedMediaRuntimeModes()
            .map(
              (mode) => DropdownMenuItem<String>(
                value: mode,
                child: Text(_displayRuntimeMode(mode)),
              ),
            )
            .toList();
    }
  }

  List<DropdownMenuItem<String>> _archiveModeItemsForRuntimeMode(
    String runtimeMode,
  ) {
    final values = <String>[
      'standard_media',
      'preserve_runtime',
    ];

    if (runtimeMode == 'standard_image' ||
        runtimeMode == 'dynamic_pan_zoom' ||
        runtimeMode == 'masked_view') {
      values.insert(1, 'zoomable_image');
    }

    return values
        .map(
          (mode) => DropdownMenuItem<String>(
            value: mode,
            child: Text(_displayArchiveMode(mode)),
          ),
        )
        .toList();
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

  static 
String _mediaExpectationLabelForStepType(String stepType) {
  switch (stepType) {
    case 'video':
      return 'Type attendu : vidéo';
    case 'audio':
    case 'call':
      return 'Type attendu : audio';
    case 'image':
      return 'Type attendu : image';
    default:
      return 'Média lié automatiquement';
  }
}

IconData _mediaKindIconForStepType(String stepType) {
  switch (stepType) {
    case 'video':
      return Icons.videocam_outlined;
    case 'audio':
    case 'call':
      return Icons.graphic_eq_outlined;
    case 'image':
      return Icons.image_outlined;
    default:
      return Icons.perm_media_outlined;
  }
}

String _displayMediaRole(String role) {
    switch (role) {
      case 'primary':
        return 'Média principal';
      case 'secondary':
        return 'Média secondaire';
      case 'clue':
        return 'Indice';
      default:
        return role;
    }
  }

  static String _displayRuntimeMode(String mode) {
    switch (mode) {
      case 'standard_image':
        return 'Image standard';
      case 'standard_video':
        return 'Vidéo standard';
      case 'standard_audio':
        return 'Audio standard';
      case 'dynamic_pan_zoom':
        return 'Fenêtre exploratoire';
      case 'masked_view':
        return 'Image cadrée / masquée';
      default:
        return mode;
    }
  }

  static String _displayArchiveMode(String mode) {
    switch (mode) {
      case 'standard_media':
        return 'Version standard';
      case 'zoomable_image':
        return 'Image zoomable';
      case 'preserve_runtime':
        return 'Conserver le rendu du poste';
      case 'none':
        return 'Non archivé';
      default:
        return mode;
    }
  }

  static String _runtimeModeDescription(String mode) {
    switch (mode) {
      case 'standard_image':
        return 'Le document est affiché normalement, en une seule vue.';
      case 'standard_video':
        return 'La vidéo est lue comme un média classique, sans comportement visuel spécifique.';
      case 'standard_audio':
        return 'L’audio est joué de manière standard pour cette étape.';
      case 'dynamic_pan_zoom':
        return 'Le joueur explore une grande image à travers une fenêtre mobile, sans voir tout le document d’un coup.';
      case 'masked_view':
        return 'Le média peut être cadré, flouté ou partiellement masqué pour ne révéler qu’une partie de l’indice.';
      default:
        return '';
    }
  }

  static String _archiveModeDescription(String mode) {
    switch (mode) {
      case 'standard_media':
        return 'Les archives montrent une version simple du média, sans rejouer le comportement visuel spécifique du poste.';
      case 'zoomable_image':
        return 'Les archives gardent une image consultable avec zoom, sans imposer la logique exploratoire du poste.';
      case 'preserve_runtime':
        return 'Les archives conservent le rendu narratif du poste pour éviter de révéler plus que ce qui a réellement été acquis.';
      case 'none':
        return 'Le média n’est pas recopié dans les archives.';
      default:
        return '';
    }
  }
}