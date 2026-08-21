import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../data/dictionary/dictionary_repository.dart';
import '../../domain/models/vocabulary_entry.dart';
import '../../services/reading_level_estimator.dart';
import 'design_system/editorial_type.dart';

/// Word entry body shared by the dictionary detail page and the lookup sheet.
///
/// The detail page hoists the bookmark into its own top bar, so it renders
/// this with [showFavoriteAction] off.
class DictionaryEntryContent extends StatefulWidget {
  final DictionaryLookupResult result;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onPlayUs;
  final VoidCallback onPlayUk;
  final VoidCallback? onPlayContext;
  final bool showFavoriteAction;

  const DictionaryEntryContent({
    super.key,
    required this.result,
    required this.favorite,
    required this.onFavorite,
    required this.onPlayUs,
    required this.onPlayUk,
    this.onPlayContext,
    this.showFavoriteAction = true,
  });

  @override
  State<DictionaryEntryContent> createState() => _DictionaryEntryContentState();
}

class _DictionaryEntryContentState extends State<DictionaryEntryContent> {
  bool _longExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final entry = widget.result.entry;
    final lookupContext = widget.result.context;
    final cefr = _cefrLabel(entry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                entry.word,
                style: TextStyle(
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: ink,
                ),
              ),
            ),
            if (widget.showFavoriteAction)
              IconButton(
                tooltip: widget.favorite
                    ? context.tr('取消收藏', 'Remove favorite', 'お気に入りから削除')
                    : context.tr('收藏', 'Save word', '単語を保存'),
                onPressed: widget.onFavorite,
                icon: Icon(
                  widget.favorite ? Icons.bookmark : Icons.bookmark_border,
                  color: widget.favorite ? ink : ink.withValues(alpha: 0.28),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_hasText(entry.usPhonetic))
              _PronunciationGroup(
                label: context.tr('美', 'US', '米国'),
                phonetic: entry.usPhonetic!,
                onPlay: widget.onPlayUs,
              ),
            if (_hasText(entry.ukPhonetic))
              _PronunciationGroup(
                label: context.tr('英', 'UK', '英国'),
                phonetic: entry.ukPhonetic!,
                onPlay: widget.onPlayUk,
              ),
            if (!_hasText(entry.usPhonetic) && !_hasText(entry.ukPhonetic))
              _PronunciationGroup(
                label: context.tr('美', 'US', '米国'),
                phonetic: '',
                onPlay: widget.onPlayUs,
              ),
            if (cefr != null) _Pill(label: cefr),
          ],
        ),
        if (entry.definitions.isNotEmpty) ...[
          const SizedBox(height: 28),
          for (final definition in entry.definitions)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: _SenseRow(definition: definition),
            ),
        ],
        if (_hasText(entry.shortExplanation)) ...[
          const SizedBox(height: 15),
          _EntryCard(
            icon: Icons.lightbulb_outline,
            title: context.tr('一句话理解', 'In one sentence', '一言で言うと'),
            child: Text(entry.shortExplanation!, style: _proseStyle(context)),
          ),
        ],
        if (_hasText(entry.longExplanation)) ...[
          const SizedBox(height: 22),
          _EntryCard(
            icon: Icons.menu_book_outlined,
            title: context.tr('词源与用法', 'Origin & usage', '語源と用法'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 420),
                    curve: const Cubic(0.2, 0.8, 0.2, 1),
                    alignment: Alignment.topCenter,
                    child: _longExpanded
                        ? Text(
                            entry.longExplanation!,
                            style: _proseStyle(context),
                          )
                        : ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black, Colors.transparent],
                              stops: [0.52, 1],
                            ).createShader(bounds),
                            blendMode: BlendMode.dstIn,
                            child: Text(
                              entry.longExplanation!,
                              maxLines: 4,
                              style: _proseStyle(context),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  key: const ValueKey('dictionary-long-explanation-toggle'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _longExpanded = !_longExpanded),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _longExpanded
                            ? context.tr('收起', 'Show less', '折りたたむ')
                            : context.tr('展开全文', 'Read more', '続きを読む'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ink.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: _longExpanded ? 0.5 : 0,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 17,
                          color: ink.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (lookupContext != null && _hasText(lookupContext.sentence)) ...[
          const SizedBox(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  context.tr('你在听的内容里', 'IN WHAT YOU HEARD', '聴いた内容の中'),
                  style: kickerTextStyle(context),
                ),
              ),
              Text(
                context.tr('1 处', '1 passage', '1か所'),
                style: technicalTextStyle(
                  context,
                  size: 12.5,
                  alpha: 0.35,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ContextCard(
            lookupContext: lookupContext,
            word: entry.word,
            onPlay: widget.onPlayContext,
          ),
        ],
        if (entry.otherForms.isNotEmpty) ...[
          const SizedBox(height: 30),
          Text(
            context.tr('词族与搭配', 'FORMS & COLLOCATIONS', '語形とコロケーション'),
            style: kickerTextStyle(context),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final form in entry.otherForms)
                _Pill(label: form, prose: true),
            ],
          ),
        ],
        const SizedBox(height: 30),
        _SourceFooter(result: widget.result),
      ],
    );
  }
}

