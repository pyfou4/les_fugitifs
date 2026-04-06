import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/browser_site_preference.dart';
import '../services/portal_access_service.dart';
import '../widgets/header_brand.dart';
import 'admin/admin_actions_section.dart';
import 'admin/admin_batches_section.dart';
import 'admin/admin_cashier_site_section.dart';
import 'admin/admin_filters_section.dart';
import 'admin/admin_intro_section.dart';
import 'admin/admin_employees_section.dart';
import 'admin/admin_low_stock_alert_section.dart';
import 'admin/admin_scenarios_breakdown_section.dart';
import 'admin/admin_sites_breakdown_section.dart';
import 'admin/admin_stats_section.dart';

class AdminScreen extends StatefulWidget {
  final PortalAccessProfile profile;

  const AdminScreen({super.key, required this.profile});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isGenerating = false;
  String? _defaultSiteId;
  bool _siteLocked = false;

  DateTime? _startDate;
  DateTime? _endDate;

  String? _selectedSiteFilterId;
  String? _selectedScenarioFilterId;

  @override
  void initState() {
    super.initState();
    _loadSitePreferences();
  }

  void _loadSitePreferences() {
    setState(() {
      _defaultSiteId = BrowserSitePreference.getDefaultSiteId();
      _siteLocked = BrowserSitePreference.isLocked();
    });
  }

  Future<void> _setDefaultSite(String siteId, String siteTitle) async {
    BrowserSitePreference.setDefaultSiteId(siteId);

    if (!mounted) return;

    setState(() {
      _defaultSiteId = siteId;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Site par défaut défini : $siteTitle'),
      ),
    );
  }

  Future<void> _clearDefaultSite() async {
    BrowserSitePreference.clearDefaultSiteId();
    BrowserSitePreference.setLocked(false);

    if (!mounted) return;

    setState(() {
      _defaultSiteId = null;
      _siteLocked = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Site par défaut effacé pour ce navigateur.'),
      ),
    );
  }

