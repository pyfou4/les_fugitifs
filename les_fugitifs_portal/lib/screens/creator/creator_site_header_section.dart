import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../features/site_readiness/site_readiness_models.dart';

class CreatorSiteHeaderSection extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> selectedSiteDoc;
  final String selectedSiteLabel;
  final int currentCount;
  final int templateCount;
  final bool isFrozen;
  final SiteReadinessResult? readinessResult;
  final bool isValidatingReadiness;
  final Future<void> Function()? onValidateReadiness;
  final Future<void> Function()? onFreeze;
  final Future<void> Function()? onUnfreeze;

  const CreatorSiteHeaderSection({
    super.key,
    required this.selectedSiteDoc,
    required this.selectedSiteLabel,
    required this.currentCount,
    required this.templateCount,
    required this.isFrozen,
    required this.readinessResult,
    required this.isValidatingReadiness,
    required this.onValidateReadiness,
    required this.onFreeze,
    required this.onUnfreeze,
  });

  @override
  Widget build(BuildContext context) {
    final result = readinessResult;
    final isReady = result?.isReady == true;
    final errorsCount = result?.errors.length ?? 0;
    final warningsCount = result?.warnings.length ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101C31),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF223250)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Site actif : $selectedSiteLabel',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                'ID: ${selectedSiteDoc.id}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFAAB7C8),
                ),
              ),
              Text(
                '$currentCount/$templateCount fiches places présentes',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFAED0FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isFrozen
                      ? const Color(0xFF342416)
                      : const Color(0xFF16281D),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isFrozen
                        ? const Color(0xFF7A4A24)
                        : const Color(0xFF2F7A4E),
                  ),
                ),
                child: Text(
                  isFrozen ? 'Coordonnées gelées' : 'Site modifiable',
                  style: TextStyle(
                    color: isFrozen
                        ? const Color(0xFFFFD7B8)
                        : const Color(0xFF9EF0B5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: isValidatingReadiness || onValidateReadiness == null
                    ? null
                    : () => onValidateReadiness!.call(),
                style: FilledButton.styleFrom(
                  backgroundColor: isReady
                      ? const Color(0xFF1F6B43)
                      : const Color(0xFF294C74),
                  foregroundColor: Colors.white,
                ),
                icon: isValidatingReadiness
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isReady ? Icons.verified_outlined : Icons.fact_check_outlined),
                label: Text(
                  isValidatingReadiness ? 'Validation...' : 'Valider le site',
                ),
              ),
              FilledButton.icon(
                onPressed: onFreeze == null ? null : () => onFreeze!.call(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF294C74),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.ac_unit),
                label: const Text('Freeze'),
              ),
              OutlinedButton.icon(
                onPressed: onUnfreeze == null ? null : () => onUnfreeze!.call(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFAED0FF),
                  side: const BorderSide(color: Color(0xFF294C74)),
                ),
                icon: const Icon(Icons.lock_open),
                label: const Text('Défreeze'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ReadinessSummary(
            result: result,
            errorsCount: errorsCount,
            warningsCount: warningsCount,
          ),
        ],
      ),
    );
  }
}

class _ReadinessSummary extends StatelessWidget {
  final SiteReadinessResult? result;
  final int errorsCount;
  final int warningsCount;

  const _ReadinessSummary({
    required this.result,
    required this.errorsCount,
    required this.warningsCount,
  });

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D192C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF223250)),
        ),
        child: const Text(
          'Aucune validation du site n’a encore été lancée.',
          style: TextStyle(
            color: Color(0xFFAAB7C8),
            height: 1.4,
          ),
        ),
      );
    }

    final color = result!.isReady
        ? const Color(0xFF9EF0B5)
        : const Color(0xFFFFD7B8);
    final borderColor = result!.isReady
        ? const Color(0xFF2F7A4E)
        : const Color(0xFF7A4A24);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D192C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result!.isReady ? 'Site prêt à jouer' : 'Site non prêt',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$errorsCount erreur(s) bloquante(s) • $warningsCount warning(s)',
            style: const TextStyle(
              color: Color(0xFFAED0FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (result!.issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...result!.issues.take(8).map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${issue.message}',
                      style: TextStyle(
                        color: issue.severity == SiteReadinessSeverity.error
                            ? const Color(0xFFFFD7B8)
                            : const Color(0xFFAED0FF),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
            if (result!.issues.length > 8)
              Text(
                '… ${result!.issues.length - 8} autre(s) point(s) masqué(s).',
                style: const TextStyle(
                  color: Color(0xFFAAB7C8),
                  fontSize: 12,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
