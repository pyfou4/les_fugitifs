import 'package:flutter/material.dart';

import '../../widgets/stat_card.dart';

class AdminStatsSection extends StatelessWidget {
  final int total;
  final int unused;
  final int reserved;
  final int emittedTotal;
  final bool lowStock;

  const AdminStatsSection({
    super.key,
    required this.total,
    required this.unused,
    required this.reserved,
    required this.emittedTotal,
    required this.lowStock,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 950;

        final realCards = [
          StatCard(
            label: 'Pool total',
            value: total,
            backgroundColor: const Color(0xFF182133),
            valueColor: const Color(0xFF8AB4FF),
          ),
          StatCard(
            label: 'Disponibles',
            value: unused,
            backgroundColor:
                lowStock ? const Color(0xFF342416) : const Color(0xFF16281D),
            valueColor:
                lowStock ? const Color(0xFFFFB24A) : const Color(0xFF59D98E),
          ),
          StatCard(
            label: 'Réservés',
            value: reserved,
            backgroundColor: const Color(0xFF241A33),
            valueColor: const Color(0xFFC59BFF),
          ),
          StatCard(
            label: 'Émis',
            value: emittedTotal,
            backgroundColor: const Color(0xFF1B1F28),
            valueColor: const Color(0xFFE5E7EB),
          ),
        ];

        if (compact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: realCards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: realCards[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: realCards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: realCards[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: realCards[0]),
            const SizedBox(width: 12),
            Expanded(child: realCards[1]),
            const SizedBox(width: 12),
            Expanded(child: realCards[2]),
            const SizedBox(width: 12),
            Expanded(child: realCards[3]),
          ],
        );
      },
    );
  }
}
