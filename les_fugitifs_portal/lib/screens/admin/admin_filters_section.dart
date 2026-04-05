import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'compact_dropdown_filter.dart';
import 'compact_filter_chip.dart';

class AdminFiltersSection extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String activePeriodLabel;
  final String? selectedSiteFilterId;
  final String? selectedScenarioFilterId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> siteDocs;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> scenarioDocs;
  final String Function(DateTime?) formatDate;
  final Future<void> Function() onPickStartDate;
  final Future<void> Function() onPickEndDate;
  final VoidCallback onApplyToday;
  final VoidCallback onApplyLast7Days;
  final VoidCallback onApplyLast30Days;
  final VoidCallback onApplyThisYear;
  final VoidCallback onClearDateRange;
  final VoidCallback onClearAllFilters;
  final ValueChanged<String?> onSiteChanged;
  final ValueChanged<String?> onScenarioChanged;

  const AdminFiltersSection({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.activePeriodLabel,
    required this.selectedSiteFilterId,
    required this.selectedScenarioFilterId,
    required this.siteDocs,
    required this.scenarioDocs,
    required this.formatDate,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onApplyToday,
    required this.onApplyLast7Days,
    required this.onApplyLast30Days,
    required this.onApplyThisYear,
    required this.onClearDateRange,
    required this.onClearAllFilters,
    required this.onSiteChanged,
    required this.onScenarioChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isClearAllDisabled = startDate == null &&
        endDate == null &&
        selectedSiteFilterId == null &&
        selectedScenarioFilterId == null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF222B38),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 18,
                color: Color(0xFFFFD7B8),
              ),
              SizedBox(width: 8),
              Text(
                'Filtres statistiques',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              CompactFilterChip(
                icon: Icons.event_available,
                label: startDate == null ? 'Date début' : formatDate(startDate),
                onTap: () => onPickStartDate(),
              ),
              CompactFilterChip(
                icon: Icons.event,
                label: endDate == null ? 'Date fin' : formatDate(endDate),
                onTap: () => onPickEndDate(),
              ),
              CompactFilterChip(
                icon: Icons.schedule,
                label: activePeriodLabel,
                onTap: null,
                isPassive: true,
              ),
              CompactFilterChip(
                icon: Icons.today,
                label: 'Aujourd’hui',
                onTap: onApplyToday,
              ),
              CompactFilterChip(
                icon: Icons.calendar_view_week,
                label: '7 jours',
                onTap: onApplyLast7Days,
              ),
              CompactFilterChip(
                icon: Icons.date_range,
                label: '30 jours',
                onTap: onApplyLast30Days,
              ),
              CompactFilterChip(
                icon: Icons.auto_graph,
                label: 'Cette année',
                onTap: onApplyThisYear,
              ),
              CompactFilterChip(
                icon: Icons.all_inclusive,
                label: 'Tout',
                onTap: onClearDateRange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              CompactDropdownFilter(
                icon: Icons.place_outlined,
                label: 'Site',
                value: selectedSiteFilterId,
                items: siteDocs
                    .map(
                      (doc) => DropdownMenuItem<String?>(
                        value: doc.id,
                        child: Text(
                          (doc.data()['title'] ?? doc.id).toString(),
                        ),
                      ),
                    )
                    .toList(),
                allLabel: 'Tous les sites',
                onChanged: onSiteChanged,
              ),
              CompactDropdownFilter(
                icon: Icons.videogame_asset_outlined,
                label: 'Jeu',
                value: selectedScenarioFilterId,
                items: scenarioDocs
                    .map(
                      (doc) => DropdownMenuItem<String?>(
                        value: doc.id,
                        child: Text(
                          (doc.data()['title'] ?? doc.id).toString(),
                        ),
                      ),
                    )
                    .toList(),
                allLabel: 'Tous les jeux',
                onChanged: onScenarioChanged,
              ),
              CompactFilterChip(
                icon: Icons.refresh,
                label: 'Réinitialiser tout',
                onTap: isClearAllDisabled ? null : onClearAllFilters,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
