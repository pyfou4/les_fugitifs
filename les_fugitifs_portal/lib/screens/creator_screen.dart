import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../services/portal_access_service.dart';
import '../features/scenario_lock/scenario_lock_models.dart';
import '../features/scenario_lock/scenario_lock_service.dart';
import '../features/site_readiness/site_readiness_models.dart';
import '../features/site_readiness/site_readiness_service.dart';
import '../core/media/services/media_admin_service.dart';
import '../core/media/services/media_structure_seed_service.dart';
import 'creator/creator_image_picker.dart';
import 'creator/creator_image_picker_model.dart';
import 'creator/creator_media_tab.dart';
import 'creator/creator_questionnaire_tab.dart';
import 'creator/creator_scenario_tab.dart';
import 'creator/creator_sites_tab.dart';
import 'creator/creator_storage_image_preview.dart';
import 'creator/creator_suspects_motives_tab.dart';
import 'creator_print_screen.dart';

class CreatorScreen extends StatefulWidget {
  final PortalAccessProfile profile;

  const CreatorScreen({super.key, required this.profile});

  @override
  State<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends State<CreatorScreen>
    with SingleTickerProviderStateMixin {
  static final CollectionReference<Map<String, dynamic>> _placesRef =
      FirebaseFirestore.instance
          .collection('games')
          .doc('les_fugitifs')
          .collection('placeTemplates');

  static final CollectionReference<Map<String, dynamic>> _sitesRef =
      FirebaseFirestore.instance.collection('sites');

  static final CollectionReference<Map<String, dynamic>> _scenariosRef =
      FirebaseFirestore.instance.collection('scenarios');

  static final CollectionReference<Map<String, dynamic>>
      _scenarioMediaSlotDefinitionsRef =
      FirebaseFirestore.instance.collection('scenario_media_slot_definitions');

  static final CollectionReference<Map<String, dynamic>> _suspectsRef =
      FirebaseFirestore.instance
          .collection('games')
          .doc('les_fugitifs')
          .collection('suspects');

  static final CollectionReference<Map<String, dynamic>> _motivesRef =
      FirebaseFirestore.instance
          .collection('games')
          .doc('les_fugitifs')
          .collection('motives');

  static final DocumentReference<Map<String, dynamic>> _gameRef =
      FirebaseFirestore.instance.collection('games').doc('les_fugitifs');

  final ScenarioLockService _scenarioLockService = ScenarioLockService(
    firestore: FirebaseFirestore.instance,
  );
  final SiteReadinessService _siteReadinessService = SiteReadinessService(
    firestore: FirebaseFirestore.instance,
  );
  final MediaAdminService _mediaAdminService = MediaAdminService();
  final ScenarioMediaStructureSeedService _mediaStructureSeedService =
      ScenarioMediaStructureSeedService();

  late final TabController _tabController;

  String? _selectedSiteId;
  String? _selectedMediaScenarioId;
  bool _isMediaActionLoading = false;
  bool _isMediaStructureSeeding = false;

  CollectionReference<Map<String, dynamic>> _sitePlacesRef(String siteId) =>
      FirebaseFirestore.instance
          .collection('sites')
          .doc(siteId)
          .collection('places');

  Query<Map<String, dynamic>> _scenarioMediaSlotsRef(String scenarioId) =>
      FirebaseFirestore.instance
          .collection('scenario_media_slots')
          .where('scenarioId', isEqualTo: scenarioId);

  String? _selectedId;
  Map<String, dynamic>? _selectedData;
  final TextEditingController _gameRulesCtrl = TextEditingController();
  final TextEditingController _briefingCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _synopsisCtrl = TextEditingController();
  final TextEditingController _mediaNotesCtrl = TextEditingController();
  final TextEditingController _keywordCtrl = TextEditingController();

  final TextEditingController _killerQuestionCtrl = TextEditingController();
  final TextEditingController _motiveQuestionCtrl = TextEditingController();
  final TextEditingController _a0QuestionCtrl = TextEditingController();
  final TextEditingController _b0QuestionCtrl = TextEditingController();
  final TextEditingController _c0QuestionCtrl = TextEditingController();

  late final List<TextEditingController> _sideQuestionCtrls;
  late final List<String?> _sideQuestionPlaceIds;
  bool _gameConfigurationLoaded = false;

  List<String> _keywords = [];

  bool _isSaving = false;
  bool _isLocking = false;
  bool _isCreatingSite = false;
  bool _adminPasswordValidatedForSession = false;
  bool _isQuestionnaireSaving = false;
  bool _isUnlocking = false;
  bool _isScenarioLocked = false;

  List<ScenarioValidationIssue> _lockIssues = const [];
  String? _lastLockedScenarioId;
  bool _isValidatingSiteReadiness = false;
  SiteReadinessResult? _currentSiteReadinessResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _sideQuestionCtrls = List<TextEditingController>.generate(
      5,
      (_) => TextEditingController(),
    );
    _sideQuestionPlaceIds = List<String?>.filled(5, null);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gameRulesCtrl.dispose();
    _briefingCtrl.dispose();
    _killerQuestionCtrl.dispose();
    _motiveQuestionCtrl.dispose();
    _a0QuestionCtrl.dispose();
    _b0QuestionCtrl.dispose();
    _c0QuestionCtrl.dispose();
    for (final ctrl in _sideQuestionCtrls) {
      ctrl.dispose();
    }
    _nameCtrl.dispose();
    _synopsisCtrl.dispose();
    _mediaNotesCtrl.dispose();
    _keywordCtrl.dispose();
    super.dispose();
  }

  Color _groupColor(String id) {
    if (id.startsWith('A')) return const Color(0xFFF2D74C);
    if (id.startsWith('B')) return const Color(0xFF68E36B);
    if (id.startsWith('C')) return const Color(0xFF6C7CFF);
    if (id.startsWith('D')) return const Color(0xFFE56AF7);
    return const Color(0xFF94A3B8);
  }

