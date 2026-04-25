import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/post_completion_engine.dart';
import 'post_completion_card_zoom_dialog.dart';

class PostCompletionCardWidget extends StatelessWidget {
  const PostCompletionCardWidget({
    super.key,
    required this.card,
  });

  final PostCompletionCard card;

  @override
  Widget build(BuildContext context) {
    final isMotive = card.targetType.trim().toLowerCase() == 'motive';
    final children = <Widget>[
      if (!isMotive) _PostCompletionCardImage(card: card),
      if (!isMotive) const SizedBox(width: 10),
      Expanded(child: _PostCompletionCardText(card: card, alignRight: isMotive)),
      if (isMotive) const SizedBox(width: 10),
      if (isMotive) _PostCompletionCardImage(card: card),
    ];

    return SizedBox(
      width: 286,
      child: Material(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showPostCompletionCardZoomDialog(context, card),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _PostCompletionCardText extends StatelessWidget {
  const _PostCompletionCardText({
    required this.card,
    required this.alignRight,
  });

  final PostCompletionCard card;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIdentity = card.contentMode == PostCompletionCardContentMode.name;
    final title = isIdentity ? card.title : card.text;
    final subtitle = isIdentity ? 'Identité' : 'Caractéristique';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_targetTypeLabel(card.targetType)} · $subtitle',
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Toucher pour agrandir',
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.black.withOpacity(0.48),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _PostCompletionCardImage extends StatelessWidget {
  const _PostCompletionCardImage({
    required this.card,
    this.size = 62,
  });

  final PostCompletionCard card;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shouldBlur = card.contentMode == PostCompletionCardContentMode.attribute;
    Widget child;

    if (card.imageKey.startsWith('http')) {
      child = Image.network(
        card.imageKey,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_search),
      );
    } else {
      child = const Icon(Icons.image_search);
    }

    if (shouldBlur) {
      child = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Opacity(
          opacity: 0.58,
          child: child,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
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
