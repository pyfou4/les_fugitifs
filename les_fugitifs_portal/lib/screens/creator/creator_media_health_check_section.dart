import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class CreatorMediaHealthCheckSection extends StatefulWidget {
  final String scenarioId;
  final String scenarioLabel;

  const CreatorMediaHealthCheckSection({
    super.key,
    required this.scenarioId,
    required this.scenarioLabel,
  });

  @override
  State<CreatorMediaHealthCheckSection> createState() =>
      _CreatorMediaHealthCheckSectionState();
}

class _CreatorMediaHealthCheckSectionState
    extends State<CreatorMediaHealthCheckSection> {
  static const Duration _metadataTimeout = Duration(seconds: 8);
  static const int _slowThresholdMs = 2000;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isRunning = false;
  DateTime? _lastRunAt;
  List<_MediaHealthResult> _results = const <_MediaHealthResult>[];
  _MediaHealthFilter _selectedFilter = _MediaHealthFilter.all;

  Future<void> _runHealthCheck() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _results = const <_MediaHealthResult>[];
    });

    try {
      final slotsQuery = await _firestore
          .collection('scenario_media_slots')
          .where('scenarioId', isEqualTo: widget.scenarioId)
          .get();

      final slots = slotsQuery.docs
          .map((doc) => _MediaSlotLite.fromDoc(doc))
          .toList()
        ..sort((a, b) {
          final blockCompare = a.blockId.compareTo(b.blockId);
          if (blockCompare != 0) return blockCompare;
          return a.label.compareTo(b.label);
        });

      final Map<String, Future<_AssetLookupOutcome>> assetLookupCache =
      <String, Future<_AssetLookupOutcome>>{};
      final Map<String, Future<_StorageCheckOutcome>> storageCheckCache =
      <String, Future<_StorageCheckOutcome>>{};

      final futures = slots.map(
            (slot) => _checkSlot(
          slot,
          assetLookupCache: assetLookupCache,
          storageCheckCache: storageCheckCache,
        ),
      );

      final List<_MediaHealthResult> nextResults = await Future.wait(futures);

      if (!mounted) return;

      setState(() {
        _results = nextResults;
        _lastRunAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _results = <_MediaHealthResult>[
          _MediaHealthResult(
            slotLabel: 'Global',
            slotKey: '-',
            blockId: '-',
            assetId: null,
            status: _MediaHealthStatus.error,
            responseTimeMs: 0,
            message: 'Impossible de lancer le contrôle: $e',
          ),
        ];
        _lastRunAt = DateTime.now();
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<_MediaHealthResult> _checkSlot(
      _MediaSlotLite slot, {
        required Map<String, Future<_AssetLookupOutcome>> assetLookupCache,
        required Map<String, Future<_StorageCheckOutcome>> storageCheckCache,
      }) async {
    final String effectiveLabel = slot.label.isEmpty ? slot.slotKey : slot.label;

    try {
      if (slot.activeMediaId == null || slot.activeMediaId!.trim().isEmpty) {
        return _MediaHealthResult(
          slotLabel: effectiveLabel,
          slotKey: slot.slotKey,
          blockId: slot.blockId,
          assetId: null,
          status: _MediaHealthStatus.missing,
          responseTimeMs: 0,
          message: 'Aucun média actif assigné à ce slot.',
        );
      }

      final String assetId = slot.activeMediaId!.trim();

      final _AssetLookupOutcome assetLookup = await assetLookupCache.putIfAbsent(
        assetId,
            () => _loadAsset(assetId),
      );

      if (!assetLookup.exists || assetLookup.asset == null) {
        return _MediaHealthResult(
          slotLabel: effectiveLabel,
          slotKey: slot.slotKey,
          blockId: slot.blockId,
          assetId: assetId,
          status: _MediaHealthStatus.assetNotFound,
          responseTimeMs: assetLookup.elapsedMs,
          message: 'Le média actif référencé est introuvable dans media_assets.',
        );
      }

      final _MediaAssetLite asset = assetLookup.asset!;

      if (asset.storagePath.trim().isEmpty) {
        return _MediaHealthResult(
          slotLabel: effectiveLabel,
          slotKey: slot.slotKey,
          blockId: slot.blockId,
          assetId: asset.id,
          status: _MediaHealthStatus.urlMissing,
          responseTimeMs: assetLookup.elapsedMs,
          message: 'Le champ storagePath est vide.',
        );
      }

      final _StorageCheckOutcome storageCheck =
      await storageCheckCache.putIfAbsent(
        asset.storagePath,
            () => _checkStorage(asset.storagePath),
      );

      switch (storageCheck.kind) {
        case _StorageCheckKind.ok:
          final _MediaHealthStatus status =
          storageCheck.elapsedMs >= _slowThresholdMs
              ? _MediaHealthStatus.slow
              : _MediaHealthStatus.ok;

          return _MediaHealthResult(
            slotLabel: effectiveLabel,
            slotKey: slot.slotKey,
            blockId: slot.blockId,
            assetId: asset.id,
            status: status,
            responseTimeMs: storageCheck.elapsedMs,
            message: status == _MediaHealthStatus.slow
                ? 'Fichier trouvé, mais réponse lente.'
                : 'Fichier trouvé et URL récupérée.',
            storagePath: asset.storagePath,
            downloadUrl: storageCheck.downloadUrl,
          );

        case _StorageCheckKind.timeout:
          return _MediaHealthResult(
            slotLabel: effectiveLabel,
            slotKey: slot.slotKey,
            blockId: slot.blockId,
            assetId: asset.id,
            status: _MediaHealthStatus.timeout,
            responseTimeMs: storageCheck.elapsedMs,
            message: 'Timeout lors de la vérification du fichier.',
            storagePath: asset.storagePath,
          );

        case _StorageCheckKind.firebaseError:
          return _MediaHealthResult(
            slotLabel: effectiveLabel,
            slotKey: slot.slotKey,
            blockId: slot.blockId,
            assetId: asset.id,
            status: _MediaHealthStatus.error,
            responseTimeMs: storageCheck.elapsedMs,
            message: storageCheck.message ??
                'Erreur Firebase Storage lors de la vérification.',
            storagePath: asset.storagePath,
          );

        case _StorageCheckKind.error:
          return _MediaHealthResult(
            slotLabel: effectiveLabel,
            slotKey: slot.slotKey,
            blockId: slot.blockId,
            assetId: asset.id,
            status: _MediaHealthStatus.error,
            responseTimeMs: storageCheck.elapsedMs,
            message:
            storageCheck.message ?? 'Erreur inattendue lors de la vérification.',
            storagePath: asset.storagePath,
          );
      }
    } catch (e) {
      return _MediaHealthResult(
        slotLabel: effectiveLabel,
        slotKey: slot.slotKey,
        blockId: slot.blockId,
        assetId: slot.activeMediaId,
        status: _MediaHealthStatus.error,
        responseTimeMs: 0,
        message: 'Erreur slot: $e',
      );
    }
  }

  Future<_AssetLookupOutcome> _loadAsset(String assetId) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final assetDoc =
      await _firestore.collection('media_assets').doc(assetId).get();

      stopwatch.stop();

      if (!assetDoc.exists || assetDoc.data() == null) {
        return _AssetLookupOutcome(
          exists: false,
          asset: null,
          elapsedMs: stopwatch.elapsedMilliseconds,
        );
      }

      return _AssetLookupOutcome(
        exists: true,
        asset: _MediaAssetLite.fromDoc(assetDoc),
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    } catch (_) {
      stopwatch.stop();
      rethrow;
    }
  }

  Future<_StorageCheckOutcome> _checkStorage(String storagePath) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final Reference ref = _storage.ref(storagePath);

      await ref.getMetadata().timeout(_metadataTimeout);
      final String downloadUrl =
      await ref.getDownloadURL().timeout(_metadataTimeout);

      stopwatch.stop();

      return _StorageCheckOutcome(
        kind: _StorageCheckKind.ok,
        elapsedMs: stopwatch.elapsedMilliseconds,
        downloadUrl: downloadUrl,
      );
    } on TimeoutException {
      stopwatch.stop();
      return _StorageCheckOutcome(
        kind: _StorageCheckKind.timeout,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    } on FirebaseException catch (e) {
      stopwatch.stop();
      return _StorageCheckOutcome(
        kind: _StorageCheckKind.firebaseError,
        elapsedMs: stopwatch.elapsedMilliseconds,
        message:
        'Firebase Storage: ${e.code}${e.message == null ? '' : ' • ${e.message}'}',
      );
    } catch (e) {
      stopwatch.stop();
      return _StorageCheckOutcome(
        kind: _StorageCheckKind.error,
        elapsedMs: stopwatch.elapsedMilliseconds,
        message: 'Erreur inattendue: $e',
      );
    }
  }

  List<_MediaHealthResult> _filteredResults(List<_MediaHealthResult> source) {
    switch (_selectedFilter) {
      case _MediaHealthFilter.all:
        return source;
      case _MediaHealthFilter.problems:
        return source.where((result) => result.isProblem).toList();
      case _MediaHealthFilter.slow:
        return source
            .where((result) => result.status == _MediaHealthStatus.slow)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int okCount = _results
        .where((r) =>
    r.status == _MediaHealthStatus.ok ||
        r.status == _MediaHealthStatus.slow)
        .length;
    final int issueCount = _results.length - okCount;
    final int slowCount = _results
        .where((r) => r.status == _MediaHealthStatus.slow)
        .length;
    final List<_MediaHealthResult> visibleResults = _filteredResults(_results);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D192C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223250)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Contrôle des médias',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              _HealthBadge(
                label: widget.scenarioLabel,
                foregroundColor: const Color(0xFFAED0FF),
                backgroundColor: const Color(0xFF13233B),
                borderColor: const Color(0xFF294C74),
              ),
              if (_results.isNotEmpty)
                _HealthBadge(
                  label: '$okCount OK',
                  foregroundColor: const Color(0xFF9EF0B5),
                  backgroundColor: const Color(0xFF16281D),
                  borderColor: const Color(0xFF2F7A4E),
                ),
              if (_results.isNotEmpty)
                _HealthBadge(
                  label: '$issueCount problème(s)',
                  foregroundColor: issueCount == 0
                      ? const Color(0xFFAAB7C8)
                      : const Color(0xFFFFD7B8),
                  backgroundColor: issueCount == 0
                      ? const Color(0xFF13233B)
                      : const Color(0xFF342416),
                  borderColor: issueCount == 0
                      ? const Color(0xFF294C74)
                      : const Color(0xFF7A4A24),
                ),
              FilledButton.icon(
                onPressed: _isRunning ? null : _runHealthCheck,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF294C74),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: _isRunning
                    ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.health_and_safety, size: 16),
                label: Text(
                  _isRunning ? 'Test en cours...' : 'Tester tous les médias',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _lastRunAt == null
                ? 'Ce contrôle vérifie les slots du scénario, la présence du média actif et l’accès au fichier Storage.'
                : 'Dernier contrôle effectué à ${_formatDateTime(_lastRunAt!)}.',
            style: const TextStyle(
              color: Color(0xFFAAB7C8),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _FilterChipButton(
                  label: 'Tous (${_results.length})',
                  isSelected: _selectedFilter == _MediaHealthFilter.all,
                  onTap: () {
                    setState(() {
                      _selectedFilter = _MediaHealthFilter.all;
                    });
                  },
                ),
                _FilterChipButton(
                  label: 'Problèmes ($issueCount)',
                  isSelected: _selectedFilter == _MediaHealthFilter.problems,
                  onTap: () {
                    setState(() {
                      _selectedFilter = _MediaHealthFilter.problems;
                    });
                  },
                ),
                _FilterChipButton(
                  label: 'Lents ($slowCount)',
                  isSelected: _selectedFilter == _MediaHealthFilter.slow,
                  onTap: () {
                    setState(() {
                      _selectedFilter = _MediaHealthFilter.slow;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (visibleResults.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101C31),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF223250)),
                ),
                child: const Text(
                  'Aucun résultat pour ce filtre.',
                  style: TextStyle(
                    color: Color(0xFFAAB7C8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFF13233B),
                    ),
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 72,
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Bloc / Slot',
                          style: TextStyle(
                            color: Color(0xFFAED0FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Statut',
                          style: TextStyle(
                            color: Color(0xFFAED0FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Temps',
                          style: TextStyle(
                            color: Color(0xFFAED0FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Message',
                          style: TextStyle(
                            color: Color(0xFFAED0FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    rows: visibleResults.map((result) {
                      return DataRow(
                        cells: [
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    result.slotLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${result.blockId} • ${result.slotKey}',
                                    style: const TextStyle(
                                      color: Color(0xFFAAB7C8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(_StatusChip(status: result.status)),
                          DataCell(
                            Text(
                              '${result.responseTimeMs} ms',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Text(
                                result.message,
                                style: const TextStyle(
                                  color: Color(0xFFE5ECF6),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(dateTime.day)}/${two(dateTime.month)}/${dateTime.year} à ${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)}';
  }
}

enum _MediaHealthStatus {
  ok,
  slow,
  missing,
  assetNotFound,
  urlMissing,
  timeout,
  error,
}

enum _MediaHealthFilter {
  all,
  problems,
  slow,
}

enum _StorageCheckKind {
  ok,
  timeout,
  firebaseError,
  error,
}

class _MediaHealthResult {
  final String slotLabel;
  final String slotKey;
  final String blockId;
  final String? assetId;
  final _MediaHealthStatus status;
  final int responseTimeMs;
  final String message;
  final String? storagePath;
  final String? downloadUrl;

  const _MediaHealthResult({
    required this.slotLabel,
    required this.slotKey,
    required this.blockId,
    required this.assetId,
    required this.status,
    required this.responseTimeMs,
    required this.message,
    this.storagePath,
    this.downloadUrl,
  });

  bool get isProblem {
    return status == _MediaHealthStatus.missing ||
        status == _MediaHealthStatus.assetNotFound ||
        status == _MediaHealthStatus.urlMissing ||
        status == _MediaHealthStatus.timeout ||
        status == _MediaHealthStatus.error;
  }
}

class _AssetLookupOutcome {
  final bool exists;
  final _MediaAssetLite? asset;
  final int elapsedMs;

  const _AssetLookupOutcome({
    required this.exists,
    required this.asset,
    required this.elapsedMs,
  });
}

class _StorageCheckOutcome {
  final _StorageCheckKind kind;
  final int elapsedMs;
  final String? message;
  final String? downloadUrl;

  const _StorageCheckOutcome({
    required this.kind,
    required this.elapsedMs,
    this.message,
    this.downloadUrl,
  });
}

class _MediaSlotLite {
  final String id;
  final String blockId;
  final String slotKey;
  final String label;
  final String? activeMediaId;

  const _MediaSlotLite({
    required this.id,
    required this.blockId,
    required this.slotKey,
    required this.label,
    required this.activeMediaId,
  });

  factory _MediaSlotLite.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

    return _MediaSlotLite(
      id: doc.id,
      blockId: (data['blockId'] ?? '') as String,
      slotKey: (data['slotKey'] ?? '') as String,
      label: (data['label'] ?? '') as String,
      activeMediaId: data['activeMediaId'] as String?,
    );
  }
}

class _MediaAssetLite {
  final String id;
  final String storagePath;

  const _MediaAssetLite({
    required this.id,
    required this.storagePath,
  });

  factory _MediaAssetLite.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

    return _MediaAssetLite(
      id: doc.id,
      storagePath: (data['storagePath'] ?? '') as String,
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  const _HealthBadge({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color foregroundColor =
    isSelected ? Colors.white : const Color(0xFFAED0FF);
    final Color backgroundColor =
    isSelected ? const Color(0xFF294C74) : const Color(0xFF13233B);
    final Color borderColor =
    isSelected ? const Color(0xFF4A76A8) : const Color(0xFF294C74);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _MediaHealthStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final _StatusVisual visual = _visualFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: visual.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: visual.borderColor),
      ),
      child: Text(
        visual.label,
        style: TextStyle(
          color: visual.foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  _StatusVisual _visualFor(_MediaHealthStatus status) {
    switch (status) {
      case _MediaHealthStatus.ok:
        return const _StatusVisual(
          label: 'OK',
          foregroundColor: Color(0xFF9EF0B5),
          backgroundColor: Color(0xFF16281D),
          borderColor: Color(0xFF2F7A4E),
        );
      case _MediaHealthStatus.slow:
        return const _StatusVisual(
          label: 'LENT',
          foregroundColor: Color(0xFFFFE4A3),
          backgroundColor: Color(0xFF352C16),
          borderColor: Color(0xFF8A6A25),
        );
      case _MediaHealthStatus.missing:
        return const _StatusVisual(
          label: 'MANQUANT',
          foregroundColor: Color(0xFFFFD7B8),
          backgroundColor: Color(0xFF342416),
          borderColor: Color(0xFF7A4A24),
        );
      case _MediaHealthStatus.assetNotFound:
        return const _StatusVisual(
          label: 'ASSET KO',
          foregroundColor: Color(0xFFFFD7B8),
          backgroundColor: Color(0xFF342416),
          borderColor: Color(0xFF7A4A24),
        );
      case _MediaHealthStatus.urlMissing:
        return const _StatusVisual(
          label: 'URL ABSENTE',
          foregroundColor: Color(0xFFFFD7B8),
          backgroundColor: Color(0xFF342416),
          borderColor: Color(0xFF7A4A24),
        );
      case _MediaHealthStatus.timeout:
        return const _StatusVisual(
          label: 'TIMEOUT',
          foregroundColor: Color(0xFFFFE4A3),
          backgroundColor: Color(0xFF352C16),
          borderColor: Color(0xFF8A6A25),
        );
      case _MediaHealthStatus.error:
        return const _StatusVisual(
          label: 'ERREUR',
          foregroundColor: Color(0xFFFFC7C7),
          backgroundColor: Color(0xFF341B1B),
          borderColor: Color(0xFF7A2F2F),
        );
    }
  }
}

class _StatusVisual {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  const _StatusVisual({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}