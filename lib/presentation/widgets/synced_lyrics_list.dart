import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/app_colors.dart';
import '../../data/database/app_database.dart' as drift_db;
import '../../domain/models/audio_text_timing.dart';
import '../../domain/models/chapter_manifest.dart';
import '../../services/lumina_audio_handler.dart';

class SyncedLyricLine {
  final String id;
  final String paragraphId;
  final String text;
  final int startMs;
  final int endMs;

  const SyncedLyricLine({
    required this.id,
    required this.paragraphId,
    required this.text,
    required this.startMs,
    required this.endMs,
  });
}

List<SyncedLyricLine> buildSyncedLyricLines(
  List<drift_db.Paragraph> paragraphs,
  ChapterManifest? manifest, {
  int maxChars = 100,
}) {
  final segments = {
    for (final segment in manifest?.segments ?? const <SegmentEntry>[])
      segment.paragraphId: segment,
  };
  final lines = <SyncedLyricLine>[];

  for (final paragraph in paragraphs) {
    final parts = splitLyricsText(paragraph.content, maxChars: maxChars);
    if (parts.isEmpty) continue;
    final segment = segments[paragraph.id];
    final durationMs = segment?.durationMs ?? 0;
    final timings = segment?.timings ?? const <AudioTextTiming>[];
    final ranges = _timingRanges(paragraph.content, parts, timings, durationMs);

    for (var index = 0; index < parts.length; index++) {
      lines.add(
        SyncedLyricLine(
          id: '${paragraph.id}:$index',
          paragraphId: paragraph.id,
          text: parts[index],
          startMs: ranges[index].$1,
          endMs: ranges[index].$2,
        ),
      );
    }
  }
  return lines;
}

List<String> splitLyricsText(String text, {int maxChars = 100}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];

  final sentences = _splitSentences(trimmed);
  return [
    for (final sentence in sentences)
      ..._splitLongLyricLine(sentence, maxChars),
  ];
}

List<String> _splitSentences(String text) {
  final sentences = <String>[];
  var start = 0;
  var inDoubleQuote = false;

  for (var index = 0; index < text.length; index++) {
    final character = text[index];
    if (character == '"') {
      inDoubleQuote = !inDoubleQuote;
      continue;
    }
    if (character == '“') {
      inDoubleQuote = true;
      continue;
    }
    if (character == '”') {
      inDoubleQuote = false;
      continue;
    }

    if (character == '\n') {
      _addSentence(sentences, text.substring(start, index));
      start = index + 1;
      continue;
    }
    if (!_isSentenceTerminator(character)) continue;
    if (character == '.' && _isAbbreviationOrDecimal(text, start, index)) {
      continue;
    }

    var end = index + 1;
    while (end < text.length && _isClosingMark(text[end])) {
      end++;
    }
    final closesQuote = end > index + 1;
    if (inDoubleQuote && !closesQuote) continue;

    var next = end;
    while (next < text.length && text[next].trim().isEmpty) {
      next++;
    }
    if (closesQuote &&
        next < text.length &&
        RegExp(r'[a-z]').hasMatch(text[next])) {
      continue;
    }

    _addSentence(sentences, text.substring(start, end));
    start = next;
    index = next - 1;
    if (closesQuote) inDoubleQuote = false;
  }

  if (start < text.length) {
    _addSentence(sentences, text.substring(start));
  }
  return sentences;
}

void _addSentence(List<String> sentences, String text) {
  final sentence = text.trim();
  if (sentence.isNotEmpty) sentences.add(sentence);
}

bool _isSentenceTerminator(String character) =>
    const {'.', '?', '!', '。', '？', '！'}.contains(character);

bool _isClosingMark(String character) =>
    const {'"', '”', '’', ')', ']', '}'}.contains(character);

bool _isAbbreviationOrDecimal(String text, int start, int periodIndex) {
  if (periodIndex > 0 &&
      periodIndex + 1 < text.length &&
      RegExp(r'\d').hasMatch(text[periodIndex - 1]) &&
      RegExp(r'\d').hasMatch(text[periodIndex + 1])) {
    return true;
  }

  var wordStart = periodIndex - 1;
  while (wordStart >= start && RegExp(r'[A-Za-z]').hasMatch(text[wordStart])) {
    wordStart--;
  }
  final word = text.substring(wordStart + 1, periodIndex).toLowerCase();
  return word.length == 1 ||
      const {
        'mr',
        'mrs',
        'ms',
        'dr',
        'prof',
        'st',
        'jr',
        'sr',
        'vs',
        'etc',
        'no',
      }.contains(word);
}

