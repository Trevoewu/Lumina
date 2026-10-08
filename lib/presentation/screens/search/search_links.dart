import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../widgets/design_system/app_icon.dart';
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

/// An author name that searches every source for that author.
class AuthorSearchLink extends StatelessWidget {
  final String author;
  final double fontSize;
  final int maxLines;

  const AuthorSearchLink({
    super.key,
    required this.author,
    this.fontSize = 15,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final term = searchableAuthor(author) ?? author;
    return Semantics(
      link: true,
      hint: context.tr('搜索该作者', 'Search for this author', 'この著者を検索'),
      child: InkWell(
        key: const ValueKey('author-search-link'),
        borderRadius: BorderRadius.circular(6),
        onTap: () => openSearchFor(context, term),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  author,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              AppIcon(
                AppIcons.arrowRight01,
                size: fontSize,
                color: context.appTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
