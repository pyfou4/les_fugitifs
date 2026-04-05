import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'creator_big_info_chip.dart';

class CreatorPlacesListSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String? selectedId;
  final Color Function(String id) groupColorBuilder;
  final String Function(Map<String, dynamic> data) experienceTypeBuilder;
  final String Function(String type) experienceLabelBuilder;
  final String Function(String id, Map<String, dynamic> data)
      displayNameBuilder;
  final List<String> Function(Map<String, dynamic> data)
      revealedCategoriesReader;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
      onSelectDoc;

  const CreatorPlacesListSection({
    super.key,
    required this.docs,
    required this.selectedId,
    required this.groupColorBuilder,
    required this.experienceTypeBuilder,
    required this.experienceLabelBuilder,
    required this.displayNameBuilder,
    required this.revealedCategoriesReader,
    required this.onSelectDoc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF07111F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Lieux du scénario',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final type = experienceTypeBuilder(data);
                final selected = selectedId == doc.id;
                final color = groupColorBuilder(doc.id);
                final revealed = revealedCategoriesReader(data);

                return InkWell(
                  onTap: () => onSelectDoc(doc),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF122139)
                          : const Color(0xFF0D192C),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? color : const Color(0xFF1E2D45),
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayNameBuilder(doc.id, data),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            CreatorBigInfoChip(
                              label: experienceLabelBuilder(type),
                              color: color,
                            ),
                            if (revealed.isNotEmpty)
                              ...revealed.map(
                                (info) => CreatorBigInfoChip(
                                  label: info,
                                  color: const Color(0xFFFFB24A),
                                ),
                              )
                            else
                              const CreatorBigInfoChip(
                                label: 'none',
                                color: Color(0xFFFFB24A),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ((data['storySynopsis'] ?? data['synopsis'] ?? '')
                                      .toString()
                                      .trim())
                                  .isEmpty
                              ? 'Aucun synopsis défini.'
                              : (data['storySynopsis'] ?? data['synopsis'])
                                  .toString()
                                  .trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.25,
                            color: Color(0xFFAAB7C8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
