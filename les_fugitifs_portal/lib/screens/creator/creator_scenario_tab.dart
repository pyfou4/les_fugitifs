import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../features/scenario_lock/scenario_lock_models.dart';
import 'creator_lock_report_banner_section.dart';
import 'creator_place_editor_section.dart';
import 'creator_places_list_section.dart';
import 'creator_schema_banner_section.dart';

class CreatorScenarioTab extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final Map<String, Map<String, dynamic>> docsById;
  final String? selectedId;
  final Map<String, dynamic>? selectedData;
  final TextEditingController nameCtrl;
  final TextEditingController synopsisCtrl;
  final TextEditingController mediaNotesCtrl;
  final TextEditingController keywordCtrl;
  final List<String> keywords;
  final TextEditingController gameRulesCtrl;
  final TextEditingController briefingCtrl;
  final bool isSaving;
  final bool isLocking;
  final List<ScenarioValidationIssue> lockIssues;
  final String? lastLockedScenarioId;
  final Color Function(String id) groupColorBuilder;
  final String Function(Map<String, dynamic> data) experienceTypeBuilder;
  final String Function(String type) experienceLabelBuilder;
  final String Function(String id, Map<String, dynamic> data)
      displayNameBuilder;
  final List<String> Function(Map<String, dynamic> data)
      revealedCategoriesReader;
  final String Function(Map<String, dynamic> data) revealedSummaryBuilder;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
      onSelectDoc;
  final void Function(String id, Map<String, Map<String, dynamic>> docsById)
      onSelectFromMap;
  final VoidCallback onAddKeyword;
  final ValueChanged<String> onRemoveKeyword;
  final VoidCallback? onSave;
  final VoidCallback? onLockScenario;
  final VoidCallback onOpenPrintView;

  const CreatorScenarioTab({
    super.key,
    required this.docs,
    required this.docsById,
    required this.selectedId,
    required this.selectedData,
    required this.nameCtrl,
    required this.synopsisCtrl,
    required this.mediaNotesCtrl,
    required this.keywordCtrl,
    required this.keywords,
    required this.gameRulesCtrl,
    required this.briefingCtrl,
    required this.isSaving,
    required this.isLocking,
    required this.lockIssues,
    required this.lastLockedScenarioId,
    required this.groupColorBuilder,
    required this.experienceTypeBuilder,
    required this.experienceLabelBuilder,
    required this.displayNameBuilder,
    required this.revealedCategoriesReader,
    required this.revealedSummaryBuilder,
    required this.onSelectDoc,
    required this.onSelectFromMap,
    required this.onAddKeyword,
    required this.onRemoveKeyword,
    required this.onSave,
    required this.onLockScenario,
    required this.onOpenPrintView,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CreatorSchemaBannerSection(
          docsById: docsById,
          selectedId: selectedId,
          groupColorBuilder: groupColorBuilder,
          onSelectFromMap: onSelectFromMap,
        ),
        CreatorLockReportBannerSection(
          issues: lockIssues,
          lockedScenarioId: lastLockedScenarioId,
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: CreatorPlacesListSection(
                  docs: docs,
                  selectedId: selectedId,
                  groupColorBuilder: groupColorBuilder,
                  experienceTypeBuilder: experienceTypeBuilder,
                  experienceLabelBuilder: experienceLabelBuilder,
                  displayNameBuilder: displayNameBuilder,
                  revealedCategoriesReader: revealedCategoriesReader,
                  onSelectDoc: onSelectDoc,
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: Color(0xFF1B2A42),
              ),
              Expanded(
                flex: 5,
                child: CreatorPlaceEditorSection(
                  selectedId: selectedId,
                  selectedData: selectedData,
                  nameCtrl: nameCtrl,
                  synopsisCtrl: synopsisCtrl,
                  mediaNotesCtrl: mediaNotesCtrl,
                  keywordCtrl: keywordCtrl,
                  keywords: keywords,
                  gameRulesCtrl: gameRulesCtrl,
                  briefingCtrl: briefingCtrl,
                  isSaving: isSaving,
                  isLocking: isLocking,
                  groupColorBuilder: groupColorBuilder,
                  experienceTypeBuilder: experienceTypeBuilder,
                  experienceLabelBuilder: experienceLabelBuilder,
                  displayNameBuilder: displayNameBuilder,
                  revealedCategoriesReader: revealedCategoriesReader,
                  revealedSummaryBuilder: revealedSummaryBuilder,
                  onAddKeyword: onAddKeyword,
                  onRemoveKeyword: onRemoveKeyword,
                  onSave: onSave,
                  onLockScenario: onLockScenario,
                  onOpenPrintView: onOpenPrintView,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
