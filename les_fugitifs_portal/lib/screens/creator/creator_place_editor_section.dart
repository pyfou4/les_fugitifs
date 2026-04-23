import 'package:flutter/material.dart';

import 'creator_big_info_chip.dart';
import 'creator_place_media_requirements_preview_section.dart';
import 'creator_place_sequence_editor_section.dart';
import 'creator_place_trigger_editor_section.dart';
import 'utils/place_media_requirements.dart';
import 'utils/place_runtime_normalizer.dart';

class CreatorPlaceEditorSection extends StatefulWidget {
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
  final Color Function(String id) groupColorBuilder;
  final String Function(Map<String, dynamic> data) experienceTypeBuilder;
  final String Function(String type) experienceLabelBuilder;
  final String Function(String id, Map<String, dynamic> data)
  displayNameBuilder;
  final List<String> Function(Map<String, dynamic> data)
  revealedCategoriesReader;
  final String Function(Map<String, dynamic> data) revealedSummaryBuilder;
  final VoidCallback onAddKeyword;
  final ValueChanged<String> onRemoveKeyword;
  final VoidCallback? onSave;
  final VoidCallback? onLockScenario;
  final VoidCallback onOpenPrintView;

  /// Nouveau callback optionnel pour remonter le patch runtime.
  /// Il reste optionnel pour ne rien casser tant que le parent
  /// n'est pas encore branché.
  final ValueChanged<Map<String, dynamic>>? onPlaceRuntimeChanged;

  const CreatorPlaceEditorSection({
    super.key,
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
    required this.groupColorBuilder,
    required this.experienceTypeBuilder,
    required this.experienceLabelBuilder,
    required this.displayNameBuilder,
    required this.revealedCategoriesReader,
    required this.revealedSummaryBuilder,
    required this.onAddKeyword,
    required this.onRemoveKeyword,
    required this.onSave,
    required this.onLockScenario,
    required this.onOpenPrintView,
    this.onPlaceRuntimeChanged,
  });

  @override
  State<CreatorPlaceEditorSection> createState() =>
      _CreatorPlaceEditorSectionState();
}

class _CreatorPlaceEditorSectionState extends State<CreatorPlaceEditorSection> {
  Map<String, dynamic> _trigger = <String, dynamic>{};
  List<Map<String, dynamic>> _sequence = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _mediaRequirementsPreview =
  <Map<String, dynamic>>[];
  String? _loadedPlaceId;

  @override
  void initState() {
    super.initState();
    _loadRuntimeStateFromSelectedData();
  }

  @override
  void didUpdateWidget(covariant CreatorPlaceEditorSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final selectedIdChanged = oldWidget.selectedId != widget.selectedId;
    final selectedDataChanged = oldWidget.selectedData != widget.selectedData;

    if (selectedIdChanged || selectedDataChanged) {
      _loadRuntimeStateFromSelectedData();
    }
  }

  void _loadRuntimeStateFromSelectedData() {
    final selectedAvailable =
        widget.selectedId != null && widget.selectedData != null;

    if (!selectedAvailable) {
      setState(() {
        _loadedPlaceId = null;
        _trigger = <String, dynamic>{};
        _sequence = <Map<String, dynamic>>[];
        _mediaRequirementsPreview = <Map<String, dynamic>>[];
      });
      return;
    }

    final runtimeFields =
    normalizePlaceRuntimeFields(widget.selectedData ?? <String, dynamic>{});
    final nextTrigger =
    Map<String, dynamic>.from(runtimeFields['trigger'] as Map);
    final nextSequence =
    List<Map<String, dynamic>>.from(runtimeFields['sequence'] as List);

    setState(() {
      _loadedPlaceId = widget.selectedId;
      _trigger = nextTrigger;
      _sequence = nextSequence;
      _mediaRequirementsPreview =
          computeMediaRequirementsFromSequence(nextSequence);
    });

    _notifyRuntimePatch();
  }

  void _updateTrigger(Map<String, dynamic> newTrigger) {
    setState(() {
      _trigger = Map<String, dynamic>.from(newTrigger);
    });
    _notifyRuntimePatch();
  }

  void _updateSequence(List<Map<String, dynamic>> newSequence) {
    final safeSequence = List<Map<String, dynamic>>.from(newSequence);

    setState(() {
      _sequence = safeSequence;
      _mediaRequirementsPreview =
          computeMediaRequirementsFromSequence(safeSequence);
    });

    _notifyRuntimePatch();
  }

