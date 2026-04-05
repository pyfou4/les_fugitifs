import 'package:flutter/material.dart';

import 'creator_big_info_chip.dart';

class CreatorPlaceEditorSection extends StatelessWidget {
  final String? selectedId;
  final Map<String, dynamic>? selectedData;
  final TextEditingController nameCtrl;
  final TextEditingController synopsisCtrl;
  final TextEditingController keywordCtrl;
  final List<String> keywords;
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

  const CreatorPlaceEditorSection({
    super.key,
    required this.selectedId,
    required this.selectedData,
    required this.nameCtrl,
    required this.synopsisCtrl,
    required this.keywordCtrl,
    required this.keywords,
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
  });

  @override
  Widget build(BuildContext context) {
    if (selectedId == null || selectedData == null) {
      return const Center(
        child: Text(
          'Sélectionne un lieu pour commencer.',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final type = experienceTypeBuilder(selectedData!);
    final color = groupColorBuilder(selectedId!);
    final revealed = revealedCategoriesReader(selectedData!);
    final displayTitle = displayNameBuilder(selectedId!, selectedData!);

    return Container(
      color: const Color(0xFF091425),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  label: experienceLabelBuilder(type),
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
              'Infos révélées : ${revealedSummaryBuilder(selectedData!)}',
              style: const TextStyle(
                fontSize: 14,
                height: 1.2,
                color: Color(0xFFAAB7C8),
                fontWeight: FontWeight.w600,
              ),
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
              controller: nameCtrl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Nom du lieu',
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
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: synopsisCtrl,
              maxLines: 5,
              minLines: 4,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.3,
              ),
              decoration: InputDecoration(
                isDense: true,
                alignLabelWithHint: true,
                labelText: 'Synopsis',
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
                if (keywords.isNotEmpty)
                  ...keywords.map(
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
                            onTap: () => onRemoveKeyword(keyword),
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
                    controller: keywordCtrl,
                    onSubmitted: (_) => onAddKeyword(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Ajouter un mot-clé',
                      labelStyle: const TextStyle(
                        color: Color(0xFFAAB7C8),
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
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onAddKeyword,
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
                  onPressed: onSave,
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
                  icon: isSaving
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
                    isSaving ? 'Enregistrement...' : 'Sauvegarder',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onLockScenario,
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
                  icon: isLocking
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
                    isLocking ? 'Verrouillage...' : 'Lock scénario',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenPrintView,
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
      ),
    );
  }
}
