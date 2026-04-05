import 'package:flutter/material.dart';

class AdminActionsSection extends StatelessWidget {
  final bool isGenerating;
  final VoidCallback? onGenerateBatch;
  final VoidCallback onReturnToCashier;

  const AdminActionsSection({
    super.key,
    required this.isGenerating,
    required this.onGenerateBatch,
    required this.onReturnToCashier,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FilledButton.icon(
          onPressed: onGenerateBatch,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD65A00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add),
          label: Text(
            isGenerating ? 'Génération...' : 'Générer 1000 codes',
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onReturnToCashier,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFFD7B8),
            side: const BorderSide(color: Color(0xFF4A2B1D)),
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.point_of_sale),
          label: const Text('Retour caisse'),
        ),
      ],
    );
  }
}