List<String> _splitLongLyricLine(String text, int maxChars) {
  final softMaxChars = math.max(maxChars, (maxChars * 1.2).round());
  if (text.length <= softMaxChars) return [text];

  final clauses = text
      .split(RegExp(r'(?<=[，,；;：:—–])\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (clauses.length < 2) return [text];

  final lines = <String>[];
  var buffer = '';
  for (final clause in clauses) {
    final candidate = buffer.isEmpty ? clause : '$buffer $clause';
    if (buffer.isEmpty || candidate.length <= softMaxChars) {
      buffer = candidate;
    } else {
      lines.add(buffer);
      buffer = clause;
    }
  }
  if (buffer.isNotEmpty) lines.add(buffer);
  return lines;
}

List<(int, int)> _timingRanges(
  String paragraph,
  List<String> parts,
  List<AudioTextTiming> timings,
  int durationMs,
) {
  final fallback = _estimatedRanges(parts, durationMs);
  if (timings.isEmpty) return fallback;

  final normalizedParagraph = _normalizeForAlignment(paragraph);
  if (normalizedParagraph.isEmpty) return fallback;

  final positionedTimings = <({AudioTextTiming timing, int start, int end})>[];
  var searchFrom = 0;
  for (final timing in timings) {
    final token = _normalizeForAlignment(timing.text);
    if (token.isEmpty) continue;
    var start = normalizedParagraph.indexOf(token, searchFrom);
    if (start < 0) start = normalizedParagraph.indexOf(token);
    if (start < 0) continue;
    final end = start + token.length;
    positionedTimings.add((timing: timing, start: start, end: end));
    searchFrom = end;
  }
  if (positionedTimings.isEmpty) return fallback;

  final ranges = <(int, int)>[];
  var normalizedOffset = 0;
  for (var index = 0; index < parts.length; index++) {
    final length = _normalizeForAlignment(parts[index]).length;
    final endOffset = normalizedOffset + length;
    final matches = positionedTimings.where(
      (item) => item.end > normalizedOffset && item.start < endOffset,
    );
    if (matches.isEmpty) {
      ranges.add(fallback[index]);
    } else {
      final first = matches.first;
      final last = matches.last;
      final startMs = _interpolateTiming(
        first,
        normalizedOffset.clamp(first.start, first.end),
      );
      final endMs = _interpolateTiming(
        last,
        endOffset.clamp(last.start, last.end),
      );
      ranges.add((startMs, endMs));
    }
    normalizedOffset = endOffset;
  }
  final effectiveDurationMs = positionedTimings.fold<int>(
    durationMs,
    (maximum, item) =>
        item.timing.endMs > maximum ? item.timing.endMs : maximum,
  );
  return _makeRangesMonotonic(ranges, effectiveDurationMs);
}

int _interpolateTiming(
  ({AudioTextTiming timing, int start, int end}) positioned,
  int offset,
) {
  final characterCount = positioned.end - positioned.start;
  final duration = positioned.timing.endMs - positioned.timing.startMs;
  if (characterCount <= 0 || duration <= 0) {
    return positioned.timing.startMs;
  }
  final progress = (offset - positioned.start) / characterCount;
  return positioned.timing.startMs + (duration * progress).round();
}

List<(int, int)> _makeRangesMonotonic(List<(int, int)> ranges, int durationMs) {
  final result = <(int, int)>[];
  var previousStart = 0;
  for (final range in ranges) {
    final upperLimit = durationMs > 0
        ? durationMs
        : (range.$2 > previousStart ? range.$2 : previousStart);
    final start = range.$1.clamp(previousStart, upperLimit);
    final end = range.$2.clamp(start, upperLimit);
    result.add((start, end));
    previousStart = start;
  }
  return result;
}

List<(int, int)> _estimatedRanges(List<String> parts, int durationMs) {
  final totalChars = parts.fold<int>(0, (sum, part) => sum + part.length);
  if (totalChars <= 0 || durationMs <= 0) {
    return List.filled(parts.length, (0, durationMs));
  }

  final ranges = <(int, int)>[];
  var chars = 0;
  for (final part in parts) {
    final startMs = (durationMs * chars / totalChars).round();
    chars += part.length;
    final endMs = (durationMs * chars / totalChars).round();
    ranges.add((startMs, endMs));
  }
  return ranges;
}

String _normalizeForAlignment(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u3400-\u9fff]+'), '');

class SyncedLyricsList extends StatefulWidget {
  final List<drift_db.Paragraph> paragraphs;
  final ChapterManifest? manifest;
  final LuminaAudioHandler handler;
  final bool expanded;

  const SyncedLyricsList({
    super.key,
    required this.paragraphs,
    required this.manifest,
    required this.handler,
    this.expanded = false,
  });

  @override
  State<SyncedLyricsList> createState() => _SyncedLyricsListState();
}

class _SyncedLyricsListState extends State<SyncedLyricsList> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _lineKeys = {};
  StreamSubscription<String?>? _paragraphSub;
  StreamSubscription<Duration>? _positionSub;
  Timer? _scrollDebounce;
  List<SyncedLyricLine> _lines = const [];
  String? _paragraphId;
  String? _activeLineId;
  String? _pendingScrollLineId;
  bool _pendingForceScroll = false;

  @override
  void initState() {
    super.initState();
    _rebuildLines();
    _bindHandler();
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paragraphs != widget.paragraphs ||
        oldWidget.manifest != widget.manifest) {
      _rebuildLines();
    }
    if (oldWidget.handler != widget.handler) _bindHandler();
  }

  void _rebuildLines() {
    _lines = buildSyncedLyricLines(widget.paragraphs, widget.manifest);
    _sync(widget.handler.position, forceScroll: true);
  }

  void _bindHandler() {
    _paragraphSub?.cancel();
    _positionSub?.cancel();
    _paragraphId = widget.handler.currentParagraphId;
    _paragraphSub = widget.handler.currentParagraphIdStream.listen((id) {
      _paragraphId = id;
      _sync(widget.handler.position, forceScroll: true);
    });
    _positionSub = widget.handler.positionStream.listen(_sync);
    _sync(widget.handler.position, forceScroll: true);
  }

  void _sync(Duration position, {bool forceScroll = false}) {
    if (!mounted) return;
    final paragraphLines = _lines
        .where((line) => line.paragraphId == _paragraphId)
        .toList(growable: false);
    SyncedLyricLine? active;
    for (final line in paragraphLines) {
      if (active == null || position.inMilliseconds >= line.startMs) {
        active = line;
      } else {
        break;
      }
    }
    if (!forceScroll && active?.id == _activeLineId) return;
    setState(() => _activeLineId = active?.id);
    if (active != null) _scrollTo(active.id, force: forceScroll);
  }

  void _scrollTo(String lineId, {bool force = false}) {
    _pendingScrollLineId = lineId;
    _pendingForceScroll = _pendingForceScroll || force;
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 70), () {
      if (!mounted) return;
      final pendingLineId = _pendingScrollLineId;
      final pendingForce = _pendingForceScroll;
      _pendingScrollLineId = null;
      _pendingForceScroll = false;
      if (pendingLineId == null) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _animateToLine(pendingLineId, force: pendingForce);
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  void _animateToLine(String lineId, {required bool force}) {
    if (!_scrollController.hasClients) return;
    final lineContext = _lineKeys[lineId]?.currentContext;
    final renderObject = lineContext?.findRenderObject();
    if (renderObject == null || !renderObject.attached) return;

    final position = _scrollController.position;
    final viewport = RenderAbstractViewport.of(renderObject);
    final target = viewport
        .getOffsetToReveal(renderObject, widget.expanded ? 0.24 : 0.18)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final distance = (target - position.pixels).abs();
    final tolerance = math.max(16.0, position.viewportDimension * 0.04);
    if (!force && distance <= tolerance) return;

    final viewportExtent = math.max(position.viewportDimension, 1.0);
    final screenDistance = (distance / viewportExtent).clamp(0.0, 1.75);
    final durationMs = (420 + screenDistance * 260).round().clamp(420, 875);
    _scrollController.animateTo(
      target,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _paragraphSub?.cancel();
    _positionSub?.cancel();
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        widget.expanded ? 24 : 20,
        8,
        widget.expanded ? 24 : 20,
        48,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in _lines)
            Builder(
              builder: (context) {
                final highlighted = line.id == _activeLineId;
                return InkWell(
                  key: _lineKeys.putIfAbsent(line.id, GlobalKey.new),
                  onTap: () => widget.handler.playFromParagraphOffset(
                    line.paragraphId,
                    Duration(milliseconds: line.startMs),
                  ),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontSize: widget.expanded ? 22 : 18,
                        fontWeight: FontWeight.w700,
                        color: highlighted
                            ? AppColors.lyricsTextPrimary
                            : AppColors.lyricsTextPrimary.withValues(
                                alpha: widget.expanded ? 0.42 : 0.3,
                              ),
                        height: widget.expanded ? 1.35 : 1.4,
                        fontFamily: fontFamily,
                      ),
                      child: Text(line.text),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
