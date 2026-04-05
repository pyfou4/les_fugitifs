import 'package:flutter/material.dart';

class AdminLowStockAlertSection extends StatelessWidget {
  const AdminLowStockAlertSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2117),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF5D3B1B),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFFB24A),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Stock faible : moins de 50 codes disponibles dans le pool global.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFD7B8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