  Future<void> _setSiteLocked(bool value) async {
    BrowserSitePreference.setLocked(value);

    if (!mounted) return;

    setState(() {
      _siteLocked = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Site verrouillé pour ce poste.'
              : 'Site déverrouillé pour ce poste.',
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final initialDate = _startDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);

      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final initialDate = _endDate ?? _startDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);

      if (_startDate != null && _startDate!.isAfter(_endDate!)) {
        _startDate = _endDate;
      }
    });
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  void _applyQuickRangeToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _startDate = today;
      _endDate = today;
    });
  }

  void _applyQuickRangeLast7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _endDate = today;
      _startDate = today.subtract(const Duration(days: 6));
    });
  }

  void _applyQuickRangeLast30Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _endDate = today;
      _startDate = today.subtract(const Duration(days: 29));
    });
  }

  void _applyQuickRangeThisYear() {
    final now = DateTime.now();

    setState(() {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _clearAllFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedSiteFilterId = null;
      _selectedScenarioFilterId = null;
    });
  }

  Future<void> _generateBatch() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();
      final batchId = 'batch_${now.millisecondsSinceEpoch}';
      final batchRef = firestore.collection('activationBatches').doc(batchId);

      await batchRef.set({
        'createdAt': now.toIso8601String(),
        'createdBy': 'admin_portal',
        'label':
            'Pool global ${now.day}/${now.month} ${_two(now.hour)}:${_two(now.minute)}',
        'status': 'active',
        'poolType': 'global',
        'countTotal': 1000,
        'countUnused': 1000,
        'countReserved': 0,
        'countUsed': 0,
      });

      final codesCollection = batchRef.collection('codes');

      WriteBatch writeBatch = firestore.batch();
      int operationCount = 0;
      final usedCodes = <String>{};

      for (int i = 0; i < 1000; i++) {
        String code;
        do {
          code = _generateCode(6);
        } while (usedCodes.contains(code));
        usedCodes.add(code);

        final docRef = codesCollection.doc(code);

        writeBatch.set(docRef, {
          'code': code,
          'status': 'unused',
          'durationHours': 5,
          'createdAt': now.toIso8601String(),
          'reservedAt': null,
          'reservedBy': null,
          'usedAt': null,
          'usedByDeviceId': null,
          'expiresAt': null,
          'issuedSiteId': null,
          'issuedScenarioId': null,
        });

        operationCount++;

        if (operationCount == 500) {
          await writeBatch.commit();
          writeBatch = firestore.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        await writeBatch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch global de 1000 codes généré avec succès.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur pendant la génération : $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  static const String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  static String _generateCode(int length) {
    final rand = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => _chars.codeUnitAt(rand.nextInt(_chars.length)),
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String _readPoolLabel(Map<String, dynamic> data) {
    final label = (data['label'] ?? '').toString().trim();
    if (label.isNotEmpty) return label;

    final poolType = (data['poolType'] ?? '').toString();
    if (poolType == 'global') return 'Pool global';

    return 'Batch';
  }

  static String _readPoolType(Map<String, dynamic> data) {
    final poolType = (data['poolType'] ?? '').toString();
    if (poolType.isNotEmpty) return poolType;

    final hasLegacySite = (data['siteId'] ?? '').toString().isNotEmpty;
    final hasLegacyScenario = (data['scenarioId'] ?? '').toString().isNotEmpty;

    if (hasLegacySite || hasLegacyScenario) {
      return 'legacy';
    }

    return 'global';
  }

  bool _isIssuedCode(Map<String, dynamic> data) {
    final issuedSiteId = (data['issuedSiteId'] ?? '').toString().trim();
    final status = (data['status'] ?? '').toString().trim();

    if (issuedSiteId.isEmpty) return false;
    return status == 'reserved' || status == 'used';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isInSelectedRange(DateTime? date) {
    if (date == null) return false;

    final day = DateTime(date.year, date.month, date.day);

    if (_startDate != null && day.isBefore(_startDate!)) {
      return false;
    }

    if (_endDate != null && day.isAfter(_endDate!)) {
      return false;
    }

    return true;
  }

  bool _matchesActiveFilters(Map<String, dynamic> data) {
    final reservedAt = _parseDate(data['reservedAt']);
    if (!_isInSelectedRange(reservedAt)) return false;

    final siteId = (data['issuedSiteId'] ?? '').toString().trim();
    final scenarioId = (data['issuedScenarioId'] ?? '').toString().trim();

    if (_selectedSiteFilterId != null && siteId != _selectedSiteFilterId) {
      return false;
    }

    if (_selectedScenarioFilterId != null &&
        scenarioId != _selectedScenarioFilterId) {
      return false;
    }

    return true;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _activePeriodLabel() {
    if (_startDate == null && _endDate == null) {
      return 'Toutes les dates';
    }
    return '${_formatDate(_startDate)} → ${_formatDate(_endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const HeaderBrand(),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('activationBatches')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, batchSnapshot) {
          if (batchSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (batchSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur Firestore : ${batchSnapshot.error}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }

          final batchDocs = batchSnapshot.data?.docs ?? [];

          int total = 0;
          int unused = 0;
          int reserved = 0;
          int used = 0;

          for (final doc in batchDocs) {
            final data = doc.data();
            final t = _readInt(data['countTotal'] ?? data['count']);
            final u = _readInt(data['countUnused'] ?? t);
            final r = _readInt(data['countReserved']);
            final us = _readInt(data['countUsed']);

            total += t;
            unused += u;
            reserved += r;
            used += us;
          }

          final lowStock = unused < 50;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collectionGroup('codes').snapshots(),
            builder: (context, codeSnapshot) {
              if (codeSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erreur Firestore (codes) : ${codeSnapshot.error}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }

              final codeDocs = codeSnapshot.data?.docs ?? [];

              final issuedBySite = <String, int>{};
              final issuedByScenario = <String, int>{};

              int emittedTotal = 0;

              for (final doc in codeDocs) {
                final data = doc.data();
                if (!_isIssuedCode(data)) continue;
                if (!_matchesActiveFilters(data)) continue;

                final siteId = (data['issuedSiteId'] ?? '').toString().trim();
                final scenarioId =
                    (data['issuedScenarioId'] ?? '').toString().trim();

                emittedTotal += 1;

                if (siteId.isNotEmpty) {
                  issuedBySite.update(
                    siteId,
                    (value) => value + 1,
                    ifAbsent: () => 1,
                  );
                }

                if (scenarioId.isNotEmpty) {
                  issuedByScenario.update(
                    scenarioId,
                    (value) => value + 1,
                    ifAbsent: () => 1,
                  );
                }
              }

              final issuedSiteEntries = issuedBySite.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final issuedScenarioEntries = issuedByScenario.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('sites').snapshots(),
                builder: (context, siteSnapshot) {
                  final siteDocs = siteSnapshot.data?.docs ?? [];
                  final siteNames = <String, String>{
                    for (final doc in siteDocs)
                      doc.id: (doc.data()['title'] ?? doc.id).toString(),
                  };

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('scenarios')
                        .snapshots(),
                    builder: (context, scenarioSnapshot) {
                      final scenarioDocs = scenarioSnapshot.data?.docs ?? [];
                      final scenarioNames = <String, String>{
                        for (final doc in scenarioDocs)
                          doc.id: (doc.data()['title'] ?? doc.id).toString(),
                      };

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AdminIntroSection(),
                            const SizedBox(height: 24),
                            AdminActionsSection(
                              isGenerating: _isGenerating,
                              onGenerateBatch: _isGenerating ? null : _generateBatch,
                              onReturnToCashier: () {
                                Navigator.pop(context);
                              },
                            ),
                            const SizedBox(height: 24),
                            AdminStatsSection(
                              total: total,
                              unused: unused,
                              reserved: reserved,
                              emittedTotal: emittedTotal,
                              lowStock: lowStock,
                            ),
                            const SizedBox(height: 20),
                            if (lowStock) const AdminLowStockAlertSection(),
                            if (lowStock) const SizedBox(height: 20),
                            AdminEmployeesSection(
                              currentProfile: widget.profile,
                            ),
                            const SizedBox(height: 24),
                            AdminCashierSiteSection(
                              defaultSiteId: _defaultSiteId,
                              siteLocked: _siteLocked,
                              siteSnapshot: siteSnapshot,
                              siteDocs: siteDocs,
                              onSetDefaultSite: _setDefaultSite,
                              onClearDefaultSite: _clearDefaultSite,
                              onSetSiteLocked: _setSiteLocked,
                            ),
                            const SizedBox(height: 24),
                            AdminFiltersSection(
                              startDate: _startDate,
                              endDate: _endDate,
                              activePeriodLabel: _activePeriodLabel(),
                              selectedSiteFilterId: _selectedSiteFilterId,
                              selectedScenarioFilterId:
                                  _selectedScenarioFilterId,
                              siteDocs: siteDocs,
                              scenarioDocs: scenarioDocs,
                              formatDate: _formatDate,
                              onPickStartDate: _pickStartDate,
                              onPickEndDate: _pickEndDate,
                              onApplyToday: _applyQuickRangeToday,
                              onApplyLast7Days: _applyQuickRangeLast7Days,
                              onApplyLast30Days: _applyQuickRangeLast30Days,
                              onApplyThisYear: _applyQuickRangeThisYear,
                              onClearDateRange: _clearDateRange,
                              onClearAllFilters: _clearAllFilters,
                              onSiteChanged: (value) {
                                setState(() {
                                  _selectedSiteFilterId = value;
                                });
                              },
                              onScenarioChanged: (value) {
                                setState(() {
                                  _selectedScenarioFilterId = value;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            AdminSitesBreakdownSection(
                              issuedSiteEntries: issuedSiteEntries,
                              siteNames: siteNames,
                            ),
                            const SizedBox(height: 24),
                            AdminScenariosBreakdownSection(
                              issuedScenarioEntries: issuedScenarioEntries,
                              scenarioNames: scenarioNames,
                            ),
                            const SizedBox(height: 24),
                            AdminBatchesSection(
                              batchDocs: batchDocs,
                              readInt: _readInt,
                              readPoolLabel: _readPoolLabel,
                              readPoolType: _readPoolType,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
