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
        ? null
        : (acceptedTypes.isEmpty
            ? 'Formats : non définis'
            : 'Formats : ${acceptedTypes.join(', ')}');

    final normalizedWorkflowStatus =
        workflowStatus.trim().toLowerCase() == 'final' ? 'final' : 'test';
    final isFinal = normalizedWorkflowStatus == 'final';

    return Container(
      padding: const EdgeInsets.all(8),
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
          Row(
            children: [
              _Pill(
                text: statusLabel,
                textColor: statusColor,
                borderColor: statusColor.withValues(alpha: 0.45),
                backgroundColor: statusColor.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 6),
              if (hasMedia)
                _WorkflowPill(
                  value: isFinal ? 'final' : 'test',
                  enabled: !isFrozen && onWorkflowStatusChanged != null,
                  onChanged: (value) => onWorkflowStatusChanged?.call(value),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            fileLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasMedia ? Colors.white : const Color(0xFFD7DFEA),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (metaLine != null) ...[
            const SizedBox(height: 2),
            Text(
              metaLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFAAB7C8),
                fontSize: 11,
                height: 1.1,
              ),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              if (hasMedia) ...[
                SizedBox(
                  height: 26,
                  child: OutlinedButton.icon(
                    onPressed: (isFrozen || onRemove == null) ? null : onRemove,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD7B8),
                      side: const BorderSide(color: Color(0xFF7A4A24)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 12),
                    label: const Text(
                      'Retirer',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: FilledButton.icon(
                    onPressed: (isFrozen || onUploadOrReplace == null)
                        ? null
                        : onUploadOrReplace,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD65A00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      hasMedia ? Icons.sync : Icons.upload_file,
                      size: 12,
                    ),
                    label: Text(
                      hasMedia ? 'Remplacer' : 'Uploader',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          height: 1.0,
        ),
      ),
    );
  }
}

class _WorkflowPill extends StatelessWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const _WorkflowPill({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFinal = value == 'final';
    final backgroundColor = isFinal
        ? const Color(0xFF163A24)
        : const Color(0xFF351A1A);
    final borderColor =
        isFinal ? const Color(0xFF2F7A4E) : const Color(0xFF8A3D3D);
    final textColor =
        isFinal ? const Color(0xFF9EF0B5) : const Color(0xFFFF8C8C);

    return InkWell(
      onTap: enabled
          ? () => onChanged?.call(isFinal ? 'test' : 'final')
          : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          isFinal ? 'Final' : 'Test',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
