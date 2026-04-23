import 'package:flutter/material.dart';

class CreatorPlaceLockedStructureSection extends StatelessWidget {
  final String? placeType;
  final String? targetType;
  final String? targetSlot;
  final List<dynamic>? targets;
  final String? phase;
  final int? phaseIndex;

  const CreatorPlaceLockedStructureSection({
    super.key,
    required this.placeType,
    required this.targetType,
    required this.targetSlot,
    required this.targets,
    required this.phase,
    required this.phaseIndex,
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
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 18),
                SizedBox(width: 8),
                Text(
                  'Structure verrouillée du poste',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Définie par le game design. Les informations affichées ici sont en lecture seule.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _infoBox(
                  label: 'Type de poste',
                  value: _displayPlaceType(placeType),
                ),
                _infoBox(
                  label: 'Révélation prévue',
                  value: _displayRevealType(targetType),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox({
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF4A3A30)),
          color: const Color(0xFF2A262A),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFD0C5B8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayPlaceType(String? type) {
    switch (type) {
      case 'media':
        return 'Média';
      case 'observation':
        return 'Observation';
      case 'physical':
        return 'Physique';
      default:
        return 'Non défini';
    }
  }

  String _displayRevealType(String? type) {
    switch (type) {
      case 'suspect':
        return 'Suspect';
      case 'motive':
        return 'Mobile';
      case 'both':
        return 'Suspect + mobile';
      case 'none':
      case null:
        return 'Aucune';
      default:
        return 'Aucune';
    }
  }
}
