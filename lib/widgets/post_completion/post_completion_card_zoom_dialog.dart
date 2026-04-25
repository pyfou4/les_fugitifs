import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/post_completion_engine.dart';

Future<void> showPostCompletionCardZoomDialog(
  BuildContext context,
  PostCompletionCard card,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => PostCompletionCardZoomDialog(card: card),
  );
}

class PostCompletionCardZoomDialog extends StatelessWidget {
  const PostCompletionCardZoomDialog({
    super.key,
    required this.card,
  });

  final PostCompletionCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMotive = card.targetType.trim().toLowerCase() == 'motive';
    final isIdentity = card.contentMode == PostCompletionCardContentMode.name;
    final image = _ZoomImage(card: card);
    final text = Expanded(
      child: Column(
        crossAxisAlignment:
            isMotive ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isIdentity ? card.title : card.text,
            textAlign: isMotive ? TextAlign.right : TextAlign.left,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_targetTypeLabel(card.targetType)} · ${isIdentity ? 'Identité' : 'Caractéristique'}',
            textAlign: isMotive ? TextAlign.right : TextAlign.left,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );

    return AlertDialog(
      title: Text(_targetTypeLabel(card.targetType)),
      content: SizedBox(
        width: 440,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: isMotive
              ? [text, const SizedBox(width: 18), image]
              : [image, const SizedBox(width: 18), text],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _ZoomImage extends StatelessWidget {
  const _ZoomImage({required this.card});

  final PostCompletionCard card;

  @override
  Widget build(BuildContext context) {
    final shouldBlur = card.contentMode == PostCompletionCardContentMode.attribute;
    Widget child;

    if (card.imageKey.startsWith('http')) {
      child = Image.network(
        card.imageKey,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_search, size: 44),
      );
    } else {
      child = const Icon(Icons.image_search, size: 44);
    }

    if (shouldBlur) {
      child = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Opacity(opacity: 0.58, child: child),
      );
    }

    return Container(
      width: 132,
      height: 132,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

String _targetTypeLabel(String targetType) {
  switch (targetType.trim().toLowerCase()) {
    case 'suspect':
      return 'Suspect';
    case 'motive':
      return 'Mobile';
    default:
      return targetType;
  }
}
