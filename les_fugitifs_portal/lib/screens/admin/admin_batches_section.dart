import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/mini_info_chip.dart';

class AdminBatchesSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> batchDocs;
  final int Function(dynamic value) readInt;
  final String Function(Map<String, dynamic> data) readPoolLabel;
  final String Function(Map<String, dynamic> data) readPoolType;

  const AdminBatchesSection({
    super.key,
    required this.batchDocs,
    required this.readInt,
    required this.readPoolLabel,
    required this.readPoolType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Batches',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...batchDocs.map((doc) {
          final data = doc.data();

          final label = readPoolLabel(data);
          final poolType = readPoolType(data);
          final t = readInt(data['countTotal'] ?? data['count']);
          final u = readInt(data['countUnused'] ?? t);
          final r = readInt(data['countReserved']);
          final us = readInt(data['countUsed']);
          final status = (data['status'] ?? '—').toString();

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              color: const Color(0xFF131A24),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        MiniInfoChip(
                          label: 'Type',
                          value: poolType == 'legacy' ? 'Legacy' : 'Global',
                        ),
                        MiniInfoChip(
                          label: 'Total',
                          value: '$t',
                        ),
                        MiniInfoChip(
                          label: 'Disponibles',
                          value: '$u',
                        ),
                        MiniInfoChip(
                          label: 'Réservés',
                          value: '$r',
                        ),
                        MiniInfoChip(
                          label: 'Utilisés',
                          value: '$us',
                        ),
                        MiniInfoChip(
                          label: 'Status',
                          value: status,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
