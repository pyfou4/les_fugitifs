import 'package:flutter/material.dart';

import 'creator_place_sequence_step_card.dart';
import 'utils/place_sequence_factories.dart';

class CreatorPlaceSequenceEditorSection extends StatelessWidget {
  final List<Map<String, dynamic>> sequence;
  final String placeKind;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const CreatorPlaceSequenceEditorSection({
    super.key,
    required this.sequence,
    required this.placeKind,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasItems = sequence.isNotEmpty;
    final normalizedPlaceKind = placeKind.trim().toLowerCase();
    final allowedStepTypes = allowedSequenceStepTypesForPlaceKind(normalizedPlaceKind);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Séquence du poste',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Décris dans l’ordre ce que vivent les joueurs, et précise si certaines étapes démarrent en parallèle, avec délai, ou bloquent la fermeture d’une autre étape.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            if (!hasItems)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aucune étape définie pour ce poste.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Commence par ajouter la première étape de l’expérience.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        final next = List<Map<String, dynamic>>.from(sequence)
                          ..add(buildDefaultSequenceStepForPlaceKind(normalizedPlaceKind));
                        onChanged(next);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter la première étape'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: List.generate(sequence.length, (index) {
                  final step = sequence[index];
                  return CreatorPlaceSequenceStepCard(
                    key: ValueKey((step['id'] ?? 'step_$index').toString()),
                    step: step,
                    index: index,
                    availableSteps: sequence,
                    allowedStepTypes: allowedStepTypes,
                    onChanged: (updatedStep) {
                      final next = List<Map<String, dynamic>>.from(sequence);
                      next[index] = updatedStep;
                      onChanged(next);
                    },
                    onDelete: () {
                      final next = List<Map<String, dynamic>>.from(sequence);
                      next.removeAt(index);
                      onChanged(next);
                    },
                    onMoveUp: index > 0
                        ? () {
                            final next = List<Map<String, dynamic>>.from(sequence);
                            final current = next[index];
                            next[index] = next[index - 1];
                            next[index - 1] = current;
                            onChanged(next);
                          }
                        : null,
                    onMoveDown: index < sequence.length - 1
                        ? () {
                            final next = List<Map<String, dynamic>>.from(sequence);
                            final current = next[index];
                            next[index] = next[index + 1];
                            next[index + 1] = current;
                            onChanged(next);
                          }
                        : null,
                  );
                }),
              ),
            const SizedBox(height: 16),
            if (hasItems)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () {
                    final next = List<Map<String, dynamic>>.from(sequence)
                      ..add(buildDefaultSequenceStepForPlaceKind(normalizedPlaceKind));
                    onChanged(next);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une étape'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
