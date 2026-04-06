import 'package:flutter/material.dart';

class CreatorQuestionnaireTab extends StatelessWidget {
  final List<String> availablePlaceIds;
  final TextEditingController killerQuestionCtrl;
  final TextEditingController motiveQuestionCtrl;
  final TextEditingController a0QuestionCtrl;
  final TextEditingController b0QuestionCtrl;
  final TextEditingController c0QuestionCtrl;
  final List<TextEditingController> sideQuestionCtrls;
  final List<String?> sideQuestionPlaceIds;
  final bool isSaving;
  final VoidCallback onSave;
  final void Function(int index, String? value) onSideQuestionPlaceChanged;

  const CreatorQuestionnaireTab({
    super.key,
    required this.availablePlaceIds,
    required this.killerQuestionCtrl,
    required this.motiveQuestionCtrl,
    required this.a0QuestionCtrl,
    required this.b0QuestionCtrl,
    required this.c0QuestionCtrl,
    required this.sideQuestionCtrls,
    required this.sideQuestionPlaceIds,
    required this.isSaving,
    required this.onSave,
    required this.onSideQuestionPlaceChanged,
  });

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFFAAB7C8),
        fontSize: 14,
      ),
      alignLabelWithHint: true,
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
        borderSide: const BorderSide(color: Color(0xFFD65A00), width: 2),
      ),
    );
  }

  Widget _mainQuestionCard({
    required String title,
    required String subtitle,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101C31),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223250)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFAAB7C8),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.3,
            ),
            decoration: _decoration('Texte de la question'),
          ),
        ],
      ),
    );
  }

  Widget _sideQuestionCard(int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101C31),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223250)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question annexe ${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choisis un lieu annexe, puis écris la question finale liée à ce poste.',
            style: TextStyle(
              color: Color(0xFFAAB7C8),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: sideQuestionPlaceIds[index],
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Aucun lieu sélectionné'),
              ),
              ...availablePlaceIds.map(
                (placeId) => DropdownMenuItem<String>(
                  value: placeId,
                  child: Text(placeId),
                ),
              ),
            ],
            onChanged: (value) {
              final normalized = (value ?? '').trim();
              onSideQuestionPlaceChanged(
                index,
                normalized.isEmpty ? null : normalized,
              );
            },
            decoration: _decoration('Lieu annexe'),
            dropdownColor: const Color(0xFF111D32),
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: sideQuestionCtrls[index],
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.3,
            ),
            decoration: _decoration('Texte de la question annexe'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF07111F),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Questionnaire final',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Le questionnaire final se lance à D0, après confirmation de l’équipe. Il comporte 10 questions : 5 principales fixes et 5 annexes choisies par le scénariste.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFFAAB7C8),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Questions principales',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _mainQuestionCard(
              title: '1. Meurtrier',
              subtitle: 'Question principale sur l’identité du coupable.',
              controller: killerQuestionCtrl,
            ),
            const SizedBox(height: 12),
            _mainQuestionCard(
              title: '2. Mobile',
              subtitle: 'Question principale sur le mobile du meurtrier.',
              controller: motiveQuestionCtrl,
            ),
            const SizedBox(height: 12),
            _mainQuestionCard(
              title: '3. Question sur A0',
              subtitle: 'Question principale liée à la scène de crime.',
              controller: a0QuestionCtrl,
            ),
            const SizedBox(height: 12),
            _mainQuestionCard(
              title: '4. Question sur B0',
              subtitle: 'Question principale liée au pivot B0.',
              controller: b0QuestionCtrl,
            ),
            const SizedBox(height: 12),
            _mainQuestionCard(
              title: '5. Question sur C0',
              subtitle: 'Question principale liée au pivot C0.',
              controller: c0QuestionCtrl,
            ),
            const SizedBox(height: 22),
            const Text(
              'Questions annexes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chaque question annexe doit pointer vers un lieu précis hors A0, B0, C0 et D0.',
              style: TextStyle(
                color: Color(0xFFAAB7C8),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < sideQuestionCtrls.length; i++) ...[
              _sideQuestionCard(i),
              if (i < sideQuestionCtrls.length - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD65A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                isSaving ? 'Enregistrement...' : 'Sauvegarder le questionnaire',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
