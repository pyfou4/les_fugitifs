import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'creator_integrity_banner_section.dart';
import 'creator_motives_section.dart';
import 'creator_suspects_section.dart';

class CreatorSuspectsMotivesTab extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> suspectsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> motivesStream;
  final Future<void> Function(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) onAddSuspect;
  final Future<void> Function(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) onEditSuspect;
  final Future<void> Function(String label, String id) onDeleteSuspect;
  final Future<void> Function(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) onAddMotive;
  final Future<void> Function(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) onEditMotive;
  final Future<void> Function(String label, String id) onDeleteMotive;
  final List<String> Function({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required List<String> fields,
  }) buildDuplicateFieldMessages;

  const CreatorSuspectsMotivesTab({
    super.key,
    required this.suspectsStream,
    required this.motivesStream,
    required this.onAddSuspect,
    required this.onEditSuspect,
    required this.onDeleteSuspect,
    required this.onAddMotive,
    required this.onEditMotive,
    required this.onDeleteMotive,
    required this.buildDuplicateFieldMessages,
  });

  List<String> _buildMissingImageMessages({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String entityLabel,
  }) {
    final messages = <String>[];

    for (final doc in docs) {
      final data = doc.data();
      final imagePath =
          (data['imagePath'] ?? data['image'] ?? '').toString().trim();
      if (imagePath.isEmpty) {
        final name = (data['name'] ?? doc.id).toString();
        messages.add('$entityLabel sans PNG : $name');
      }
    }

    return messages;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: suspectsStream,
      builder: (context, suspectsSnapshot) {
        if (suspectsSnapshot.connectionState == ConnectionState.waiting &&
            !suspectsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (suspectsSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur Firestore (suspects) : ${suspectsSnapshot.error}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 18),
              ),
            ),
          );
        }

        final suspectDocs = [
          ...(suspectsSnapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
        ]..sort((a, b) => a.id.compareTo(b.id));

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: motivesStream,
          builder: (context, motivesSnapshot) {
            if (motivesSnapshot.connectionState == ConnectionState.waiting &&
                !motivesSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (motivesSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Erreur Firestore (mobiles) : ${motivesSnapshot.error}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 18,
                    ),
                  ),
                ),
              );
            }

            final motiveDocs = [
              ...(motivesSnapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
            ]..sort((a, b) => a.id.compareTo(b.id));

            final suspectIssues = <String>[
              if (suspectDocs.length != 6)
                'Suspects: ${suspectDocs.length}/6. Il en faut exactement 6.',
              ...buildDuplicateFieldMessages(
                docs: suspectDocs,
                fields: const ['age', 'profession', 'build'],
              ),
              ..._buildMissingImageMessages(
                docs: suspectDocs,
                entityLabel: 'Suspect',
              ),
            ];

            final motiveIssues = <String>[
              if (motiveDocs.length != 6)
                'Mobiles: ${motiveDocs.length}/6. Il en faut exactement 6.',
              ...buildDuplicateFieldMessages(
                docs: motiveDocs,
                fields: const ['violence', 'delays', 'preparations'],
              ),
              ..._buildMissingImageMessages(
                docs: motiveDocs,
                entityLabel: 'Mobile',
              ),
            ];

            return Container(
              color: const Color(0xFF07111F),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int gridCount;
                    if (constraints.maxWidth >= 1600) {
                      gridCount = 4;
                    } else if (constraints.maxWidth >= 1200) {
                      gridCount = 3;
                    } else if (constraints.maxWidth >= 850) {
                      gridCount = 2;
                    } else {
                      gridCount = 1;
                    }

                    final cardHeight = gridCount == 1 ? 198.0 : 208.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suspects & Mobiles',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Le scénariste gère ici les 6 présumés coupables et les 6 mobiles. Les champs d’indices doivent rester uniques et chaque fiche doit embarquer son PNG.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: Color(0xFFAAB7C8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CreatorIntegrityBannerSection(
                          suspectIssues: suspectIssues,
                          motiveIssues: motiveIssues,
                        ),
                        if (suspectIssues.isNotEmpty || motiveIssues.isNotEmpty)
                          const SizedBox(height: 16),
                        CreatorSuspectsSection(
                          suspectDocs: suspectDocs,
                          gridCount: gridCount,
                          cardHeight: cardHeight,
                          onAdd: () => onAddSuspect(suspectDocs),
                          onEdit: (doc) => onEditSuspect(doc, suspectDocs),
                          onDelete: (label, id) => onDeleteSuspect(label, id),
                        ),
                        const SizedBox(height: 20),
                        CreatorMotivesSection(
                          motiveDocs: motiveDocs,
                          gridCount: gridCount,
                          cardHeight: cardHeight,
                          onAdd: () => onAddMotive(motiveDocs),
                          onEdit: (doc) => onEditMotive(doc, motiveDocs),
                          onDelete: (label, id) => onDeleteMotive(label, id),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
