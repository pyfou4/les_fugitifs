import 'package:flutter/material.dart';

class CreatorPlaceMediaRequirementsPreviewSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const CreatorPlaceMediaRequirementsPreviewSection({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Synthèse média automatique',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Déduite de la séquence du poste',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),

            /// CAS : aucun média
            if (items.isEmpty)
              const Text('Aucun média requis pour ce poste.'),

            /// CAS : liste des médias
            if (items.isNotEmpty)
              Column(
                children: items.map((item) {
                  final title = item['title'] ?? 'Étape';
                  final type = _displayStepType(item['stepType']);
                  final format =
                  _displayRequiredFormat(item['requiredFormat']);

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.play_circle_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Type : $type',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                format,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _displayStepType(dynamic type) {
    switch (type) {
      case 'call':
        return 'Appel';
      case 'video':
        return 'Vidéo';
      case 'audio':
        return 'Audio';
      case 'image':
        return 'Image';
      case 'popup':
        return 'Popup';
      case 'observation':
        return 'Observation';
      default:
        return 'Inconnu';
    }
  }

  String _displayRequiredFormat(dynamic format) {
    switch (format) {
      case 'audio':
        return 'Audio requis';
      case 'video':
        return 'Vidéo requise';
      case 'image':
        return 'Image requise';
      default:
        return '';
    }
  }
}