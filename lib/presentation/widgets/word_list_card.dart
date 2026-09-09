import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_design_tokens.dart';
import '../../domain/models/vocabulary_entry.dart';
import '../../services/reading_level_estimator.dart';
import 'design_system/app_surface.dart';

class WordListCard extends StatelessWidget {
  final VocabularyEntry entry;
  final VoidCallback onTap;
  final bool favorite;
  final String? contextLabel;

  const WordListCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.favorite = false,
    this.contextLabel,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final definition = entry.definitions.firstOrNull;
    final subtitle = definition?.meaning ?? entry.shortExplanation ?? '';
    final phonetic = entry.usPhonetic ?? entry.ukPhonetic;
    final partOfSpeech = definition?.partOfSpeech.trim();
    final readingLevel = _readingLevelLabel(entry);
    final accent = favorite
        ? Theme.of(context).colorScheme.primary
        : context.appTextSecondary;

    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WordInitialBadge(word: entry.word, favorite: favorite),
          SizedBox(width: design.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        entry.word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: context.appTextPrimary,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                    ),
                    if (phonetic != null && phonetic.trim().isNotEmpty) ...[
                      SizedBox(width: design.spaceSm),
                      Flexible(
                        child: Text(
                          phonetic,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.appTextSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: design.spaceXs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appTextSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
                if ((partOfSpeech != null && partOfSpeech.isNotEmpty) ||
                    readingLevel != null ||
                    contextLabel != null) ...[
                  SizedBox(height: design.spaceSm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (partOfSpeech != null && partOfSpeech.isNotEmpty)
                        _WordMetaChip(label: partOfSpeech),
                      if (readingLevel != null)
                        _WordMetaChip(
                          icon: AppIcons.mortarboard01,
                          label: readingLevel,
                        ),
                      if (contextLabel != null)
                        _WordMetaChip(
                          icon: AppIcons.bookOpen01,
                          label: contextLabel!,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: design.spaceSm),
          AppIcon(
            favorite ? AppIcons.bookmark01 : AppIcons.arrowRight01,
            color: accent,
            size: favorite ? 22 : 24,
          ),
        ],
      ),
    );
  }

  String? _readingLevelLabel(VocabularyEntry entry) {
    final code = _normalizeCefr(entry.readingLevelCode);
    if (code == null) return null;
    return entry.readingLevelSource == estimatedReadingLevelSource
        ? 'CEFR est. $code'
        : 'CEFR $code';
  }

  String? _normalizeCefr(String? value) {
    final normalized = value?.trim().toUpperCase();
    return switch (normalized) {
      'A1' || 'A2' || 'B1' || 'B2' => normalized,
      _ => null,
    };
  }
}

class _WordInitialBadge extends StatelessWidget {
  final String word;
  final bool favorite;

  const _WordInitialBadge({required this.word, required this.favorite});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final initial = word.trim().isEmpty ? '?' : word.trim()[0].toUpperCase();
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: favorite
            ? accent.withValues(alpha: 0.18)
            : context.appSurfaceHighlight,
        borderRadius: BorderRadius.circular(context.appDesign.radiusSmall),
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: favorite ? accent : context.appTextPrimary,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }
}

class _WordMetaChip extends StatelessWidget {
  final AppIconData? icon;
  final String label;

  const _WordMetaChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.appSurfaceHighlight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: 14, color: context.appTextSecondary),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.appTextSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
