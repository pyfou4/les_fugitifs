import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'creator_media_header_section.dart';
import 'creator_media_slots_grid_section.dart';

class CreatorMediaTab extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> slotDefinitionDocs;
  final String? selectedScenarioId;
  final bool isLoadingAction;
  final bool isAdmin;
  final Stream<QuerySnapshot<Map<String, dynamic>>> scenariosStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(String scenarioId)
      scenarioMediaSlotsStreamBuilder;
  final String Function(DocumentSnapshot<Map<String, dynamic>> doc)
      scenarioLabelBuilder;
  final ValueChanged<String?> onSelectScenario;
  final Future<void> Function(String scenarioId) onFreezeMedia;
  final Future<void> Function(String scenarioId) onUnfreezeMedia;
  final Future<void> Function({
    required String scenarioId,
    required String slotId,
    required Map<String, dynamic> slotDefinitionData,
  }) onUploadOrReplaceMedia;
  final Future<void> Function({
    required String scenarioId,
    required String slotId,
    required Map<String, dynamic> slotDefinitionData,
  })? onRemoveMedia;

  const CreatorMediaTab({
    super.key,
    required this.slotDefinitionDocs,
    required this.selectedScenarioId,
    required this.isLoadingAction,
    required this.isAdmin,
    required this.scenariosStream,
    required this.scenarioMediaSlotsStreamBuilder,
    required this.scenarioLabelBuilder,
    required this.onSelectScenario,
    required this.onFreezeMedia,
    required this.onUnfreezeMedia,
    required this.onUploadOrReplaceMedia,
    required this.onRemoveMedia,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: scenariosStream,
      builder: (context, scenarioSnapshot) {
        if (scenarioSnapshot.connectionState == ConnectionState.waiting &&
            !scenarioSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (scenarioSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur Firestore (scénarios) : ${scenarioSnapshot.error}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 18,
                ),
              ),
            ),
          );
        }

        final scenarioDocs =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          scenarioSnapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        )..sort((a, b) => scenarioLabelBuilder(a).compareTo(scenarioLabelBuilder(b)));

        if (scenarioDocs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucun scénario disponible.',
                style: TextStyle(
                  color: Color(0xFFAAB7C8),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        final effectiveScenarioId = _resolveSelectedScenarioId(
          selectedScenarioId: selectedScenarioId,
          scenarioDocs: scenarioDocs,
        );

        if (selectedScenarioId != effectiveScenarioId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onSelectScenario(effectiveScenarioId);
          });
        }

        final selectedScenarioDoc = scenarioDocs.firstWhere(
          (doc) => doc.id == effectiveScenarioId,
          orElse: () => scenarioDocs.first,
        );

        final selectedScenarioLabel = scenarioLabelBuilder(selectedScenarioDoc);
        final availableScenarioLabel = scenarioDocs.length == 1
            ? '1 scénario disponible'
            : '${scenarioDocs.length} scénarios disponibles';

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: scenarioMediaSlotsStreamBuilder(selectedScenarioDoc.id),
          builder: (context, slotsSnapshot) {
            if (slotsSnapshot.connectionState == ConnectionState.waiting &&
                !slotsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (slotsSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Erreur Firestore (slots médias) : ${slotsSnapshot.error}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 18,
                    ),
                  ),
                ),
              );
            }

            final scenarioSlotDocs =
                List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              slotsSnapshot.data?.docs ??
                  const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
            );

            return FutureBuilder<Map<String, Map<String, dynamic>>>(
              future: _loadHydratedScenarioSlots(scenarioSlotDocs),
              builder: (context, hydratedSnapshot) {
                if (hydratedSnapshot.connectionState == ConnectionState.waiting &&
                    !hydratedSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final scenarioSlotsById =
                    hydratedSnapshot.data ?? <String, Map<String, dynamic>>{};

                final requiredCount = slotDefinitionDocs.where((doc) {
                  final value = doc.data()['isRequired'];
                  if (value is bool) return value;
                  final lower = value?.toString().trim().toLowerCase();
                  return lower == 'true' || lower == '1';
                }).length;

                final currentCount = slotDefinitionDocs.where((doc) {
                  final slotData =
                      scenarioSlotsById[doc.id] ?? const <String, dynamic>{};
                  final activeMediaId = _stringFrom(slotData['activeMediaId']);
                  final fileName = _stringFrom(
                    slotData['activeFileName'] ?? slotData['fileName'],
                  );
                  final storagePath = _stringFrom(
                    slotData['activeStoragePath'] ?? slotData['storagePath'],
                  );
                  return activeMediaId != null ||
                      fileName != null ||
                      storagePath != null;
                }).length;

                final isFrozen =
                    (selectedScenarioDoc.data()?['mediaFrozen'] ?? false) == true;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 360,
                            child: DropdownButtonFormField<String>(
                              value: effectiveScenarioId,
                              dropdownColor: const Color(0xFF101A2B),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                labelText: availableScenarioLabel,
                                helperText:
                                    'Choisis le scénario à gérer dans l’onglet Médias.',
                              ),
                              items: scenarioDocs.map((doc) {
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(
                                    scenarioLabelBuilder(doc),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: isLoadingAction ? null : onSelectScenario,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CreatorMediaHeaderSection(
                        selectedScenarioDoc: selectedScenarioDoc,
                        selectedScenarioLabel: selectedScenarioLabel,
                        currentCount: currentCount,
                        requiredCount: requiredCount,
                        totalCount: slotDefinitionDocs.length,
                        isFrozen: isFrozen,
                        canUnfreeze: isAdmin,
                        onFreeze: isFrozen || isLoadingAction
                            ? null
                            : () => onFreezeMedia(selectedScenarioDoc.id),
                        onUnfreeze: (!isFrozen || !isAdmin || isLoadingAction)
                            ? null
                            : () => onUnfreezeMedia(selectedScenarioDoc.id),
                      ),
                      const SizedBox(height: 16),
                      CreatorMediaSlotsGridSection(
                        scenarioId: selectedScenarioDoc.id,
                        slotDefinitionDocs: slotDefinitionDocs,
                        scenarioSlotsById: scenarioSlotsById,
                        isFrozen: isFrozen || isLoadingAction,
                        onUploadOrReplaceMedia: ({
                          required String slotId,
                          required Map<String, dynamic> slotDefinitionData,
                        }) =>
                            onUploadOrReplaceMedia(
                          scenarioId: selectedScenarioDoc.id,
                          slotId: slotId,
                          slotDefinitionData: slotDefinitionData,
                        ),
                        onRemoveMedia: onRemoveMedia == null
                            ? null
                            : ({
                                required String slotId,
                                required Map<String, dynamic> slotDefinitionData,
                              }) =>
                                onRemoveMedia!(
                                  scenarioId: selectedScenarioDoc.id,
                                  slotId: slotId,
                                  slotDefinitionData: slotDefinitionData,
                                ),
                        onWorkflowStatusChanged: ({
                          required String slotId,
                          required String workflowStatus,
                        }) =>
                            _updateWorkflowStatus(
                          slotId: slotId,
                          slotData:
                              scenarioSlotsById[slotId] ?? const <String, dynamic>{},
                          workflowStatus: workflowStatus,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  static String _resolveSelectedScenarioId({
    required String? selectedScenarioId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> scenarioDocs,
  }) {
    if (selectedScenarioId != null &&
        scenarioDocs.any((doc) => doc.id == selectedScenarioId)) {
      return selectedScenarioId;
    }
    return scenarioDocs.first.id;
  }

  static Future<Map<String, Map<String, dynamic>>> _loadHydratedScenarioSlots(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> scenarioSlotDocs,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final result = <String, Map<String, dynamic>>{};

    for (final doc in scenarioSlotDocs) {
      final slotData = Map<String, dynamic>.from(doc.data());
      final activeMediaId = _stringFrom(slotData['activeMediaId']);

      if (activeMediaId != null) {
        final mediaDoc =
            await firestore.collection('media_assets').doc(activeMediaId).get();
        if (mediaDoc.exists) {
          final mediaData = mediaDoc.data() ?? <String, dynamic>{};
          slotData['activeMediaTitle'] =
              mediaData['title'] ?? mediaData['activeMediaTitle'];
          slotData['activeFileName'] =
              mediaData['fileName'] ?? mediaData['activeFileName'];
          slotData['activeMimeType'] =
              mediaData['mimeType'] ?? mediaData['activeMimeType'];
          slotData['technicalStatus'] =
              mediaData['technicalStatus'] ?? slotData['technicalStatus'];
          slotData['activeStoragePath'] =
              mediaData['storagePath'] ?? slotData['activeStoragePath'];
          slotData['workflowStatus'] =
              slotData['workflowStatus'] ??
              mediaData['workflowStatus'] ??
              mediaData['validationStatus'] ??
              'test';
        }
      }

      result[doc.id] = slotData;
    }

    return result;
  }

  static Future<void> _updateWorkflowStatus({
    required String slotId,
    required Map<String, dynamic> slotData,
    required String workflowStatus,
  }) async {
    final normalized = workflowStatus.trim().toLowerCase() == 'final'
        ? 'final'
        : 'test';

    final firestore = FirebaseFirestore.instance;
    final activeMediaId = _stringFrom(slotData['activeMediaId']);

    final batch = firestore.batch();

    batch.set(
      firestore.collection('scenario_media_slots').doc(slotId),
      {
        'workflowStatus': normalized,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );

    if (activeMediaId != null) {
      batch.set(
        firestore.collection('media_assets').doc(activeMediaId),
        {
          'workflowStatus': normalized,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static String? _stringFrom(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
