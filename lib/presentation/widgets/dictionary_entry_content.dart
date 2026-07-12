import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_design_tokens.dart';
import '../../core/app_localizations.dart';
import '../../data/dictionary/dictionary_repository.dart';
import 'design_system/app_surface.dart';

class DictionaryEntryContent extends StatelessWidget {
  final DictionaryLookupResult result;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onPlayUs;
  final VoidCallback onPlayUk;
  final VoidCallback? onPlayContext;

  const DictionaryEntryContent({
    super.key,
    required this.result,
    required this.favorite,
    required this.onFavorite,
    required this.onPlayUs,
    required this.onPlayUk,
    this.onPlayContext,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final entry = result.entry;
    final accent = Theme.of(context).colorScheme.primary;
    final titleStyle = Theme.of(
      context,
    ).textTheme.headlineLarge!.copyWith(color: context.appTextPrimary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(entry.word, style: titleStyle)),
            IconButton(
              tooltip: favorite
                  ? context.tr('取消收藏', 'Remove favorite')
                  : context.tr('收藏', 'Save word'),
              onPressed: onFavorite,
              icon: Icon(
                favorite ? Icons.bookmark : Icons.bookmark_border,
                color: favorite ? accent : context.appTextSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: design.spaceMd),
        for (final definition in entry.definitions)
          Padding(
            padding: EdgeInsets.only(bottom: design.spaceMd),
            child: Text.rich(
              TextSpan(
                children: [
                  if (definition.partOfSpeech.isNotEmpty)
                    TextSpan(
                      text: '${definition.partOfSpeech}  ',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                  TextSpan(text: definition.meaning),
                ],
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: context.appTextPrimary),
            ),
          ),
        if (entry.shortExplanation != null) ...[
          SizedBox(height: design.spaceMd),
          _ExplanationSection(
            title: context.tr('简短解释', 'Short explanation'),
            text: entry.shortExplanation!,
          ),
        ],
        if (entry.longExplanation != null) ...[
          SizedBox(height: design.spaceLg),
          _ExplanationSection(
            title: context.tr('详细解释', 'Long explanation'),
            text: entry.longExplanation!,
          ),
        ],
        if (entry.otherForms.isNotEmpty) ...[
          SizedBox(height: design.spaceXl),
          Wrap(
            spacing: design.spaceSm,
            runSpacing: design.spaceSm,
            children: [
              for (final form in entry.otherForms)
                Chip(visualDensity: VisualDensity.compact, label: Text(form)),
            ],
          ),
        ],
        SizedBox(height: design.spaceLg),
        Wrap(
          spacing: design.spaceMd,
          runSpacing: design.spaceSm,
          children: [
            _PronunciationAction(
              label: 'US',
              phonetic: entry.usPhonetic,
              onPlay: onPlayUs,
            ),
            _PronunciationAction(
              label: 'UK',
              phonetic: entry.ukPhonetic,
              onPlay: onPlayUk,
            ),
          ],
        ),
        if (result.context case final lookupContext?) ...[
          SizedBox(height: design.spaceXl),
          Text(
            context.tr('来自你的有声书', 'From your audiobook'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: design.spaceSm),
          AppSurface(
            level: AppSurfaceLevel.elevated,
            padding: EdgeInsets.all(design.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lookupContext.chapterTitle.isEmpty
                      ? lookupContext.bookTitle
                      : '${lookupContext.bookTitle} · ${lookupContext.chapterTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                SizedBox(height: design.spaceSm),
                Text(
                  lookupContext.sentence,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
                if (lookupContext.audioStartMs != null) ...[
                  SizedBox(height: design.spaceSm),
                  if (onPlayContext == null)
                    Text(
                      _formatTimestamp(lookupContext.audioStartMs!),
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: accent),
                    )
                  else
                    TextButton.icon(
                      onPressed: onPlayContext,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(
                        context.tr(
                          '从 ${_formatTimestamp(lookupContext.audioStartMs!)} 播放',
                          'Play from ${_formatTimestamp(lookupContext.audioStartMs!)}',
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
        SizedBox(height: design.spaceLg),
        Row(
          children: [
            Icon(Icons.menu_book_rounded, color: accent, size: 18),
            SizedBox(width: design.spaceSm),
            Expanded(
              child: Text(
                '${entry.providerLabel}${result.fromCache ? ' · ${context.tr('本地', 'Cached')}' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
            ),
            IconButton(
              tooltip: context.tr('打开来源', 'Open source'),
              onPressed: () => launchUrl(
                Uri.parse(entry.sourceUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTimestamp(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return duration.inHours > 0
        ? '${duration.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}

class _PronunciationAction extends StatelessWidget {
  final String label;
  final String? phonetic;
  final VoidCallback onPlay;

  const _PronunciationAction({
    required this.label,
    required this.phonetic,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.volume_up_outlined, size: 18),
      onPressed: onPlay,
      label: Text('$label${phonetic == null ? '' : '  $phonetic'}'),
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  final String title;
  final String text;

  const _ExplanationSection({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: design.spaceSm),
        Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}
