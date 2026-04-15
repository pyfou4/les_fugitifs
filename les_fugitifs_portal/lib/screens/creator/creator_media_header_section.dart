import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreatorMediaHeaderSection extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> selectedScenarioDoc;
  final String selectedScenarioLabel;
  final int currentCount;
  final int requiredCount;
  final int totalCount;
  final bool isFrozen;
  final bool canUnfreeze;
  final Future<void> Function()? onFreeze;
  final Future<void> Function()? onUnfreeze;

  const CreatorMediaHeaderSection({
    super.key,
    required this.selectedScenarioDoc,
    required this.selectedScenarioLabel,
    required this.currentCount,
    required this.requiredCount,
    required this.totalCount,
    required this.isFrozen,
    required this.canUnfreeze,
    required this.onFreeze,
    required this.onUnfreeze,
  });

  @override
  Widget build(BuildContext context) {
    final missingRequiredCount =
        (requiredCount - currentCount).clamp(0, requiredCount);
    final isComplete = missingRequiredCount == 0 && requiredCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101C31),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223250)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                selectedScenarioLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                selectedScenarioDoc.id,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFAAB7C8),
                ),
              ),
              _Badge(
                text: '$currentCount/$requiredCount requis',
                textColor: isComplete
                    ? const Color(0xFF9EF0B5)
                    : const Color(0xFFAED0FF),
                borderColor: isComplete
                    ? const Color(0xFF2F7A4E)
                    : const Color(0xFF294C74),
                backgroundColor: isComplete
                    ? const Color(0xFF16281D)
                    : const Color(0xFF13233B),
              ),
              _Badge(
                text: '$totalCount ${totalCount > 1 ? "slots" : "slot"}',
                textColor: const Color(0xFFAAB7C8),
                borderColor: const Color(0xFF223250),
                backgroundColor: const Color(0xFF0D192C),
              ),
              _Badge(
                text: isFrozen ? 'Figé' : 'Modifiable',
                textColor: isFrozen
                    ? const Color(0xFFFFD7B8)
                    : const Color(0xFF9EF0B5),
                borderColor: isFrozen
                    ? const Color(0xFF7A4A24)
                    : const Color(0xFF2F7A4E),
                backgroundColor: isFrozen
                    ? const Color(0xFF342416)
                    : const Color(0xFF16281D),
              ),
              FilledButton.icon(
                onPressed: onFreeze == null ? null : () => onFreeze!.call(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF294C74),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.ac_unit, size: 16),
                label: const Text('Freeze'),
              ),
              if (canUnfreeze)
                OutlinedButton.icon(
                  onPressed: onUnfreeze == null ? null : () => onUnfreeze!.call(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFAED0FF),
                    side: const BorderSide(color: Color(0xFF294C74)),
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text('Défreeze'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isComplete
                ? 'Tous les médias requis sont présents.'
                : '$missingRequiredCount média(s) requis manquant(s) • ${totalCount - currentCount} slot(s) sans média.',
            style: TextStyle(
              color: isComplete
                  ? const Color(0xFF9EF0B5)
                  : const Color(0xFFAED0FF),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color borderColor;
  final Color backgroundColor;

  const _Badge({
    required this.text,
    required this.textColor,
    required this.borderColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
