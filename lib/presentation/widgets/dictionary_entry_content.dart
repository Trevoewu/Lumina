import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_design_tokens.dart';
import '../../core/app_localizations.dart';
import '../../data/dictionary/dictionary_repository.dart';
import 'design_system/app_surface.dart';

class DictionaryEntryContent extends StatefulWidget {
  final DictionaryLookupResult result;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onPlayUs;
  final VoidCallback onPlayUk;
  final VoidCallback? onPlayContext;
  final bool compact;

  const DictionaryEntryContent({
    super.key,
    required this.result,
    required this.favorite,
    required this.onFavorite,
    required this.onPlayUs,
    required this.onPlayUk,
    this.onPlayContext,
    this.compact = false,
  });

  @override
  State<DictionaryEntryContent> createState() => _DictionaryEntryContentState();
}

class _DictionaryEntryContentState extends State<DictionaryEntryContent> {
  bool _longExplanationExpanded = false;

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final entry = widget.result.entry;
    final accent = Theme.of(context).colorScheme.primary;
    final readingTitle = context.readingStyle(
      Theme.of(
        context,
      ).textTheme.headlineLarge!.copyWith(color: context.appTextPrimary),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(entry.word, style: readingTitle)),
            IconButton(
              tooltip: widget.favorite
                  ? context.tr('取消收藏', 'Remove favorite')
                  : context.tr('收藏', 'Save word'),
              onPressed: widget.onFavorite,
              icon: Icon(
                widget.favorite ? Icons.bookmark : Icons.bookmark_border,
                color: widget.favorite ? accent : context.appTextSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: design.spaceSm),
        Wrap(
          spacing: design.spaceMd,
          runSpacing: design.spaceSm,
          children: [
            _PronunciationAction(
              label: 'US',
              phonetic: entry.usPhonetic,
              onPlay: widget.onPlayUs,
            ),
            _PronunciationAction(
              label: 'UK',
              phonetic: entry.ukPhonetic,
              onPlay: widget.onPlayUk,
            ),
          ],
        ),
        SizedBox(height: design.spaceXl),
        for (final definition in entry.definitions.take(
          widget.compact ? 2 : 99,
        ))
          Padding(
            padding: EdgeInsets.only(bottom: design.spaceMd),
            child: Text.rich(
              TextSpan(
                children: [
                  if (definition.partOfSpeech.isNotEmpty)
                    TextSpan(
                      text: '${definition.partOfSpeech}  ',
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontWeight: FontWeight.w600,
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
        if (entry.otherForms.isNotEmpty) ...[
          SizedBox(height: design.spaceXs),
          Wrap(
            spacing: design.spaceSm,
            runSpacing: design.spaceSm,
            children: [
              for (final form in entry.otherForms)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(form),
                  side: BorderSide.none,
                  backgroundColor: context.appSurfaceHighlight,
                ),
            ],
          ),
        ],
        if (widget.result.context case final lookupContext?) ...[
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
                  style: context.readingStyle(
                    Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                if (lookupContext.audioStartMs != null) ...[
                  SizedBox(height: design.spaceSm),
                  if (widget.onPlayContext == null)
                    Text(
                      _formatTimestamp(lookupContext.audioStartMs!),
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: accent),
                    )
                  else
                    TextButton.icon(
                      onPressed: widget.onPlayContext,
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
        if (!widget.compact && entry.shortExplanation != null) ...[
          SizedBox(height: design.spaceXl),
          _ExplanationSection(
            title: context.tr('简短解释', 'Short explanation'),
            text: entry.shortExplanation!,
          ),
        ],
        if (!widget.compact && entry.longExplanation != null) ...[
          SizedBox(height: design.spaceLg),
          AppSurface(
            child: ExpansionTile(
              initiallyExpanded: _longExplanationExpanded,
              onExpansionChanged: (value) =>
                  setState(() => _longExplanationExpanded = value),
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              shape: const RoundedRectangleBorder(side: BorderSide.none),
              collapsedShape: const RoundedRectangleBorder(
                side: BorderSide.none,
              ),
              title: Text(context.tr('详细解释', 'Long explanation')),
              childrenPadding: EdgeInsets.fromLTRB(
                design.spaceLg,
                0,
                design.spaceLg,
                design.spaceLg,
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    entry.longExplanation!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
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
                '${entry.providerLabel}${widget.result.fromCache ? ' · ${context.tr('本地', 'Cached')}' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
            ),
            if (!widget.compact)
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
      side: BorderSide.none,
      backgroundColor: context.appSurface,
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
