import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'creator_entity_card.dart';
import 'creator_entity_section_header.dart';

class CreatorMotivesSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> motiveDocs;
  final int gridCount;
  final double cardHeight;
  final VoidCallback onAdd;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
      onEdit;
  final Future<void> Function(String label, String id) onDelete;

  const CreatorMotivesSection({
    super.key,
    required this.motiveDocs,
    required this.gridCount,
    required this.cardHeight,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CreatorEntitySectionHeader(
          title: 'Mobiles',
          subtitle:
              '6 mobiles requis. Violence, délais et préparatifs doivent rester uniques. Chaque fiche doit aussi avoir son PNG.',
          countLabel: '${motiveDocs.length}/6',
          onAdd: onAdd,
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: motiveDocs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) {
            final doc = motiveDocs[index];
            final data = doc.data();
            final imagePath =
                (data['imagePath'] ?? data['image'] ?? '').toString().trim();
            final headline =
                'Violence: ${(data['violence'] ?? '—').toString()} • Délais: ${(data['delays'] ?? '—').toString()}';
            final secondary = imagePath.isEmpty
                ? 'Préparatifs: ${(data['preparations'] ?? '—').toString()} • PNG manquant'
                : 'Préparatifs: ${(data['preparations'] ?? '—').toString()} • ${imagePath.split('/').last}';
            return CreatorEntityCard(
              accentColor: const Color(0xFFFFB24A),
              title: (data['name'] ?? doc.id).toString(),
              badge: doc.id,
              headline: headline,
              secondary: secondary,
              imagePath: imagePath,
              onEdit: () => onEdit(doc),
              onDelete: () => onDelete((data['name'] ?? doc.id).toString(), doc.id),
            );
          },
        ),
      ],
    );
  }
}
