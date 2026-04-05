import 'package:flutter/material.dart';

class CreatorIntegrityBannerSection extends StatelessWidget {
  final List<String> suspectIssues;
  final List<String> motiveIssues;

  const CreatorIntegrityBannerSection({
    super.key,
    required this.suspectIssues,
    required this.motiveIssues,
  });

  @override
  Widget build(BuildContext context) {
    if (suspectIssues.isEmpty && motiveIssues.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2117),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF5D3B1B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Points à corriger',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFD7B8),
            ),
          ),
          const SizedBox(height: 10),
          ...[...suspectIssues, ...motiveIssues].map(
            (issue) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '• $issue',
                style: const TextStyle(
                  color: Color(0xFFFFD7B8),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
