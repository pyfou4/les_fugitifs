import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreatorPrintScreen extends StatelessWidget {
  const CreatorPrintScreen({super.key});

  static final CollectionReference<Map<String, dynamic>> _placesRef =
  FirebaseFirestore.instance
      .collection('games')
      .doc('les_fugitifs')
      .collection('placeTemplates');

  String _experienceType(Map<String, dynamic> data) {
    final raw = (data['experienceType'] ?? data['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (raw == 'physical') return 'physique';
    return raw;
  }

  String _experienceLabel(String type) {
    switch (type) {
      case 'media':
        return 'Média';
      case 'observation':
        return 'Observation';
      case 'physique':
      case 'physical':
        return 'Physique';
      default:
        return 'Non défini';
    }
  }

  List<String> _readRawRevealValues(Map<String, dynamic> data) {
    final results = <String>{};

    void addValue(dynamic value) {
      if (value == null) return;

      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;

        final parts = trimmed
            .split(RegExp(r'[,;|/]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);

        results.addAll(parts);
        return;
      }

      if (value is Iterable) {
        for (final item in value) {
          addValue(item);
        }
        return;
      }

      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString().trim();
          final entryValue = entry.value;

          if (entryValue == true && key.isNotEmpty) {
            results.add(key);
          } else {
            addValue(entryValue);
          }
        }
      }
    }

    final preferredCandidates = <dynamic>[
      data['targetType'],
      data['targetTypes'],
      data['revealedInfoKeys'],
      data['revealedInfo'],
      data['infoRevealed'],
      data['reveals'],
      data['revealsAbout'],
      data['targets'],
      data['linkedInfo'],
      data['associatedInfo'],
      data['associatedInfoKeys'],
      data['moLinks'],
      data['infoTargets'],
      data['clueTargets'],
    ];

    for (final candidate in preferredCandidates) {
      addValue(candidate);
    }

    final ordered = results.toList()..sort();
    return ordered;
  }

  List<String> _readDisplayRevealCategories(Map<String, dynamic> data) {
    final raw = _readRawRevealValues(data);
    final categories = <String>{};

    for (final item in raw) {
      final lower = item.toLowerCase().trim();

      if (lower.contains('suspect') || lower.startsWith('pc')) {
        categories.add('suspect');
      } else if (lower.contains('motive') || lower.startsWith('mo')) {
        categories.add('motive');
      } else if (lower.isNotEmpty && lower != 'none') {
        categories.add(item);
      }
    }

    final ordered = categories.toList()..sort();
    return ordered;
  }

  void _print() {
    html.window.print();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        title: const Text(
          'Vue impression scénariste',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _print,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimer'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _placesRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur Firestore : ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final docs = [...(snapshot.data?.docs ?? [])]
            ..sort((a, b) => a.id.compareTo(b.id));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Les Fugitifs - Fiche scénariste',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vue imprimable des lieux et de leur structure.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    _PrintPhaseChip(label: 'A0 → A1..A6'),
                    _PrintPhaseChip(label: '2 lieux requis → B0'),
                    _PrintPhaseChip(label: 'B1..B5 → C0'),
                    _PrintPhaseChip(label: 'C1..C4 → D0'),
                  ],
                ),
                const SizedBox(height: 28),
                ...docs.map((doc) {
                  final data = doc.data();
                  final title =
                  (data['title'] ?? data['name'] ?? '').toString().trim();
                  final synopsis = (data['storySynopsis'] ?? data['synopsis'] ?? '')
                      .toString()
                      .trim();
                  final type = _experienceLabel(_experienceType(data));
                  final reveal = _readDisplayRevealCategories(data);

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? doc.id : '${doc.id} - $title',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _PrintInfoChip(label: type),
                            if (reveal.isNotEmpty)
                              ...reveal.map((e) => _PrintInfoChip(label: e))
                            else
                              const _PrintInfoChip(label: 'none'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          synopsis.isEmpty ? 'Aucun synopsis défini.' : synopsis,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PrintInfoChip extends StatelessWidget {
  final String label;

  const _PrintInfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PrintPhaseChip extends StatelessWidget {
  final String label;

  const _PrintPhaseChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}