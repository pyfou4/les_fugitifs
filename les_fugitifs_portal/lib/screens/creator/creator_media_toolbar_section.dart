import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreatorMediaToolbarSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> scenarioDocs;
  final String? selectedScenarioId;
  final bool isLoading;
  final String Function(DocumentSnapshot<Map<String, dynamic>> doc)
      scenarioLabelBuilder;
  final ValueChanged<String> onSelectScenario;

  const CreatorMediaToolbarSection({
    super.key,
    required this.scenarioDocs,
    required this.selectedScenarioId,
    required this.isLoading,
    required this.scenarioLabelBuilder,
    required this.onSelectScenario,
  });

  @override
  Widget build(BuildContext context) {
    final hasScenarios = scenarioDocs.isNotEmpty;
    final effectiveValue = hasScenarios &&
            selectedScenarioId != null &&
            scenarioDocs.any((doc) => doc.id == selectedScenarioId)
        ? selectedScenarioId
        : (hasScenarios ? scenarioDocs.first.id : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101C31),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF223250)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 340,
            child: DropdownButtonFormField<String>(
              value: effectiveValue,
              isExpanded: true,
              dropdownColor: const Color(0xFF101C31),
              decoration: InputDecoration(
                labelText: 'Scénario',
                labelStyle: const TextStyle(color: Color(0xFFAAB7C8)),
                filled: true,
                fillColor: const Color(0xFF0D192C),
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
                  borderSide: const BorderSide(
                    color: Color(0xFF4E8DFF),
                    width: 1.4,
                  ),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              iconEnabledColor: Colors.white,
              items: scenarioDocs
                  .map(
                    (doc) => DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(
                        scenarioLabelBuilder(doc),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: isLoading || !hasScenarios
                  ? null
                  : (value) {
                      if (value == null) return;
                      onSelectScenario(value);
                    },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF0D192C),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF223250)),
            ),
            child: Text(
              '${scenarioDocs.length} scénario(x) disponible(s)',
              style: const TextStyle(
                color: Color(0xFFAED0FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
