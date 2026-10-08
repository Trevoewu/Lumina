import 'package:flutter/material.dart';

import 'search_screen.dart';

/// Catalogs such as Gutenberg store "Austen, Jane", which other sources do
/// not match; searches use the name the way it is written on a cover.
String? searchableAuthor(String? author) {
  final name = author?.trim() ?? '';
  if (name.isEmpty) return null;
  final parts = name.split(',');
  if (parts.length != 2) return name;
  final last = parts[0].trim();
  final first = parts[1].trim();
  return first.isEmpty ? last : '$first $last';
}

/// Opens Search for [term] on top of the current page, so Back returns to
/// the book or show the reader came from.
Future<void> openSearchFor(BuildContext context, String term) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SearchScreen(initialQuery: term)),
    );