  String _experienceType(Map<String, dynamic> data) {
    final raw = (data['experienceType'] ?? data['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (raw == 'physical') return 'physique';
    return raw;
  }

  String _experienceLabel(String type) {
    switch (type) {
      case 'media':
        return 'Média';
      case 'observation':
        return 'Observation';
      case 'physique':
      case 'physical':
        return 'Physique';
      default:
        return 'Non défini';
    }
  }

  String _displayName(String id, Map<String, dynamic> data) {
    final title = (data['title'] ?? data['name'] ?? '').toString().trim();
    if (title.isEmpty) return id;
    return '$id - $title';
  }

  List<String> _readRawRevealValues(Map<String, dynamic> data) {
    final results = <String>{};

    void addValue(dynamic value) {
      if (value == null) return;

      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;

        final parts = trimmed
            .split(RegExp(r'[,;|/]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);

        results.addAll(parts);
        return;
      }

      if (value is Iterable) {
        for (final item in value) {
          addValue(item);
        }
        return;
      }

      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString().trim();
          final entryValue = entry.value;

          if (entryValue == true && key.isNotEmpty) {
            results.add(key);
          } else {
            addValue(entryValue);
          }
        }
      }
    }

    final preferredCandidates = <dynamic>[
      data['targetType'],
      data['targetTypes'],
      data['revealedInfoKeys'],
      data['revealedInfo'],
      data['infoRevealed'],
      data['reveals'],
      data['revealsAbout'],
      data['targets'],
      data['linkedInfo'],
      data['associatedInfo'],
      data['associatedInfoKeys'],
      data['moLinks'],
      data['infoTargets'],
      data['clueTargets'],
    ];

    for (final candidate in preferredCandidates) {
      addValue(candidate);
    }

    final ordered = results.toList()..sort();
    return ordered;
  }

  List<String> _readDisplayRevealCategories(Map<String, dynamic> data) {
    final raw = _readRawRevealValues(data);
    final categories = <String>{};

    for (final item in raw) {
      final lower = item.toLowerCase().trim();

      if (lower.contains('suspect') || lower.startsWith('pc')) {
        categories.add('suspect');
      } else if (lower.contains('motive') || lower.startsWith('mo')) {
        categories.add('motive');
      } else if (lower.isNotEmpty && lower != 'none') {
        categories.add(item);
      }
    }

    final ordered = categories.toList()..sort();
    return ordered;
  }

  String _revealedInfoSummary(Map<String, dynamic> data) {
    final info = _readDisplayRevealCategories(data);
    if (info.isEmpty) return 'none';
    return info.join(' • ');
  }

  void _selectDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    setState(() {
      _selectedId = doc.id;
      _selectedData = data;
      _nameCtrl.text = (data['title'] ?? data['name'] ?? '').toString().trim();
      _synopsisCtrl.text =
          (data['storySynopsis'] ?? data['synopsis'] ?? '').toString().trim();
      _mediaNotesCtrl.text =
          (data['mediaNotes'] ?? data['mediaDescription'] ?? '')
              .toString()
              .trim();
      _keywords = _normalizeKeywords(data['keywords']);
    });
  }

  void _selectFromMap(String id, Map<String, Map<String, dynamic>> docsById) {
    final data = docsById[id];
    if (data == null) return;

    setState(() {
      _selectedId = id;
      _selectedData = data;
      _nameCtrl.text = (data['title'] ?? data['name'] ?? '').toString().trim();
      _synopsisCtrl.text =
          (data['storySynopsis'] ?? data['synopsis'] ?? '').toString().trim();
      _mediaNotesCtrl.text =
          (data['mediaNotes'] ?? data['mediaDescription'] ?? '')
              .toString()
              .trim();
      _keywords = _normalizeKeywords(data['keywords']);
    });
  }

  List<String> _normalizeKeywords(dynamic raw) {
    final values = <String>[];

    if (raw is Iterable) {
      for (final item in raw) {
        final value = item.toString().trim().toLowerCase();
        if (value.isEmpty) continue;
        if (!values.contains(value)) {
          values.add(value);
        }
      }
    }

    return values;
  }

  void _addKeyword() {
    if (_isScenarioLocked) {
      _showLockedSnackBar();
      return;
    }

    final value = _keywordCtrl.text.trim().toLowerCase();
    if (value.isEmpty) return;

    setState(() {
      if (!_keywords.contains(value)) {
        _keywords = [..._keywords, value];
      }
      _keywordCtrl.clear();
    });
  }

  void _removeKeyword(String value) {
    if (_isScenarioLocked) {
      _showLockedSnackBar();
      return;
    }

    setState(() {
      _keywords = _keywords.where((e) => e != value).toList();
    });
  }

