import 'subtitle_line.dart';
import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';

import '../../core/app_colors.dart';
import '../../core/app_design_tokens.dart';
import '../../core/app_localizations.dart';
import '../../data/database/app_database.dart' as drift_db;
import '../../domain/models/audio_text_timing.dart';
import '../../domain/models/chapter_manifest.dart';
import '../../domain/models/vocabulary_entry.dart';
import '../../services/lumina_audio_handler.dart';
import 'dictionary_lookup_sheet.dart';

/// Speech-friendly tuning knobs for the karaoke-style renderer.
const syncedLyricsSweepLeadMs = 80;
const syncedLyricsSweepFeatherEm = 0.5;

/// `playing` is user intent and remains true while just_audio is buffering.
bool syncedLyricsAudioIsAdvancing(PlaybackState state) =>
    state.playing && state.processingState == AudioProcessingState.ready;

/// A frame-rate playback clock anchored to just_audio's coarse position stream.
///
/// The real position is authoritative for seeks and pause transitions. Small
/// backwards corrections are ignored while playing so a 5 Hz stream cannot
/// make the highlight visibly reverse; the next ticker frames catch up.
class SyncedLyricsClock extends ChangeNotifier {
  SyncedLyricsClock({TickerProvider? vsync}) {
    if (vsync != null) _ticker = vsync.createTicker(_onTick);
  }

  Ticker? _ticker;
  Duration _position = Duration.zero;
  Duration _lastTickElapsed = Duration.zero;
  int _correctionUs = 0;
  bool _playing = false;
  bool _enabled = true;
  double _speed = 1.0;
  bool _initialized = false;

  Duration get position => _position;
  int get positionMs => _position.inMilliseconds;
  bool get playing => _playing;
  double get speed => _speed;

  void reanchor(
    Duration realPosition, {
    required bool playing,
    double speed = 1.0,
  }) {
    final nextSpeed = speed.clamp(0.5, 3.0).toDouble();
    final driftUs = realPosition.inMicroseconds - _position.inMicroseconds;
    final largeDrift =
        !_initialized || playing != _playing || driftUs.abs() >= 250000;
    final shouldMoveForward = driftUs >= 0;
    final positionChanged = !playing || largeDrift || shouldMoveForward;
    _playing = playing;
    _speed = nextSpeed;
    _initialized = true;
    if (largeDrift || !playing) _correctionUs = 0;
    if (!largeDrift && playing && driftUs > 0) {
      _correctionUs = math.max(_correctionUs, driftUs);
    }
    if (positionChanged &&
        _position != realPosition &&
        (largeDrift || !playing)) {
      _position = realPosition;
      notifyListeners();
    }
    _syncTicker();
  }

  void setPlaybackState({required bool playing, double speed = 1.0}) {
    _playing = playing;
    _speed = speed.clamp(0.5, 3.0).toDouble();
    _syncTicker();
  }

