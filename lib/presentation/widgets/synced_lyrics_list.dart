import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_design_tokens.dart';
import '../../core/app_localizations.dart';
import '../../data/database/app_database.dart' as drift_db;
import '../../domain/models/audio_text_timing.dart';
import '../../domain/models/chapter_manifest.dart';
import '../../domain/models/vocabulary_entry.dart';
import '../../services/lumina_audio_handler.dart';
import 'dictionary_lookup_sheet.dart';

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
  final bool playbackEnabled;
  final bool expanded;
  final bool focusMode;
  final String? bookTitle;
  final String? chapterTitle;
  final String? bookId;
  final String? chapterId;

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
  });

  @override
  State<SyncedLyricsList> createState() => _SyncedLyricsListState();
}

class _SyncedLyricsListState extends State<SyncedLyricsList> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<SelectionAreaState> _selectionAreaKey =
      GlobalKey<SelectionAreaState>();
  final Map<String, GlobalKey> _lineKeys = {};
  StreamSubscription<String?>? _paragraphSub;
  StreamSubscription<Duration>? _positionSub;
  Timer? _scrollDebounce;
  List<SyncedLyricLine> _lines = const [];
  String? _paragraphId;
  String? _activeLineId;
  String? _pendingScrollLineId;
  bool _pendingForceScroll = false;
  String _selectedText = '';
  String? _selectionLineId;
  String? _wordSelectionLineId;
  List<SelectableTextToken> _wordSelectionTokens = const [];
  final Set<int> _selectedTokenIndices = {};
  final Map<int, GlobalKey> _tokenKeys = {};
  int? _pointerStartToken;
  Offset? _pointerStartPosition;
  bool _pointerDidDrag = false;
  String? _pressedLineId;

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
    if (oldWidget.handler != widget.handler ||
        oldWidget.playbackEnabled != widget.playbackEnabled) {
      _bindHandler();
    }
  }

  void _rebuildLines() {
    _lines = buildSyncedLyricLines(widget.paragraphs, widget.manifest);
    if (_wordSelectionLineId != null &&
        !_lines.any((line) => line.id == _wordSelectionLineId)) {
      _wordSelectionLineId = null;
      _wordSelectionTokens = const [];
      _selectedTokenIndices.clear();
      _tokenKeys.clear();
      _resetSelectionPointer();
    }
    _sync(widget.handler.position, forceScroll: true);
  }

  void _bindHandler() {
    _paragraphSub?.cancel();
    _positionSub?.cancel();
    if (!widget.playbackEnabled) {
      _paragraphId = null;
      _activeLineId = null;
      return;
    }
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
    if (!widget.playbackEnabled) {
      if (_activeLineId != null) setState(() => _activeLineId = null);
      return;
    }
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
    if (_wordSelectionLineId != null) return;
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

    final viewportExtent = math.max(position.viewportDimension, 1.0);
    final screenDistance = (distance / viewportExtent).clamp(0.0, 1.75);
    final durationMs = (420 + screenDistance * 260).round().clamp(420, 875);
    _scrollController.animateTo(
      target,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeInOutCubic,
    );
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
          label: context.tr('查词', 'Look Up'),
          onPressed: () => _lookUpSelection(selectableRegionState),
        ),
      );
      items.insert(
        items.length < 2 ? items.length : 2,
        ContextMenuButtonItem(
          label: context.tr('询问 AI', 'Ask AI'),
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
    _clearSelection();
    setState(() {
      _pressedLineId = null;
      _wordSelectionLineId = line.id;
      _wordSelectionTokens = tokens;
      _selectedTokenIndices.clear();
      _tokenKeys.clear();
      _resetSelectionPointer();
    });
  }

  void _exitWordSelection() {
    if (_wordSelectionLineId == null) return;
    setState(() {
      _wordSelectionLineId = null;
      _wordSelectionTokens = const [];
      _selectedTokenIndices.clear();
      _tokenKeys.clear();
      _resetSelectionPointer();
    });
    _sync(widget.handler.position);
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
    for (final entry in _tokenKeys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (rect.inflate(3).contains(globalPosition)) return entry.key;
    }
    return null;
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
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wordSelectionActive = _wordSelectionLineId != null;
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in _lines)
          _buildLineSlot(line, wordSelectionActive: wordSelectionActive),
      ],
    );
    final content = wordSelectionActive
        ? lines
        : SelectionArea(
            key: _selectionAreaKey,
            onSelectionChanged: (content) {
              _selectedText = content?.plainText.trim() ?? '';
              if (content == null) _selectionLineId = null;
            },
            contextMenuBuilder: _buildSelectionMenu,
            child: lines,
          );
    return TapRegion(
      groupId: SelectableRegion,
      onTapOutside: (_) {
        if (wordSelectionActive) {
          _exitWordSelection();
        } else {
          _clearSelection();
        }
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          widget.focusMode
              ? 0
              : widget.expanded
              ? context.appDesign.pageGutter
              : context.appDesign.spaceLg,
          context.appDesign.spaceSm,
          widget.focusMode
              ? 0
              : widget.expanded
              ? context.appDesign.pageGutter
              : context.appDesign.spaceLg,
          context.appDesign.spaceXxl + context.appDesign.spaceLg,
        ),
        child: content,
      ),
    );
  }

  Widget _buildLineSlot(
    SyncedLyricLine line, {
    required bool wordSelectionActive,
  }) {
    final selectingThisLine = line.id == _wordSelectionLineId;
    return KeyedSubtree(
      key: _lineKeys.putIfAbsent(line.id, GlobalKey.new),
      child: AnimatedSwitcher(
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
        child: selectingThisLine
            ? KeyedSubtree(
                key: ValueKey('word-selection-${line.id}'),
                child: _buildWordSelectionLine(line),
              )
            : KeyedSubtree(
                key: ValueKey('lyric-line-${line.id}'),
                child: _buildLyricLine(line, enabled: !wordSelectionActive),
              ),
      ),
    );
  }

  Widget _buildLyricLine(SyncedLyricLine line, {required bool enabled}) {
    final highlighted = line.id == _activeLineId;
    final pressed = line.id == _pressedLineId;
    return Listener(
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
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: pressed
                  ? context.appSurfaceHighlight.withValues(alpha: 0.22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: _lineTextStyle(
                color: enabled
                    ? highlighted
                          ? AppColors.lyricsTextPrimary
                          : AppColors.lyricsTextPrimary.withValues(
                              alpha: widget.focusMode
                                  ? 0.56
                                  : widget.expanded
                                  ? 0.42
                                  : 0.3,
                            )
                    : AppColors.lyricsTextPrimary.withValues(alpha: 0.16),
              ),
              child: Text(line.text),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordSelectionLine(SyncedLyricLine line) {
    final accent = Theme.of(context).colorScheme.primary;
    final tokenStyle = _lineTextStyle(color: context.appTextPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onTokenPointerDown,
            onPointerMove: _onTokenPointerMove,
            onPointerUp: _onTokenPointerUp,
            onPointerCancel: _onTokenPointerCancel,
            child: Wrap(
              spacing: 0,
              runSpacing: 0,
              children: [
                for (
                  var index = 0;
                  index < _wordSelectionTokens.length;
                  index++
                )
                  AnimatedContainer(
                    key: _tokenKeys.putIfAbsent(index, GlobalKey.new),
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.only(
                      right: _tokenTrailingSpaceWidth(
                        line.text,
                        index,
                        tokenStyle,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: _selectedTokenIndices.contains(index)
                          ? accent
                          : context.appSurfaceHighlight.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _wordSelectionTokens[index].text,
                      style: tokenStyle.copyWith(
                        color: _selectedTokenIndices.contains(index)
                            ? Colors.black
                            : context.appTextPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildWordSelectionToolbar(),
        ],
      ),
    );
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
              tooltip: context.tr('取消', 'Cancel'),
              onPressed: _exitWordSelection,
              icon: const Icon(Icons.close),
            ),
            Expanded(
              child: Text(
                hasSelection
                    ? selectedTokenText(
                        selectionLine?.text ?? '',
                        _wordSelectionTokens,
                        _selectedTokenIndices,
                      )
                    : context.tr('点击或滑动选择', 'Tap or slide to select'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.appTextSecondary, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: hasSelection
                  ? () => _submitWordSelection(askAi: false)
                  : null,
              child: Text(context.tr('查词', 'Look Up')),
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

  TextStyle _lineTextStyle({required Color color}) {
    return TextStyle(
      fontSize: widget.expanded || widget.focusMode ? 22 : 18,
      fontWeight: FontWeight.w700,
      color: color,
      height: widget.expanded || widget.focusMode ? 1.35 : 1.4,
      fontFamily: context.appDesign.readingFontFamily,
      fontFamilyFallback: context.appDesign.readingFontFamilyFallback,
    );
  }

  double _tokenTrailingSpaceWidth(String source, int index, TextStyle style) {
    if (index >= _wordSelectionTokens.length - 1) return 0;
    final current = _wordSelectionTokens[index];
    final next = _wordSelectionTokens[index + 1];
    if (current.end >= next.start) return 0;
    final whitespace = source.substring(current.end, next.start);
    if (whitespace.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: whitespace, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }
}
