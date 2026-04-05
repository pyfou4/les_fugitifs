import 'package:flutter/material.dart';

class AdminSitesBreakdownSection extends StatelessWidget {
  final List<MapEntry<String, int>> issuedSiteEntries;
  final Map<String, String> siteNames;

  const AdminSitesBreakdownSection({
    super.key,
    required this.issuedSiteEntries,
    required this.siteNames,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF131A24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Codes émis par site',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nombre de codes sortis du pool global par site de vente, sur les filtres choisis.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF9AA7BC),
              ),
            ),
            const SizedBox(height: 16),
            if (issuedSiteEntries.isEmpty)
              const Text(
                'Aucun code émis pour ces filtres.',
                style: TextStyle(
                  color: Color(0xFF9AA7BC),
                ),
              )
            else
              Column(
                children: issuedSiteEntries.map((entry) {
                  final siteId = entry.key;
                  final count = entry.value;
                  final siteTitle = siteNames[siteId] ?? siteId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171E2A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF2A3443),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                siteTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                siteId,
                                style: const TextStyle(
                                  color: Color(0xFF9AA7BC),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF221A15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF4A2B1D),
                            ),
                          ),
                          child: Text(
                            '$count émis',
                            style: const TextStyle(
                              color: Color(0xFFFFD7B8),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
