import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminCashierSiteSection extends StatelessWidget {
  final String? defaultSiteId;
  final bool siteLocked;
  final AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> siteSnapshot;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> siteDocs;
  final Future<void> Function(String siteId, String siteTitle) onSetDefaultSite;
  final Future<void> Function() onClearDefaultSite;
  final Future<void> Function(bool value) onSetSiteLocked;

  const AdminCashierSiteSection({
    super.key,
    required this.defaultSiteId,
    required this.siteLocked,
    required this.siteSnapshot,
    required this.siteDocs,
    required this.onSetDefaultSite,
    required this.onClearDefaultSite,
    required this.onSetSiteLocked,
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
              'Site par défaut du poste caissier',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              defaultSiteId == null
                  ? 'Aucun site par défaut n’est enregistré pour ce navigateur.'
                  : 'Site par défaut actuel pour ce navigateur : $defaultSiteId',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF9AA7BC),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              siteLocked
                  ? 'Le site est actuellement verrouillé sur ce poste.'
                  : 'Le site reste modifiable côté caisse.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF7D8A9E),
              ),
            ),
            const SizedBox(height: 18),
            Builder(
              builder: (context) {
                if (siteSnapshot.connectionState == ConnectionState.waiting &&
                    !siteSnapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  );
                }

                final defaultExists = defaultSiteId == null
                    ? true
                    : siteDocs.any((doc) => doc.id == defaultSiteId);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!defaultExists && defaultSiteId != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF221A15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF4B3421),
                          ),
                        ),
                        child: Text(
                          'Le site par défaut enregistré ($defaultSiteId) n’apparaît plus dans la liste des sites actifs. Il reste mémorisé tant que tu ne l’effaces pas manuellement.',
                          style: const TextStyle(
                            color: Color(0xFFCCB49B),
                            height: 1.4,
                          ),
                        ),
                      ),
                    if (siteDocs.isEmpty)
                      const Text(
                        'Aucun site actif disponible.',
                        style: TextStyle(
                          color: Color(0xFF9AA7BC),
                        ),
                      )
                    else
                      Column(
                        children: [
                          ...siteDocs.map((doc) {
                            final data = doc.data();
                            final siteId = doc.id;
                            final siteTitle = (data['title'] ?? siteId).toString();
                            final isCurrentDefault = defaultSiteId == siteId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isCurrentDefault
                                    ? const Color(0xFF1B2A1F)
                                    : const Color(0xFF171E2A),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isCurrentDefault
                                      ? const Color(0xFF2F7A4E)
                                      : const Color(0xFF2A3443),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                  if (isCurrentDefault)
                                    Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF23452E),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Par défaut',
                                        style: TextStyle(
                                          color: Color(0xFF9EF0B5),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  FilledButton(
                                    onPressed: isCurrentDefault
                                        ? null
                                        : () => onSetDefaultSite(
                                              siteId,
                                              siteTitle,
                                            ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFD65A00),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(
                                      isCurrentDefault ? 'Déjà actif' : 'Définir',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed:
                            defaultSiteId == null ? null : () => onClearDefaultSite(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFD7B8),
                          side: const BorderSide(
                            color: Color(0xFF4A2B1D),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Effacer le site par défaut'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF171E2A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF2A3443),
                        ),
                      ),
                      child: SwitchListTile(
                        value: siteLocked,
                        onChanged: defaultSiteId == null
                            ? null
                            : (value) => onSetSiteLocked(value),
                        title: const Text(
                          'Verrouiller le site sur ce poste',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Empêche le caissier de modifier le site.',
                          style: TextStyle(
                            color: Color(0xFF9AA7BC),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
