import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreatorSitesToolbarSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> siteDocs;
  final String? selectedSiteId;
  final bool isCreatingSite;
  final int templateCount;
  final String Function(DocumentSnapshot<Map<String, dynamic>> doc)
      siteLabelBuilder;
  final ValueChanged<String> onSelectSite;
  final VoidCallback onCreateSite;

  const CreatorSitesToolbarSection({
    super.key,
    required this.siteDocs,
    required this.selectedSiteId,
    required this.isCreatingSite,
    required this.templateCount,
    required this.siteLabelBuilder,
    required this.onSelectSite,
    required this.onCreateSite,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<String>(
            initialValue: selectedSiteId,
            items: siteDocs
                .map(
                  (doc) => DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(siteLabelBuilder(doc)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              onSelectSite(value);
            },
            decoration: InputDecoration(
              labelText: 'Site',
              labelStyle: const TextStyle(
                color: Color(0xFFAAB7C8),
                fontSize: 16,
              ),
              filled: true,
              fillColor: const Color(0xFF111D32),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF263854)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF263854)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFD65A00),
                  width: 2,
                ),
              ),
            ),
            dropdownColor: const Color(0xFF111D32),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        FilledButton.icon(
          onPressed: isCreatingSite ? null : onCreateSite,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD65A00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: isCreatingSite
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add_business_outlined),
          label: Text(
            isCreatingSite ? 'Création...' : 'Créer un nouveau site',
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF101C31),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF223250)),
          ),
          child: Text(
            '$templateCount lieux modèles',
            style: const TextStyle(
              color: Color(0xFFAED0FF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
