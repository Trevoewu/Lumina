import 'package:flutter/material.dart';

class PodcastCategoryChips extends StatelessWidget {
  final Iterable<String> categories;
  final int limit;

  /// When set, each chip searches for its category.
  final ValueChanged<String>? onSelected;

  const PodcastCategoryChips({
    super.key,
    required this.categories,
    this.limit = 4,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in categories.take(limit))
          if (onSelected case final onSelected?)
            ActionChip(
              key: ValueKey('podcast-category-$category'),
              visualDensity: VisualDensity.compact,
              label: Text(category),
              onPressed: () => onSelected(category),
            )
          else
            Chip(visualDensity: VisualDensity.compact, label: Text(category)),
      ],
    );
  }
}
