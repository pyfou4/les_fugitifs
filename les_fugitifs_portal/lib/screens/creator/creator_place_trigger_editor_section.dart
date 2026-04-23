import 'package:flutter/material.dart';

class CreatorPlaceTriggerEditorSection extends StatelessWidget {
  final Map<String, dynamic> trigger;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const CreatorPlaceTriggerEditorSection({
    super.key,
    required this.trigger,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final triggerType =
        _sanitizeTriggerType((trigger['type'] ?? 'manual_start').toString());
    final delayMs = _readInt(trigger['delayMs'], fallback: 0);
    final delaySeconds = (delayMs / 1000).round();

    final params = (trigger['params'] is Map)
        ? Map<String, dynamic>.from(trigger['params'] as Map)
        : <String, dynamic>{};

    final startLabel = (params['startLabel'] ?? 'Commencer').toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Déclenchement du poste',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _helpTextForTriggerType(triggerType),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: triggerType,
              decoration: const InputDecoration(
                labelText: 'Mode de déclenchement',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'auto_on_enter',
                  child: Text('Automatique à l’arrivée sur le lieu'),
                ),
                DropdownMenuItem(
                  value: 'manual_start',
                  child: Text('Déclenché par action du groupe'),
                ),
                DropdownMenuItem(
                  value: 'delayed_auto',
                  child: Text('Automatique après délai à l’arrivée'),
                ),
              ],
              onChanged: (value) {
                final nextType = _sanitizeTriggerType(value);
                onChanged(
                  _buildTriggerForType(
                    nextType,
                    delayMs: delayMs,
                    startLabel: startLabel,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            if (triggerType == 'manual_start')
              TextFormField(
                initialValue: startLabel,
                decoration: const InputDecoration(
                  labelText: 'Libellé du bouton de lancement',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  onChanged(
                    _buildTriggerForType(
                      triggerType,
                      delayMs: delayMs,
                      startLabel: value,
                    ),
                  );
                },
              ),
            if (triggerType == 'delayed_auto')
              TextFormField(
                key: const ValueKey('trigger_delay_field_seconds'),
                initialValue: delaySeconds.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Délai après arrivée sur le lieu (secondes)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  onChanged(
                    _buildTriggerForType(
                      triggerType,
                      delayMs: _readInt(value, fallback: 0) * 1000,
                      startLabel: startLabel,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _buildTriggerForType(
    String type, {
    required int delayMs,
    required String startLabel,
  }) {
    switch (type) {
      case 'auto_on_enter':
        return <String, dynamic>{
          'type': 'auto_on_enter',
          'delayMs': 0,
          'retryPolicy': 'none',
          'params': <String, dynamic>{},
        };
      case 'manual_start':
        return <String, dynamic>{
          'type': 'manual_start',
          'delayMs': 0,
          'retryPolicy': 'none',
          'params': <String, dynamic>{
            'startLabel':
                startLabel.trim().isEmpty ? 'Commencer' : startLabel.trim(),
          },
        };
      case 'delayed_auto':
        return <String, dynamic>{
          'type': 'delayed_auto',
          'delayMs': delayMs < 0 ? 0 : delayMs,
          'retryPolicy': 'none',
          'params': <String, dynamic>{},
        };
      default:
        return <String, dynamic>{
          'type': 'manual_start',
          'delayMs': 0,
          'retryPolicy': 'none',
          'params': <String, dynamic>{
            'startLabel': 'Commencer',
          },
        };
    }
  }

  String _sanitizeTriggerType(String? raw) {
    switch (raw) {
      case 'auto_on_enter':
      case 'manual_start':
      case 'delayed_auto':
        return raw!;
      default:
        return 'manual_start';
    }
  }

  String _helpTextForTriggerType(String type) {
    switch (type) {
      case 'auto_on_enter':
        return 'Le poste démarre dès que l’équipe est géolocalisée sur le lieu.';
      case 'manual_start':
        return 'Le poste démarre quand les joueurs le lancent volontairement depuis l’interface de jeu.';
      case 'delayed_auto':
        return 'Le poste démarre automatiquement après un délai une fois l’équipe arrivée sur le lieu.';
      default:
        return 'Définit comment le poste commence.';
    }
  }

  int _readInt(dynamic raw, {required int fallback}) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }
}