  void _showLockedSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scénario verrouillé. Déverrouille-le avant toute modification.'),
      ),
    );
  }

  Widget _wrapCreatorTabLocked({
    required bool locked,
    required Widget child,
  }) {
    if (!locked) return child;

    return Stack(
      children: [
        IgnorePointer(
          ignoring: true,
          child: child,
        ),
        Positioned.fill(
          child: Container(
            color: const Color(0x9907111F),
            alignment: Alignment.center,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF111D32),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF263854)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFFFFD7B8),
                    size: 44,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Scénario verrouillé',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Le créateur est entièrement figé tant que le scénario reste verrouillé. Seul un déverrouillage permet de reprendre les modifications.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFB8C3D6),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _syncGameConfiguration(Map<String, dynamic>? data) {
    if (_gameConfigurationLoaded) return;

    _gameRulesCtrl.text = (data?['gameRules'] ?? '').toString().trim();
    _briefingCtrl.text = (data?['briefing'] ?? '').toString().trim();

    final finalQuestionnaire =
        (data?['finalQuestionnaire'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
    final mainQuestions =
        (finalQuestionnaire['mainQuestions'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
    final sideQuestions =
        (finalQuestionnaire['sideQuestions'] as List<dynamic>?) ?? <dynamic>[];

    _killerQuestionCtrl.text = (mainQuestions['killer'] ?? '').toString().trim();
    _motiveQuestionCtrl.text = (mainQuestions['motive'] ?? '').toString().trim();
    _a0QuestionCtrl.text = (mainQuestions['A0'] ?? '').toString().trim();
    _b0QuestionCtrl.text = (mainQuestions['B0'] ?? '').toString().trim();
    _c0QuestionCtrl.text = (mainQuestions['C0'] ?? '').toString().trim();

    for (int i = 0; i < _sideQuestionCtrls.length; i++) {
      final raw = i < sideQuestions.length ? sideQuestions[i] : null;
      if (raw is Map) {
        final placeId = (raw['placeId'] ?? '').toString().trim();
        _sideQuestionPlaceIds[i] = placeId.isEmpty ? null : placeId;
        _sideQuestionCtrls[i].text =
            (raw['question'] ?? '').toString().trim();
      } else {
        _sideQuestionPlaceIds[i] = null;
        _sideQuestionCtrls[i].clear();
      }
    }

    _gameConfigurationLoaded = true;
  }

  Future<void> _saveQuestionnaire() async {
    if (_isScenarioLocked) {
      _showLockedSnackBar();
      return;
    }

    if (_isQuestionnaireSaving) return;

    setState(() {
      _isQuestionnaireSaving = true;
    });

    try {
      final sideQuestions = List<Map<String, dynamic>>.generate(5, (index) {
        return {
          'slot': index + 1,
          'placeId': (_sideQuestionPlaceIds[index] ?? '').trim(),
          'question': _sideQuestionCtrls[index].text.trim(),
        };
      });

      await _gameRef.set({
        'finalQuestionnaire': {
          'mainQuestions': {
            'killer': _killerQuestionCtrl.text.trim(),
            'motive': _motiveQuestionCtrl.text.trim(),
            'A0': _a0QuestionCtrl.text.trim(),
            'B0': _b0QuestionCtrl.text.trim(),
            'C0': _c0QuestionCtrl.text.trim(),
          },
          'sideQuestions': sideQuestions,
        },
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questionnaire final sauvegardé.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pendant la sauvegarde du questionnaire : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isQuestionnaireSaving = false;
        });
      }
    }
  }

  void _updateSideQuestionPlace(int index, String? value) {
    if (_isScenarioLocked) {
      _showLockedSnackBar();
      return;
    }

    setState(() {
      _sideQuestionPlaceIds[index] = value;
    });
  }

  Future<void> _save() async {
    if (_isScenarioLocked) {
      _showLockedSnackBar();
      return;
    }

    if (_selectedId == null || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _placesRef.doc(_selectedId).update({
        'title': _nameCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'storySynopsis': _synopsisCtrl.text.trim(),
        'synopsis': _synopsisCtrl.text.trim(),
        'mediaNotes': _mediaNotesCtrl.text.trim(),
        'mediaDescription': _mediaNotesCtrl.text.trim(),
        'keywords': _keywords,
      });

      await _gameRef.set({
        'gameRules': _gameRulesCtrl.text.trim(),
        'briefing': _briefingCtrl.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lieu et textes globaux sauvegardés.')),
      );

      setState(() {
        if (_selectedData != null) {
          _selectedData = {
            ..._selectedData!,
            'title': _nameCtrl.text.trim(),
            'name': _nameCtrl.text.trim(),
            'storySynopsis': _synopsisCtrl.text.trim(),
            'synopsis': _synopsisCtrl.text.trim(),
            'mediaNotes': _mediaNotesCtrl.text.trim(),
            'mediaDescription': _mediaNotesCtrl.text.trim(),
            'keywords': _keywords,
          };
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pendant la sauvegarde : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _buildLockIssuesSummary(List<ScenarioValidationIssue> issues) {
    if (issues.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (final issue in issues) {
      final parts = <String>[];
      if (issue.itemId != null && issue.itemId!.trim().isNotEmpty) {
        parts.add(issue.itemId!.trim());
      }
      if (issue.field != null && issue.field!.trim().isNotEmpty) {
        parts.add(issue.field!.trim());
      }

      final suffix = parts.isEmpty ? '' : ' (${parts.join(' • ')})';
      buffer.writeln('• ${issue.message}$suffix');
    }

    return buffer.toString().trim();
  }

  Future<void> _showLockResultDialog(ScenarioLockResult result) async {
    final errors = result.errors;
    final warnings = result.warnings;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B25),
          title: Text(
            result.success ? 'Scénario verrouillé' : 'Lock refusé',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (result.success) ...[
                    const Text(
                      'Le snapshot locké a bien été créé dans lockedScenarios.',
                      style: TextStyle(
                        color: Color(0xFFB8C3D6),
                        height: 1.45,
                      ),
                    ),
                    if ((result.lockedScenarioId ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        'ID lock: ${result.lockedScenarioId}',
                        style: const TextStyle(
                          color: Color(0xFFAED0FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      'Le scénario n’est pas suffisamment complet pour être verrouillé.',
                      style: TextStyle(
                        color: Color(0xFFB8C3D6),
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Erreurs bloquantes',
                      style: TextStyle(
                        color: Color(0xFFFFD7B8),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _buildLockIssuesSummary(errors),
                      style: const TextStyle(
                        color: Color(0xFFFFD7B8),
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Warnings',
                      style: TextStyle(
                        color: Color(0xFFAED0FF),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _buildLockIssuesSummary(warnings),
                      style: const TextStyle(
                        color: Color(0xFFAED0FF),
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD65A00),
                foregroundColor: Colors.white,
              ),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _requestAdminValidation() async {
    if (_adminPasswordValidatedForSession) {
      return true;
    }

    final canLock = widget.profile.role == PortalUserRole.admin;
    if (!canLock) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seul un administrateur peut verrouiller un scénario.'),
          ),
        );
      }
      return false;
    }

    setState(() {
      _adminPasswordValidatedForSession = true;
    });
    return true;
  }

  Future<void> _lockScenario() async {
    if (_isScenarioLocked || _isLocking) return;

    final granted = await _requestAdminValidation();
    if (!granted) return;

    setState(() {
      _isLocking = true;
    });

    try {
      final result = await _scenarioLockService.lockCurrentScenario(
        lockedBy: 'admin_portal',
      );

      if (!mounted) return;

      setState(() {
        _lockIssues = result.issues;
        if ((result.lockedScenarioId ?? '').isNotEmpty) {
          _lastLockedScenarioId = result.lockedScenarioId;
        }
      });

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.warnings.isEmpty
                  ? 'Scénario verrouillé avec succès.'
                  : 'Scénario verrouillé avec warnings.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lock refusé: ${result.errors.length} erreur(s) bloquante(s).',
            ),
          ),
        );
      }

      await _showLockResultDialog(result);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pendant le verrouillage : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLocking = false;
        });
      }
    }
  }

  String _siteLabel(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final label = (data['title'] ?? data['name'] ?? doc.id).toString().trim();
    return label.isEmpty ? doc.id : label;
  }

  Future<void> _toggleSiteFreeze({
    required String siteId,
    required bool frozen,
  }) async {
    await _sitesRef.doc(siteId).set({
      'coordinatesFrozen': frozen,
      'coordinatesFrozenAt': DateTime.now().toIso8601String(),
      'coordinatesFrozenBy': 'admin_portal',
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveSitePlaceCoordinates({
    required String siteId,
    required String placeId,
    required Map<String, dynamic> templateData,
    required String latText,
    required String lngText,
  }) async {
    final lat = double.tryParse(latText.replaceAll(',', '.').trim());
    final lng = double.tryParse(lngText.replaceAll(',', '.').trim());
    final title = (templateData['title'] ?? templateData['name'] ?? placeId)
        .toString()
        .trim();

    await _sitePlacesRef(siteId).doc(placeId).set({
      'id': placeId,
      'templateId': placeId,
      'title': title,
      'name': title,
      'lat': lat,
      'lng': lng,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> _validateCurrentSiteReadiness(String siteId) async {
    if (_isValidatingSiteReadiness) return;

    setState(() {
      _isValidatingSiteReadiness = true;
    });

    try {
      final result = await _siteReadinessService.validateSite(siteId);

      if (!mounted) return;

      setState(() {
        _currentSiteReadinessResult = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isReady
                ? 'Site validé: prêt à jouer.'
                : 'Site non prêt: ${result.errors.length} erreur(s) bloquante(s).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pendant la validation du site : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingSiteReadiness = false;
        });
      }
    }
  }

  Future<void> _unlockScenario() async {
    if (_isUnlocking) return;

    final canUnlock = widget.profile.role == PortalUserRole.admin;
    if (!canUnlock) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seul un admin peut déverrouiller le scénario.'),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B25),
          title: const Text(
            'Déverrouiller le scénario',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Le créateur redeviendra modifiable pour tous les rôles autorisés. Continuer ?',
            style: TextStyle(color: Color(0xFFB8C3D6), height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD65A00),
                foregroundColor: Colors.white,
              ),
              child: const Text('Déverrouiller'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isUnlocking = true;
    });

    try {
      await _scenarioLockService.unlockCurrentScenario(
        unlockedBy: 'admin_portal',
      );

      if (!mounted) return;
      setState(() {
        _lastLockedScenarioId = null;
        _lockIssues = const <ScenarioValidationIssue>[];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scénario déverrouillé.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      final message = e.code == 'permission-denied'
          ? 'Seul un administrateur peut déverrouiller le scénario.'
          : 'Erreur pendant le déverrouillage : ${e.message ?? e.code}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pendant le déverrouillage : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUnlocking = false;
        });
      }
    }
  }

  Future<void> _createSite(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> templateDocs,
  ) async {
    if (_isCreatingSite) return;

    final idCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    String? errorText;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151B25),
              title: const Text(
                'Créer un nouveau site',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Crée un site puis initialise automatiquement sa collection places à partir des 19 placeTemplates.',
                      style: TextStyle(
                        color: Color(0xFFB8C3D6),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: idCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Identifiant du site',
                        hintText: 'ex: sion, geneve, site_test',
                        errorText: errorText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nom affiché',
                        hintText: 'ex: Sion',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    final rawId = idCtrl.text.trim().toLowerCase();
                    final siteId = rawId
                        .replaceAll(RegExp(r'\s+'), '_')
                        .replaceAll(RegExp(r'[^a-z0-9_-]'), '');
                    final title = titleCtrl.text.trim();

                    if (siteId.isEmpty) {
                      setLocalState(() {
                        errorText = 'Identifiant invalide';
                      });
                      return;
                    }

                    Navigator.of(context).pop({
                      'siteId': siteId,
                      'title': title.isEmpty ? siteId : title,
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD65A00),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Créer le site'),
                ),
              ],
            );
          },
        );
      },
    );

    idCtrl.dispose();
    titleCtrl.dispose();

    if (result == null) return;

    final siteId = result['siteId']!;
    final title = result['title']!;

    setState(() {
      _isCreatingSite = true;
    });

    try {
      final existingSite = await _sitesRef.doc(siteId).get();
      if (existingSite.exists) {
        throw Exception('Le site "$siteId" existe déjà.');
      }

      final batch = FirebaseFirestore.instance.batch();
      final siteRef = _sitesRef.doc(siteId);
      final now = DateTime.now().toIso8601String();

      batch.set(siteRef, {
        'id': siteId,
        'title': title,
        'name': title,
        'gameId': 'les_fugitifs',
        'coordinatesFrozen': false,
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      for (final doc in templateDocs) {
        final placeRef = siteRef.collection('places').doc(doc.id);
        batch.set(placeRef, {
          'id': doc.id,
          'templateId': doc.id,
          'lat': null,
          'lng': null,
          'createdAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _selectedSiteId = siteId;
        _currentSiteReadinessResult = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Site "$title" créé avec ${templateDocs.length} lieux.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pendant la création du site : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingSite = false;
        });
      }
    }
  }

  void _openPrintView() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreatorPrintScreen(),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final copy = [...docs];
    copy.sort((a, b) => a.id.compareTo(b.id));
    return copy;
  }

  List<String> _questionnaireAvailablePlaceIds(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final ids = docs.map((doc) => doc.id).where((id) {
      return id != 'A0' && id != 'B0' && id != 'C0' && id != 'D0';
    }).toList();
    ids.sort();
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Text(
          'Créateur de scénario',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_isScenarioLocked && widget.profile.role == PortalUserRole.admin)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: _isUnlocking ? null : _unlockScenario,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD65A00),
                  foregroundColor: Colors.white,
                ),
                icon: _isUnlocking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_open_rounded),
                label: Text(_isUnlocking ? 'Déverrouillage...' : 'Déverrouiller'),
              ),
            )
          else if (_isScenarioLocked)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Déverrouillage réservé à l’admin',
                  style: TextStyle(
                    color: Color(0xFFFFD7B8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Scénario'),
            Tab(text: 'Sites'),
            Tab(text: 'Médias'),
            Tab(text: 'Suspects & Mobiles'),
            Tab(text: 'Questionnaire'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _placesRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur Firestore : ${snapshot.error}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 18,
                  ),
                ),
              ),
            );
          }

          final docs = _sortedDocs(snapshot.data?.docs ?? []);
          final docsById = <String, Map<String, dynamic>>{
            for (final doc in docs) doc.id: doc.data(),
          };

          if (_selectedId == null && docs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _selectedId != null) return;
              _selectDoc(docs.first);
            });
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _gameRef.snapshots(),
            builder: (context, gameSnapshot) {
              if (gameSnapshot.connectionState == ConnectionState.waiting &&
                  !gameSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (gameSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erreur Firestore (game) : ${gameSnapshot.error}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 18,
                      ),
                    ),
                  ),
                );
              }

              final gameData = gameSnapshot.data?.data();
              final isScenarioLocked = gameData?['creatorLocked'] == true;
              final isAdmin = widget.profile.role == PortalUserRole.admin;

              if (_isScenarioLocked != isScenarioLocked) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _isScenarioLocked = isScenarioLocked;
                  });
                });
              }

              _syncGameConfiguration(gameData);

              return TabBarView(
                controller: _tabController,
                children: [
                  _wrapCreatorTabLocked(
                    locked: isScenarioLocked,
                    child: CreatorScenarioTab(
                      docs: docs,
                      docsById: docsById,
                      selectedId: _selectedId,
                      selectedData: _selectedData,
                      nameCtrl: _nameCtrl,
                      synopsisCtrl: _synopsisCtrl,
                      mediaNotesCtrl: _mediaNotesCtrl,
                      keywordCtrl: _keywordCtrl,
                      keywords: _keywords,
                      gameRulesCtrl: _gameRulesCtrl,
                      briefingCtrl: _briefingCtrl,
                      isSaving: _isSaving,
                      isLocking: _isLocking,
                      lockIssues: _lockIssues,
                      lastLockedScenarioId: _lastLockedScenarioId,
                      groupColorBuilder: _groupColor,
                      experienceTypeBuilder: _experienceType,
                      experienceLabelBuilder: _experienceLabel,
                      displayNameBuilder: _displayName,
                      revealedCategoriesReader: _readDisplayRevealCategories,
                      revealedSummaryBuilder: _revealedInfoSummary,
                      onSelectDoc: _selectDoc,
                      onSelectFromMap: _selectFromMap,
                      onAddKeyword: _addKeyword,
                      onRemoveKeyword: _removeKeyword,
                      onSave: (_isSaving || isScenarioLocked) ? null : () => _save(),
                      onLockScenario: (!isAdmin || _isLocking || isScenarioLocked) ? null : () => _lockScenario(),
                      onOpenPrintView: _openPrintView,
                    ),
                  ),
                  _buildSitesTab(docs),
                  _buildMediaTab(),
                  _wrapCreatorTabLocked(locked: isScenarioLocked, child: _buildSuspectsMotivesTab()),
                  _wrapCreatorTabLocked(
                    locked: isScenarioLocked,
                    child: CreatorQuestionnaireTab(
                      availablePlaceIds: _questionnaireAvailablePlaceIds(docs),
                      killerQuestionCtrl: _killerQuestionCtrl,
                      motiveQuestionCtrl: _motiveQuestionCtrl,
                      a0QuestionCtrl: _a0QuestionCtrl,
                      b0QuestionCtrl: _b0QuestionCtrl,
                      c0QuestionCtrl: _c0QuestionCtrl,
                      sideQuestionCtrls: _sideQuestionCtrls,
                      sideQuestionPlaceIds: _sideQuestionPlaceIds,
                      isSaving: _isQuestionnaireSaving,
                      onSave: isScenarioLocked ? () {} : _saveQuestionnaire,
                      onSideQuestionPlaceChanged: _updateSideQuestionPlace,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSitesTab(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> templateDocs,
  ) {
    return CreatorSitesTab(
      templateDocs: templateDocs,
      selectedSiteId: _selectedSiteId,
      isCreatingSite: _isCreatingSite,
      isValidatingReadiness: _isValidatingSiteReadiness,
      currentReadinessResult: _currentSiteReadinessResult != null &&
              _currentSiteReadinessResult!.siteId == _selectedSiteId
          ? _currentSiteReadinessResult
          : null,
      sitesStream: _sitesRef.snapshots(),
      sitePlacesStreamBuilder: (siteId) => _sitePlacesRef(siteId).snapshots(),
      siteLabelBuilder: _siteLabel,
      groupColorBuilder: _groupColor,
      onSelectSite: (value) {
        setState(() {
          _selectedSiteId = value;
          _currentSiteReadinessResult = null;
        });
      },
      onCreateSite: () => _createSite(templateDocs),
      onValidateReadiness: (siteId) => _validateCurrentSiteReadiness(siteId),
      onFreezeSite: (siteId) async {
        await _toggleSiteFreeze(siteId: siteId, frozen: true);
      },
      onUnfreezeSite: (siteId) async {
        await _toggleSiteFreeze(siteId: siteId, frozen: false);
      },
      onSaveSitePlaceCoordinates: ({
        required String siteId,
        required String placeId,
        required Map<String, dynamic> templateData,
        required String latText,
        required String lngText,
      }) async {
        await _saveSitePlaceCoordinates(
          siteId: siteId,
          placeId: placeId,
          templateData: templateData,
          latText: latText,
          lngText: lngText,
        );
      },
    );
  }


  Widget _buildMediaTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _scenarioMediaSlotDefinitionsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur Firestore (définitions médias) : ${snapshot.error}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 18,
                ),
              ),
            ),
          );
        }

        final slotDefinitionDocs =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        );

        final mediaTab = CreatorMediaTab(
          slotDefinitionDocs: slotDefinitionDocs,
          selectedScenarioId: _selectedMediaScenarioId,
          isLoadingAction: _isMediaActionLoading,
          isAdmin: widget.profile.role == PortalUserRole.admin,
          scenariosStream: _scenariosRef.snapshots(),
          scenarioMediaSlotsStreamBuilder: (scenarioId) =>
              _scenarioMediaSlotsRef(scenarioId).snapshots(),
          scenarioLabelBuilder: _scenarioLabel,
          onSelectScenario: (value) {
            setState(() {
              _selectedMediaScenarioId = value;
            });
          },
          onFreezeMedia: (scenarioId) async {
            await _toggleMediaFreeze(scenarioId: scenarioId, frozen: true);
          },
          onUnfreezeMedia: (scenarioId) async {
            await _toggleMediaFreeze(scenarioId: scenarioId, frozen: false);
          },
          onUploadOrReplaceMedia: ({
            required String scenarioId,
            required String slotId,
            required Map<String, dynamic> slotDefinitionData,
          }) async {
            final acceptedTypes =
                (slotDefinitionData['acceptedTypes'] as List<dynamic>? ?? const [])
                    .map((e) => e.toString())
                    .where((e) => e.trim().isNotEmpty)
                    .toList();

            final slotKey =
                (slotDefinitionData['slotKey'] ?? slotId).toString().trim();
            final blockId =
                (slotDefinitionData['blockId'] ?? '').toString().trim();

            Timer? loaderTimer;

            try {
              loaderTimer = Timer(const Duration(milliseconds: 180), () {
                if (!mounted) return;
                setState(() {
                  _isMediaActionLoading = true;
                });
              });

              final result = await _mediaAdminService.uploadAndAssignMedia(
                scenarioId: scenarioId,
                slotId: slotId,
                slotKey: slotKey,
                acceptedTypes: acceptedTypes,
                blockId: blockId.isEmpty ? null : blockId,
                actorLabel: 'creator_portal',
              );

              loaderTimer.cancel();

              if (!mounted || result.cancelled) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.success
                        ? 'Média téléversé : ${result.fileName ?? "fichier"}'
                        : 'Téléversement annulé.',
                  ),
                ),
              );
            } catch (e) {
              loaderTimer?.cancel();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur pendant le téléversement média : $e'),
                ),
              );
            } finally {
              loaderTimer?.cancel();
              if (mounted) {
                setState(() {
                  _isMediaActionLoading = false;
                });
              }
            }
          },
          onRemoveMedia: ({
            required String scenarioId,
            required String slotId,
            required Map<String, dynamic> slotDefinitionData,
          }) async {
            final title = (slotDefinitionData['label'] ??
                    slotDefinitionData['title'] ??
                    slotDefinitionData['name'] ??
                    slotId)
                .toString()
                .trim();

            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  backgroundColor: const Color(0xFF151B25),
                  title: const Text(
                    'Retirer le média',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Text(
                    'Cette action retire le média actif du slot "$title" et supprime le fichier associé.',
                    style: const TextStyle(
                      color: Color(0xFFB8C3D6),
                      height: 1.45,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB3261E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retirer'),
                    ),
                  ],
                );
              },
            );

            if (confirmed != true) return;

            setState(() {
              _isMediaActionLoading = true;
            });

            try {
              await _mediaAdminService.removeActiveMediaFromSlot(
                slotId: slotId,
                actorLabel: 'creator_portal',
              );

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Média retiré pour "$title".'),
                ),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur pendant le retrait du média : $e'),
                ),
              );
            } finally {
              if (mounted) {
                setState(() {
                  _isMediaActionLoading = false;
                });
              }
            }
          },
        );

        return Stack(
          children: [
            mediaTab,
            if (_isMediaActionLoading)
              Positioned.fill(
                child: Container(
                  color: const Color(0xB307111F),
                  alignment: Alignment.center,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111D32),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF263854)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFFD65A00),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Upload média en cours',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Le fichier est en train d’être envoyé et relié au slot. Merci de patienter quelques secondes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB8C3D6),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _seedMediaStructure() async {
    if (_isMediaStructureSeeding) return;

    final scenarioId = (_selectedMediaScenarioId ?? '').trim();
    if (scenarioId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choisis d’abord un scénario dans l’onglet Médias avant d’initialiser la structure.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isMediaStructureSeeding = true;
    });

    try {
      final result = await _mediaStructureSeedService.seedScenario(
        scenarioId: scenarioId,
        actorLabel: 'creator_portal',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Structure médias initialisée pour $scenarioId : '
            '${result.blocksCreated} bloc(s), '
            '${result.slotDefinitionsCreated} définition(s), '
            '${result.slotsCreated} slot(s) créés.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur pendant l’initialisation de la structure médias : $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMediaStructureSeeding = false;
        });
      }
    }
  }

  String _scenarioLabel(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final label =
        (data['title'] ?? data['name'] ?? data['label'] ?? doc.id).toString().trim();
    return label.isEmpty ? doc.id : label;
  }

  Future<void> _toggleMediaFreeze({
    required String scenarioId,
    required bool frozen,
  }) async {
    await _scenariosRef.doc(scenarioId).set({
      'mediaFrozen': frozen,
      'mediaFrozenAt': DateTime.now().toIso8601String(),
      'mediaFrozenBy': 'admin_portal',
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  String _normalizeEntityId(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '');
  }

  String _normalizeUniqueText(String raw) {
    return raw.trim().toLowerCase();
  }

  int? _parseOptionalInt(String raw) {
    return int.tryParse(raw.trim());
  }

  String _readEntityImagePath(Map<String, dynamic> data) {
    final imagePath =
        (data['imagePath'] ?? data['image'] ?? '').toString().trim();
    return imagePath;
  }

  String _creatorImageStoragePath({
    required String folder,
    required String entityId,
  }) {
    return 'games/les_fugitifs/assets/$folder/$entityId.png';
  }

  Future<String> _uploadCreatorImageToStorage({
    required String folder,
    required String entityId,
    required PickedCreatorImage pickedImage,
  }) async {
    final storagePath = _creatorImageStoragePath(
      folder: folder,
      entityId: entityId,
    );

    final ref = FirebaseStorage.instance.ref(storagePath);

    await ref.putData(
      pickedImage.bytes,
      SettableMetadata(
        contentType:
            pickedImage.mimeType.isEmpty ? 'image/png' : pickedImage.mimeType,
        customMetadata: {
          'uploadedBy': 'creator_portal',
          'originalFileName': pickedImage.fileName,
        },
      ),
    );

    return storagePath;
  }

  Future<void> _deleteCreatorImageFromStorage(String imagePath) async {
    final trimmed = imagePath.trim();
    if (trimmed.isEmpty) return;

    try {
      await FirebaseStorage.instance.ref(trimmed).delete();
    } catch (_) {
      // Ignore missing files or stale paths. Firestore remains the source of truth.
    }
  }

  String? _findDuplicateFieldOwner({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String field,
    required dynamic value,
    required String? excludeId,
  }) {
    if (value == null) return null;
    final normalized = value is String ? _normalizeUniqueText(value) : value;

    for (final doc in docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final data = doc.data();
      final other = data[field];
      final normalizedOther =
          other is String ? _normalizeUniqueText(other) : other;
      if (normalizedOther == normalized) {
        return (data['name'] ?? doc.id).toString();
      }
    }
    return null;
  }

  List<String> _buildDuplicateFieldMessages({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required List<String> fields,
  }) {
    final messages = <String>[];

    for (final field in fields) {
      final owners = <String, List<String>>{};
      for (final doc in docs) {
        final data = doc.data();
        final raw = data[field];
        if (raw == null) continue;
        final key = raw is String ? _normalizeUniqueText(raw) : raw.toString();
        if (key.trim().isEmpty) continue;
        owners.putIfAbsent(key, () => []).add((data['name'] ?? doc.id).toString());
      }

      for (final entry in owners.entries) {
        if (entry.value.length > 1) {
          messages.add('$field en doublon : ${entry.value.join(", ")}');
        }
      }
    }

    return messages;
  }

  Future<void> _deleteEntity({
    required String label,
    required DocumentReference<Map<String, dynamic>> ref,
  }) async {
    if (_isScenarioLocked) {
      _showLockedSnackBar();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B25),
          title: Text(
            'Supprimer $label',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            'Cette action supprime définitivement "$label".',
            style: const TextStyle(color: Color(0xFFB8C3D6)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB3261E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await ref.delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label supprimé.')),
    );
  }

  Future<void> _openSuspectDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  }) async {
    if (_isScenarioLocked) {
      _showLockedSnackBar();
      return;
    }

    if (doc == null && allDocs.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu as déjà 6 suspects. Supprime-en un avant d’en créer un nouveau.',
          ),
        ),
      );
      return;
    }

    final data = doc?.data() ?? <String, dynamic>{};
    final idCtrl = TextEditingController(text: doc?.id ?? '');
    final nameCtrl = TextEditingController(text: (data['name'] ?? '').toString());
    final ageCtrl = TextEditingController(text: (data['age'] ?? '').toString());
    final professionCtrl =
        TextEditingController(text: (data['profession'] ?? '').toString());
    final buildCtrl = TextEditingController(text: (data['build'] ?? '').toString());

    String imagePath = _readEntityImagePath(data);
    PickedCreatorImage? pendingImage;
    bool removeExistingImage = false;
    String? errorText;
    bool isPersisting = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: !isPersisting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Widget buildPreview() {
              if (pendingImage != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    pendingImage!.bytes,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                );
              }

              if (imagePath.isNotEmpty && !removeExistingImage) {
                return CreatorStorageImagePreview(
                  storagePath: imagePath,
                  width: 120,
                  height: 120,
                  borderRadius: 16,
                  emptyLabel: 'Introuvable',
                );
              }

              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1A2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF263854)),
                ),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFFAAB7C8),
                      size: 34,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'PNG manquant',
                      style: TextStyle(
                        color: Color(0xFFAAB7C8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }

            final hasVisibleImage = pendingImage != null ||
                (imagePath.isNotEmpty && !removeExistingImage);
            final imageStatusLabel = pendingImage != null
                ? pendingImage!.fileName
                : hasVisibleImage
                    ? imagePath.split('/').last
                    : 'Aucune image sélectionnée';

            return AlertDialog(
              backgroundColor: const Color(0xFF151B25),
              title: Text(
                doc == null ? 'Ajouter un suspect' : 'Modifier le suspect',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: idCtrl,
                        enabled: doc == null && !isPersisting,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'ID',
                          hintText: 'ex: anna',
                          errorText: errorText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        enabled: !isPersisting,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Nom'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ageCtrl,
                        enabled: !isPersisting,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Âge'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: professionCtrl,
                        enabled: !isPersisting,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Profession'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: buildCtrl,
                        enabled: !isPersisting,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            const InputDecoration(labelText: 'Gabarit / Build'),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111D32),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF263854)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Image PNG du suspect',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Téléverse un PNG. Conseil: 1024 px max sur le plus grand côté et 500 Ko environ pour garder le portal léger.',
                              style: TextStyle(
                                color: Color(0xFFAAB7C8),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildPreview(),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0A1424),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0xFF223250),
                                          ),
                                        ),
                                        child: Text(
                                          imageStatusLabel,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFAED0FF),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          FilledButton.icon(
                                            onPressed: isPersisting
                                                ? null
                                                : () async {
                                                    final picked =
                                                        await pickPngImage();
                                                    if (picked == null) return;
                                                    setLocalState(() {
                                                      pendingImage = picked;
                                                      removeExistingImage = false;
                                                      errorText = null;
                                                    });
                                                  },
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFD65A00),
                                              foregroundColor: Colors.white,
                                            ),
                                            icon: const Icon(Icons.upload_file),
                                            label: Text(
                                              hasVisibleImage
                                                  ? 'Remplacer le PNG'
                                                  : 'Téléverser un PNG',
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed:
                                                isPersisting || !hasVisibleImage
                                                    ? null
                                                    : () {
                                                        setLocalState(() {
                                                          pendingImage = null;
                                                          removeExistingImage =
                                                              imagePath.isNotEmpty;
                                                        });
                                                      },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  const Color(0xFFFFD7B8),
                                              side: const BorderSide(
                                                color: Color(0xFF4A2B1D),
                                              ),
                                            ),
                                            icon:
                                                const Icon(Icons.delete_outline),
                                            label: const Text('Retirer'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isPersisting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: isPersisting
                      ? null
                      : () async {
                          final suspectId =
                              doc?.id ?? _normalizeEntityId(idCtrl.text);
                          final suspectName = nameCtrl.text.trim();
                          final suspectAge = _parseOptionalInt(ageCtrl.text);
                          final suspectProfession = professionCtrl.text.trim();
                          final suspectBuild = buildCtrl.text.trim();

                          if (suspectId.isEmpty || suspectName.isEmpty) {
                            setLocalState(() {
                              errorText = 'ID et nom obligatoires';
                            });
                            return;
                          }

                          if (doc == null &&
                              allDocs.any((element) => element.id == suspectId)) {
                            setLocalState(() {
                              errorText = 'Cet ID existe déjà';
                            });
                            return;
                          }

                          final duplicateAge = _findDuplicateFieldOwner(
                            docs: allDocs,
                            field: 'age',
                            value: suspectAge,
                            excludeId: doc?.id,
                          );
                          if (duplicateAge != null) {
                            setLocalState(() {
                              errorText = 'Âge déjà utilisé par $duplicateAge';
                            });
                            return;
                          }

                          final duplicateProfession = _findDuplicateFieldOwner(
                            docs: allDocs,
                            field: 'profession',
                            value: suspectProfession,
                            excludeId: doc?.id,
                          );
                          if (duplicateProfession != null) {
                            setLocalState(() {
                              errorText =
                                  'Profession déjà utilisée par $duplicateProfession';
                            });
                            return;
                          }

                          final duplicateBuild = _findDuplicateFieldOwner(
                            docs: allDocs,
                            field: 'build',
                            value: suspectBuild,
                            excludeId: doc?.id,
                          );
                          if (duplicateBuild != null) {
                            setLocalState(() {
                              errorText =
                                  'Build déjà utilisé par $duplicateBuild';
                            });
                            return;
                          }

                          setLocalState(() {
                            isPersisting = true;
                            errorText = null;
                          });

                          try {
                            String finalImagePath = imagePath;

                            if (pendingImage != null) {
                              finalImagePath = await _uploadCreatorImageToStorage(
                                folder: 'suspects',
                                entityId: suspectId,
                                pickedImage: pendingImage!,
                              );
                            } else if (removeExistingImage) {
                              await _deleteCreatorImageFromStorage(imagePath);
                              finalImagePath = '';
                            }

                            if (!context.mounted) return;

                            Navigator.of(context).pop({
                              'id': suspectId,
                              'name': suspectName,
                              'age': suspectAge,
                              'profession': suspectProfession,
                              'build': suspectBuild,
                              'image': finalImagePath,
                              'imagePath': finalImagePath,
                            });
                          } catch (e) {
                            setLocalState(() {
                              isPersisting = false;
                              errorText =
                                  'Erreur pendant le téléversement du PNG';
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD65A00),
                    foregroundColor: Colors.white,
                  ),
                  child: isPersisting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sauvegarder'),
                ),
              ],
            );
          },
        );
      },
    );

    idCtrl.dispose();
    nameCtrl.dispose();
    ageCtrl.dispose();
    professionCtrl.dispose();
    buildCtrl.dispose();

    if (result == null) return;

    final ref = _suspectsRef.doc(result['id'] as String);
    final now = DateTime.now().toIso8601String();

    await ref.set({
      'id': result['id'],
      'name': result['name'],
      'age': result['age'],
      'profession': result['profession'],
      'build': result['build'],
      'image': result['image'],
      'imagePath': result['imagePath'],
      'updatedAt': now,
      if (doc == null) 'createdAt': now,
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          doc == null
              ? 'Suspect ${result['name']} créé.'
              : 'Suspect ${result['name']} mis à jour.',
        ),
      ),
    );
  }

  Future<void> _openMotiveDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  }) async {
    if (_isScenarioLocked) {
      _showLockedSnackBar();
      return;
    }

    if (doc == null && allDocs.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu as déjà 6 mobiles. Supprime-en un avant d’en créer un nouveau.',
          ),
        ),
      );
      return;
    }

    final data = doc?.data() ?? <String, dynamic>{};
    final idCtrl = TextEditingController(text: doc?.id ?? '');
    final nameCtrl = TextEditingController(text: (data['name'] ?? '').toString());
    final violenceCtrl =
        TextEditingController(text: (data['violence'] ?? '').toString());
    final delaysCtrl =
        TextEditingController(text: (data['delays'] ?? '').toString());
    final preparationsCtrl =
        TextEditingController(text: (data['preparations'] ?? '').toString());

    String imagePath = _readEntityImagePath(data);
    PickedCreatorImage? pendingImage;
    bool removeExistingImage = false;
    String? errorText;
    bool isPersisting = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: !isPersisting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Widget buildPreview() {
              if (pendingImage != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    pendingImage!.bytes,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                );
              }

              if (imagePath.isNotEmpty && !removeExistingImage) {
                return CreatorStorageImagePreview(
                  storagePath: imagePath,
                  width: 120,
                  height: 120,
                  borderRadius: 16,
                  emptyLabel: 'Introuvable',
                );
              }

              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1A2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF263854)),
                ),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFFAAB7C8),
                      size: 34,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'PNG manquant',
                      style: TextStyle(
                        color: Color(0xFFAAB7C8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }

            final hasVisibleImage = pendingImage != null ||
                (imagePath.isNotEmpty && !removeExistingImage);
            final imageStatusLabel = pendingImage != null
                ? pendingImage!.fileName
                : hasVisibleImage
                    ? imagePath.split('/').last
                    : 'Aucune image sélectionnée';

            return AlertDialog(
              backgroundColor: const Color(0xFF151B25),
              title: Text(
                doc == null ? 'Ajouter un mobile' : 'Modifier le mobile',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: idCtrl,
                        enabled: doc == null && !isPersisting,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'ID',
                          hintText: 'ex: amour',
                          errorText: errorText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        enabled: !isPersisting,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Nom'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: violenceCtrl,
                        enabled: !isPersisting,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Violence'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: delaysCtrl,
                        enabled: !isPersisting,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Délais'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: preparationsCtrl,
                        enabled: !isPersisting,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            const InputDecoration(labelText: 'Préparatifs'),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111D32),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF263854)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Image PNG du mobile',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Téléverse un PNG. Conseil: 1024 px max sur le plus grand côté et 500 Ko environ pour garder le portal léger.',
                              style: TextStyle(
                                color: Color(0xFFAAB7C8),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildPreview(),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0A1424),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0xFF223250),
                                          ),
                                        ),
                                        child: Text(
                                          imageStatusLabel,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFAED0FF),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          FilledButton.icon(
                                            onPressed: isPersisting
                                                ? null
                                                : () async {
                                                    final picked =
                                                        await pickPngImage();
                                                    if (picked == null) return;
                                                    setLocalState(() {
                                                      pendingImage = picked;
                                                      removeExistingImage = false;
                                                      errorText = null;
                                                    });
                                                  },
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFD65A00),
                                              foregroundColor: Colors.white,
                                            ),
                                            icon: const Icon(Icons.upload_file),
                                            label: Text(
                                              hasVisibleImage
                                                  ? 'Remplacer le PNG'
                                                  : 'Téléverser un PNG',
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed:
                                                isPersisting || !hasVisibleImage
                                                    ? null
                                                    : () {
                                                        setLocalState(() {
                                                          pendingImage = null;
                                                          removeExistingImage =
                                                              imagePath.isNotEmpty;
                                                        });
                                                      },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  const Color(0xFFFFD7B8),
                                              side: const BorderSide(
                                                color: Color(0xFF4A2B1D),
                                              ),
                                            ),
                                            icon:
                                                const Icon(Icons.delete_outline),
                                            label: const Text('Retirer'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isPersisting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: isPersisting
                      ? null
                      : () async {
                          final motiveId =
                              doc?.id ?? _normalizeEntityId(idCtrl.text);
                          final motiveName = nameCtrl.text.trim();
                          final motiveViolence = violenceCtrl.text.trim();
                          final motiveDelays = delaysCtrl.text.trim();
                          final motivePreparations = preparationsCtrl.text.trim();

                          if (motiveId.isEmpty || motiveName.isEmpty) {
                            setLocalState(() {
                              errorText = 'ID et nom obligatoires';
                            });
                            return;
                          }

                          if (doc == null &&
                              allDocs.any((element) => element.id == motiveId)) {
                            setLocalState(() {
                              errorText = 'Cet ID existe déjà';
                            });
                            return;
                          }

                          final duplicateViolence = _findDuplicateFieldOwner(
                            docs: allDocs,
                            field: 'violence',
                            value: motiveViolence,
                            excludeId: doc?.id,
                          );
                          if (duplicateViolence != null) {
                            setLocalState(() {
                              errorText =
                                  'Violence déjà utilisée par $duplicateViolence';
                            });
                            return;
                          }

                          final duplicateDelays = _findDuplicateFieldOwner(
                            docs: allDocs,
                            field: 'delays',
                            value: motiveDelays,
                            excludeId: doc?.id,
                          );
                          if (duplicateDelays != null) {
                            setLocalState(() {
                              errorText =
                                  'Délais déjà utilisés par $duplicateDelays';
                            });
                            return;
                          }

                          final duplicatePreparations = _findDuplicateFieldOwner(
                            docs: allDocs,
                            field: 'preparations',
                            value: motivePreparations,
                            excludeId: doc?.id,
                          );
                          if (duplicatePreparations != null) {
                            setLocalState(() {
                              errorText =
                                  'Préparatifs déjà utilisés par $duplicatePreparations';
                            });
                            return;
                          }

                          setLocalState(() {
                            isPersisting = true;
                            errorText = null;
                          });

                          try {
                            String finalImagePath = imagePath;

                            if (pendingImage != null) {
                              finalImagePath = await _uploadCreatorImageToStorage(
                                folder: 'motives',
                                entityId: motiveId,
                                pickedImage: pendingImage!,
                              );
                            } else if (removeExistingImage) {
                              await _deleteCreatorImageFromStorage(imagePath);
                              finalImagePath = '';
                            }

                            if (!context.mounted) return;

                            Navigator.of(context).pop({
                              'id': motiveId,
                              'name': motiveName,
                              'violence': motiveViolence,
                              'delays': motiveDelays,
                              'preparations': motivePreparations,
                              'image': finalImagePath,
                              'imagePath': finalImagePath,
                            });
                          } catch (e) {
                            setLocalState(() {
                              isPersisting = false;
                              errorText =
                                  'Erreur pendant le téléversement du PNG';
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD65A00),
                    foregroundColor: Colors.white,
                  ),
                  child: isPersisting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sauvegarder'),
                ),
              ],
            );
          },
        );
      },
    );

    idCtrl.dispose();
    nameCtrl.dispose();
    violenceCtrl.dispose();
    delaysCtrl.dispose();
    preparationsCtrl.dispose();

    if (result == null) return;

    final ref = _motivesRef.doc(result['id'] as String);
    final now = DateTime.now().toIso8601String();

    await ref.set({
      'id': result['id'],
      'name': result['name'],
      'violence': result['violence'],
      'delays': result['delays'],
      'preparations': result['preparations'],
      'image': result['image'],
      'imagePath': result['imagePath'],
      'updatedAt': now,
      if (doc == null) 'createdAt': now,
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          doc == null
              ? 'Mobile ${result['name']} créé.'
              : 'Mobile ${result['name']} mis à jour.',
        ),
      ),
    );
  }

  Widget _buildSuspectsMotivesTab() {
    return CreatorSuspectsMotivesTab(
      suspectsStream: _suspectsRef.snapshots(),
      motivesStream: _motivesRef.snapshots(),
      onAddSuspect: (allDocs) => _openSuspectDialog(allDocs: allDocs),
      onEditSuspect: (doc, allDocs) =>
          _openSuspectDialog(doc: doc, allDocs: allDocs),
      onDeleteSuspect: (label, id) => _deleteEntity(
        label: label,
        ref: _suspectsRef.doc(id),
      ),
      onAddMotive: (allDocs) => _openMotiveDialog(allDocs: allDocs),
      onEditMotive: (doc, allDocs) =>
          _openMotiveDialog(doc: doc, allDocs: allDocs),
      onDeleteMotive: (label, id) => _deleteEntity(
        label: label,
        ref: _motivesRef.doc(id),
      ),
      buildDuplicateFieldMessages: _buildDuplicateFieldMessages,
    );
  }
}
