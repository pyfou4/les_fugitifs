import 'package:flutter/material.dart';

import '../../services/post_completion_engine.dart';
import 'post_completion_card_widget.dart';

class PostCompletionCardsSection extends StatelessWidget {
  const PostCompletionCardsSection({
    super.key,
    required this.cards,
  });

  final List<PostCompletionCard> cards;

  @override
  Widget build(BuildContext context) {
    final suspects = cards
        .where((card) => card.targetType.trim().toLowerCase() == 'suspect')
        .toList(growable: false);
    final motives = cards
        .where((card) => card.targetType.trim().toLowerCase() == 'motive')
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (suspects.isNotEmpty)
          _PostCompletionCardGroup(
            title: 'Suspects',
            subtitle: _subtitleForCount(suspects.length),
            cards: suspects,
          ),
        if (suspects.isNotEmpty && motives.isNotEmpty)
          const SizedBox(height: 14),
        if (motives.isNotEmpty)
          _PostCompletionCardGroup(
            title: 'Mobiles',
            subtitle: _subtitleForCount(motives.length),
            cards: motives,
          ),
      ],
    );
  }

  String _subtitleForCount(int count) {
    if (count <= 1) return '1 signal isolé';
    return '$count signaux possibles';
  }
}

class _PostCompletionCardGroup extends StatelessWidget {
  const _PostCompletionCardGroup({
    required this.title,
    required this.subtitle,
    required this.cards,
  });

  final String title;
  final String subtitle;
  final List<PostCompletionCard> cards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black.withOpacity(0.52),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 132,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  if (index > 0) const SizedBox(width: 10),
                  PostCompletionCardWidget(card: cards[index]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
