class MediaSchemaBlockDefinition {
  final String blockKey;
  final String label;
  final int order;
  final bool isPivot;
  final bool isFinalBlock;
  final bool isEnabled;
  final List<MediaSchemaSlotDefinition> slots;

  const MediaSchemaBlockDefinition({
    required this.blockKey,
    required this.label,
    required this.order,
    this.isPivot = false,
    this.isFinalBlock = false,
    this.isEnabled = true,
    this.slots = const <MediaSchemaSlotDefinition>[],
  });
}

class MediaSchemaSlotDefinition {
  final String slotKey;
  final String label;
  final int order;
  final List<String> acceptedTypes;
  final bool isRequired;
  final bool isEnabled;
  final String workflowStatus;
  final String? notes;

  const MediaSchemaSlotDefinition({
    required this.slotKey,
    required this.label,
    required this.order,
    required this.acceptedTypes,
    this.isRequired = false,
    this.isEnabled = true,
    this.workflowStatus = 'test',
    this.notes,
  });
}

class LesFugitifsMediaSchema {
  static const String scenarioId = 'les_fugitifs';

  static const List<MediaSchemaBlockDefinition> blocks = <MediaSchemaBlockDefinition>[
    MediaSchemaBlockDefinition(
      blockKey: 'intro',
      label: 'Intro',
      order: 10,
      slots: <MediaSchemaSlotDefinition>[
        MediaSchemaSlotDefinition(
          slotKey: 'intro_briefing',
          label: 'Briefing',
          order: 10,
          acceptedTypes: <String>['video', 'audio', 'image', 'pdf'],
          isRequired: true,
          notes: 'Support principal de briefing de début de partie.',
        ),
        MediaSchemaSlotDefinition(
          slotKey: 'intro_regles',
          label: 'Règles du jeu',
          order: 20,
          acceptedTypes: <String>['video', 'audio', 'image', 'pdf'],
          isRequired: true,
          notes: 'Règles ou consignes de démarrage.',
        ),
        MediaSchemaSlotDefinition(
          slotKey: 'intro_call_1',
          label: 'Appel Cherry on the Cake 1',
          order: 30,
          acceptedTypes: <String>['audio', 'video'],
          notes: 'Premier appel téléphonique d’introduction.',
        ),
        MediaSchemaSlotDefinition(
          slotKey: 'intro_call_2',
          label: 'Appel Cherry on the Cake 2',
          order: 40,
          acceptedTypes: <String>['audio', 'video'],
          notes: 'Deuxième appel téléphonique d’introduction.',
        ),
      ],
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'A0',
      label: 'A0',
      order: 20,
      isPivot: true,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'A1',
      label: 'A1',
      order: 30,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'A2',
      label: 'A2',
      order: 40,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'A3',
      label: 'A3',
      order: 50,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'A4',
      label: 'A4',
      order: 60,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'A5',
      label: 'A5',
      order: 70,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'A6',
      label: 'A6',
      order: 80,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'B0',
      label: 'B0',
      order: 90,
      isPivot: true,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'B1',
      label: 'B1',
      order: 100,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'B2',
      label: 'B2',
      order: 110,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'B3',
      label: 'B3',
      order: 120,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'B4',
      label: 'B4',
      order: 130,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'B5',
      label: 'B5',
      order: 140,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'C0',
      label: 'C0',
      order: 150,
      isPivot: true,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'C1',
      label: 'C1',
      order: 160,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'C2',
      label: 'C2',
      order: 170,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'C3',
      label: 'C3',
      order: 180,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'C4',
      label: 'C4',
      order: 190,
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'D0',
      label: 'D0',
      order: 200,
      isPivot: true,
      isFinalBlock: true,
      slots: <MediaSchemaSlotDefinition>[
        MediaSchemaSlotDefinition(
          slotKey: 'd0_final_call',
          label: 'Appel final Cherry on the Cake',
          order: 10,
          acceptedTypes: <String>['audio', 'video'],
          notes: 'Appel téléphonique final.',
        ),
      ],
    ),
    MediaSchemaBlockDefinition(
      blockKey: 'fin',
      label: 'Fin',
      order: 210,
      isFinalBlock: true,
      slots: <MediaSchemaSlotDefinition>[
        MediaSchemaSlotDefinition(
          slotKey: 'fin_success_video',
          label: 'Vidéo de succès',
          order: 10,
          acceptedTypes: <String>['video'],
          isRequired: true,
        ),
        MediaSchemaSlotDefinition(
          slotKey: 'fin_failure_video',
          label: 'Vidéo d’échec',
          order: 20,
          acceptedTypes: <String>['video'],
          isRequired: true,
        ),
      ],
    ),
  ];
}
