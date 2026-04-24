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

  Future<void> _toggleCompletionStatus(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final currentStatus = (data['completionStatus'] ?? 'in_progress')
        .toString()
        .trim()
        .toLowerCase();
    final nextStatus = currentStatus == 'done' ? 'in_progress' : 'done';

    try {
      await doc.reference.update({
        'completionStatus': nextStatus,
        'completionStatusUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de modifier le statut du poste : $error',
          ),
          backgroundColor: const Color(0xFF8A2D2D),
        ),
      );
    }
  }

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
                final completionStatus = (data['completionStatus'] ??
                        'in_progress')
                    .toString()
                    .trim()
                    .toLowerCase();
                final isDone = completionStatus == 'done';

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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                displayNameBuilder(doc.id, data),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _CompletionStatusSwitch(
                              isDone: isDone,
                              onTap: () => _toggleCompletionStatus(
                                context,
                                doc,
                              ),
                            ),
                          ],
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

class _CompletionStatusSwitch extends StatelessWidget {
  final bool isDone;
  final VoidCallback onTap;

  const _CompletionStatusSwitch({
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDone
        ? const Color(0xFF41D483)
        : const Color(0xFFFFB24A);
    final activeLabel = isDone ? 'En cours' : 'Terminé';

    return Semantics(
      button: true,
      label: 'Statut éditorial du poste : $activeLabel',
      child: Tooltip(
        message: 'Changer le statut éditorial du poste',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 104,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF07111F),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: activeColor.withOpacity(0.85),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: activeColor.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 9),
                    child: Text(
                      'Terminé',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: isDone
                            ? const Color(0xFF607087)
                            : const Color(0xFF07111F),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 9),
                    child: Text(
                      'En cours',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: isDone
                            ? const Color(0xFF07111F)
                            : const Color(0xFF607087),
                      ),
                    ),
                  ),
                ),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment:
                      isDone ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 50,
                    height: 24,
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
