import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/audio_text_timing.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/presentation/widgets/synced_lyrics_list.dart';
import 'package:lumina/services/lumina_audio_handler.dart';

void main() {
  testWidgets('scrub preview overrides live subtitles until released', (
    tester,
  ) async {
    final handler = _VirtualLyricsAudioHandler(paragraphId: 'streaming');
    final preview = ValueNotifier<Duration?>(null);
    addTearDown(handler.dispose);
    addTearDown(preview.dispose);
    await tester.pumpWidget(
      _growingTranscript(
        handler,
        _streamedTranscriptLines(100),
        scrollingEnabled: false,
        previewPosition: preview,
      ),
    );
    await tester.pumpAndSettle();
    preview.value = const Duration(seconds: 75);
    await tester.pumpAndSettle();
    expect(find.text('Transcript segment 75.'), findsOneWidget);
    handler.currentPosition = const Duration(seconds: 12);
    handler.playbackState.add(PlaybackState());
    await tester.pumpAndSettle();
    expect(find.text('Transcript segment 75.'), findsOneWidget);
    preview.value = const Duration(seconds: 30);
    await tester.pumpAndSettle();
    expect(find.text('Transcript segment 30.'), findsOneWidget);
    preview.value = null;
    await tester.pumpAndSettle();
    expect(find.text('Transcript segment 12.'), findsOneWidget);
  });
  testWidgets('single-line mode follows playback and can resume scrolling', (
    tester,
  ) async {
    final handler = _VirtualLyricsAudioHandler(paragraphId: 'streaming');
    addTearDown(handler.dispose);
    final lines = _streamedTranscriptLines(100);
    await tester.pumpWidget(
      _growingTranscript(handler, lines, scrollingEnabled: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transcript segment 0.'), findsOneWidget);
    expect(find.text('Transcript segment 1.'), findsNothing);
    handler.currentPosition = const Duration(seconds: 80);
    handler.playbackState.add(PlaybackState());
    await tester.pumpAndSettle();
    expect(find.text('Transcript segment 0.'), findsNothing);
    expect(find.text('Transcript segment 80.'), findsOneWidget);
    expect(find.text('Transcript segment 81.'), findsNothing);
    await tester.pumpWidget(_growingTranscript(handler, lines));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('synced-lyrics-virtualized-list')),
      findsOneWidget,
    );
    expect(find.text('Transcript segment 80.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('highlight clock stops during buffering even with play intent', () {
    final clock = SyncedLyricsClock();
    addTearDown(clock.dispose);
    for (final state in AudioProcessingState.values) {
      final advancing = syncedLyricsAudioIsAdvancing(
        PlaybackState(playing: true, processingState: state),
      );
      expect(advancing, state == AudioProcessingState.ready);
      clock.reanchor(const Duration(seconds: 37), playing: advancing);
      clock.advance(const Duration(seconds: 2));
      expect(clock.position, Duration(seconds: advancing ? 39 : 37));
    }
    clock.reanchor(const Duration(seconds: 37), playing: false);
    clock.reanchor(const Duration(milliseconds: 37100), playing: true);
    expect(clock.position.inMilliseconds, 37100);
  });
  test(
    'reflow preserves original timestamps including repeated words and silence',
    () {
      const timings = [
        AudioTextTiming(text: 'The', startMs: 1000, endMs: 1200),
        AudioTextTiming(text: 'ocean.', startMs: 1200, endMs: 2000),
        AudioTextTiming(text: 'The', startMs: 3500, endMs: 3700),
        AudioTextTiming(text: 'devil.', startMs: 3700, endMs: 4500),
      ];
      final manifest = ChapterManifest(
        chapterId: 'c',
        bookId: 'b',
        providerId: 'librivox',
        voiceId: '',
        speed: 1,
        updatedAt: 0,
        segments: [
          SegmentEntry(
            paragraphId: 'p',
            audioFile: 'recording.mp3',
            durationMs: 9000,
            state: ParagraphAudioState.ready,
            timings: timings,
          ),
        ],
      );
      for (final content in [
        'The ocean.\nThe devil.',
        'The ocean. The\ndevil.',
      ]) {
        final lines = buildSyncedLyricLines([
          Paragraph(
            id: 'p',
            chapterId: 'c',
            bookId: 'b',
            paragraphIndex: 0,
            content: content,
          ),
        ], manifest);
        final words = lines.expand((line) => line.words).toList();
        expect(words.map((word) => (word.startMs, word.endMs)), [
          (1000, 1200),
          (1200, 2000),
          (3500, 3700),
          (3700, 4500),
        ]);
      }
    },
  );

  test('synced lyrics clock extrapolates at playback speed', () {
    final clock = SyncedLyricsClock();
    addTearDown(clock.dispose);

    clock.reanchor(Duration.zero, playing: true, speed: 1.5);
    clock.advance(const Duration(milliseconds: 200));

    expect(clock.position, const Duration(milliseconds: 300));
  });

  test('synced lyrics clock never runs backwards on small stream drift', () {
    final clock = SyncedLyricsClock();
    addTearDown(clock.dispose);

    clock.reanchor(const Duration(milliseconds: 1000), playing: true);
    clock.advance(const Duration(milliseconds: 200));
    clock.reanchor(const Duration(milliseconds: 1100), playing: true);

    expect(clock.position, const Duration(milliseconds: 1200));
  });

  test('synced lyrics clock eases a small forward correction', () {
    final clock = SyncedLyricsClock();
    addTearDown(clock.dispose);

    clock.reanchor(const Duration(milliseconds: 1000), playing: true);
    clock.reanchor(const Duration(milliseconds: 1100), playing: true);
    expect(clock.position, const Duration(milliseconds: 1000));

    clock.advance(const Duration(milliseconds: 16));
    expect(clock.position.inMilliseconds, greaterThan(1016));
    expect(clock.position.inMilliseconds, lessThan(1100));
  });

  test('synced lyrics clock snaps large seeks and pauses', () {
    final clock = SyncedLyricsClock();
    addTearDown(clock.dispose);

    clock.reanchor(const Duration(milliseconds: 1000), playing: true);
    clock.reanchor(const Duration(milliseconds: 5000), playing: true);
    expect(clock.position, const Duration(milliseconds: 5000));

    clock.reanchor(const Duration(milliseconds: 4800), playing: false);
    expect(clock.position, const Duration(milliseconds: 4800));
  });

  test('sweep stays on the visual row holding the active word', () {
    // Six words, one second each, forced to wrap by a narrow layout width.
    const words = ['alpha', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot'];
    final line = SyncedLyricLine(
      id: 'p1:0',
      paragraphId: 'p1',
      text: words.join(' '),
      startMs: 0,
      endMs: 6000,
      words: [
        for (var index = 0; index < words.length; index++)
          SyncedLyricWord(
            text: words[index],
            leadingWhitespace: index == 0 ? '' : ' ',
            startMs: index * 1000,
            endMs: (index + 1) * 1000,
          ),
      ],
    );
    final painter = TextPainter(
      text: TextSpan(
        text: line.text,
        style: const TextStyle(fontSize: 20, height: 1.4),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);

    // The layout must actually wrap for this test to mean anything.
    expect(painter.computeLineMetrics().length, greaterThan(1));

    final first = syncedLyricsSweepGeometry(
      painter: painter,
      line: line,
      positionMs: 100,
    );
    final last = syncedLyricsSweepGeometry(
      painter: painter,
      line: line,
      positionMs: 5500,
    );

    expect(first, isNotNull);
    expect(last, isNotNull);
    // A horizontal-only gradient reports the same band for every row, which is
    // what made wrapped lines light up all at once.
    expect(last!.rowTop, greaterThan(first!.rowTop));
    expect(first.rowBottom, lessThanOrEqualTo(last.rowTop));
    painter.dispose();
  });

  test('tokenizes words, hyphenated phrases, numbers, and punctuation', () {
    final tokens = tokenizeSelectableText(
      'The mind-bender costs 3.07 MB, really.',
    );

    expect(tokens.map((token) => token.text), [
      'The',
      'mind-bender',
      'costs',
      '3.07',
      'MB',
      ',',
      'really',
      '.',
    ]);
  });

  test('rebuilds tapped and dragged token selections', () {
    const source = 'The mind-bender costs 3.07 MB, really.';
    final tokens = tokenizeSelectableText(source);

    expect(
      selectedTokenText(source, tokens, {1, 2, 3, 4, 5}),
      'mind-bender costs 3.07 MB,',
    );
    expect(selectedTokenText(source, tokens, {1, 6}), 'mind-bender really');
  });

  test('keeps sentences separate and splits long ones at weak boundaries', () {
    final lines = splitLyricsText(
      'First sentence. Second sentence is deliberately much longer, '
      'so it must be wrapped without filling the screen.',
      maxChars: 30,
    );

    expect(lines, [
      'First sentence.',
      'Second sentence is deliberately much longer,',
      'so it must be wrapped without filling the screen.',
    ]);
    expect(lines[1].length, greaterThan(30));
  });

  test('keeps closing quotes and dialogue tags with their sentence', () {
    final lines = splitLyricsText(
      '"Go!" shouted Annemarie, and the girls ran. '
      '"Oh, all right. Ready," she said.',
      maxChars: 55,
    );

    expect(lines, [
      '"Go!" shouted Annemarie, and the girls ran.',
      '"Oh, all right. Ready," she said.',
    ]);
    expect(lines, isNot(contains('"')));
  });

  test('attaches a Japanese closing quote on the next line', () {
    expect(splitLyricsText('「对吧？\n」'), ['「对吧？」']);
    expect(splitLyricsText('『真的吗？\n』'), ['『真的吗？』']);
  });

  test('does not split common abbreviations', () {
    final lines = splitLyricsText(
      'Where is Mrs. Hirsch? Dr. Smith knows.',
      maxChars: 100,
    );

    expect(lines, ['Where is Mrs. Hirsch?', 'Dr. Smith knows.']);
  });

  test('keeps a spoken domain on one line', () {
    final lines = splitLyricsText(
      'Sign up to LEP Premium at teacherluke.co.uk/premium. '
      'Right then, welcome back.',
      maxChars: 100,
    );

    expect(lines, [
      'Sign up to LEP Premium at teacherluke.co.uk/premium.',
      'Right then, welcome back.',
    ]);
  });

  test('keeps versions, file names and ellipses intact', () {
    expect(
      splitLyricsText('We shipped v1.2.3 and notes.txt today.', maxChars: 100),
      ['We shipped v1.2.3 and notes.txt today.'],
    );
    // An ellipsis still reads as a pause worth breaking on, but it stays whole
    // instead of shattering into 'Wait.' / '.' / '.' the way it used to.
    expect(splitLyricsText('Wait... what happened? Nothing.', maxChars: 100), [
      'Wait...',
      'what happened?',
      'Nothing.',
    ]);
  });

  test('splits long sentences at clause boundaries before spaces', () {
    final lines = splitLyricsText(
      'Annemarie outdistanced her friend quickly, even though one of her '
      'shoes came untied as she sped along the street called Osterbrogade, '
      'past the small shops and cafes of her neighborhood.',
      maxChars: 100,
    );

    expect(lines, [
      'Annemarie outdistanced her friend quickly,',
      'even though one of her shoes came untied as she sped along the street '
          'called Osterbrogade,',
      'past the small shops and cafes of her neighborhood.',
    ]);
  });

  test('keeps an oversized clause intact instead of creating an orphan', () {
    final lines = splitLyricsText(
      'If you ask my mother whether she ever considered the ramifications '
      'of having a mixed child under apartheid, she will say no.',
      maxChars: 70,
    );

    expect(lines, [
      'If you ask my mother whether she ever considered the ramifications '
          'of having a mixed child under apartheid,',
      'she will say no.',
    ]);
    expect(lines.first.length, greaterThan(70));
  });

  test('does not force-split a long sentence without a pause boundary', () {
    const words = 'one two extraordinarilylongword three four five six';
    final lines = splitLyricsText(words, maxChars: 16);

    expect(lines, [words]);
  });

  test('Fish timestamps map display lines to exact audio offsets', () {
    const paragraph = Paragraph(
      id: 'p1',
      chapterId: 'c1',
      bookId: 'b1',
      paragraphIndex: 0,
      content: 'Hello world. Again.',
    );
    final manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'fish_audio_api',
      voiceId: 'default',
      speed: 1,
      updatedAt: 1,
      segments: const [
        SegmentEntry(
          paragraphId: 'p1',
          audioFile: 'c1/p1.wav',
          durationMs: 2000,
          state: ParagraphAudioState.ready,
          timings: [
            AudioTextTiming(text: 'Hello', startMs: 100, endMs: 400),
            AudioTextTiming(text: 'world', startMs: 450, endMs: 900),
            AudioTextTiming(text: 'Again', startMs: 1100, endMs: 1600),
          ],
        ),
      ],
    );

    final lines = buildSyncedLyricLines([paragraph], manifest, maxChars: 12);

    expect(lines.map((line) => line.text), ['Hello world.', 'Again.']);
    expect((lines.first.startMs, lines.first.endMs), (100, 900));
    expect((lines.last.startMs, lines.last.endMs), (1100, 1600));
    expect(lines.first.words.map((word) => word.text), ['Hello', 'world.']);
    expect(lines.first.words.map((word) => (word.startMs, word.endMs)), [
      (100, 400),
      (450, 900),
    ]);
  });

  test(
    'aligns Japanese kana instead of falling back to full-duration timing',
    () {
      const paragraph = Paragraph(
        id: 'ja',
        chapterId: 'c1',
        bookId: 'b1',
        paragraphIndex: 0,
        content: 'これはテストです。',
      );
      final manifest = ChapterManifest(
        chapterId: 'c1',
        bookId: 'b1',
        providerId: 'whisper-local',
        voiceId: '',
        speed: 1,
        updatedAt: 1,
        segments: const [
          SegmentEntry(
            paragraphId: 'ja',
            audioFile: 'episode.mp3',
            durationMs: 5000,
            state: ParagraphAudioState.ready,
            timings: [
              AudioTextTiming(text: 'これはテストです', startMs: 800, endMs: 1600),
            ],
          ),
        ],
      );

      final lines = buildSyncedLyricLines([paragraph], manifest);

      expect(lines, hasLength(1));
      expect((lines.single.startMs, lines.single.endMs), (800, 1600));
    },
  );

  test('interpolates lines that share one Fish timing segment', () {
    const paragraph = Paragraph(
      id: 'p1',
      chapterId: 'c1',
      bookId: 'b1',
      paragraphIndex: 0,
      content: 'Alpha beta gamma, delta epsilon zeta.',
    );
    final manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'fish_audio_api',
      voiceId: 'default',
      speed: 1,
      updatedAt: 1,
      segments: const [
        SegmentEntry(
          paragraphId: 'p1',
          audioFile: 'c1/p1.wav',
          durationMs: 3000,
          state: ParagraphAudioState.ready,
          timings: [
            AudioTextTiming(
              text: 'Alpha beta gamma, delta epsilon zeta',
              startMs: 0,
              endMs: 3000,
            ),
          ],
        ),
      ],
    );

    final lines = buildSyncedLyricLines([paragraph], manifest, maxChars: 18);

    expect(lines, hasLength(greaterThan(1)));
    expect(lines.last.startMs, greaterThan(lines.first.startMs));
    expect(
      lines.map((line) => line.startMs).toList(),
      orderedEquals([...lines.map((line) => line.startMs)]..sort()),
    );
  });

  test('keeps a standalone punctuation line inside phrase timing', () {
    const paragraph = Paragraph(
      id: 'punctuation',
      chapterId: 'c1',
      bookId: 'b1',
      paragraphIndex: 0,
      content: 'Hello\n—\nworld',
    );
    final manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'fish_audio_api',
      voiceId: 'default',
      speed: 1,
      updatedAt: 1,
      segments: const [
        SegmentEntry(
          paragraphId: 'punctuation',
          audioFile: 'c1/punctuation.wav',
          durationMs: 1000,
          state: ParagraphAudioState.ready,
          timings: [
            AudioTextTiming(text: 'Hello world', startMs: 0, endMs: 1000),
          ],
        ),
      ],
    );

    final lines = buildSyncedLyricLines([paragraph], manifest);

    expect(lines.map((line) => line.text), ['Hello', '—', 'world']);
    // The dash normalizes to an empty range at offset five. It is still
    // strictly inside the phrase timing, so it must interpolate to 500 ms
    // rather than fall back to its proportional whole-line estimate.
    expect((lines[1].startMs, lines[1].endMs), (500, 500));
    expect(
      (lines[1].words.single.startMs, lines[1].words.single.endMs),
      (500, 501),
    );
  });

  test('folds a standalone Japanese closing quote across paragraphs', () {
    const paragraphs = [
      Paragraph(
        id: 'dialogue',
        chapterId: 'c1',
        bookId: 'b1',
        paragraphIndex: 0,
        content: '「说到恐怖，昨天我房间出现一只好大的蜘蛛耶。',
      ),
      Paragraph(
        id: 'closing-quote',
        chapterId: 'c1',
        bookId: 'b1',
        paragraphIndex: 1,
        content: '」',
      ),
    ];
    final manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'fish_audio_api',
      voiceId: 'default',
      speed: 1,
      updatedAt: 1,
      segments: const [
        SegmentEntry(
          paragraphId: 'dialogue',
          audioFile: 'c1/dialogue.wav',
          durationMs: 1000,
          state: ParagraphAudioState.ready,
        ),
        SegmentEntry(
          paragraphId: 'closing-quote',
          audioFile: 'c1/closing-quote.wav',
          durationMs: 1,
          state: ParagraphAudioState.ready,
        ),
      ],
    );

    final lines = buildSyncedLyricLines(paragraphs, manifest);

    expect(lines, hasLength(1));
    expect(lines.single.text, '「说到恐怖，昨天我房间出现一只好大的蜘蛛耶。」');
    expect(lines.single.representedParagraphIds, ['dialogue', 'closing-quote']);
  });

  test('legacy cached audio gets proportional line offsets', () {
    const paragraph = Paragraph(
      id: 'p1',
      chapterId: 'c1',
      bookId: 'b1',
      paragraphIndex: 0,
      content: 'One. Two.',
    );
    final manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'kokoro',
      voiceId: 'default',
      speed: 1,
      updatedAt: 1,
      segments: const [
        SegmentEntry(
          paragraphId: 'p1',
          audioFile: 'c1/p1.wav',
          durationMs: 1000,
          state: ParagraphAudioState.ready,
        ),
      ],
    );

    final lines = buildSyncedLyricLines([paragraph], manifest, maxChars: 6);

    expect(lines, hasLength(2));
    expect(lines.first.startMs, 0);
    expect(lines.first.endMs, greaterThan(0));
    expect(lines.last.startMs, lines.first.endMs);
    expect(lines.last.endMs, 1000);
  });

  test('indexes long transcript timings without quadratic scans', () {
    // One timing per display line mirrors a Whisper transcript with short
    // segments. The former implementation scanned every timing once for the
    // line and once for its word, making this O(n²). Count index visits rather
    // than elapsed time so this remains a reliable regression test on CI.
    const timingCount = 4096;
    String tokenFor(int index) {
      var value = index;
      final characters = <int>[];
      do {
        characters.add(97 + value % 26);
        value ~/= 26;
      } while (value > 0);
      return 'token${String.fromCharCodes(characters.reversed)}';
    }

    final transcriptLines = [
      for (var index = 0; index < timingCount; index++) '${tokenFor(index)}.',
    ];
    final timings = [
      for (var index = 0; index < timingCount; index++)
        AudioTextTiming(
          text: tokenFor(index),
          startMs: index * 10,
          endMs: (index + 1) * 10,
        ),
    ];
    final metrics = SyncedLyricsBuildMetrics();
    final paragraph = Paragraph(
      id: 'large',
      chapterId: 'large',
      bookId: 'podcast:large-show',
      paragraphIndex: 0,
      content: transcriptLines.join('\n'),
    );
    final manifest = ChapterManifest(
      chapterId: 'large',
      bookId: 'podcast:large-show',
      providerId: 'whisper-local',
      voiceId: '',
      speed: 1,
      updatedAt: 1,
      segments: [
        SegmentEntry(
          paragraphId: 'large',
          audioFile: 'https://example.com/episode.mp3',
          durationMs: timingCount * 10,
          state: ParagraphAudioState.ready,
          format: 'podcast',
          timings: timings,
        ),
      ],
    );

    final lines = buildSyncedLyricLines(
      [paragraph],
      manifest,
      metrics: metrics,
    );

    expect(lines, hasLength(timingCount));
    expect(lines[2048].words.single.startMs, 20480);
    expect(lines[2048].words.single.endMs, 20490);
    expect(metrics.timingRangeQueries, timingCount * 2);
    // A query uses one binary search plus two max-end tree descents. This is
    // deliberately loose, but orders of magnitude below the former ~33M
    // timing checks at this input size.
    expect(metrics.timingIndexNodeVisits, lessThan(timingCount * 120));
  });

  testWidgets('long transcripts lazily build only visible lyric lines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handler = _VirtualLyricsAudioHandler();
    addTearDown(handler.dispose);
    final transcriptLines = [
      for (var index = 0; index < 500; index++) 'Transcript segment $index.',
    ];
    final timings = [
      for (var index = 0; index < transcriptLines.length; index++)
        AudioTextTiming(
          text: transcriptLines[index],
          startMs: index * 1000,
          endMs: (index + 1) * 1000,
        ),
    ];
    final manifest = ChapterManifest(
      chapterId: 'long-transcript',
      bookId: 'podcast:long-show',
      providerId: 'whisper-local',
      voiceId: '',
      speed: 1,
      updatedAt: 1,
      segments: [
        SegmentEntry(
          paragraphId: 'long-transcript',
          audioFile: 'https://example.com/episode.mp3',
          durationMs: 500000,
          state: ParagraphAudioState.ready,
          format: 'podcast',
          timings: timings,
        ),
      ],
    );
    final paragraphs = [
      Paragraph(
        id: 'long-transcript',
        chapterId: 'long-transcript',
        bookId: 'podcast:long-show',
        paragraphIndex: 0,
        content: transcriptLines.join('\n'),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 500,
            child: SyncedLyricsList(
              paragraphs: paragraphs,
              manifest: manifest,
              handler: handler,
              playbackEnabled: false,
              expanded: true,
              virtualized: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final virtualList = find.byKey(
      const ValueKey('synced-lyrics-virtualized-list'),
    );
    expect(virtualList, findsOneWidget);
    expect(find.text('Transcript segment 0.'), findsOneWidget);
    expect(find.text('Transcript segment 499.'), findsNothing);
    expect(
      find.byType(AnimatedDefaultTextStyle).evaluate().length,
      lessThan(50),
    );

    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: virtualList, matching: find.byType(Scrollable)),
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('Transcript segment 499.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('subtitle seek animates with reduce motion $reduceMotion', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: reduceMotion);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final handler = _VirtualLyricsAudioHandler(paragraphId: 'streaming');
      addTearDown(handler.dispose);
      await tester.pumpWidget(
        _growingTranscript(handler, _streamedTranscriptLines(100)),
      );
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const ValueKey('synced-lyrics-virtualized-list')),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      final before = position.pixels;
      handler.currentPosition = const Duration(seconds: 80);
      handler.playbackState.add(PlaybackState());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final intermediate = position.pixels;
      await tester.pumpAndSettle();
      final target = position.pixels;
      expect(target, greaterThan(before + 1000));
      if (reduceMotion) {
        expect(intermediate, closeTo(target, 0.1));
      } else {
        expect(intermediate, greaterThan(before));
        expect(intermediate, lessThan(target - 1));
      }
      expect(find.text('Transcript segment 80.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('paused long transcript eventually scrolls to active line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handler = _VirtualLyricsAudioHandler(
      paragraphId: 'paused-long-transcript',
      initialPosition: const Duration(seconds: 450),
    );
    addTearDown(handler.dispose);
    final transcriptLines = [
      for (var index = 0; index < 500; index++) 'Transcript segment $index.',
    ];
    final timings = [
      for (var index = 0; index < transcriptLines.length; index++)
        AudioTextTiming(
          text: transcriptLines[index],
          startMs: index * 1000,
          endMs: (index + 1) * 1000,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 500,
            child: SyncedLyricsList(
              paragraphs: [
                Paragraph(
                  id: 'paused-long-transcript',
                  chapterId: 'paused-long-transcript',
                  bookId: 'podcast:paused-long-show',
                  paragraphIndex: 0,
                  content: transcriptLines.join('\n'),
                ),
              ],
              manifest: ChapterManifest(
                chapterId: 'paused-long-transcript',
                bookId: 'podcast:paused-long-show',
                providerId: 'whisper-local',
                voiceId: '',
                speed: 1,
                updatedAt: 1,
                segments: [
                  SegmentEntry(
                    paragraphId: 'paused-long-transcript',
                    audioFile: 'https://example.com/episode.mp3',
                    durationMs: 500000,
                    state: ParagraphAudioState.ready,
                    format: 'podcast',
                    timings: timings,
                  ),
                ],
              ),
              handler: handler,
              playbackEnabled: true,
              expanded: true,
              virtualized: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final virtualList = find.byKey(
      const ValueKey('synced-lyrics-virtualized-list'),
    );
    final scrollable = find.descendant(
      of: virtualList,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, greaterThan(10000));
    expect(find.text('Transcript segment 450.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not miss paragraph selected while lyrics bind', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handler = _BindingRaceLyricsAudioHandler(
      paragraphId: 'binding-race-transcript',
      initialPosition: const Duration(seconds: 450),
    );
    addTearDown(handler.dispose);
    final transcriptLines = [
      for (var index = 0; index < 500; index++) 'Binding segment $index.',
    ];
    final timings = [
      for (var index = 0; index < transcriptLines.length; index++)
        AudioTextTiming(
          text: transcriptLines[index],
          startMs: index * 1000,
          endMs: (index + 1) * 1000,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 500,
            child: SyncedLyricsList(
              paragraphs: [
                Paragraph(
                  id: 'binding-race-transcript',
                  chapterId: 'binding-race-transcript',
                  bookId: 'podcast:binding-race-show',
                  paragraphIndex: 0,
                  content: transcriptLines.join('\n'),
                ),
              ],
              manifest: ChapterManifest(
                chapterId: 'binding-race-transcript',
                bookId: 'podcast:binding-race-show',
                providerId: 'whisper-local',
                voiceId: '',
                speed: 1,
                updatedAt: 1,
                segments: [
                  SegmentEntry(
                    paragraphId: 'binding-race-transcript',
                    audioFile: 'https://example.com/episode.mp3',
                    durationMs: 500000,
                    state: ParagraphAudioState.ready,
                    format: 'podcast',
                    timings: timings,
                  ),
                ],
              ),
              handler: handler,
              playbackEnabled: true,
              expanded: true,
              virtualized: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final virtualList = find.byKey(
      const ValueKey('synced-lyrics-virtualized-list'),
    );
    final scrollable = find.descendant(
      of: virtualList,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, greaterThan(10000));
    expect(find.text('Binding segment 450.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newly cached chunk leaves the reading position alone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handler = _VirtualLyricsAudioHandler(paragraphId: 'growing');
    addTearDown(handler.dispose);

    List<AudioTextTiming> timingsFor(int count) => [
      for (var index = 0; index < count; index++)
        AudioTextTiming(
          text: 'Transcript segment $index.',
          startMs: index * 1000,
          endMs: (index + 1) * 1000,
        ),
    ];
    Widget buildAt(int count) {
      final timings = timingsFor(count);
      return MaterialApp(
        theme: AppTheme.darkTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 500,
            child: SyncedLyricsList(
              paragraphs: [
                Paragraph(
                  id: 'growing',
                  chapterId: 'growing',
                  bookId: 'podcast:growing-show',
                  paragraphIndex: 0,
                  content: timings.map((timing) => timing.text).join('\n'),
                ),
              ],
              manifest: ChapterManifest(
                chapterId: 'growing',
                bookId: 'podcast:growing-show',
                providerId: 'whisper-local',
                voiceId: '',
                speed: 1,
                updatedAt: 1,
                segments: [
                  SegmentEntry(
                    paragraphId: 'growing',
                    audioFile: 'https://example.com/episode.mp3',
                    durationMs: count * 1000,
                    state: ParagraphAudioState.ready,
                    format: 'podcast',
                    timings: timings,
                  ),
                ],
              ),
              handler: handler,
              // Playback is enabled while a podcast transcribes, so the list
              // tracks an active line the whole time.
              playbackEnabled: true,
              expanded: true,
              virtualized: true,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildAt(200));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('synced-lyrics-virtualized-list')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent * 0.6);
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(1000));

    // Whisper caches another chunk while the reader is further down.
    await tester.pumpWidget(buildAt(240));
    await tester.pumpAndSettle();

    expect(find.text('Transcript segment 239.'), findsNothing);
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(before, 1),
      reason: 'appending cached lines must not scroll the transcript',
    );
  });

  testWidgets('a cached chunk keeps the transcript scrollable right away', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handler = _VirtualLyricsAudioHandler(paragraphId: 'streaming');
    addTearDown(handler.dispose);

    await tester.pumpWidget(
      _growingTranscript(handler, _streamedTranscriptLines(200)),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('synced-lyrics-virtualized-list')),
      matching: find.byType(Scrollable),
    );
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);

    // Whisper caches another chunk in the same frame that playback moves on.
    // Following the new line must not wait for the appended text to be
    // measured: everything above it was measured already, and stalling until
    // the whole transcript is remeasured is what makes the page lurch.
    handler.currentPosition = const Duration(seconds: 100);
    await tester.pumpWidget(
      _growingTranscript(handler, _streamedTranscriptLines(240)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));

    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
      reason: 'an appended chunk must not stall following the active line',
    );
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(5000),
    );
  });

  testWidgets('a rewritten earlier line keeps the reader on their line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handler = _VirtualLyricsAudioHandler(paragraphId: 'streaming');
    addTearDown(handler.dispose);

    await tester.pumpWidget(
      _growingTranscript(handler, _streamedTranscriptLines(200)),
    );
    await tester.pumpAndSettle();

    final virtualList = find.byKey(
      const ValueKey('synced-lyrics-virtualized-list'),
    );
    final scrollable = find.descendant(
      of: virtualList,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent * 0.6);
    await tester.pumpAndSettle();

    final anchor = _lyricLineNear(tester, virtualList, 120);

    // A chunk overlap can re-transcribe the sentence it joins onto, which
    // makes a line above the reader taller and pushes everything below it down.
    final rewritten = _streamedTranscriptLines(240);
    rewritten[8] =
        'Transcript segment 8 came back from the chunk overlap far longer '
        'than it first arrived.';
    await tester.pumpWidget(_growingTranscript(handler, rewritten));
    await tester.pumpAndSettle();

    expect(
      _lyricLineTop(tester, virtualList, anchor.text),
      closeTo(anchor.dy, 1),
      reason: 'a rewritten line above the viewport must not shift the reader',
    );
  });

  testWidgets(
    'word selection preserves the active focus-line typography and wrapping',
    (tester) async {
      tester.view.physicalSize = const Size(390, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handler = _VirtualLyricsAudioHandler(
        paragraphId: 'focus-line',
        initialPosition: const Duration(milliseconds: 500),
      );
      addTearDown(handler.dispose);
      const sentence =
          'the managers found it impossible to fill my warehouse position '
          'with a long-term employee.';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 620,
              child: SyncedLyricsList(
                paragraphs: const [
                  Paragraph(
                    id: 'focus-line',
                    chapterId: 'focus-line',
                    bookId: 'focus-book',
                    paragraphIndex: 0,
                    content: sentence,
                  ),
                ],
                manifest: const ChapterManifest(
                  chapterId: 'focus-line',
                  bookId: 'focus-book',
                  providerId: 'test',
                  voiceId: 'test',
                  speed: 1,
                  updatedAt: 1,
                  segments: [
                    SegmentEntry(
                      paragraphId: 'focus-line',
                      audioFile: 'focus.wav',
                      durationMs: 2000,
                      state: ParagraphAudioState.ready,
                      timings: [
                        AudioTextTiming(
                          text: sentence,
                          startMs: 0,
                          endMs: 2000,
                        ),
                      ],
                    ),
                  ],
                ),
                handler: handler,
                focusMode: true,
                sweepEnabled: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final originalText = find.text(sentence);
      expect(originalText, findsOneWidget);
      final originalSize = tester.getSize(originalText);
      final originalStyle = tester.widget<AnimatedDefaultTextStyle>(
        find
            .ancestor(
              of: originalText,
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      );
      expect(originalStyle.style.fontSize, 21);

      final lineInkWell = tester.widget<InkWell>(
        find.ancestor(of: originalText, matching: find.byType(InkWell)).first,
      );
      lineInkWell.onLongPress!();
      await tester.pumpAndSettle();

      final selection = find.byKey(
        const ValueKey('word-selection-focus-line:0'),
      );
      expect(selection, findsOneWidget);
      final selectionTextRoot = find.descendant(
        of: selection,
        matching: find.byKey(
          const ValueKey('word-selection-text-focus-line:0'),
        ),
      );
      final selectionText = find.descendant(
        of: selectionTextRoot,
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(selectionText).style?.fontSize, 21);
      expect(
        tester.getSize(selectionText).height,
        closeTo(originalSize.height, 1),
      );

      await tester.tapAt(tester.getTopLeft(selectionText) + const Offset(8, 8));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Ask AI'))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'long-press word selection preserves virtualized transcript position',
    (tester) async {
      tester.view.physicalSize = const Size(390, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handler = _VirtualLyricsAudioHandler();
      addTearDown(handler.dispose);
      final transcriptLines = [
        for (var index = 0; index < 400; index++) 'Transcript segment $index.',
      ];
      final timings = [
        for (var index = 0; index < transcriptLines.length; index++)
          AudioTextTiming(
            text: transcriptLines[index],
            startMs: index * 1000,
            endMs: (index + 1) * 1000,
          ),
      ];
      final manifest = ChapterManifest(
        chapterId: 'long-transcript',
        bookId: 'podcast:long-show',
        providerId: 'whisper-local',
        voiceId: '',
        speed: 1,
        updatedAt: 1,
        segments: [
          SegmentEntry(
            paragraphId: 'long-transcript',
            audioFile: 'https://example.com/episode.mp3',
            durationMs: 400000,
            state: ParagraphAudioState.ready,
            format: 'podcast',
            timings: timings,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 500,
              child: SyncedLyricsList(
                paragraphs: [
                  Paragraph(
                    id: 'long-transcript',
                    chapterId: 'long-transcript',
                    bookId: 'podcast:long-show',
                    paragraphIndex: 0,
                    content: transcriptLines.join('\n'),
                  ),
                ],
                manifest: manifest,
                handler: handler,
                playbackEnabled: false,
                expanded: true,
                virtualized: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final virtualList = find.byKey(
        const ValueKey('synced-lyrics-virtualized-list'),
      );
      final scrollable = find.descendant(
        of: virtualList,
        matching: find.byType(Scrollable),
      );
      final scrollableState = tester.state<ScrollableState>(scrollable);
      scrollableState.position.jumpTo(
        scrollableState.position.maxScrollExtent * 0.65,
      );
      await tester.pump();
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(before, greaterThan(1000));
      final visibleTargetElement = find
          .descendant(of: virtualList, matching: find.byType(Text))
          .evaluate()
          .where((element) {
            final text = element.widget as Text;
            if (!(text.data ?? '').startsWith('Transcript segment ')) {
              return false;
            }
            final renderObject = element.renderObject;
            if (renderObject is! RenderBox || !renderObject.attached) {
              return false;
            }
            final rect =
                renderObject.localToGlobal(Offset.zero) & renderObject.size;
            return rect.top >= 80 && rect.bottom <= 420;
          })
          .first;
      final targetText = (visibleTargetElement.widget as Text).data!;
      final targetIndex = int.parse(
        RegExp(r'\d+').firstMatch(targetText)!.group(0)!,
      );
      final target = find.byElementPredicate(
        (element) => identical(element, visibleTargetElement),
      );

      final targetInkWell = tester.widget<InkWell>(
        find.ancestor(of: target, matching: find.byType(InkWell)).first,
      );
      targetInkWell.onLongPress!();
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('word-selection-long-transcript:$targetIndex')),
        findsOneWidget,
      );
      final after = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(after, closeTo(before, 1));
      expect(find.text('Transcript segment 0.'), findsNothing);
    },
  );
}

List<String> _streamedTranscriptLines(int count) => [
  for (var index = 0; index < count; index++) 'Transcript segment $index.',
];

double? _lyricLineTop(WidgetTester tester, Finder virtualList, String text) =>
    find
        .descendant(of: virtualList, matching: find.byType(Text))
        .evaluate()
        .where((element) {
          final widget = element.widget as Text;
          return (widget.data ?? widget.textSpan?.toPlainText() ?? '') == text;
        })
        .map(
          (element) =>
              (element.renderObject as RenderBox).localToGlobal(Offset.zero).dy,
        )
        .singleOrNull;

({String text, double dy}) _lyricLineNear(
  WidgetTester tester,
  Finder virtualList,
  double y,
) {
  final entry = find
      .descendant(of: virtualList, matching: find.byType(Text))
      .evaluate()
      .map((element) {
        final text = element.widget as Text;
        return (
          // A playing transcript renders each line as word spans, so the plain
          // `data` is only set while playback is disabled.
          text: text.data ?? text.textSpan?.toPlainText() ?? '',
          box: element.renderObject as RenderBox,
        );
      })
      .where((entry) => entry.text.startsWith('Transcript segment '))
      .firstWhere((entry) {
        final top = entry.box.localToGlobal(Offset.zero).dy;
        return top >= y && top <= y + 140;
      });
  return (text: entry.text, dy: entry.box.localToGlobal(Offset.zero).dy);
}

Widget _growingTranscript(
  _VirtualLyricsAudioHandler handler,
  List<String> lines, {
  bool scrollingEnabled = true,
  ValueNotifier<Duration?>? previewPosition,
}) {
  final timings = [
    for (var index = 0; index < lines.length; index++)
      AudioTextTiming(
        text: lines[index],
        startMs: index * 1000,
        endMs: (index + 1) * 1000,
      ),
  ];
  return MaterialApp(
    theme: AppTheme.darkTheme(),
    home: Scaffold(
      body: SizedBox(
        width: 390,
        height: 500,
        child: SyncedLyricsList(
          previewPosition: previewPosition,
          paragraphs: [
            Paragraph(
              id: 'streaming',
              chapterId: 'streaming',
              bookId: 'podcast:streaming-show',
              paragraphIndex: 0,
              content: lines.join('\n'),
            ),
          ],
          manifest: ChapterManifest(
            chapterId: 'streaming',
            bookId: 'podcast:streaming-show',
            providerId: 'whisper-local',
            voiceId: '',
            speed: 1,
            updatedAt: 1,
            segments: [
              SegmentEntry(
                paragraphId: 'streaming',
                audioFile: 'https://example.com/episode.mp3',
                durationMs: lines.length * 1000,
                state: ParagraphAudioState.ready,
                format: 'podcast',
                timings: timings,
              ),
            ],
          ),
          scrollingEnabled: scrollingEnabled,
          handler: handler,
          playbackEnabled: true,
          expanded: true,
          virtualized: true,
        ),
      ),
    ),
  );
}

class _VirtualLyricsAudioHandler extends BaseAudioHandler
    implements LuminaAudioHandler {
  _VirtualLyricsAudioHandler({this.paragraphId, this.initialPosition});

  final String? paragraphId;
  final Duration? initialPosition;

  /// Lets a test advance playback between pumps.
  Duration? currentPosition;

  @override
  Duration get chapterDuration => Duration.zero;

  @override
  Duration get chapterPosition => Duration.zero;

  @override
  Stream<Duration> get chapterPositionStream => const Stream<Duration>.empty();

  @override
  String? get currentBookId => null;

  @override
  String? get currentChapterId => null;

  @override
  ChapterManifest? get currentManifest => null;

  @override
  String? get currentParagraphId => paragraphId;

  @override
  String? get currentPodcastEpisodeId => null;

  @override
  Stream<String?> get currentParagraphIdStream => const Stream<String?>.empty();

  @override
  Duration get position => currentPosition ?? initialPosition ?? Duration.zero;

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BindingRaceLyricsAudioHandler extends BaseAudioHandler
    implements LuminaAudioHandler {
  _BindingRaceLyricsAudioHandler({
    required this.paragraphId,
    required this.initialPosition,
  });

  final String paragraphId;
  final Duration initialPosition;
  final StreamController<String?> _paragraphController =
      StreamController<String?>.broadcast();
  bool _snapshotRead = false;

  @override
  Duration get chapterDuration => Duration.zero;

  @override
  Duration get chapterPosition => initialPosition;

  @override
  Stream<Duration> get chapterPositionStream => const Stream.empty();

  @override
  String? get currentBookId => null;

  @override
  String? get currentChapterId => null;

  @override
  ChapterManifest? get currentManifest => null;

  @override
  String? get currentParagraphId {
    if (_snapshotRead) return paragraphId;
    _snapshotRead = true;
    _paragraphController.add(paragraphId);
    // Model a load completing during the initial snapshot read: the stale
    // value is returned while the transition event carries the new value.
    return null;
  }

  @override
  String? get currentPodcastEpisodeId => paragraphId;

  @override
  Stream<String?> get currentParagraphIdStream => _paragraphController.stream;

  @override
  Duration get position => initialPosition;

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {
    await _paragraphController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
