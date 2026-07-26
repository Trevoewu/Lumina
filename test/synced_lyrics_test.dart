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

  test('does not split common abbreviations', () {
    final lines = splitLyricsText(
      'Where is Mrs. Hirsch? Dr. Smith knows.',
      maxChars: 100,
    );

    expect(lines, ['Where is Mrs. Hirsch?', 'Dr. Smith knows.']);
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
  });

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

class _VirtualLyricsAudioHandler extends BaseAudioHandler
    implements LuminaAudioHandler {
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
  String? get currentParagraphId => null;

  @override
  String? get currentPodcastEpisodeId => null;

  @override
  Stream<String?> get currentParagraphIdStream => const Stream<String?>.empty();

  @override
  Duration get position => Duration.zero;

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
