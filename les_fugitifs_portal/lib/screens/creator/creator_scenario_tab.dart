import 'dart:html' as html;

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
  static const String _graphCollapsedStorageKey =
      'creator_scenario_tab.graph_collapsed';
  static const String _globalTextsCollapsedStorageKey =
      'creator_scenario_tab.global_texts_collapsed';

  bool _isGraphCollapsed = true;
  bool _isGlobalTextsCollapsed = true;

  @override
  void initState() {
    super.initState();
    _isGraphCollapsed = _readPersistedBool(
      _graphCollapsedStorageKey,
      defaultValue: true,
    );
    _isGlobalTextsCollapsed = _readPersistedBool(
      _globalTextsCollapsedStorageKey,
      defaultValue: true,
    );
  }

  bool _readPersistedBool(String key, {required bool defaultValue}) {
    final value = html.window.localStorage[key];

    if (value == 'true') {
      return true;
    }

    if (value == 'false') {
      return false;
    }

    return defaultValue;
  }

  void _writePersistedBool(String key, bool value) {
    html.window.localStorage[key] = value.toString();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required Color color,
    bool multiline = false,
  }) {
    return InputDecoration(
      isDense: true,
      alignLabelWithHint: multiline,
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFFAAB7C8),
        fontSize: 14,
      ),
      filled: true,
      fillColor: const Color(0xFF111D32),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF263854)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF263854)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopActionBar(),
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
        _buildGlobalScenarioTextsSection(),
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
                  groupColorBuilder: widget.groupColorBuilder,
                  experienceTypeBuilder: widget.experienceTypeBuilder,
                  experienceLabelBuilder: widget.experienceLabelBuilder,
                  displayNameBuilder: widget.displayNameBuilder,
                  revealedCategoriesReader: widget.revealedCategoriesReader,
                  revealedSummaryBuilder: widget.revealedSummaryBuilder,
                  onAddKeyword: widget.onAddKeyword,
                  onRemoveKeyword: widget.onRemoveKeyword,
                  onPlaceRuntimeChanged: widget.onPlaceRuntimeChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopActionBar() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF071120),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const Icon(
            Icons.edit_note_outlined,
            color: Color(0xFFFFB24A),
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Création du scénario',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: widget.onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD65A00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: widget.isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(
                  widget.isSaving ? 'Enregistrement...' : 'Sauvegarder',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onLockScenario,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFD7B8),
                  side: const BorderSide(color: Color(0xFF4A2B1D)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: widget.isLocking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFFD7B8),
                        ),
                      )
                    : const Icon(Icons.lock_outline, size: 16),
                label: Text(
                  widget.isLocking ? 'Verrouillage...' : 'Lock scénario',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenPrintView,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFAED0FF),
                  side: const BorderSide(color: Color(0xFF294C74)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text(
                  'Vue impression',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
            final nextValue = !_isGraphCollapsed;

            setState(() {
              _isGraphCollapsed = nextValue;
            });

            _writePersistedBool(_graphCollapsedStorageKey, nextValue);
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

  Widget _buildGlobalScenarioTextsSection() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF091425),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF101C31),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF223250)),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                final nextValue = !_isGlobalTextsCollapsed;

                setState(() {
                  _isGlobalTextsCollapsed = nextValue;
                });

                _writePersistedBool(
                  _globalTextsCollapsedStorageKey,
                  nextValue,
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Icon(
                      _isGlobalTextsCollapsed
                          ? Icons.expand_more
                          : Icons.expand_less,
                      color: const Color(0xFFFFB24A),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Textes globaux du scénario',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Text(
                      'Briefing + règles',
                      style: TextStyle(
                        color: Color(0xFFAAB7C8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ces deux blocs ne sont liés à aucun lieu. Ils servent au briefing général et aux règles du jeu.',
                      style: TextStyle(
                        color: Color(0xFFAAB7C8),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: widget.gameRulesCtrl,
                      maxLines: 4,
                      minLines: 3,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.3,
                      ),
                      decoration: _fieldDecoration(
                        label: 'Règles du jeu',
                        color: const Color(0xFFD65A00),
                        multiline: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: widget.briefingCtrl,
                      maxLines: 4,
                      minLines: 3,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.3,
                      ),
                      decoration: _fieldDecoration(
                        label: 'Briefing',
                        color: const Color(0xFFD65A00),
                        multiline: true,
                      ),
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _isGlobalTextsCollapsed
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }
}
