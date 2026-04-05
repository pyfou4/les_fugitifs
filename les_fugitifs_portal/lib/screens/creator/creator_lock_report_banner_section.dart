import 'package:flutter/material.dart';

import '../../features/scenario_lock/scenario_lock_models.dart';

class CreatorLockReportBannerSection extends StatelessWidget {
  final List<ScenarioValidationIssue> issues;
  final String? lockedScenarioId;

  const CreatorLockReportBannerSection({
    super.key,
    required this.issues,
    this.lockedScenarioId,
  });

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty && lockedScenarioId == null) {
      return const SizedBox.shrink();
    }

    final errors = issues.where((issue) => issue.isError).toList();
    final warnings = issues.where((issue) => issue.isWarning).toList();

    final hasErrors = errors.isNotEmpty;
    final hasWarnings = warnings.isNotEmpty;
    final isSuccessOnly = !hasErrors && !hasWarnings && lockedScenarioId != null;

    final backgroundColor = isSuccessOnly
        ? const Color(0xFF13261C)
        : hasErrors
        ? const Color(0xFF2D1717)
        : const Color(0xFF2A2214);

    final borderColor = isSuccessOnly
        ? const Color(0xFF2D7D46)
        : hasErrors
        ? const Color(0xFF7A2C2C)
        : const Color(0xFF7A5A1A);

    final title = isSuccessOnly
        ? 'Scénario verrouillé'
        : hasErrors
        ? 'Le lock a été refusé'
        : 'Lock effectué avec avertissements';

    final titleColor = isSuccessOnly
        ? const Color(0xFFB8F5C8)
        : hasErrors
        ? const Color(0xFFFFC5C5)
        : const Color(0xFFFFE2B8);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: titleColor,
            ),
          ),
          if (lockedScenarioId != null) ...[
            const SizedBox(height: 10),
            Text(
              'ID du lockedScenario: $lockedScenarioId',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (hasErrors) ...[
            const SizedBox(height: 14),
            const Text(
              'Erreurs bloquantes',
              style: TextStyle(
                color: Color(0xFFFFD3D3),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...errors.map(
                  (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• ${issue.message}',
                  style: const TextStyle(
                    color: Color(0xFFFFD3D3),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
          if (hasWarnings) ...[
            const SizedBox(height: 14),
            const Text(
              'Avertissements',
              style: TextStyle(
                color: Color(0xFFFFE2B8),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...warnings.map(
                  (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• ${issue.message}',
                  style: const TextStyle(
                    color: Color(0xFFFFE2B8),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}