TextStyle _proseStyle(BuildContext context) => TextStyle(
  fontSize: 15.5,
  height: 1.6,
  color: context.appTextPrimary.withValues(alpha: 0.62),
);

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String? _cefrLabel(VocabularyEntry entry) {
  final code = entry.readingLevelCode?.trim().toUpperCase();
  final normalized = switch (code) {
    'A1' || 'A2' || 'B1' || 'B2' => code,
    _ => null,
  };
  if (normalized == null) return null;
  return entry.readingLevelSource == estimatedReadingLevelSource
      ? 'CEFR est. $normalized'
      : 'CEFR $normalized';
}

class _SenseRow extends StatelessWidget {
  final VocabularyDefinition definition;

  const _SenseRow({required this.definition});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              definition.partOfSpeech,
              style: technicalTextStyle(context, size: 11.5, alpha: 0.35),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            definition.meaning,
            style: TextStyle(fontSize: 16, height: 1.5, color: ink),
          ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _EntryCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: ink),
              const SizedBox(width: 9),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  final DictionaryLookupContext lookupContext;
  final String word;
  final VoidCallback? onPlay;

  const _ContextCard({
    required this.lookupContext,
    required this.word,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final accent = Theme.of(context).colorScheme.primary;
    final audioStartMs = lookupContext.audioStartMs;
    final timestamp = audioStartMs == null
        ? null
        : _formatTimestamp(audioStartMs);
    final meta = [
      if (lookupContext.chapterTitle.trim().isNotEmpty)
        lookupContext.chapterTitle,
      ?timestamp,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 18,
                  color: ink.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lookupContext.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: technicalTextStyle(
                          context,
                          size: 12,
                          alpha: 0.42,
                          weight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text.rich(
            _highlightWord(context, lookupContext.sentence, word),
            style: TextStyle(
              fontSize: 15.5,
              height: 1.62,
              color: ink.withValues(alpha: 0.62),
            ),
          ),
          if (onPlay != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              key: const ValueKey('dictionary-context-play'),
              behavior: HitTestBehavior.opaque,
              onTap: onPlay,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    timestamp == null
                        ? context.tr('播放这段', 'Play this passage', 'この箇所を再生')
                        : context.tr(
                            '从 $timestamp 播放这段',
                            'Play from $timestamp',
                            '$timestampからこの箇所を再生',
                          ),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Bolds every occurrence of the looked-up word inside the saved sentence.
  TextSpan _highlightWord(BuildContext context, String sentence, String word) {
    final term = word.trim();
    if (term.isEmpty) return TextSpan(text: sentence);
    final matches = RegExp(
      RegExp.escape(term),
      caseSensitive: false,
    ).allMatches(sentence);
    if (matches.isEmpty) return TextSpan(text: sentence);

    final highlight = TextStyle(
      fontWeight: FontWeight.w800,
      color: context.appTextPrimary,
    );
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: sentence.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: sentence.substring(match.start, match.end),
          style: highlight,
        ),
      );
      cursor = match.end;
    }
    if (cursor < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(cursor)));
    }
    return TextSpan(children: spans);
  }
}

class _PronunciationGroup extends StatelessWidget {
  final String label;
  final String phonetic;
  final VoidCallback onPlay;

  const _PronunciationGroup({
    required this.label,
    required this.phonetic,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          phonetic.isEmpty ? label : '$label $phonetic',
          style: technicalTextStyle(
            context,
            size: 13.5,
            alpha: 0.45,
            weight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPlay,
          child: Tooltip(
            message: context.tr('播放发音', 'Play pronunciation', '発音を再生'),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.volume_up_outlined, size: 17, color: ink),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool prose;

  const _Pill({required this.label, this.prose = false});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: prose ? 13 : 11, vertical: 6),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: prose
            ? TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: ink.withValues(alpha: 0.62),
              )
            : technicalTextStyle(context, size: 12.5, alpha: 0.45),
      ),
    );
  }
}

class _SourceFooter extends StatelessWidget {
  final DictionaryLookupResult result;

  const _SourceFooter({required this.result});

  @override
  Widget build(BuildContext context) {
    final entry = result.entry;
    final label =
        '${entry.providerLabel}'
        '${result.fromCache ? ' · ${context.tr('本地', 'Cached', 'キャッシュ済み')}' : ''}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => launchUrl(
        Uri.parse(entry.sourceUrl),
        mode: LaunchMode.externalApplication,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: technicalTextStyle(
                context,
                size: 12,
                alpha: 0.35,
                weight: FontWeight.w400,
              ),
            ),
          ),
          Icon(
            Icons.open_in_new,
            size: 15,
            color: context.appTextPrimary.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

String _formatTimestamp(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return duration.inHours > 0
      ? '${duration.inHours}:$minutes:$seconds'
      : '$minutes:$seconds';
}