  void _notifyRuntimePatch() {
    widget.onPlaceRuntimeChanged?.call({
      'trigger': _trigger,
      'sequence': _sequence,
    });
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
    final selectedAvailable =
        widget.selectedId != null && widget.selectedData != null;

    final type = selectedAvailable
        ? widget.experienceTypeBuilder(widget.selectedData!)
        : 'media';

    final color = selectedAvailable
        ? widget.groupColorBuilder(widget.selectedId!)
        : const Color(0xFFD65A00);

    final revealed = selectedAvailable
        ? widget.revealedCategoriesReader(widget.selectedData!)
        : const <String>[];

    final displayTitle = selectedAvailable
        ? widget.displayNameBuilder(widget.selectedId!, widget.selectedData!)
        : 'Aucun lieu sélectionné';

    final selected = widget.selectedData ?? <String, dynamic>{};

    return Container(
      color: const Color(0xFF091425),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101C31),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF223250)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Textes globaux du scénario',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
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
            const SizedBox(height: 16),
            if (!selectedAvailable)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Text(
                    'Sélectionne un lieu pour commencer.',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else ...[
              Text(
                displayTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  CreatorBigInfoChip(
                    label: widget.experienceLabelBuilder(type),
                    color: color,
                  ),
                  if (revealed.isNotEmpty)
                    ...revealed.map(
                          (info) => CreatorBigInfoChip(
                        label: info,
                        color: const Color(0xFFFFB24A),
                      ),
                    )
                  else
                    const CreatorBigInfoChip(
                      label: 'none',
                      color: Color(0xFFFFB24A),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Infos révélées : ${widget.revealedSummaryBuilder(widget.selectedData!)}',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  color: Color(0xFFAAB7C8),
                  fontWeight: FontWeight.w600,
                ),
              ),

              /// NOUVEAU BLOC : déclenchement
              CreatorPlaceTriggerEditorSection(
                trigger: _trigger,
                onChanged: _updateTrigger,
              ),

              /// NOUVEAU BLOC : séquence
              CreatorPlaceSequenceEditorSection(
                sequence: _sequence,
                onChanged: _updateSequence,
              ),

              /// NOUVEAU BLOC : preview média
              CreatorPlaceMediaRequirementsPreviewSection(
                items: _mediaRequirementsPreview,
              ),

              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF101C31),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF223250)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coordonnées terrain',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Les coordonnées lat/lng sont gérées uniquement dans l’onglet Sites.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: Color(0xFFAAB7C8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: widget.nameCtrl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                decoration: _fieldDecoration(
                  label: 'Nom du lieu',
                  color: color,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: widget.synopsisCtrl,
                maxLines: 5,
                minLines: 4,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.3,
                ),
                decoration: _fieldDecoration(
                  label: 'Synopsis',
                  color: color,
                  multiline: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: widget.mediaNotesCtrl,
                maxLines: 5,
                minLines: 4,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.3,
                ),
                decoration: _fieldDecoration(
                  label: 'Médias',
                  color: color,
                  multiline: true,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Décris ici le média imaginé pour ce lieu et ce qu’il raconte. Exemple: vidéo de télé-journal, audio d’interrogatoire, caméra de surveillance, voix off, etc.',
                style: TextStyle(
                  color: Color(0xFFAAB7C8),
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Mots-clés vocaux',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (widget.keywords.isNotEmpty)
                    ...widget.keywords.map(
                          (keyword) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF122139),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFF294C74)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              keyword,
                              style: const TextStyle(
                                color: Color(0xFFAED0FF),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 5),
                            InkWell(
                              onTap: () => widget.onRemoveKeyword(keyword),
                              child: const Icon(
                                Icons.close,
                                size: 13,
                                color: Color(0xFFAED0FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101C31),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF223250)),
                      ),
                      child: const Text(
                        'Aucun mot-clé',
                        style: TextStyle(
                          color: Color(0xFFAAB7C8),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.keywordCtrl,
                      onSubmitted: (_) => widget.onAddKeyword(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: _fieldDecoration(
                        label: 'Ajouter un mot-clé',
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: widget.onAddKeyword,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF294C74),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Ajouter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
                      widget.isSaving
                          ? 'Enregistrement...'
                          : 'Sauvegarder',
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
                      widget.isLocking
                          ? 'Verrouillage...'
                          : 'Lock scénario',
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
          ],
        ),
      ),
    );
  }
}