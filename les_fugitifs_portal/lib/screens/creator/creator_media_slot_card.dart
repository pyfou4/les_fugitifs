import 'package:flutter/material.dart';

class CreatorMediaSlotCard extends StatelessWidget {
  final String slotId;
  final String title;
  final String blockLabel;
  final List<String> acceptedTypes;
  final bool isRequired;
  final bool isFrozen;
  final bool hasMedia;
  final String? activeMediaTitle;
  final String? activeFileName;
  final String? activeMimeType;
  final String? technicalStatus;
  final String? storagePath;
  final String workflowStatus;
  final ValueChanged<String>? onWorkflowStatusChanged;
  final VoidCallback? onUploadOrReplace;
  final VoidCallback? onRemove;

  const CreatorMediaSlotCard({
    super.key,
    required this.slotId,
    required this.title,
    required this.blockLabel,
    required this.acceptedTypes,
    required this.isRequired,
    required this.isFrozen,
    required this.hasMedia,
    required this.activeMediaTitle,
    required this.activeFileName,
    required this.activeMimeType,
    required this.technicalStatus,
    required this.storagePath,
    required this.workflowStatus,
    required this.onWorkflowStatusChanged,
    required this.onUploadOrReplace,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = hasMedia
        ? const Color(0xFF9EF0B5)
        : (isRequired ? const Color(0xFFFFD7B8) : const Color(0xFFAED0FF));
    final statusLabel =
        hasMedia ? 'Présent' : (isRequired ? 'Manquant' : 'Optionnel');

    final fileLine = hasMedia
        ? (activeFileName ?? activeMediaTitle ?? 'Nom introuvable')
        : 'Aucun média';

    final metaLine = hasMedia
        ? [
            if ((activeMimeType ?? '').trim().isNotEmpty) activeMimeType!.trim(),
            if ((technicalStatus ?? '').trim().isNotEmpty)
              technicalStatus!.trim(),
          ].join(' • ')
        : (acceptedTypes.isEmpty ? 'Type non défini' : acceptedTypes.join(', '));

    final normalizedWorkflowStatus =
        workflowStatus.trim().toLowerCase() == 'final' ? 'final' : 'test';
    final isFinal = normalizedWorkflowStatus == 'final';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D192C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFrozen ? const Color(0xFF38465A) : const Color(0xFF1E2D45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(
                text: statusLabel,
                textColor: statusColor,
                borderColor: statusColor.withValues(alpha: 0.45),
                backgroundColor: statusColor.withValues(alpha: 0.12),
              ),
              if (acceptedTypes.isNotEmpty)
                _Pill(
                  text: acceptedTypes.join(', '),
                  textColor: const Color(0xFFAAB7C8),
                  borderColor: const Color(0xFF2A3A53),
                  backgroundColor: const Color(0xFF101A2B),
                ),
              if (isRequired)
                const _Pill(
                  text: 'Obligatoire',
                  textColor: Color(0xFFFFD7B8),
                  borderColor: Color(0xFF7A4A24),
                  backgroundColor: Color(0xFF341F14),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            blockLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFAAB7C8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fileLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metaLine.isEmpty ? '—' : metaLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFAAB7C8),
              fontSize: 12,
            ),
          ),
          if (hasMedia) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Statut',
                  style: TextStyle(
                    color: Color(0xFFAAB7C8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.72,
                  alignment: Alignment.centerLeft,
                  child: Switch(
                    value: isFinal,
                    onChanged: (isFrozen || onWorkflowStatusChanged == null)
                        ? null
                        : (value) => onWorkflowStatusChanged!(
                              value ? 'final' : 'test',
                            ),
                    activeColor: const Color(0xFF2F7A4E),
                    activeTrackColor: const Color(0xFF1A3523),
                    inactiveThumbColor: const Color(0xFFB44545),
                    inactiveTrackColor: const Color(0xFF351A1A),
                    trackOutlineColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? const Color(0xFF2F7A4E)
                          : const Color(0xFF8A3D3D),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                Text(
                  isFinal ? 'Final' : 'Test',
                  style: TextStyle(
                    color: isFinal
                        ? const Color(0xFF9EF0B5)
                        : const Color(0xFFFF8C8C),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          const SizedBox(height: 2),
          Row(
            children: [
              if (hasMedia) ...[
                Flexible(
                  child: OutlinedButton.icon(
                    onPressed: (isFrozen || onRemove == null) ? null : onRemove,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD7B8),
                      side: const BorderSide(color: Color(0xFF7A4A24)),
                      minimumSize: const Size(0, 28),
                      maximumSize: const Size(double.infinity, 28),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 12),
                    label: const Text(
                      'Retirer',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: (isFrozen || onUploadOrReplace == null)
                      ? null
                      : onUploadOrReplace,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD65A00),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 28),
                    maximumSize: const Size(double.infinity, 28),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(hasMedia ? Icons.sync : Icons.upload_file, size: 12),
                  label: Text(
                    hasMedia ? 'Remplacer' : 'Uploader',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color borderColor;
  final Color backgroundColor;

  const _Pill({
    required this.text,
    required this.textColor,
    required this.borderColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
