import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'creator_entity_card.dart';
import 'creator_entity_section_header.dart';

class CreatorSuspectsSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> suspectDocs;
  final int gridCount;
  final double cardHeight;
  final VoidCallback onAdd;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
      onEdit;
  final Future<void> Function(String label, String id) onDelete;

  const CreatorSuspectsSection({
    super.key,
    required this.suspectDocs,
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
          title: 'Suspects',
          subtitle:
              '6 suspects requis. Un âge, une profession et un build uniques par suspect. Chaque fiche doit aussi avoir son PNG.',
          countLabel: '${suspectDocs.length}/6',
          onAdd: onAdd,
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: suspectDocs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) {
            final doc = suspectDocs[index];
            final data = doc.data();
            final imagePath =
                (data['imagePath'] ?? data['image'] ?? '').toString().trim();
            final headline =
                '${data['age'] ?? '—'} ans • ${(data['profession'] ?? '—').toString()} • ${(data['build'] ?? '—').toString()}';
            return CreatorEntityCard(
              accentColor: const Color(0xFF4E8DFF),
              title: (data['name'] ?? doc.id).toString(),
              badge: doc.id,
              headline: headline,
              secondary: imagePath.isEmpty
                  ? 'PNG manquant pour le runtime'
                  : imagePath,
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