  void setEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    _syncTicker();
  }

  /// Advances the clock without requiring a Flutter ticker. This is also used
  /// by unit tests to verify extrapolation and drift behavior.
  void advance(Duration delta) {
    if (!_playing || !_enabled || delta <= Duration.zero) return;
    var advanceUs = (delta.inMicroseconds * _speed).round();
    if (_correctionUs > 0) {
      final correction = math.min(
        _correctionUs,
        math.max(1000, (_correctionUs * 0.18).round()),
      );
      advanceUs += correction;
      _correctionUs -= correction;
    }
    _position += Duration(microseconds: advanceUs);
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastTickElapsed;
    _lastTickElapsed = elapsed;
    advance(delta);
  }

  void _syncTicker() {
    final ticker = _ticker;
    if (ticker == null) return;
    final shouldTick = _enabled && _playing;
    if (shouldTick && !ticker.isActive) {
      _lastTickElapsed = Duration.zero;
      ticker.start();
    } else if (!shouldTick && ticker.isActive) {
      ticker.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}

class SyncedLyricWord {
  final String text;
  final String leadingWhitespace;
  final int startMs;
  final int endMs;

  const SyncedLyricWord({
    required this.text,
    required this.leadingWhitespace,
    required this.startMs,
    required this.endMs,
  });
}

class SyncedLyricLine {
  final String id;
  final String paragraphId;
  final String text;
  final int startMs;
  final int endMs;
  final List<SyncedLyricWord> words;

  /// Paragraphs represented by this display line.
  ///
  /// This normally contains only [paragraphId]. A punctuation-only paragraph
  /// can be folded into the preceding line while remaining addressable when
  /// playback advances to that paragraph.
  final List<String> sourceParagraphIds;

  const SyncedLyricLine({
    required this.id,
    required this.paragraphId,
    required this.text,
    required this.startMs,
    required this.endMs,
    this.words = const [],
    this.sourceParagraphIds = const [],
  });

  Iterable<String> get representedParagraphIds =>
      sourceParagraphIds.isEmpty ? [paragraphId] : sourceParagraphIds;
}

typedef _PositionedTiming = ({AudioTextTiming timing, int start, int end});

/// Optional instrumentation for transcript-line construction.
///
/// It intentionally measures index nodes rather than elapsed time so the
/// large-transcript regression test stays deterministic on both CI and slow
/// devices. Production callers do not need to provide one.
@visibleForTesting
class SyncedLyricsBuildMetrics {
  int timingRangeQueries = 0;
  int timingIndexNodeVisits = 0;
}

/// Finds the first and last timing whose normalized-text interval overlaps a
/// requested range.
///
/// Positioned timings are normally disjoint word intervals, but some speech
/// engines emit phrase-level timings that span several display words. A plain
/// binary search is not sufficient for those overlapping intervals: one long
/// interval near the beginning would make every later query scan from zero.
/// The max-end tree lets either edge of the matching interval be found in
/// logarithmic time while retaining phrase-level interpolation.
class _PositionedTimingIndex {
  _PositionedTimingIndex(List<_PositionedTiming> positioned, {this.metrics})
    : _items = [
        for (var index = 0; index < positioned.length; index++)
          (positioned: positioned[index], originalIndex: index),
      ] {
    _items.sort((left, right) {
      final byStart = left.positioned.start.compareTo(right.positioned.start);
      if (byStart != 0) return byStart;
      // Keep the manifest order for identical source positions. This matches
      // the old `where(...).first/last` behavior for phrase-level timings.
      return left.originalIndex.compareTo(right.originalIndex);
    });

    var leafCount = 1;
    while (leafCount < _items.length) {
      leafCount <<= 1;
    }
    _leafCount = leafCount;
    _maxEnds = List<int>.filled(leafCount * 2, -1);
    for (var index = 0; index < _items.length; index++) {
      _maxEnds[leafCount + index] = _items[index].positioned.end;
    }
    for (var index = leafCount - 1; index > 0; index--) {
      _maxEnds[index] = math.max(
        _maxEnds[index << 1],
        _maxEnds[index << 1 | 1],
      );
    }
  }

  final SyncedLyricsBuildMetrics? metrics;
  final List<({_PositionedTiming positioned, int originalIndex})> _items;
  late final int _leafCount;
  late final List<int> _maxEnds;

  bool get isEmpty => _items.isEmpty;

  int get latestTimingEndMs => _items.fold<int>(
    0,
    (maximum, item) => math.max(maximum, item.positioned.timing.endMs),
  );

  ({_PositionedTiming first, _PositionedTiming last})? overlapping(
    int start,
    int end,
  ) {
    // A display-only punctuation line has no normalized characters, but it
    // can still sit inside a phrase-level timing interval. The old overlap
    // predicate intentionally matched that zero-length range when it was
    // strictly contained by a timing, so retain that behavior.
    if (start > end || _items.isEmpty) return null;
    metrics?.timingRangeQueries++;

    // Only timings that start before the requested end can overlap it.
    final upperBound = _firstStartAtOrAfter(end);
    if (upperBound == 0) return null;
    final firstIndex = _findFirstEndingAfter(
      node: 1,
      nodeStart: 0,
      nodeEnd: _leafCount,
      upperBound: upperBound,
      start: start,
    );
    if (firstIndex == null) return null;
    final lastIndex = _findLastEndingAfter(
      node: 1,
      nodeStart: 0,
      nodeEnd: _leafCount,
      upperBound: upperBound,
      start: start,
    );
    if (lastIndex == null) return null;
    return (
      first: _items[firstIndex].positioned,
      last: _items[lastIndex].positioned,
    );
  }

  int _firstStartAtOrAfter(int offset) {
    var low = 0;
    var high = _items.length;
    while (low < high) {
      metrics?.timingIndexNodeVisits++;
      final middle = low + ((high - low) >> 1);
      if (_items[middle].positioned.start < offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  int? _findFirstEndingAfter({
    required int node,
    required int nodeStart,
    required int nodeEnd,
    required int upperBound,
    required int start,
  }) {
    metrics?.timingIndexNodeVisits++;
    if (nodeStart >= upperBound || _maxEnds[node] <= start) return null;
    if (nodeEnd - nodeStart == 1) {
      return nodeStart < _items.length ? nodeStart : null;
    }
    final middle = nodeStart + ((nodeEnd - nodeStart) >> 1);
    return _findFirstEndingAfter(
          node: node << 1,
          nodeStart: nodeStart,
          nodeEnd: middle,
          upperBound: upperBound,
          start: start,
        ) ??
        _findFirstEndingAfter(
          node: node << 1 | 1,
          nodeStart: middle,
          nodeEnd: nodeEnd,
          upperBound: upperBound,
          start: start,
        );
  }

  int? _findLastEndingAfter({
    required int node,
    required int nodeStart,
    required int nodeEnd,
    required int upperBound,
    required int start,
  }) {
    metrics?.timingIndexNodeVisits++;
    if (nodeStart >= upperBound || _maxEnds[node] <= start) return null;
    if (nodeEnd - nodeStart == 1) {
      return nodeStart < _items.length ? nodeStart : null;
    }
    final middle = nodeStart + ((nodeEnd - nodeStart) >> 1);
    return _findLastEndingAfter(
          node: node << 1 | 1,
          nodeStart: middle,
          nodeEnd: nodeEnd,
          upperBound: upperBound,
          start: start,
        ) ??
        _findLastEndingAfter(
          node: node << 1,
          nodeStart: nodeStart,
          nodeEnd: middle,
          upperBound: upperBound,
          start: start,
        );
  }
}

class SelectableTextToken {
  final String text;
  final int start;
  final int end;

  const SelectableTextToken({
    required this.text,
    required this.start,
    required this.end,
  });
}

List<SelectableTextToken> tokenizeSelectableText(String text) {
  final pattern = RegExp(
    r"[A-Za-z\u00c0-\u02af\u3400-\u9fff]+(?:['’\-][A-Za-z\u00c0-\u02af\u3400-\u9fff]+)*|\d+(?:[.,]\d+)*|[^\s]",
    unicode: true,
  );
  return [
    for (final match in pattern.allMatches(text))
      SelectableTextToken(
        text: match.group(0)!,
        start: match.start,
        end: match.end,
      ),
  ];
}

String selectedTokenText(
  String source,
  List<SelectableTextToken> tokens,
  Set<int> selected,
) {
  if (selected.isEmpty) return '';
  final indices = selected.where((index) => index < tokens.length).toList()
    ..sort();
  if (indices.isEmpty) return '';
  final buffer = StringBuffer(tokens[indices.first].text);
  for (var position = 1; position < indices.length; position++) {
    final previous = indices[position - 1];
    final current = indices[position];
    if (current == previous + 1) {
      buffer.write(
        source.substring(tokens[previous].end, tokens[current].start),
      );
    } else {
      buffer.write(' ');
    }
    buffer.write(tokens[current].text);
  }
  return buffer.toString().trim();
}

List<SyncedLyricLine> buildSyncedLyricLines(
  List<drift_db.Paragraph> paragraphs,
  ChapterManifest? manifest, {
  int maxChars = 100,
  SyncedLyricsBuildMetrics? metrics,
}) {
  final segments = {
    for (final segment in manifest?.segments ?? const <SegmentEntry>[])
      segment.paragraphId: segment,
  };
  final lines = <SyncedLyricLine>[];

  for (final paragraph in paragraphs) {
    // ASR transcripts already carry pause-aware line boundaries. Splitting
    // them into sentences again would discard those grouping decisions.
    final isTranscript =
        manifest?.providerId == 'whisper-local' ||
        manifest?.providerId == 'librivox';
    final parts = isTranscript
        ? paragraph.content
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList()
        : splitLyricsText(paragraph.content, maxChars: maxChars);
    if (parts.isEmpty) continue;

    // Light-novel source files sometimes put a Japanese closing quote in its
    // own physical paragraph. It has no spoken content, so presenting it as a
    // separate karaoke line creates the conspicuous orphan shown in the
    // player. Fold it into the preceding line, while retaining this paragraph
    // as an alias so the line stays active for already-generated audio.
    if (parts.length == 1 &&
        _isStandaloneClosingMarks(parts.single) &&
        lines.isNotEmpty) {
      final previous = lines.removeLast();
      final markStartMs = math.max(previous.startMs, previous.endMs - 1);
      lines.add(
        SyncedLyricLine(
          id: previous.id,
          paragraphId: previous.paragraphId,
          text: '${previous.text}${parts.single}',
          startMs: previous.startMs,
          endMs: previous.endMs,
          words: [
            ...previous.words,
            SyncedLyricWord(
              text: parts.single,
              leadingWhitespace: '',
              startMs: markStartMs,
              endMs: math.max(markStartMs + 1, previous.endMs),
            ),
          ],
          sourceParagraphIds: [
            ...previous.representedParagraphIds,
            paragraph.id,
          ],
        ),
      );
      continue;
    }
    final segment = segments[paragraph.id];
    final durationMs = segment?.durationMs ?? 0;
    final timings = segment?.timings ?? const <AudioTextTiming>[];
    final positionedTimings = _positionTimings(paragraph.content, timings);
    final timingIndex = _PositionedTimingIndex(
      positionedTimings,
      metrics: metrics,
    );
    final ranges = _timingRanges(
      paragraph.content,
      parts,
      timings,
      durationMs,
      timingIndex: timingIndex,
    );

    var normalizedOffset = 0;
    for (var index = 0; index < parts.length; index++) {
      final normalizedLength = _normalizeForAlignment(parts[index]).length;
      final endOffset = normalizedOffset + normalizedLength;
      lines.add(
        SyncedLyricLine(
          id: '${paragraph.id}:$index',
          paragraphId: paragraph.id,
          text: parts[index],
          startMs: ranges[index].$1,
          endMs: ranges[index].$2,
          words: _buildLyricWords(
            parts[index],
            lineStartMs: ranges[index].$1,
            lineEndMs: ranges[index].$2,
            lineStartOffset: normalizedOffset,
            lineEndOffset: endOffset,
            timingIndex: timingIndex,
          ),
        ),
      );
      normalizedOffset = endOffset;
    }
  }
  return lines;
}

List<String> splitLyricsText(String text, {int maxChars = 100}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];

  final sentences = _mergeStandaloneClosingMarkSentences(
    _splitSentences(trimmed),
  );
  return [
    for (final sentence in sentences)
      ..._splitLongLyricLine(sentence, maxChars),
  ];
}

List<String> _mergeStandaloneClosingMarkSentences(List<String> sentences) {
  final merged = <String>[];
  for (final sentence in sentences) {
    if (merged.isNotEmpty && _isStandaloneClosingMarks(sentence)) {
      merged[merged.length - 1] = '${merged.last}${sentence.trim()}';
    } else {
      merged.add(sentence);
    }
  }
  return merged;
}

bool _isStandaloneClosingMarks(String text) => RegExp(
  r'^[\s\u3000]*[\u300d\u300f\u3011\u3015\u3017\u3019\u301b\u3009\u300b\u3001\u3002\uff0c\uff0e\uff01\uff1f\u2019\u201d\)\]\}]+[\s\u3000]*$',
  unicode: true,
).hasMatch(text);

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
    if (character == '.' &&
        (_isIntraTokenPeriod(text, index) ||
            _isAbbreviationOrDecimal(text, start, index))) {
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

bool _isClosingMark(String character) => const {
  '"',
  '”',
  '’',
  ')',
  ']',
  '}',
  '」',
  '』',
  '】',
  '〕',
  '〗',
  '〙',
  '〛',
  '〉',
  '》',
}.contains(character);

final _intraTokenPeriodPattern = RegExp(r'[A-Za-z0-9.]');

/// A period glued straight onto a letter, a digit, or another period sits
/// inside a token — `teacherluke.co.uk`, `notes.txt`, `v1.2`, an ellipsis —
/// rather than ending a sentence. Speech leaves whitespace after a real
/// sentence break, so requiring it keeps a spoken URL on one lyric line
/// instead of shattering it into `teacherluke.` / `co.` / `uk/premium.`
///
/// This deliberately only guards the ASCII period. CJK text runs `。` straight
/// into the next sentence with no space, so the same rule there would stop
/// Chinese and Japanese transcripts from splitting at all.
bool _isIntraTokenPeriod(String text, int periodIndex) {
  final next = periodIndex + 1;
  if (next >= text.length) return false;
  return _intraTokenPeriodPattern.hasMatch(text[next]);
}

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
  int durationMs, {
  _PositionedTimingIndex? timingIndex,
}) {
  final fallback = _estimatedRanges(parts, durationMs);
  if (timings.isEmpty) return fallback;

  final positionedIndex =
      timingIndex ??
      _PositionedTimingIndex(_positionTimings(paragraph, timings));
  if (positionedIndex.isEmpty) return fallback;

  final ranges = <(int, int)>[];
  var normalizedOffset = 0;
  for (var index = 0; index < parts.length; index++) {
    final length = _normalizeForAlignment(parts[index]).length;
    final endOffset = normalizedOffset + length;
    final matches = positionedIndex.overlapping(normalizedOffset, endOffset);
    if (matches == null) {
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
  final effectiveDurationMs = math.max(
    durationMs,
    positionedIndex.latestTimingEndMs,
  );
  return _makeRangesMonotonic(ranges, effectiveDurationMs);
}

List<_PositionedTiming> _positionTimings(
  String paragraph,
  List<AudioTextTiming> timings,
) {
  final normalizedParagraph = _normalizeForAlignment(paragraph);
  if (normalizedParagraph.isEmpty || timings.isEmpty) return const [];

  // Transcripts are the timing text with only whitespace/line breaks changed.
  // Use source order directly, avoiding ambiguous searches for repeated words.
  final tokens = [
    for (final timing in timings) _normalizeForAlignment(timing.text),
  ];
  if (tokens.join() == normalizedParagraph) {
    var offset = 0;
    return [
      for (var i = 0; i < timings.length; i++)
        if (tokens[i].isNotEmpty)
          (timing: timings[i], start: offset, end: offset += tokens[i].length),
    ];
  }

  final positioned = <_PositionedTiming>[];
  var searchFrom = 0;
  for (final timing in timings) {
    final token = _normalizeForAlignment(timing.text);
    if (token.isEmpty) continue;
    var start = normalizedParagraph.indexOf(token, searchFrom);
    // Never map a later repeated word backwards onto an earlier occurrence.
    if (start < 0) continue;
    final end = start + token.length;
    positioned.add((timing: timing, start: start, end: end));
    searchFrom = end;
  }
  return positioned;
}

List<SyncedLyricWord> _buildLyricWords(
  String text, {
  required int lineStartMs,
  required int lineEndMs,
  required int lineStartOffset,
  required int lineEndOffset,
  required _PositionedTimingIndex timingIndex,
}) {
  final ranges = _lyricWordRanges(text);
  if (ranges.isEmpty) {
    return [
      SyncedLyricWord(
        text: text,
        leadingWhitespace: '',
        startMs: lineStartMs,
        endMs: lineEndMs,
      ),
    ];
  }

  final normalizedLineLength = math.max(1, lineEndOffset - lineStartOffset);
  final normalizedRanges = _normalizedWordRanges(text, ranges);
  var previousEndMs = lineStartMs;
  final words = <SyncedLyricWord>[];
  var sourceEnd = 0;
  for (var index = 0; index < ranges.length; index++) {
    final range = ranges[index];
    final normalizedRange = normalizedRanges[index];
    final word = text.substring(range.start, range.end);
    final leadingWhitespace = text.substring(sourceEnd, range.start);
    sourceEnd = range.end;
    final wordStartOffset = lineStartOffset + normalizedRange.start;
    final wordEndOffset = lineStartOffset + normalizedRange.end;
    final matches = timingIndex.overlapping(wordStartOffset, wordEndOffset);

    int startMs;
    int endMs;
    if (matches != null) {
      final first = matches.first;
      final last = matches.last;
      startMs = _interpolateTiming(
        first,
        wordStartOffset.clamp(first.start, first.end),
      );
      endMs = _interpolateTiming(
        last,
        wordEndOffset.clamp(last.start, last.end),
      );
    } else {
      final startRatio =
          (wordStartOffset - lineStartOffset) / normalizedLineLength;
      final endRatio = (wordEndOffset - lineStartOffset) / normalizedLineLength;
      startMs = lineStartMs + ((lineEndMs - lineStartMs) * startRatio).round();
      endMs = lineStartMs + ((lineEndMs - lineStartMs) * endRatio).round();
    }
    startMs = math.max(previousEndMs, startMs);
    endMs = math.max(startMs + 1, endMs);
    words.add(
      SyncedLyricWord(
        text: word,
        leadingWhitespace: leadingWhitespace,
        startMs: startMs,
        endMs: endMs,
      ),
    );
    previousEndMs = endMs;
  }
  return words;
}

/// Maps every display-word range to the number of normalized characters
/// before and after it. The old implementation re-normalized the entire line
/// prefix for every word, which is another quadratic path for long lines.
List<({int start, int end})> _normalizedWordRanges(
  String text,
  List<({int start, int end})> ranges,
) {
  final normalized = <({int start, int end})>[];
  var sourceOffset = 0;
  var normalizedOffset = 0;
  for (final range in ranges) {
    normalizedOffset += _normalizeForAlignment(
      text.substring(sourceOffset, range.start),
    ).length;
    final start = normalizedOffset;
    normalizedOffset += _normalizeForAlignment(
      text.substring(range.start, range.end),
    ).length;
    normalized.add((start: start, end: normalizedOffset));
    sourceOffset = range.end;
  }
  return normalized;
}

List<({int start, int end})> _lyricWordRanges(String text) {
  final pattern = RegExp(
    r"[A-Za-z\u00c0-\u02af\u1e00-\u1eff\u3400-\u9fff]+(?:['’\-][A-Za-z\u00c0-\u02af\u1e00-\u1eff\u3400-\u9fff]+)*|\d+(?:[.,]\d+)*|[^\s]",
    unicode: true,
  );
  final ranges = <({int start, int end})>[];
  for (final match in pattern.allMatches(text)) {
    final token = match.group(0)!;
    final alignmentToken = _normalizeForAlignment(token).isNotEmpty;
    final characterTimedScript = RegExp(
      r'^[\u3040-\u30ff\u3130-\u318f\u3400-\u9fff\uac00-\ud7af]+$',
      unicode: true,
    ).hasMatch(token);
    if (!alignmentToken) {
      if (ranges.isNotEmpty && ranges.last.end == match.start) {
        final previous = ranges.removeLast();
        ranges.add((start: previous.start, end: match.end));
      } else {
        ranges.add((start: match.start, end: match.end));
      }
      continue;
    }
    if (!characterTimedScript) {
      ranges.add((start: match.start, end: match.end));
      continue;
    }
    for (var index = 0; index < token.length; index++) {
      ranges.add((start: match.start + index, end: match.start + index + 1));
    }
  }
  return ranges;
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

final _alignmentNoisePattern = RegExp(
  r'[^a-z0-9\u00c0-\u02af\u0300-\u036f\u0370-\u052f\u0590-\u08ff\u0900-\u0fff\u1100-\u1fff\u3040-\u30ff\u3130-\u318f\u3400-\u9fff\ua000-\ua4cf\ua960-\ua97f\uac00-\ud7af\uf900-\ufaff\uff00-\uffef]+',
  unicode: true,
);

String _normalizeForAlignment(String text) =>
    text.toLowerCase().replaceAll(_alignmentNoisePattern, '');

typedef _SweepGeometry = ({double center, double rowTop, double rowBottom});

/// Resolves where the highlight sweep currently sits: its x offset plus the
/// vertical band of the visual row holding the active word. Wrapped lines
/// occupy several rows, and the sweep has to be confined to one of them.
@visibleForTesting
({double center, double rowTop, double rowBottom})? syncedLyricsSweepGeometry({
  required TextPainter painter,
  required SyncedLyricLine line,
  required int positionMs,
}) {
  final ranges = _lyricWordRanges(line.text);
  if (ranges.isEmpty || line.words.isEmpty) return null;

  final effectivePosition = positionMs + syncedLyricsSweepLeadMs;
  var wordIndex = -1;
  for (var index = 0; index < line.words.length; index++) {
    final word = line.words[index];
    if (effectivePosition < word.startMs) {
      wordIndex = index;
      break;
    }
    wordIndex = index;
    if (effectivePosition <= word.endMs) break;
  }
  if (wordIndex < 0 || wordIndex >= ranges.length) return null;

  final range = ranges[wordIndex];
  final boxes = painter.getBoxesForSelection(
    TextSelection(baseOffset: range.start, extentOffset: range.end),
  );
  if (boxes.isEmpty) return null;

  final word = line.words[wordIndex];
  final progress =
      ((effectivePosition - word.startMs) /
              math.max(1, word.endMs - word.startMs))
          .clamp(0.0, 1.0)
          .toDouble();

  // A word straddling a line break reports one box per row; walk them in order
  // so the sweep follows the glyphs instead of snapping back to the first row.
  final scaled = progress * boxes.length;
  final boxIndex = math.min(boxes.length - 1, scaled.floor());
  final box = boxes[boxIndex];
  final boxProgress = (scaled - boxIndex).clamp(0.0, 1.0).toDouble();
  return (
    center: box.left + (box.right - box.left) * boxProgress,
    rowTop: box.top,
    rowBottom: box.bottom,
  );
}

class _LyricSweepPainter extends CustomPainter {
  final SyncedLyricLine line;
  final TextStyle style;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final SyncedLyricsClock clock;

  _LyricSweepPainter({
    required this.line,
    required this.style,
    required this.textDirection,
    required this.textScaler,
    required this.clock,
  }) : super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    final bright = style.color ?? Colors.white;
    final painter = TextPainter(
      text: TextSpan(
        text: line.text,
        style: style.copyWith(color: bright.withValues(alpha: 0.46)),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);
    painter.paint(canvas, Offset.zero);

    final sweep = syncedLyricsSweepGeometry(
      painter: painter,
      line: line,
      positionMs: clock.positionMs,
    );
    if (sweep == null) {
      painter.dispose();
      return;
    }

    // The bright layer is painted whole and then masked back out, because a
    // horizontal gradient is constant down the y axis: applied to the text
    // directly it would light every wrapped row at the same x instead of
    // sweeping row by row.
    final brightPainter = TextPainter(
      text: TextSpan(
        text: line.text,
        style: style.copyWith(color: bright),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);
    canvas.saveLayer(Offset.zero & size, Paint());
    brightPainter.paint(canvas, Offset.zero);
    _paintRevealMask(canvas, size, sweep);
    canvas.restore();
    brightPainter.dispose();
    painter.dispose();
  }

  /// Masks the bright layer down to what has been spoken so far. The mask must
  /// cover the full bounds — `dstIn` leaves untouched regions at full opacity,
  /// so rows below the sweep are erased explicitly rather than skipped.
  void _paintRevealMask(Canvas canvas, Size size, _SweepGeometry sweep) {
    final feather = (style.fontSize ?? 18) * syncedLyricsSweepFeatherEm;
    final safeWidth = math.max(size.width, 1.0);
    final leading = ((sweep.center - feather) / safeWidth).clamp(0.0, 1.0);
    final trailing = ((sweep.center + feather) / safeWidth)
        .clamp(leading + 0.001, 1.0)
        .toDouble();

    if (sweep.rowTop > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, 0, size.width, sweep.rowTop),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..color = const Color(0xFFFFFFFF),
      );
    }

    final band = Rect.fromLTRB(0, sweep.rowTop, size.width, sweep.rowBottom);
    canvas.drawRect(
      band,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x59FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0, leading, trailing, 1],
        ).createShader(band),
    );

    if (sweep.rowBottom < size.height) {
      canvas.drawRect(
        Rect.fromLTRB(0, sweep.rowBottom, size.width, size.height),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..color = const Color(0x00FFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LyricSweepPainter oldDelegate) =>
      oldDelegate.line != line ||
      oldDelegate.style != style ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.clock != clock;
}

class SyncedLyricsList extends StatefulWidget {
  final List<drift_db.Paragraph> paragraphs;
  final ChapterManifest? manifest;
  final LuminaAudioHandler handler;
  final bool playbackEnabled;
  final bool expanded;
  final bool focusMode;
  final String? bookTitle;
  final String? chapterTitle;
  final String? bookId;
  final String? chapterId;
  final bool virtualized;
  final double scrollSpeed;
  final bool sweepEnabled;
  final double subtitleGap;
  final double fontScale;

  const SyncedLyricsList({
    super.key,
    required this.paragraphs,
    required this.manifest,
    required this.handler,
    this.playbackEnabled = true,
    this.expanded = false,
    this.focusMode = false,
    this.bookTitle,
    this.chapterTitle,
    this.bookId,
    this.chapterId,
    this.virtualized = false,
    this.scrollSpeed = 1.0,
    this.sweepEnabled = true,
    this.subtitleGap = 40,
    this.fontScale = 1,
  });

  @override
  State<SyncedLyricsList> createState() => _SyncedLyricsListState();
}

class _SyncedLyricsListState extends State<SyncedLyricsList>
    with TickerProviderStateMixin {
  /// Vertical padding a lyric line adds around its text, so a measured or
  /// estimated text height turns into the extent the list lays out.
  double get _lyricLineVerticalPadding => widget.subtitleGap.clamp(20.0, 80.0);

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<SelectionAreaState> _selectionAreaKey =
      GlobalKey<SelectionAreaState>();
  final Map<String, GlobalKey> _lineKeys = {};
  StreamSubscription<String?>? _paragraphSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription? _playbackStateSub;
  Timer? _scrollDebounce;
  Timer? _manualScrollResume;
  late final SyncedLyricsClock _clock;
  AnimationController? _scrollAnimation;
  List<SyncedLyricLine> _lines = const [];
  Map<String, List<SyncedLyricLine>> _linesByParagraph = const {};
  Map<String, int> _lineIndexById = const {};

  /// Per-line heights and their prefix sums. Both are kept at `_lines.length`
  /// while the list is virtualized: the first [_virtualMeasuredCount] entries
  /// were laid out exactly, the rest are estimates good enough to keep
  /// `itemExtentBuilder` answerable for every index.
  List<double> _virtualLineExtents = const [];
  List<double> _virtualLineOffsets = const [];
  int _virtualMeasuredCount = 0;

  /// Row geometry sampled from real text layout, used to estimate the lines
  /// this pass has not reached yet. Both are cleared whenever the layout
  /// constraints or the text style change.
  double? _estimateRowHeight;
  double? _estimateCharsPerRow;
  double? _virtualMetricsWidth;
  TextStyle? _virtualMetricsStyle;
  TextDirection? _virtualMetricsDirection;
  TextScaler? _virtualMetricsTextScaler;
  double _virtualTopPadding = 0;
  int _virtualMetricsGeneration = 0;
  bool _virtualMetricsBuilding = false;
  String? _deferredVirtualScrollLineId;
  bool _deferredVirtualScrollForce = false;
  String? _anchorLineId;
  double _anchorDelta = 0;
  bool _parkedAtEnd = false;
  String? _paragraphId;
  String? _activeLineId;
  String? _pendingScrollLineId;
  bool _pendingForceScroll = false;
  String _selectedText = '';
  String? _selectionLineId;
  String? _wordSelectionLineId;
  List<SelectableTextToken> _wordSelectionTokens = const [];
  final Set<int> _selectedTokenIndices = {};
  final GlobalKey _wordSelectionTextKey = GlobalKey();
  int? _pointerStartToken;
  Offset? _pointerStartPosition;
  bool _pointerDidDrag = false;
  String? _pressedLineId;
  bool _manuallyScrolling = false;
  bool _tickerModeEnabled = true;
  bool get _selectionActive =>
      _wordSelectionLineId != null || _selectedText.isNotEmpty;

  bool get _hasAnimatedTimings =>
      widget.manifest?.segments.any((segment) => segment.timings.isNotEmpty) ??
      false;

  bool get _clockEnabled =>
      widget.playbackEnabled && _hasAnimatedTimings && _tickerModeEnabled;

  @override
  void initState() {
    super.initState();
    _clock = SyncedLyricsClock(vsync: this)..addListener(_handleClockTick);
    _rebuildLines();
    _bindHandler();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    _clock.setEnabled(_clockEnabled);
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paragraphs != widget.paragraphs ||
        oldWidget.manifest != widget.manifest) {
      // A podcast caches a chunk every few minutes while the reader is
      // somewhere else in the transcript. Rebuild the lines, but let the
      // position stand unless the active line itself moved.
      _captureScrollAnchor();
      _rebuildLines(forceScroll: false);
      if (_anchorLineId != null) {
        // Scroll offsets cannot be touched while the parent is building, and
        // the new extents are not laid out yet either.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _restoreScrollAnchor();
        });
        WidgetsBinding.instance.scheduleFrame();
      }
    }
    if (oldWidget.expanded != widget.expanded ||
        oldWidget.subtitleGap != widget.subtitleGap ||
        oldWidget.fontScale != widget.fontScale ||
        oldWidget.focusMode != widget.focusMode ||
        oldWidget.virtualized != widget.virtualized) {
      _invalidateVirtualMetrics();
    }
    if (oldWidget.handler != widget.handler ||
        oldWidget.playbackEnabled != widget.playbackEnabled) {
      _bindHandler();
    }
  }

  void _rebuildLines({bool forceScroll = true}) {
    final previousLines = _lines;
    _lines = buildSyncedLyricLines(widget.paragraphs, widget.manifest);
    final linesByParagraph = <String, List<SyncedLyricLine>>{};
    final lineIndexById = <String, int>{};
    for (var index = 0; index < _lines.length; index++) {
      final line = _lines[index];
      for (final paragraphId in line.representedParagraphIds) {
        (linesByParagraph[paragraphId] ??= []).add(line);
      }
      lineIndexById[line.id] = index;
    }
    _linesByParagraph = linesByParagraph;
    _lineIndexById = lineIndexById;
    _clock.setEnabled(_clockEnabled);
    _lineKeys.removeWhere((id, _) => !lineIndexById.containsKey(id));
    _retainVirtualMetrics(previousLines);
    if (_wordSelectionLineId != null &&
        !_lines.any((line) => line.id == _wordSelectionLineId)) {
      _wordSelectionLineId = null;
      _wordSelectionTokens = const [];
      _selectedTokenIndices.clear();
      _resetSelectionPointer();
    }
    _sync(widget.handler.position, forceScroll: forceScroll);
  }

  void _bindHandler() {
    _paragraphSub?.cancel();
    _positionSub?.cancel();
    _playbackStateSub?.cancel();
    if (!widget.playbackEnabled) {
      _paragraphId = null;
      _activeLineId = null;
      _clock.reanchor(
        widget.handler.position,
        playing: false,
        speed: widget.handler.playbackState.value.speed,
      );
      return;
    }
    // Subscribe before taking the current snapshot. The handler exposes a
    // broadcast stream, so an entry change between a snapshot-first read and
    // listen() would be dropped forever. That left the transcript bound to a
    // stale/null paragraph until this widget was recreated (for example by
    // leaving and reopening transcript mode).
    _paragraphSub = widget.handler.currentParagraphIdStream.listen((id) {
      _paragraphId = id;
      // A paragraph notification is a state update, not necessarily a seek.
      // Let the normal line-change path animate from the current offset.
      _sync(widget.handler.position);
    });
    _paragraphId = widget.handler.currentParagraphId;
    _positionSub = widget.handler.positionStream.listen(_handleRealPosition);
    _playbackStateSub = widget.handler.playbackState.listen((state) {
      _clock.reanchor(
        widget.handler.position,
        playing: _clockEnabled && syncedLyricsAudioIsAdvancing(state),
        speed: state.speed,
      );
      _handleClockTick();
    });
    _sync(widget.handler.position, forceScroll: true);
  }

  void _sync(Duration position, {bool forceScroll = false}) {
    if (!mounted) return;
    final playbackState = widget.handler.playbackState.value;
    _clock.reanchor(
      position,
      playing: _clockEnabled && syncedLyricsAudioIsAdvancing(playbackState),
      speed: playbackState.speed,
    );
    if (!widget.playbackEnabled) {
      if (_activeLineId != null) {
        setState(() => _activeLineId = null);
      }
      return;
    }
    _updateActiveLine(forceScroll: forceScroll);
  }

  void _handleRealPosition(Duration position) {
    if (!mounted) return;
    final playbackState = widget.handler.playbackState.value;
    _clock.reanchor(
      position,
      playing: _clockEnabled && syncedLyricsAudioIsAdvancing(playbackState),
      speed: playbackState.speed,
    );
    _handleClockTick();
  }

  void _handleClockTick() {
    if (!mounted || !widget.playbackEnabled || _selectionActive) return;
    _updateActiveLine();
  }

  void _updateActiveLine({bool forceScroll = false}) {
    final paragraphLines = _linesByParagraph[_paragraphId] ?? const [];
    final active = _activeLineAt(paragraphLines, _clock.positionMs);
    final lineChanged = active?.id != _activeLineId;
    if (!forceScroll && !lineChanged) return;
    setState(() => _activeLineId = active?.id);
    if ((forceScroll || lineChanged) && active != null && !_manuallyScrolling) {
      _scrollTo(active.id, force: forceScroll);
    }
  }

  SyncedLyricLine? _activeLineAt(List<SyncedLyricLine> lines, int positionMs) {
    if (lines.isEmpty) return null;
    var low = 0;
    var high = lines.length - 1;
    var result = 0;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (lines[middle].startMs <= positionMs) {
        result = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return lines[result];
  }

  void _scrollTo(String lineId, {bool force = false}) {
    if (_selectionActive || _manuallyScrolling) return;
    _pendingScrollLineId = lineId;
    _pendingForceScroll = _pendingForceScroll || force;
    _scrollDebounce?.cancel();
    // Position streams can emit every 16 ms. A single frame of coalescing is
    // enough to let the active line settle without adding a visible lyric lag.
    _scrollDebounce = Timer(const Duration(milliseconds: 16), () {
      if (!mounted || _selectionActive || _manuallyScrolling) return;
      final pendingLineId = _pendingScrollLineId;
      final pendingForce = _pendingForceScroll;
      _pendingScrollLineId = null;
      _pendingForceScroll = false;
      if (pendingLineId == null) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectionActive || _manuallyScrolling) return;
        _animateToLine(pendingLineId, force: pendingForce);
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  void _animateToLine(String lineId, {required bool force}) {
    if (_selectionActive ||
        _manuallyScrolling ||
        !_scrollController.hasClients) {
      return;
    }
    if (widget.virtualized) {
      _animateToVirtualizedLine(lineId, force: force);
      return;
    }
    final lineContext = _lineKeys[lineId]?.currentContext;
    final renderObject = lineContext?.findRenderObject();
    if (renderObject == null || !renderObject.attached) return;

    final position = _scrollController.position;
    final viewport = RenderAbstractViewport.of(renderObject);
    final target = viewport
        .getOffsetToReveal(
          renderObject,
          widget.focusMode
              ? 0.34
              : widget.expanded
              ? 0.24
              : 0.18,
        )
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final distance = (target - position.pixels).abs();
    final tolerance = math.max(16.0, position.viewportDimension * 0.04);
    if (!force && distance <= tolerance) return;
    _scrollToTarget(target, distance: distance, lineId: lineId, force: force);
  }

  void _animateToVirtualizedLine(String lineId, {required bool force}) {
    final index = _lineIndexById[lineId];
    if (index == null || index >= _virtualMeasuredCount) {
      // Exact extents are measured in small post-frame batches so a long
      // transcript cannot block its first paint. Estimated extents are good
      // enough to lay the list out but not to land a scroll on, so keep the
      // most recent target and resolve it once this line has been measured.
      _deferredVirtualScrollLineId = lineId;
      _deferredVirtualScrollForce = _deferredVirtualScrollForce || force;
      return;
    }

    final position = _scrollController.position;
    final alignment = widget.focusMode
        ? 0.34
        : widget.expanded
        ? 0.24
        : 0.18;
    final extent = _virtualLineExtents[index];
    final itemStart = _virtualTopPadding + _virtualLineOffsets[index];
    final target =
        (itemStart - (position.viewportDimension - extent) * alignment)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    final distance = (target - position.pixels).abs();
    final tolerance = math.max(12.0, position.viewportDimension * 0.035);
    if (!force && distance <= tolerance) return;
    _scrollToTarget(target, distance: distance, lineId: lineId, force: force);
  }

  void _scrollToTarget(
    double target, {
    required double distance,
    required String lineId,
    required bool force,
  }) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final largeMove =
        force || distance > math.max(position.viewportDimension, 1.0) * 1.25;
    if (MediaQuery.disableAnimationsOf(context)) {
      _stopScrollAnimation();
      _scrollController.jumpTo(target);
      return;
    }

    final speed = widget.scrollSpeed.clamp(0.5, 2.0).toDouble();
    if (largeMove) {
      // Seeking and returning to the current subtitle should preserve spatial
      // continuity too. Retarget from the live offset so rapid seeks remain
      // interruptible, with a bounded duration even across a long transcript.
      _ensureScrollAnimation();
      final animation = _scrollAnimation!;
      animation.stop();
      animation.value = position.pixels;
      unawaited(
        animation.animateTo(
          target,
          duration: Duration(milliseconds: (280 / speed).round()),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }

    final lineIndex = _lineIndexById[lineId];
    final previousIndex = lineIndex == null ? null : lineIndex - 1;
    final interval =
        lineIndex == null || previousIndex == null || previousIndex < 0
        ? 500.0
        : (_lines[lineIndex].startMs - _lines[previousIndex].startMs)
              .clamp(100, 800)
              .toDouble();
    final ratio = math
        .pow((1 - (interval - 100) / 700).clamp(0.0, 1.0), 0.2)
        .toDouble();
    final baseStiffness = 170 + ratio * 50;
    final description = SpringDescription(
      mass: 0.9,
      stiffness: baseStiffness * speed * speed,
      damping: math.sqrt(baseStiffness) * 2.2 * speed,
    );
    _ensureScrollAnimation();
    final animation = _scrollAnimation!;
    animation.stop();
    animation.value = position.pixels;
    unawaited(
      animation.animateWith(
        SpringSimulation(description, position.pixels, target, 0),
      ),
    );
  }

  void _ensureScrollAnimation() {
    _scrollAnimation ??= AnimationController.unbounded(vsync: this)
      ..addListener(_applyScrollAnimation);
  }

  void _applyScrollAnimation() {
    final animation = _scrollAnimation;
    if (animation == null || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final value = animation.value
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((value - position.pixels).abs() > 0.01) {
      _scrollController.jumpTo(value);
    }
  }

  void _stopScrollAnimation() {
    _scrollAnimation?.stop();
  }

  void _invalidateVirtualMetrics() {
    _virtualMetricsGeneration++;
    _virtualMetricsBuilding = false;
    _virtualLineExtents = const [];
    _virtualLineOffsets = const [];
    _virtualMeasuredCount = 0;
    _estimateRowHeight = null;
    _estimateCharsPerRow = null;
    _parkedAtEnd = false;
    _virtualMetricsWidth = null;
    _virtualMetricsStyle = null;
    _virtualMetricsDirection = null;
    _virtualMetricsTextScaler = null;
  }

  /// Keeps the measurements a transcript update did not invalidate.
  ///
  /// A running podcast transcription appends chunks at the tail, so every line
  /// above the new text keeps its id and its wrapping. Discarding those extents
  /// is what makes the list jump: the geometry of everything the reader can
  /// currently see gets rebuilt from scratch, twice — once when the list falls
  /// back to lazy measurement and once when the exact extents land. Truncate to
  /// the common prefix instead and resume measuring at the first changed line.
  void _retainVirtualMetrics(List<SyncedLyricLine> previous) {
    if (_virtualMeasuredCount == 0) {
      _invalidateVirtualMetrics();
      return;
    }
    var keep = math.min(
      _virtualMeasuredCount,
      math.min(previous.length, _lines.length),
    );
    for (var index = 0; index < keep; index++) {
      if (previous[index].id != _lines[index].id ||
          previous[index].text != _lines[index].text) {
        keep = index;
        break;
      }
    }
    if (keep == 0) {
      _invalidateVirtualMetrics();
      return;
    }

    // Cancels batches already queued against the previous line list.
    _virtualMetricsGeneration++;
    _virtualMetricsBuilding = false;
    _virtualLineExtents = _virtualLineExtents.sublist(0, keep);
    _virtualLineOffsets = _virtualLineOffsets.sublist(0, keep);
    _virtualMeasuredCount = keep;
  }

  void _ensureVirtualMetrics(double width) {
    final safeWidth = math.max(width, 1.0);
    // Playback and inactive lines share font metrics, keeping item extents
    // stable when the active sentence changes.
    final style = _lineTextStyle(
      color: _primaryLyricTextColor,
      highlighted: widget.focusMode,
    );
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final configChanged =
        _virtualMetricsWidth != safeWidth ||
        _virtualMetricsStyle != style ||
        _virtualMetricsDirection != direction ||
        _virtualMetricsTextScaler != textScaler;
    if (!configChanged &&
        _virtualLineExtents.length == _lines.length &&
        (_virtualMeasuredCount == _lines.length || _virtualMetricsBuilding)) {
      return;
    }
    if (configChanged) {
      // Every extent was measured against layout constraints that no longer
      // hold, so none of them can be carried over.
      _virtualLineExtents = const [];
      _virtualLineOffsets = const [];
      _virtualMeasuredCount = 0;
      _estimateRowHeight = null;
      _estimateCharsPerRow = null;
      _virtualMetricsWidth = safeWidth;
      _virtualMetricsStyle = style;
      _virtualMetricsDirection = direction;
      _virtualMetricsTextScaler = textScaler;
    }
    if (_lines.isEmpty) {
      _virtualMetricsBuilding = false;
      return;
    }

    _seedEstimatedExtents(safeWidth, style, direction, textScaler);
    _virtualMetricsBuilding = true;
    _scheduleVirtualMetricsBatch(++_virtualMetricsGeneration);
  }

  /// Fills the not-yet-measured tail with estimates.
  ///
  /// `itemExtentBuilder` can only be used when it answers for every index, so
  /// leaving the tail empty would drop the list back to measuring its children
  /// lazily for the whole pass — which changes the scroll extent and the offset
  /// of every line on screen. An estimate is wrong by a few pixels somewhere
  /// below the viewport; the fallback moves what the reader is looking at.
  void _seedEstimatedExtents(
    double width,
    TextStyle style,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    if (_virtualLineExtents.length == _lines.length) return;
    _calibrateLineEstimator(width, style, direction, textScaler);
    final extents = List<double>.filled(_lines.length, 0);
    final offsets = List<double>.filled(_lines.length, 0);
    var offset = 0.0;
    for (var index = 0; index < _lines.length; index++) {
      offsets[index] = offset;
      final extent = index < _virtualMeasuredCount
          ? _virtualLineExtents[index]
          : _estimateLineExtent(_lines[index].text);
      extents[index] = extent;
      offset += extent;
    }
    _virtualLineExtents = extents;
    _virtualLineOffsets = offsets;
  }

  /// Lays out a handful of lines spread across the transcript to learn how tall
  /// a wrapped row is and how many characters fit on one at this width.
  ///
  /// Guessing those from the font size alone is off by tens of percent, which
  /// leaves the scroll extent wrong enough to matter. Eight real layouts cost
  /// nothing next to a list of thousands and make the estimate track the actual
  /// wrapping of this transcript's script.
  void _calibrateLineEstimator(
    double width,
    TextStyle style,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    if (_estimateRowHeight != null || _lines.isEmpty) return;
    const sampleSize = 8;
    final step = math.max(1, _lines.length ~/ sampleSize);
    var sampledRows = 0;
    var sampledCharacters = 0;
    var sampledHeight = 0.0;
    for (
      var index = 0;
      index < _lines.length && sampledRows < sampleSize * 4;
      index += step
    ) {
      final text = _lines[index].text;
      if (text.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: textScaler,
      )..layout(maxWidth: width);
      final rows = math.max(1, painter.computeLineMetrics().length);
      sampledHeight += painter.height;
      painter.dispose();
      sampledRows += rows;
      sampledCharacters += text.length;
    }
    if (sampledRows == 0) return;
    _estimateRowHeight = sampledHeight / sampledRows;
    _estimateCharsPerRow = math.max(1.0, sampledCharacters / sampledRows);
  }

  double _estimateLineExtent(String text) {
    final rowHeight = _estimateRowHeight;
    final charactersPerRow = _estimateCharsPerRow;
    if (rowHeight == null || charactersPerRow == null) {
      return _lyricLineVerticalPadding;
    }
    // Deliberately not rounded up to a whole row: `charactersPerRow` is an
    // average, so rounding up turns a two-row line into three often enough to
    // inflate the scroll extent by a third. A fractional row is unbiased
    // across the list, and the one-row floor keeps short lines from collapsing.
    final rows = (text.length / charactersPerRow).clamp(1.0, 40.0);
    return rows * rowHeight + _lyricLineVerticalPadding;
  }

  /// A post-frame callback alone does not keep Flutter producing frames. In a
  /// paused player there is no ticker to do that for us, so explicitly request
  /// one for every measurement batch. The generation check in the callback
  /// makes callbacks queued before an update or dispose harmless.
  void _scheduleVirtualMetricsBatch(int generation) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _measureVirtualMetricsBatch(generation),
    );
    WidgetsBinding.instance.scheduleFrame();
  }

  void _measureVirtualMetricsBatch(int generation) {
    if (!mounted || generation != _virtualMetricsGeneration) return;
    final width = _virtualMetricsWidth;
    final style = _virtualMetricsStyle;
    final direction = _virtualMetricsDirection;
    final textScaler = _virtualMetricsTextScaler;
    if (width == null ||
        style == null ||
        direction == null ||
        textScaler == null) {
      return;
    }

    if (_virtualLineExtents.length != _lines.length) return;

    const linesPerFrame = 32;
    final start = _virtualMeasuredCount;
    final end = math.min(start + linesPerFrame, _lines.length);
    final extents = List<double>.of(_virtualLineExtents);
    final offsets = List<double>.of(_virtualLineOffsets);
    var offset = start == 0 ? 0.0 : offsets[start - 1] + extents[start - 1];
    for (var index = start; index < end; index++) {
      offsets[index] = offset;
      final painter = TextPainter(
        text: TextSpan(text: _lines[index].text, style: style),
        textDirection: direction,
        textScaler: textScaler,
      )..layout(maxWidth: width);
      final extent = painter.height + _lyricLineVerticalPadding;
      painter.dispose();
      extents[index] = extent;
      offset += extent;
    }
    // Re-place the estimated tail behind the lines this batch corrected.
    for (var index = end; index < _lines.length; index++) {
      offsets[index] = offset;
      offset += extents[index];
    }
    _virtualLineExtents = extents;
    _virtualLineOffsets = offsets;
    _virtualMeasuredCount = end;
    _restoreScrollAnchor();

    if (end < _lines.length) {
      _scheduleVirtualMetricsBatch(generation);
      return;
    }

    _virtualMetricsBuilding = false;
    final lineId = _deferredVirtualScrollLineId;
    final force = _deferredVirtualScrollForce;
    _deferredVirtualScrollLineId = null;
    _deferredVirtualScrollForce = false;
    setState(() {});
    if (lineId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateToLine(lineId, force: force);
      });
      return;
    }
    if (!_parkedAtEnd) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _manuallyScrolling || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent) return;
      position.jumpTo(position.maxScrollExtent);
    });
  }

  /// Whether the last scroll left the viewport at the end of the list.
  ///
  /// Correcting an estimated extent moves the end away from a reader parked
  /// there, and it does so in the same frame, so this cannot be sampled while
  /// measuring — by then the position is already short of the new end. Record
  /// it as the scroll happens instead.
  void _trackScrollEnd(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (!metrics.hasContentDimensions || metrics.maxScrollExtent <= 0) return;
    _parkedAtEnd = metrics.pixels >= metrics.maxScrollExtent - 0.5;
  }

  /// Remembers the line at the top of the viewport and how far into it the
  /// viewport starts.
  ///
  /// The retained prefix already keeps a plain tail append from moving
  /// anything, but a chunk overlap can also rewrite the sentence it joins onto,
  /// which shifts every line below the rewrite. Pin the reader's line back to
  /// where it was once the corrected geometry is known.
  void _captureScrollAnchor() {
    _anchorLineId = null;
    if (!widget.virtualized ||
        _manuallyScrolling ||
        _selectionActive ||
        !_scrollController.hasClients ||
        _virtualMeasuredCount == 0) {
      return;
    }
    final pixels = _scrollController.position.pixels - _virtualTopPadding;
    var low = 0;
    var high = _virtualMeasuredCount - 1;
    var anchor = 0;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (_virtualLineOffsets[middle] <= pixels) {
        anchor = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    _anchorLineId = _lines[anchor].id;
    _anchorDelta = pixels - _virtualLineOffsets[anchor];
  }

  /// Puts the anchored line back under the same pixel it occupied before the
  /// transcript changed. A no-op whenever the prefix survived intact, which is
  /// the common case; it only does work when an earlier line was rewritten.
  void _restoreScrollAnchor() {
    final anchorLineId = _anchorLineId;
    if (anchorLineId == null) return;
    final index = _lineIndexById[anchorLineId];
    if (index == null) {
      _anchorLineId = null;
      return;
    }
    // Still estimated — wait for the batch that measures it exactly.
    if (index >= _virtualMeasuredCount) return;
    _anchorLineId = null;
    if (_manuallyScrolling ||
        _selectionActive ||
        !_scrollController.hasClients ||
        (_scrollAnimation?.isAnimating ?? false)) {
      return;
    }
    final position = _scrollController.position;
    final target =
        (_virtualTopPadding + _virtualLineOffsets[index] + _anchorDelta)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    if ((target - position.pixels).abs() < 0.5) return;
    _scrollController.jumpTo(target);
  }

  void _stopAutomaticScroll({bool stopCurrentMotion = false}) {
    _scrollDebounce?.cancel();
    _scrollDebounce = null;
    _pendingScrollLineId = null;
    _pendingForceScroll = false;
    _deferredVirtualScrollLineId = null;
    _deferredVirtualScrollForce = false;
    _anchorLineId = null;
    _stopScrollAnimation();
    if (!stopCurrentMotion || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    _scrollController.jumpTo(
      position.pixels.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _trackScrollEnd(notification);
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _manualScrollResume?.cancel();
      _stopAutomaticScroll();
      _manuallyScrolling = true;
    } else if (notification is ScrollEndNotification && _manuallyScrolling) {
      _manualScrollResume?.cancel();
      _manualScrollResume = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _manuallyScrolling = false;
        // A paused transcript has no moving playhead to follow. Forcing the
        // current line back into view after every manual drag feels like a
        // delayed scroll correction and is especially visible during the
        // page's elastic settle. Resume following only for active playback.
        if (widget.handler.playbackState.value.playing) {
          _sync(widget.handler.position, forceScroll: true);
        }
      });
    }
    return false;
  }

  Widget _buildSelectionMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final items = [...selectableRegionState.contextMenuButtonItems];
    if (_selectedText.isNotEmpty) {
      items.insert(
        items.isEmpty ? 0 : 1,
        ContextMenuButtonItem(
          label: context.tr('查词', 'Look Up', '調べる'),
          onPressed: () => _lookUpSelection(selectableRegionState),
        ),
      );
      items.insert(
        items.length < 2 ? items.length : 2,
        ContextMenuButtonItem(
          label: context.tr('询问 AI', 'Ask AI', 'AIに質問'),
          onPressed: () => _askAiAboutSelection(selectableRegionState),
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  Future<void> _lookUpSelection(SelectableRegionState selectableRegionState) =>
      _openSelection(selectableRegionState, askAi: false);

  Future<void> _askAiAboutSelection(
    SelectableRegionState selectableRegionState,
  ) => _openSelection(selectableRegionState, askAi: true);

  Future<void> _openSelection(
    SelectableRegionState selectableRegionState, {
    required bool askAi,
  }) async {
    final text = _selectedText.trim();
    if (text.isEmpty) return;
    await widget.handler.pause();
    selectableRegionState.hideToolbar();
    final selectedLine = _lines
        .where((line) => line.id == _selectionLineId)
        .firstOrNull;
    final matchingLines = _lines
        .where((line) => line.text.contains(text))
        .toList(growable: false);
    final contextLine =
        selectedLine ??
        matchingLines.where((line) => line.id == _activeLineId).firstOrNull ??
        matchingLines.firstOrNull;
    await _openDictionaryText(text, contextLine: contextLine, askAi: askAi);
  }

  DictionaryLookupContext _contextForLine(
    SyncedLyricLine line,
    String selectedText,
  ) {
    final selectionStart = line.text.toLowerCase().indexOf(
      selectedText.toLowerCase(),
    );
    return DictionaryLookupContext(
      bookTitle: widget.bookTitle ?? '',
      chapterTitle: widget.chapterTitle ?? '',
      sentence: line.text,
      bookId: widget.bookId,
      chapterId: widget.chapterId,
      paragraphId: line.paragraphId,
      lineId: line.id,
      selectionStart: selectionStart < 0 ? null : selectionStart,
      selectionEnd: selectionStart < 0
          ? null
          : selectionStart + selectedText.length,
      audioStartMs: line.startMs,
      audioEndMs: line.endMs,
    );
  }

  Future<void> _openDictionaryText(
    String text, {
    required SyncedLyricLine? contextLine,
    required bool askAi,
  }) async {
    final lookupContext = contextLine == null
        ? null
        : _contextForLine(contextLine, text);
    await showDictionaryLookupSheet(
      context,
      initialQuery: text,
      lookupContext: lookupContext,
      askAi: askAi,
    );
  }

  void _enterWordSelection(SyncedLyricLine line) {
    final tokens = tokenizeSelectableText(line.text);
    if (tokens.isEmpty) return;
    unawaited(widget.handler.pause());
    unawaited(HapticFeedback.mediumImpact());
    _stopAutomaticScroll(stopCurrentMotion: true);
    _clearSelection();
    setState(() {
      _pressedLineId = null;
      _wordSelectionLineId = line.id;
      _wordSelectionTokens = tokens;
      _selectedTokenIndices.clear();
      _resetSelectionPointer();
    });
  }

  void _exitWordSelection() {
    if (_wordSelectionLineId == null) return;
    setState(() {
      _wordSelectionLineId = null;
      _wordSelectionTokens = const [];
      _selectedTokenIndices.clear();
      _resetSelectionPointer();
    });
    _sync(widget.handler.position);
  }

  void _handleSelectionChanged(SelectedContent? content) {
    final selectedText = content?.plainText.trim() ?? '';
    if (selectedText.isNotEmpty && _selectedText.isEmpty) {
      _stopAutomaticScroll(stopCurrentMotion: true);
    }
    _selectedText = selectedText;
    if (content == null) _selectionLineId = null;
  }

  void _onTokenPointerDown(PointerDownEvent event) {
    final index = _tokenAt(event.position);
    if (index == null) return;
    _pointerStartToken = index;
    _pointerStartPosition = event.position;
    _pointerDidDrag = false;
  }

  void _onTokenPointerMove(PointerMoveEvent event) {
    final start = _pointerStartToken;
    final origin = _pointerStartPosition;
    if (start == null || origin == null) return;
    if (!_pointerDidDrag && (event.position - origin).distance < 8) return;
    final current = _tokenAt(event.position);
    if (current == null) return;
    _pointerDidDrag = true;
    final first = math.min(start, current);
    final last = math.max(start, current);
    setState(() {
      _selectedTokenIndices
        ..clear()
        ..addAll([for (var index = first; index <= last; index++) index]);
    });
  }

  void _onTokenPointerUp(PointerUpEvent event) {
    final index = _pointerStartToken;
    if (index != null && !_pointerDidDrag) {
      setState(() {
        if (!_selectedTokenIndices.add(index)) {
          _selectedTokenIndices.remove(index);
        }
      });
    }
    _resetSelectionPointer();
  }

  void _onTokenPointerCancel(PointerCancelEvent event) =>
      _resetSelectionPointer();

  void _resetSelectionPointer() {
    _pointerStartToken = null;
    _pointerStartPosition = null;
    _pointerDidDrag = false;
  }

  int? _tokenAt(Offset globalPosition) {
    final renderObject = _wordSelectionTextKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderParagraph || !renderObject.attached) {
      return null;
    }
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (!rect.inflate(3).contains(globalPosition)) return null;
    final offset = renderObject
        .getPositionForOffset(renderObject.globalToLocal(globalPosition))
        .offset;
    for (var index = 0; index < _wordSelectionTokens.length; index++) {
      final token = _wordSelectionTokens[index];
      if (offset < token.start) return math.max(0, index - 1);
      if (offset < token.end) return index;
    }
    return _wordSelectionTokens.isEmpty
        ? null
        : _wordSelectionTokens.length - 1;
  }

  Future<void> _submitWordSelection({required bool askAi}) async {
    final line = _lines
        .where((item) => item.id == _wordSelectionLineId)
        .firstOrNull;
    if (line == null) return;
    final text = selectedTokenText(
      line.text,
      _wordSelectionTokens,
      _selectedTokenIndices,
    );
    if (text.isEmpty) return;
    _exitWordSelection();
    await _openDictionaryText(text, contextLine: line, askAi: askAi);
  }

  void _clearSelection() {
    _selectionAreaKey.currentState?.selectableRegion.clearSelection();
    _selectedText = '';
    _selectionLineId = null;
  }

  @override
  void dispose() {
    _paragraphSub?.cancel();
    _positionSub?.cancel();
    _playbackStateSub?.cancel();
    _scrollDebounce?.cancel();
    _manualScrollResume?.cancel();
    _scrollAnimation?.dispose();
    _clock.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wordSelectionActive = _wordSelectionLineId != null;
    final scrollable = widget.virtualized
        ? _buildVirtualizedList(wordSelectionActive)
        : _buildEagerList(wordSelectionActive);
    return TapRegion(
      groupId: SelectableRegion,
      onTapOutside: (_) {
        if (wordSelectionActive) {
          _exitWordSelection();
        } else {
          _clearSelection();
        }
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: scrollable,
      ),
    );
  }

  EdgeInsets _lyricsPadding() {
    final horizontal = widget.focusMode
        ? context.appDesign.pageInsetFor(MediaQuery.sizeOf(context).width)
        : widget.expanded
        ? context.appDesign.pageGutter
        : context.appDesign.spaceLg;
    // Focus mode floats the header and the controls over the transcript, so the
    // list needs enough slack at both ends for the first and last sentences to
    // reach the active-line position instead of stopping under the chrome.
    return EdgeInsets.fromLTRB(
      horizontal,
      widget.focusMode
          ? context.appDesign.spaceXxl * 3
          : context.appDesign.spaceSm,
      horizontal,
      widget.focusMode
          ? context.appDesign.spaceXxl * 7
          : context.appDesign.spaceXxl + context.appDesign.spaceLg,
    );
  }

  Widget _buildEagerList(bool wordSelectionActive) {
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in _lines)
          _buildLineSlot(line, wordSelectionActive: wordSelectionActive),
      ],
    );
    return SingleChildScrollView(
      controller: _scrollController,
      padding: _lyricsPadding(),
      child: SelectionArea(
        key: _selectionAreaKey,
        onSelectionChanged: _handleSelectionChanged,
        contextMenuBuilder: _buildSelectionMenu,
        child: lines,
      ),
    );
  }

  Widget _buildVirtualizedList(bool wordSelectionActive) {
    final padding = _lyricsPadding();
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth - padding.horizontal;
        _virtualTopPadding = padding.top;
        _ensureVirtualMetrics(contentWidth);
        return SelectionArea(
          key: _selectionAreaKey,
          onSelectionChanged: _handleSelectionChanged,
          contextMenuBuilder: _buildSelectionMenu,
          child: ListView.builder(
            key: const ValueKey('synced-lyrics-virtualized-list'),
            controller: _scrollController,
            padding: padding,
            itemCount: _lines.length,
            itemExtentBuilder: _virtualLineExtents.length != _lines.length
                ? null
                : (index, _) {
                    final selectionExtra =
                        _lines[index].id == _wordSelectionLineId ? 70.0 : 0.0;
                    return _virtualLineExtents[index] + selectionExtra;
                  },
            addAutomaticKeepAlives: false,
            itemBuilder: (context, index) => _buildLineSlot(
              _lines[index],
              wordSelectionActive: wordSelectionActive,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLineSlot(
    SyncedLyricLine line, {
    required bool wordSelectionActive,
  }) {
    final selectingThisLine = line.id == _wordSelectionLineId;
    final child = selectingThisLine
        ? KeyedSubtree(
            key: ValueKey('word-selection-${line.id}'),
            child: _buildWordSelectionLine(line),
          )
        : KeyedSubtree(
            key: ValueKey('lyric-line-${line.id}'),
            child: _buildLyricLine(line, enabled: !wordSelectionActive),
          );
    final slot = KeyedSubtree(
      key: _lineKeys.putIfAbsent(line.id, GlobalKey.new),
      child: widget.virtualized
          ? child
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              reverseDuration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topLeft,
                children: [...previousChildren, ?currentChild],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topLeft,
                  child: child,
                ),
              ),
              child: child,
            ),
    );
    return wordSelectionActive
        ? SelectionContainer.disabled(child: slot)
        : slot;
  }

  Widget _buildLyricLine(SyncedLyricLine line, {required bool enabled}) {
    final highlighted = line.id == _activeLineId;
    final lineIndex = _lineIndexById[line.id] ?? -1;
    final activeIndex = _activeLineId == null
        ? -1
        : (_lineIndexById[_activeLineId!] ?? -1);
    // The sweep painter listens to the clock directly. Only the non-sweep
    // word renderer needs to rebuild the active line on every animation frame.
    final rebuildActiveLine =
        widget.playbackEnabled && highlighted && !widget.sweepEnabled;
    Widget buildFrame(int positionMs) => _buildLyricLineFrame(
      line,
      enabled: enabled,
      highlighted: highlighted,
      positionMs: positionMs,
      lineIndex: lineIndex,
      activeIndex: activeIndex,
    );

    final content = rebuildActiveLine
        ? AnimatedBuilder(
            animation: _clock,
            builder: (_, _) => buildFrame(_clock.positionMs),
          )
        : buildFrame(_clock.positionMs);
    return RepaintBoundary(child: content);
  }

  Widget _buildLyricLineFrame(
    SyncedLyricLine line, {
    required bool enabled,
    required bool highlighted,
    required int positionMs,
    required int lineIndex,
    required int activeIndex,
  }) {
    final pressed = line.id == _pressedLineId;
    final primaryTextColor = _primaryLyricTextColor;
    final distanceFromActive = lineIndex < 0 || activeIndex < 0
        ? -1
        : (lineIndex - activeIndex).abs();
    final text = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 220),
      style: _lineTextStyle(
        highlighted: highlighted,
        color: _lineBaseColor(
          line,
          highlighted: highlighted,
          enabled: enabled,
          positionMs: positionMs,
          distanceFromActive: distanceFromActive,
        ),
      ),
      child: _buildLyricText(
        line,
        highlighted: highlighted,
        enabled: enabled,
        primaryTextColor: primaryTextColor,
        positionMs: positionMs,
        distanceFromActive: distanceFromActive,
      ),
    );
    final frame = Listener(
      onPointerDown: enabled ? (_) => _selectionLineId = line.id : null,
      child: InkWell(
        onTap: enabled && widget.playbackEnabled
            ? () => widget.handler.playFromParagraphOffset(
                line.paragraphId,
                Duration(milliseconds: line.startMs),
              )
            : null,
        onLongPress: enabled ? () => _enterWordSelection(line) : null,
        onHighlightChanged: enabled
            ? (value) {
                if (_pressedLineId == (value ? line.id : null)) return;
                setState(() => _pressedLineId = value ? line.id : null);
              }
            : null,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedScale(
          scale: pressed ? 0.985 : 1,
          alignment: Alignment.centerLeft,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: SubtitleLine(
            gap: widget.subtitleGap,
            backgroundColor: pressed
                ? context.appSurfaceHighlight.withValues(alpha: 0.22)
                : Colors.transparent,
            child: text,
          ),
        ),
      ),
    );
    return frame;
  }

  Widget _buildLyricText(
    SyncedLyricLine line, {
    required bool highlighted,
    required bool enabled,
    required Color primaryTextColor,
    required int positionMs,
    required int distanceFromActive,
  }) {
    // Disabled transcript lists are also used for static selection/search
    // views. Keep them as a plain Text widget; only the active player needs
    // the extra RichText spans for live word progress.
    if (line.words.isEmpty || !enabled || !widget.playbackEnabled) {
      return Text(line.text);
    }
    if (widget.sweepEnabled && highlighted) {
      final style = _lineTextStyle(color: primaryTextColor, highlighted: true);
      return CustomPaint(
        foregroundPainter: _LyricSweepPainter(
          line: line,
          style: style,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          clock: _clock,
        ),
        child: Text(
          line.text,
          style: style.copyWith(color: Colors.transparent),
        ),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          for (final word in line.words)
            TextSpan(
              text: '${word.leadingWhitespace}${word.text}',
              style: TextStyle(
                color: _wordColor(
                  word,
                  line: line,
                  highlighted: highlighted,
                  enabled: enabled,
                  primaryTextColor: primaryTextColor,
                  positionMs: positionMs,
                  distanceFromActive: distanceFromActive,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _lineBaseColor(
    SyncedLyricLine line, {
    required bool highlighted,
    required bool enabled,
    required int positionMs,
    int distanceFromActive = -1,
  }) {
    final primaryTextColor = _primaryLyricTextColor;
    if (!enabled) return primaryTextColor.withValues(alpha: 0.16);
    if (highlighted) return primaryTextColor;
    final passed = line.endMs > line.startMs && line.endMs <= positionMs;
    // Focus mode fades by distance rather than by a flat inactive alpha, so the
    // sentences around the current one read as depth instead of as a wall of
    // equally dim text. The far end is clamped well above zero because a
    // transcript is read, not glanced at.
    if (widget.focusMode && !passed && distanceFromActive > 0) {
      final alpha = math.max(0.2, 0.56 - distanceFromActive * 0.09);
      return primaryTextColor.withValues(alpha: alpha);
    }
    final alpha = passed
        ? 0.22
        : widget.focusMode
        ? 0.56
        : widget.expanded
        ? 0.42
        : 0.3;
    return primaryTextColor.withValues(alpha: alpha);
  }

  Color _wordColor(
    SyncedLyricWord word, {
    required SyncedLyricLine line,
    required bool highlighted,
    required bool enabled,
    required Color primaryTextColor,
    required int positionMs,
    required int distanceFromActive,
  }) {
    if (!enabled || !highlighted) {
      return _lineBaseColor(
        line,
        highlighted: highlighted,
        enabled: enabled,
        positionMs: positionMs,
        distanceFromActive: distanceFromActive,
      );
    }
    final progress = _wordProgress(word, positionMs);
    final inactive = primaryTextColor.withValues(alpha: 0.46);
    return Color.lerp(inactive, primaryTextColor, progress)!;
  }

  double _wordProgress(SyncedLyricWord word, int positionMs) {
    if (positionMs <= word.startMs) return 0;
    if (positionMs >= word.endMs) return 1;
    final duration = math.max(1, word.endMs - word.startMs);
    return ((positionMs - word.startMs) / duration).clamp(0.0, 1.0);
  }

  Widget _buildWordSelectionLine(SyncedLyricLine line) {
    final accent = Theme.of(context).colorScheme.primary;
    // Selection shares playback typography so long-pressing cannot reflow text.
    final tokenStyle = _lineTextStyle(
      color: context.appTextPrimary,
      highlighted: line.id == _activeLineId,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _lyricLineVerticalPadding / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onTokenPointerDown,
            onPointerMove: _onTokenPointerMove,
            onPointerUp: _onTokenPointerUp,
            onPointerCancel: _onTokenPointerCancel,
            child: KeyedSubtree(
              key: ValueKey('word-selection-text-${line.id}'),
              child: Text.rich(
                key: _wordSelectionTextKey,
                TextSpan(
                  children: _wordSelectionSpans(
                    line.text,
                    tokenStyle: tokenStyle,
                    accent: accent,
                  ),
                ),
                style: tokenStyle,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildWordSelectionToolbar(),
        ],
      ),
    );
  }

  List<InlineSpan> _wordSelectionSpans(
    String source, {
    required TextStyle tokenStyle,
    required Color accent,
  }) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (var index = 0; index < _wordSelectionTokens.length; index++) {
      final token = _wordSelectionTokens[index];
      if (token.start > cursor) {
        spans.add(TextSpan(text: source.substring(cursor, token.start)));
      }
      final selected = _selectedTokenIndices.contains(index);
      spans.add(
        TextSpan(
          text: source.substring(token.start, token.end),
          style: tokenStyle.copyWith(
            color: selected ? Colors.black : context.appTextPrimary,
            backgroundColor: selected
                ? accent
                : context.appSurfaceHighlight.withValues(alpha: 0.3),
          ),
        ),
      );
      cursor = token.end;
    }
    if (cursor < source.length) {
      spans.add(TextSpan(text: source.substring(cursor)));
    }
    return spans;
  }

  Widget _buildWordSelectionToolbar() {
    final hasSelection = _selectedTokenIndices.isNotEmpty;
    final selectionLine = _lines
        .where((line) => line.id == _wordSelectionLineId)
        .firstOrNull;
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.tr('取消', 'Cancel', 'キャンセル'),
              onPressed: _exitWordSelection,
              icon: const AppIcon(AppIcons.cancel01),
            ),
            Expanded(
              child: Text(
                hasSelection
                    ? selectedTokenText(
                        selectionLine?.text ?? '',
                        _wordSelectionTokens,
                        _selectedTokenIndices,
                      )
                    : context.tr(
                        '点击或滑动选择',
                        'Tap or slide to select',
                        'タップまたはスライドして選択',
                      ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.appTextSecondary, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: hasSelection
                  ? () => _submitWordSelection(askAi: false)
                  : null,
              child: Text(context.tr('查词', 'Look Up', '調べる')),
            ),
            const SizedBox(width: 2),
            FilledButton(
              onPressed: hasSelection
                  ? () => _submitWordSelection(askAi: true)
                  : null,
              child: const Text('Ask AI'),
            ),
          ],
        ),
      ),
    );
  }

  /// Playback changes emphasis, never font metrics or line wrapping.
  TextStyle _lineTextStyle({required Color color, bool highlighted = false}) {
    return subtitleTextStyle(
      context,
      color: color,
      fontScale: widget.fontScale,
      focusMode: widget.focusMode,
      expanded: widget.expanded,
    );
  }

  /// The white lyric palette belongs to the dark full-screen sheet. Focus mode
  /// renders over the player's own light background, so it stays on the theme
  /// text color.
  Color get _primaryLyricTextColor => widget.expanded && !widget.focusMode
      ? AppColors.lyricsTextPrimary
      : context.appTextPrimary;
}
