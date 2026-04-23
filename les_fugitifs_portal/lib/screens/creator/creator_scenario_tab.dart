import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../features/scenario_lock/scenario_lock_models.dart';
import 'creator_lock_report_banner_section.dart';
import 'creator_place_editor_section.dart';
import 'creator_places_list_section.dart';
import 'creator_schema_banner_section.dart';

class CreatorScenarioTab extends StatefulWidget {
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
  final ValueChanged<Map<String, dynamic>>? onPlaceRuntimeChanged;

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
    this.onPlaceRuntimeChanged,
  });

  @override
  State<CreatorScenarioTab> createState() => _CreatorScenarioTabState();
}

class _CreatorScenarioTabState extends State<CreatorScenarioTab> {
  bool _isGraphCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildGraphHeader(),
        AnimatedCrossFade(
          firstChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CreatorSchemaBannerSection(
                docsById: widget.docsById,
                selectedId: widget.selectedId,
                groupColorBuilder: widget.groupColorBuilder,
                onSelectFromMap: widget.onSelectFromMap,
              ),
              CreatorLockReportBannerSection(
                issues: widget.lockIssues,
                lockedScenarioId: widget.lastLockedScenarioId,
              ),
            ],
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _isGraphCollapsed
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: CreatorPlacesListSection(
                  docs: widget.docs,
                  selectedId: widget.selectedId,
                  groupColorBuilder: widget.groupColorBuilder,
                  experienceTypeBuilder: widget.experienceTypeBuilder,
                  experienceLabelBuilder: widget.experienceLabelBuilder,
                  displayNameBuilder: widget.displayNameBuilder,
                  revealedCategoriesReader: widget.revealedCategoriesReader,
                  onSelectDoc: widget.onSelectDoc,
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: Color(0xFF1B2A42),
              ),
              Expanded(
                flex: 6,
                child: CreatorPlaceEditorSection(
                  selectedId: widget.selectedId,
                  selectedData: widget.selectedData,
                  nameCtrl: widget.nameCtrl,
                  synopsisCtrl: widget.synopsisCtrl,
                  mediaNotesCtrl: widget.mediaNotesCtrl,
                  keywordCtrl: widget.keywordCtrl,
                  keywords: widget.keywords,
                  gameRulesCtrl: widget.gameRulesCtrl,
                  briefingCtrl: widget.briefingCtrl,
                  isSaving: widget.isSaving,
                  isLocking: widget.isLocking,
                  groupColorBuilder: widget.groupColorBuilder,
                  experienceTypeBuilder: widget.experienceTypeBuilder,
                  experienceLabelBuilder: widget.experienceLabelBuilder,
                  displayNameBuilder: widget.displayNameBuilder,
                  revealedCategoriesReader: widget.revealedCategoriesReader,
                  revealedSummaryBuilder: widget.revealedSummaryBuilder,
                  onAddKeyword: widget.onAddKeyword,
                  onRemoveKeyword: widget.onRemoveKeyword,
                  onSave: widget.onSave,
                  onLockScenario: widget.onLockScenario,
                  onOpenPrintView: widget.onOpenPrintView,
                  onPlaceRuntimeChanged: widget.onPlaceRuntimeChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGraphHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF091425),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _isGraphCollapsed = !_isGraphCollapsed;
            });
          },
          icon: Icon(
            _isGraphCollapsed ? Icons.expand_more : Icons.expand_less,
            size: 18,
          ),
          label: Text(
            _isGraphCollapsed ? 'Afficher le graphe' : 'Réduire le graphe',
          ),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFAED0FF),
          ),
        ),
      ),
    );
  }
}
