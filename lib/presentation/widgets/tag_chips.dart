import 'package:flutter/material.dart';

/// Genre or subject tags for a show or book.
class TagChips extends StatelessWidget {
  final Iterable<String> tags;
  final int limit;

  /// When set, each chip searches for its tag.
  final ValueChanged<String>? onSelected;

  const TagChips({
    super.key,
    required this.tags,
    this.limit = 4,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags.take(limit))
          if (onSelected case final onSelected?)
            ActionChip(
              key: ValueKey('tag-$tag'),
              visualDensity: VisualDensity.compact,
              label: Text(tag),
              onPressed: () => onSelected(tag),
            )
          else
            Chip(visualDensity: VisualDensity.compact, label: Text(tag)),
      ],
    );
  }
}
