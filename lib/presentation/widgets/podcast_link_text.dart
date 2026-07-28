import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_localizations.dart';

class PodcastTextSegment {
  final String text;
  final Uri? uri;
  final Duration? seekPosition;

  const PodcastTextSegment(this.text, {this.uri, this.seekPosition});
}

final _podcastUrlPattern = RegExp(
  r'https?://[^\s<>"“”]+',
  caseSensitive: false,
);
final _podcastTimestampPattern = RegExp(
  r'(?<!\d)(?:(\d{1,3}):)?([0-5]\d):([0-5]\d)(?![\d:])',
);

List<PodcastTextSegment> linkifyPodcastText(String text) {
  final urlSegments = <PodcastTextSegment>[];
  var cursor = 0;
  for (final match in _podcastUrlPattern.allMatches(text)) {
    if (match.start > cursor) {
      _appendPodcastTextSegment(
        urlSegments,
        PodcastTextSegment(text.substring(cursor, match.start)),
      );
    }

    final candidate = match.group(0)!;
    final linkText = _trimPodcastUrlPunctuation(candidate);
    final uri = Uri.tryParse(linkText);
    if (linkText.isNotEmpty &&
        uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http')) {
      _appendPodcastTextSegment(
        urlSegments,
        PodcastTextSegment(linkText, uri: uri),
      );
      if (linkText.length < candidate.length) {
        _appendPodcastTextSegment(
          urlSegments,
          PodcastTextSegment(candidate.substring(linkText.length)),
        );
      }
    } else {
      _appendPodcastTextSegment(urlSegments, PodcastTextSegment(candidate));
    }
    cursor = match.end;
  }
  if (cursor < text.length) {
    _appendPodcastTextSegment(
      urlSegments,
      PodcastTextSegment(text.substring(cursor)),
    );
  }

  final segments = <PodcastTextSegment>[];
  for (final segment in urlSegments) {
    if (segment.uri != null) {
      _appendPodcastTextSegment(segments, segment);
      continue;
    }
    _appendPodcastTimestampSegments(segments, segment.text);
  }
  return segments;
}

void _appendPodcastTimestampSegments(
  List<PodcastTextSegment> segments,
  String text,
) {
  var cursor = 0;
  for (final match in _podcastTimestampPattern.allMatches(text)) {
    if (match.start > cursor) {
      _appendPodcastTextSegment(
        segments,
        PodcastTextSegment(text.substring(cursor, match.start)),
      );
    }
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    _appendPodcastTextSegment(
      segments,
      PodcastTextSegment(
        match.group(0)!,
        seekPosition: Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
        ),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    _appendPodcastTextSegment(
      segments,
      PodcastTextSegment(text.substring(cursor)),
    );
  }
}

void _appendPodcastTextSegment(
  List<PodcastTextSegment> segments,
  PodcastTextSegment segment,
) {
  if (segment.text.isEmpty) return;
  if (segment.uri == null &&
      segment.seekPosition == null &&
      segments.isNotEmpty &&
      segments.last.uri == null &&
      segments.last.seekPosition == null) {
    final previous = segments.removeLast();
    segments.add(PodcastTextSegment('${previous.text}${segment.text}'));
    return;
  }
  segments.add(segment);
}

String _trimPodcastUrlPunctuation(String value) {
  var end = _firstPodcastUrlBoundary(value);
  const trailingPunctuation = '.,;:!?…，。；：！？\'’';
  while (end > 0 && trailingPunctuation.contains(value[end - 1])) {
    end--;
  }

  bool hasUnbalancedClosing(String opening, String closing) {
    final candidate = value.substring(0, end);
    return candidate.split(closing).length > candidate.split(opening).length;
  }

  var changed = true;
  while (changed && end > 0) {
    changed = false;
    for (final pair in const [('(', ')'), ('[', ']'), ('{', '}')]) {
      if (value[end - 1] == pair.$2 && hasUnbalancedClosing(pair.$1, pair.$2)) {
        end--;
        changed = true;
      }
    }
  }
  return value.substring(0, end);
}

int _firstPodcastUrlBoundary(String value) {
  const proseBoundaries = '、，。；：！？）》】」』';
  const pairs = {'(': ')', '[': ']', '{': '}'};
  final openingCounts = <String, int>{};
  for (var index = 0; index < value.length; index++) {
    final character = value[index];
    if (proseBoundaries.contains(character) || character == r'\') {
      return index;
    }
    final closing = pairs[character];
    if (closing != null) {
      openingCounts[character] = (openingCounts[character] ?? 0) + 1;
      continue;
    }
    for (final entry in pairs.entries) {
      if (character != entry.value) continue;
      final count = openingCounts[entry.key] ?? 0;
      if (count == 0) return index;
      openingCounts[entry.key] = count - 1;
      break;
    }
  }
  return value.length;
}

typedef PodcastUrlOpener = FutureOr<void> Function(Uri uri);
typedef PodcastTimestampSeeker = FutureOr<void> Function(Duration position);

class PodcastLinkText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;
  final PodcastUrlOpener? onOpenUrl;
  final PodcastTimestampSeeker? onSeekTimestamp;

  const PodcastLinkText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.textAlign,
    this.onOpenUrl,
    this.onSeekTimestamp,
  });

  @override
  State<PodcastLinkText> createState() => _PodcastLinkTextState();
}

class _PodcastLinkTextState extends State<PodcastLinkText> {
  List<PodcastTextSegment> _segments = const [];
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _rebuildSegments();
  }

  @override
  void didUpdateWidget(covariant PodcastLinkText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        (oldWidget.onSeekTimestamp == null) !=
            (widget.onSeekTimestamp == null)) {
      _rebuildSegments();
    }
  }

  bool _isInteractive(PodcastTextSegment segment) =>
      segment.uri != null ||
      (segment.seekPosition != null && widget.onSeekTimestamp != null);

  void _rebuildSegments() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    _segments = linkifyPodcastText(widget.text);
    for (final segment in _segments) {
      if (!_isInteractive(segment)) continue;
      _recognizers.add(
        TapGestureRecognizer()..onTap = () => unawaited(_activate(segment)),
      );
    }
  }

  Future<void> _activate(PodcastTextSegment segment) async {
    try {
      final uri = segment.uri;
      if (uri != null) {
        final opener = widget.onOpenUrl;
        if (opener != null) {
          await opener(uri);
          return;
        }
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) _showActionError(isLink: true);
        return;
      }

      final position = segment.seekPosition;
      final seeker = widget.onSeekTimestamp;
      if (position != null && seeker != null) await seeker(position);
    } catch (_) {
      if (mounted) _showActionError(isLink: segment.uri != null);
    }
  }

  void _showActionError({required bool isLink}) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          isLink
              ? context.tr('无法打开这个链接', 'Could not open this link')
              : context.tr('无法跳转到这个时间点', 'Could not seek to this time'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    var recognizerIndex = 0;
    return Text.rich(
      TextSpan(
        children: [
          for (final segment in _segments)
            if (!_isInteractive(segment))
              TextSpan(text: segment.text)
            else
              TextSpan(
                text: segment.text,
                style: TextStyle(
                  color: accent,
                  decoration: TextDecoration.underline,
                  decorationColor: accent.withValues(alpha: 0.7),
                ),
                mouseCursor: SystemMouseCursors.click,
                recognizer: _recognizers[recognizerIndex++],
              ),
        ],
      ),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}
