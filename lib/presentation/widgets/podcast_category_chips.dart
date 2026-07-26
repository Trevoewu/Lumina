import 'package:flutter/material.dart';

class PodcastCategoryChips extends StatelessWidget {
  final Iterable<String> categories;
  final int limit;

  const PodcastCategoryChips({
    super.key,
    required this.categories,
    this.limit = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in categories.take(limit))
          Chip(visualDensity: VisualDensity.compact, label: Text(category)),
      ],
    );
  }
}
