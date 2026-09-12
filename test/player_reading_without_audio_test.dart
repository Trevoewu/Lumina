import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/domain/models/audio_text_timing.dart';
import 'package:lumina/presentation/screens/album/album_screen.dart';
import 'package:lumina/presentation/screens/player/player_screen.dart';
import 'package:lumina/presentation/screens/settings/tts_service_screen.dart';
import 'package:lumina/presentation/widgets/mini_player.dart';
import 'package:lumina/services/lumina_audio_handler.dart';
import 'package:lumina/services/audiobook_transcription_storage.dart';
import 'package:lumina/services/manifest_store.dart';
import 'package:lumina/services/sleep_timer_service.dart';
import 'package:lumina/tts/provider_registry.dart';
import 'package:lumina/tts/providers/fish_audio_api_tts_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final nativeIconChannels = <MethodChannel>[];
  setUp(() {
    // Native view pixels require a device; widget tests verify layout/actions.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          if (call.method == 'create') {
            final args = call.arguments as Map;
            if (args['viewType'] == 'CupertinoNativeIcon') {
              final channel = MethodChannel(
                'CupertinoNativeIcon_${args['id']}',
              );
              nativeIconChannels.add(channel);
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                  .setMockMethodCallHandler(channel, (_) async => null);
            }
          }
          return null;
        });
  });
  tearDown(() {
    for (final channel in nativeIconChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
    nativeIconChannels.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'recorded books offer local subtitles and show arriving ASR text',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final temp = Directory.systemTemp.createTempSync('recorded_book_ui_');
      final store = _TestManifestStore(temp);
      final handler = _TestAudioHandler();
      addTearDown(database.close);
      addTearDown(handler.dispose);
      addTearDown(() => temp.deleteSync(recursive: true));
      const book = Book(
        id: 'recorded-book',
        title: 'Recorded Book',
        format: 'txt',
        sourcePath: '/tmp/book.txt',
        chapterCount: 1,
        paragraphCount: 1,
        currentParagraphIndex: 0,
        playbackOffsetMs: 0,
        importedAt: 1,
        lastReadAt: 0,
        isRead: false,
        kind: 'book',
        rightsStatus: 'public_domain',
        externalSource: 'librivox',
      );
      const chapter = Chapter(
        id: 'recorded-chapter',
        bookId: 'recorded-book',
        chapterIndex: 0,
        title: 'Recorded Chapter',
        textOffset: 0,
        isHidden: false,
      );
      await database.replaceBookData(
        book: book,
        chapterEntries: [chapter],
        paragraphEntries: [
          const Paragraph(
            id: 'recorded-audio',
            chapterId: 'recorded-chapter',
            bookId: 'recorded-book',
            paragraphIndex: 0,
            content: 'Narrated by Volunteer.',
          ),
        ],
      );
      store.manifest = const ChapterManifest(
        chapterId: 'recorded-chapter',
        bookId: 'recorded-book',
        providerId: 'librivox',
        voiceId: 'Volunteer',
        speed: 1,
        updatedAt: 1,
        segments: [
          SegmentEntry(
            paragraphId: 'recorded-audio',
            audioFile: 'https://archive.org/download/book/audio.mp3',
            durationMs: 60000,
            state: ParagraphAudioState.ready,
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            manifestStoreProvider.overrideWithValue(store),
            luminaAudioHandlerProvider.overrideWith((ref) async => handler),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const PlayerScreen(book: book, initialChapter: chapter),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('player-transcript-toggle'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('book-transcript-start')),
        findsOneWidget,
      );
      expect(find.textContaining('Narrated by Volunteer'), findsNothing);

      final storage = AudiobookTranscriptionStorage(
        database,
        manifests: store,
        book: book,
        chapter: chapter,
      );
      await storage.update(
        chapter.id,
        status: 'paused',
        transcriptJson:
            '[{"text":"The recorded story begins.","startMs":0,"endMs":3000}]',
        progressMs: 30000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('book-transcript-start')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('player-more-menu')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('book-transcript-resume')),
        findsOneWidget,
      );
      expect(
        find.textContaining('The recorded story begins.', findRichText: true),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('mini player reopens the active audiobook chapter', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final audioHandler = _TestAudioHandler();
    addTearDown(database.close);
    addTearDown(audioHandler.dispose);

    const book = Book(
      id: 'mini-player-book',
      title: 'Mini Player Book',
      author: 'Reader',
      format: 'epub',
      sourcePath: '/tmp/mini-player.epub',
      chapterCount: 1,
      paragraphCount: 2,
      currentChapterId: 'mini-player-chapter',
      currentParagraphIndex: 1,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 1,
      isRead: false,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );
    const chapter = Chapter(
      id: 'mini-player-chapter',
      bookId: 'mini-player-book',
      chapterIndex: 0,
      title: 'Chapter 1',
      textOffset: 0,
      isHidden: false,
    );
    await database.replaceBookData(
      book: book,
      chapterEntries: const [chapter],
      paragraphEntries: const [
        Paragraph(
          id: 'mini-player-paragraph-1',
          chapterId: 'mini-player-chapter',
          bookId: 'mini-player-book',
          paragraphIndex: 0,
          content: 'First paragraph.',
        ),
        Paragraph(
          id: 'mini-player-paragraph-2',
          chapterId: 'mini-player-chapter',
          bookId: 'mini-player-book',
          paragraphIndex: 1,
          content: 'Second paragraph.',
        ),
      ],
    );
    audioHandler.startLoadedChapter(
      bookId: book.id,
      chapterId: chapter.id,
      paragraphId: 'mini-player-paragraph-2',
    );
    audioHandler.mediaItem.add(
      const MediaItem(
        id: 'mini-player-paragraph-2',
        title: 'Chapter 1 · Paragraph 2',
        album: 'Mini Player Book',
        extras: {
          'bookId': 'mini-player-book',
          'chapterId': 'mini-player-chapter',
          'paragraphId': 'mini-player-paragraph-2',
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          luminaAudioHandlerProvider.overrideWith((ref) async => audioHandler),
        ],
        child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chapter 1 · Paragraph 2'), findsOneWidget);
    await tester.tap(find.text('Chapter 1 · Paragraph 2'));
    await tester.pumpAndSettle();

    final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
    expect(player.initialChapter?.id, chapter.id);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('playlist switches chapters and seek controls change progress', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final temp = Directory.systemTemp.createTempSync('lumina_queue_test_');
    final manifestStore = _MultiManifestStore(temp);
    final audioHandler = _TestAudioHandler();
    addTearDown(database.close);
    addTearDown(audioHandler.dispose);
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    const book = Book(
      id: 'queue-book',
      title: 'Queue Book',
      format: 'epub',
      sourcePath: '/tmp/queue.epub',
      chapterCount: 3,
      paragraphCount: 3,
      currentChapterId: 'queue-chapter-1',
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 1,
      isRead: false,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );
    const chapters = [
      Chapter(
        id: 'queue-chapter-1',
        bookId: 'queue-book',
        chapterIndex: 0,
        title: 'Queue Chapter One',
        textOffset: 0,
        isHidden: false,
      ),
      Chapter(
        id: 'queue-chapter-2',
        bookId: 'queue-book',
        chapterIndex: 1,
        title: 'Queue Chapter Two',
        textOffset: 0,
        isHidden: false,
      ),
      Chapter(
        id: 'queue-chapter-3',
        bookId: 'queue-book',
        chapterIndex: 2,
        title: 'Queue Chapter Three',
        textOffset: 0,
        isHidden: false,
      ),
    ];
    const paragraphs = [
      Paragraph(
        id: 'queue-paragraph-1',
        chapterId: 'queue-chapter-1',
        bookId: 'queue-book',
        paragraphIndex: 0,
        content: 'First chapter text.',
      ),
      Paragraph(
        id: 'queue-paragraph-2',
        chapterId: 'queue-chapter-2',
        bookId: 'queue-book',
        paragraphIndex: 0,
        content: 'Second chapter text.',
      ),
      Paragraph(
        id: 'queue-paragraph-3',
        chapterId: 'queue-chapter-3',
        bookId: 'queue-book',
        paragraphIndex: 0,
        content: 'Third chapter text.',
      ),
    ];
    await database.replaceBookData(
      book: book,
      chapterEntries: chapters,
      paragraphEntries: paragraphs,
    );
    for (var index = 0; index < chapters.length; index++) {
      manifestStore.manifests[chapters[index].id] = ChapterManifest(
        chapterId: chapters[index].id,
        bookId: book.id,
        providerId: 'test',
        voiceId: 'voice',
        speed: 1,
        updatedAt: 1,
        segments: [
          SegmentEntry(
            paragraphId: paragraphs[index].id,
            audioFile: '${chapters[index].id}.mp3',
            durationMs: 1000,
            state: ParagraphAudioState.ready,
          ),
        ],
      );
    }
    audioHandler.startLoadedChapter(
      bookId: book.id,
      chapterId: chapters.first.id,
      paragraphId: paragraphs.first.id,
    );
    audioHandler.queue.add([
      for (var index = 0; index < chapters.length; index++)
        MediaItem(
          id: paragraphs[index].id,
          title: chapters[index].title,
          extras: {
            'bookId': book.id,
            'chapterId': chapters[index].id,
            'paragraphId': paragraphs[index].id,
          },
        ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          manifestStoreProvider.overrideWithValue(manifestStore),
          luminaAudioHandlerProvider.overrideWith((ref) async => audioHandler),
        ],
        child: MaterialApp(
          home: PlayerScreen(book: book, initialChapter: chapters.first),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player-playlist-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Queue Chapter One'),
      ),
      findsNothing,
    );
    expect(find.text('Queue Chapter Two'), findsOneWidget);
    expect(find.text('Queue Chapter Three'), findsOneWidget);

    await tester.tap(find.text('Queue Chapter Two'));
    await tester.pumpAndSettle();
    expect(find.text('Queue Chapter Two'), findsOneWidget);
    expect(audioHandler.skippedQueueIndex, 1);

    await audioHandler.seek(const Duration(seconds: 45));
    await tester.tap(find.byKey(const ValueKey('player-forward-three-lines')));
    await tester.pumpAndSettle();
    expect(audioHandler.soughtPosition, const Duration(seconds: 45));

    await tester.tap(find.byKey(const ValueKey('player-backward-one-line')));
    await tester.pumpAndSettle();
    expect(find.text('Queue Chapter Two'), findsOneWidget);
    expect(audioHandler.skippedQueueIndex, 1);
    expect(audioHandler.soughtPosition, const Duration(seconds: 45));
  });

  testWidgets(
    'an uncached chapter remains readable and offers streaming playback',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final temp = Directory.systemTemp.createTempSync('lumina_reader_test_');
      final manifestStore = ManifestStore(documentsDirectory: () async => temp);
      final audioHandler = _TestAudioHandler();
      final sleepTimerService = SleepTimerService();
      addTearDown(database.close);
      addTearDown(audioHandler.dispose);
      addTearDown(sleepTimerService.dispose);
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      const book = Book(
        id: 'readable-book',
        title: 'Readable Book',
        author: 'Reader',
        format: 'epub',
        sourcePath: '/tmp/readable.epub',
        chapterCount: 1,
        paragraphCount: 6,
        currentParagraphIndex: 0,
        playbackOffsetMs: 0,
        importedAt: 1,
        lastReadAt: 0,
        isRead: false,
        kind: 'book',
        rightsStatus: 'user_uploaded',
      );
      const chapter = Chapter(
        id: 'readable-chapter',
        bookId: 'readable-book',
        chapterIndex: 0,
        title: 'Chapter One',
        textOffset: 0,
        isHidden: false,
      );
      await database.replaceBookData(
        book: book,
        chapterEntries: const [chapter],
        paragraphEntries: const [
          Paragraph(
            id: 'readable-paragraph-1',
            chapterId: 'readable-chapter',
            bookId: 'readable-book',
            paragraphIndex: 0,
            content: 'This text is readable before any audio is cached.',
          ),
          Paragraph(
            id: 'readable-paragraph-2',
            chapterId: 'readable-chapter',
            bookId: 'readable-book',
            paragraphIndex: 1,
            content: 'The story continues across several visible lines.',
          ),
          Paragraph(
            id: 'readable-paragraph-3',
            chapterId: 'readable-chapter',
            bookId: 'readable-book',
            paragraphIndex: 2,
            content: 'The current sentence stays bright while it is spoken.',
          ),
          Paragraph(
            id: 'readable-paragraph-4',
            chapterId: 'readable-chapter',
            bookId: 'readable-book',
            paragraphIndex: 3,
            content: 'Nearby sentences remain visible for context.',
          ),
          Paragraph(
            id: 'readable-paragraph-5',
            chapterId: 'readable-chapter',
            bookId: 'readable-book',
            paragraphIndex: 4,
            content: 'More than one line stays on screen as playback moves.',
          ),
          Paragraph(
            id: 'readable-paragraph-6',
            chapterId: 'readable-chapter',
            bookId: 'readable-book',
            paragraphIndex: 5,
            content: 'You can tap any sentence to continue from there.',
          ),
        ],
      );
      expect(await database.getParagraphs(chapter.id), hasLength(6));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            manifestStoreProvider.overrideWithValue(manifestStore),
            luminaAudioHandlerProvider.overrideWith(
              (ref) async => audioHandler,
            ),
            sleepTimerServiceProvider.overrideWithValue(sleepTimerService),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const PlayerScreen(book: book, initialChapter: chapter),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      expect(find.text('Chapter One'), findsOneWidget);
      // Rotation reveals the transcript alongside the cover without a tap,
      // including on a small phone with safe-area insets.
      for (final size in [const Size(844, 390), const Size(667, 375)]) {
        tester.view.physicalSize = size;
        tester.view.padding = FakeViewPadding(left: 44, right: 44, bottom: 21);
        await tester.pumpAndSettle();
        final cover = find.byKey(const ValueKey('player-landscape-cover'));
        final transcript = find.byKey(
          const ValueKey('player-landscape-transcript'),
        );
        expect(cover, findsOneWidget);
        expect(transcript, findsOneWidget);
        expect(
          tester.getRect(cover).right,
          lessThanOrEqualTo(tester.getRect(transcript).left),
        );
        expect(
          find.text('This text is readable before any audio is cached.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('player-playback-controls')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('player-default-header')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('player-output-toggle')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('player-playlist-toggle')),
          findsOneWidget,
        );
        final coverRect = tester.getRect(cover);
        final actionsRect = tester.getRect(
          find.byKey(const ValueKey('player-landscape-actions')),
        );
        final artworkRect = tester.getRect(
          find.byKey(const ValueKey('player-artwork')),
        );
        expect(actionsRect.left, greaterThanOrEqualTo(coverRect.left));
        expect(actionsRect.right, lessThanOrEqualTo(coverRect.right));
        expect(actionsRect.bottom, closeTo(coverRect.bottom, 0.1));
        expect(artworkRect.center.dx, closeTo(coverRect.center.dx, 0.1));
        expect(artworkRect.width, closeTo(artworkRect.height, 0.1));
        final artworkViewport = tester.getRect(
          find.byKey(const ValueKey('player-landscape-artwork-viewport')),
        );
        expect(artworkRect.center.dy, closeTo(artworkViewport.center.dy, 0.1));
        expect(
          artworkRect.top - artworkViewport.top,
          greaterThanOrEqualTo(artworkViewport.height * 0.09),
        );
        expect(
          artworkViewport.bottom - artworkRect.bottom,
          closeTo(artworkRect.top - artworkViewport.top, 0.1),
        );
        expect(artworkRect.bottom, lessThan(actionsRect.top));
        expect(
          tester.getRect(transcript).bottom,
          closeTo(coverRect.bottom, 0.1),
        );
        final toggle = find.byKey(const ValueKey('player-transcript-toggle'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(transcript, findsNothing);
        expect(cover, findsOneWidget);
        expect(
          find
              .byKey(const ValueKey('player-primary-audio-action'))
              .hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(transcript, findsOneWidget);
        expect(
          find.byKey(const ValueKey('player-playback-controls')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }

      // iPad / macOS landscape layout (1024 x 768)
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('player-landscape-layout')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('player-close-button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('player-playback-controls')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player-landscape-transcript')),
        findsOneWidget,
      );

      tester.view.resetPadding();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('player-landscape-layout')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('player-playback-controls')),
        findsOneWidget,
      );
      // The chapter text now lives behind the reading toggle rather than in a
      // card on the cover face, but it must still be reachable with no audio
      // cached at all — reading is the whole point of an ungenerated chapter.
      final readingToggle = find.byKey(
        const ValueKey('player-transcript-toggle'),
      );
      await tester.ensureVisible(readingToggle);
      await tester.tap(readingToggle);
      await tester.pumpAndSettle();
      expect(
        find.text('This text is readable before any audio is cached.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('synced-lyrics-virtualized-list')),
        findsOneWidget,
      );
      // Reading mode renders on the player's own light background, so it must
      // keep the theme text colour rather than the dark sheet's white.
      final transcriptLineStyle = tester
          .widget<AnimatedDefaultTextStyle>(
            find
                .ancestor(
                  of: find.text(
                    'This text is readable before any audio is cached.',
                  ),
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first,
          )
          .style;
      expect(transcriptLineStyle.color, isNot(Colors.white));
      await tester.tap(readingToggle);
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is AppIcon && widget.icon == AppIcons.play,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is AppIcon && widget.icon == AppIcons.download01,
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.downloading_rounded), findsNothing);
      expect(find.text('Cached 0%'), findsNothing);
      expect(
        find.byKey(const ValueKey('player-cache-progress-label')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('player-background-cache-indicator')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('player-primary-audio-action')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      final progress = tester.widget<Slider>(
        find.byKey(const ValueKey('player-cache-playback-progress')),
      );
      expect(progress.value, 0);
      expect(progress.secondaryTrackValue, 0);
      final sliderTheme = tester.widget<SliderTheme>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('player-cache-playback-progress')),
              matching: find.byType(SliderTheme),
            )
            .first,
      );
      expect(
        sliderTheme.data.activeTrackColor,
        isNot(sliderTheme.data.secondaryActiveTrackColor),
      );
      expect(
        find.byKey(const ValueKey('player-immersive-background')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('player-artwork')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('player-artwork-repaint-boundary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player-controls-repaint-boundary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('book-player-scroll-view')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('book-information-card')), findsNothing);
      expect(find.byKey(const ValueKey('player-more-menu')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('player-sleep-timer-toggle')),
        findsOneWidget,
      );

      final background = tester.widget<Container>(
        find.byKey(const ValueKey('player-immersive-background')),
      );
      final backgroundDecoration = background.decoration! as BoxDecoration;
      final backgroundGradient =
          backgroundDecoration.gradient! as LinearGradient;
      expect(
        backgroundGradient.colors.every(
          (color) => color.computeLuminance() > 0.8,
        ),
        isTrue,
      );
      expect(
        find.ancestor(
          of: find.byType(Scaffold),
          matching: find.byKey(const ValueKey('player-immersive-background')),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
      );
      final primaryButtonMaterial = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('player-primary-audio-action')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(primaryButtonMaterial.color, Colors.transparent);

      // Inline mode preserves scroll position; normalize only the screenshot.
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('book-player-scroll-view')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PlayerScreen),
        matchesGoldenFile('goldens/player_spotify_light_390.png'),
      );

      await tester.drag(
        find.byKey(const ValueKey('book-player-scroll-view')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-summary-card')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('transcript-pointer-card')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('ai-summary-card'))).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('transcript-pointer-card')))
              .dy,
        ),
      );
      final lightOnSurface = AppTheme.lightTheme().colorScheme.onSurface;
      expect(
        tester.widget<Text>(find.text('AI Summary')).style?.color,
        lightOnSurface,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('player-sleep-timer-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('player-sleep-timer-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('15 minutes'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('15 minutes'));
      await tester.pumpAndSettle();
      expect(sleepTimerService.state.mode, SleepTimerMode.duration);
      expect(sleepTimerService.state.duration, const Duration(minutes: 15));
      await sleepTimerService.cancel();

      audioHandler.startLoadedChapter(
        bookId: book.id,
        chapterId: chapter.id,
        paragraphId: 'readable-paragraph-3',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('player-live-lyrics-stage')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('lyrics-card')), findsNothing);
      expect(
        find.byKey(const ValueKey('transcript-pointer-card')),
        findsOneWidget,
      );

      // Several sentences of context around the current one stay on screen,
      // which is the whole point of the lyric-style reading panel.
      final playingToggle = find.byKey(
        const ValueKey('player-transcript-toggle'),
      );
      await tester.ensureVisible(playingToggle);
      await tester.tap(playingToggle);
      await tester.pumpAndSettle();
      expect(
        find.text('The story continues across several visible lines.'),
        findsOneWidget,
      );
      expect(
        find.text('The current sentence stays bright while it is spoken.'),
        findsOneWidget,
      );
      expect(
        find.text('Nearby sentences remain visible for context.'),
        findsOneWidget,
      );
      await tester.tap(playingToggle);
      await tester.pumpAndSettle();
      final compactArtwork = tester.getSize(
        find.byKey(const ValueKey('player-artwork')),
      );
      expect(compactArtwork, const Size.square(320));

      // Inline mode preserves scroll position; normalize only the screenshot.
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('book-player-scroll-view')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PlayerScreen),
        matchesGoldenFile('goldens/player_spotify_light_playing_390.png'),
      );

      expect(audioHandler.hasChapterPositionListener, isTrue);
      final coverDrag = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('book-cover-focus-viewport')),
        ),
      );
      await coverDrag.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(
        audioHandler.hasChapterPositionListener,
        isFalse,
        reason: 'cover scrolling should suspend high-frequency progress UI',
      );
      await coverDrag.up();
      await tester.pumpAndSettle();
      expect(audioHandler.hasChapterPositionListener, isTrue);

      final overscrollDrag = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('book-player-scroll-view'))),
      );
      await overscrollDrag.moveBy(const Offset(0, -1000));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('player-sticky-mini-player')),
        findsNothing,
        reason: 'elastic overscroll must not toggle the mini player',
      );
      await overscrollDrag.up();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('player-sticky-mini-player')),
        findsNothing,
        reason: 'the mini player must wait for the full player stage to exit',
      );
      expect(find.byKey(const ValueKey('player-default-header')), findsNothing);
      expect(
        find.byKey(const ValueKey('ai-summary-card')).hitTestable(),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('transcript-pointer-card')).hitTestable(),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const ValueKey('book-player-scroll-view')),
        const Offset(0, 700),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('player-sticky-mini-player')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('player-default-header')), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('player-primary-audio-action')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is AppIcon && widget.icon == AppIcons.play,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player-live-lyrics-stage')),
        findsNothing,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('player-artwork'))),
        const Size.square(320),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('autoplay does not use providers after player is disposed', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final temp = Directory.systemTemp.createTempSync('lumina_autoplay_test_');
    final manifestStore = _TestManifestStore(temp);
    final audioHandler = _TestAudioHandler();
    final pendingLoad = Completer<void>();
    audioHandler.pendingLoadChapter = pendingLoad;
    addTearDown(database.close);
    addTearDown(audioHandler.dispose);
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    const book = Book(
      id: 'autoplay-dispose-book',
      title: 'Autoplay Dispose Book',
      format: 'epub',
      sourcePath: '/tmp/autoplay-dispose.epub',
      chapterCount: 1,
      paragraphCount: 2,
      currentChapterId: 'autoplay-dispose-chapter',
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 1,
      isRead: false,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );
    const chapter = Chapter(
      id: 'autoplay-dispose-chapter',
      bookId: 'autoplay-dispose-book',
      chapterIndex: 0,
      title: 'Autoplay Chapter',
      textOffset: 0,
      isHidden: false,
    );
    await database.replaceBookData(
      book: book,
      chapterEntries: const [chapter],
      paragraphEntries: const [
        Paragraph(
          id: 'autoplay-dispose-paragraph-1',
          chapterId: 'autoplay-dispose-chapter',
          bookId: 'autoplay-dispose-book',
          paragraphIndex: 0,
          content: 'The first paragraph is cached.',
        ),
        Paragraph(
          id: 'autoplay-dispose-paragraph-2',
          chapterId: 'autoplay-dispose-chapter',
          bookId: 'autoplay-dispose-book',
          paragraphIndex: 1,
          content: 'The second paragraph is still pending.',
        ),
      ],
    );
    manifestStore.manifest = const ChapterManifest(
      chapterId: 'autoplay-dispose-chapter',
      bookId: 'autoplay-dispose-book',
      providerId: 'test',
      voiceId: 'test',
      speed: 1,
      updatedAt: 1,
      segments: [
        SegmentEntry(
          paragraphId: 'autoplay-dispose-paragraph-1',
          audioFile: 'autoplay-dispose-chapter/paragraph-1.mp3',
          durationMs: 1000,
          state: ParagraphAudioState.ready,
        ),
        SegmentEntry(
          paragraphId: 'autoplay-dispose-paragraph-2',
          audioFile: 'autoplay-dispose-chapter/paragraph-2.mp3',
          durationMs: 0,
          state: ParagraphAudioState.notGenerated,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          manifestStoreProvider.overrideWithValue(manifestStore),
          luminaAudioHandlerProvider.overrideWith((ref) async => audioHandler),
        ],
        child: const MaterialApp(
          home: PlayerScreen(
            book: book,
            initialChapter: chapter,
            autoplayOnOpen: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    pendingLoad.complete();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('play guides an unconfigured user to cloud TTS settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final temp = Directory.systemTemp.createTempSync('lumina_tts_gate_test_');
    final manifestStore = ManifestStore(documentsDirectory: () async => temp);
    final audioHandler = _TestAudioHandler();
    addTearDown(database.close);
    addTearDown(audioHandler.dispose);
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    const book = Book(
      id: 'tts-gate-book',
      title: 'Cloud Narration',
      author: 'Reader',
      format: 'epub',
      sourcePath: '/tmp/cloud.epub',
      chapterCount: 1,
      paragraphCount: 1,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 0,
      isRead: false,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );
    const chapter = Chapter(
      id: 'tts-gate-chapter',
      bookId: 'tts-gate-book',
      chapterIndex: 0,
      title: 'Chapter',
      textOffset: 0,
      isHidden: false,
    );
    await database.replaceBookData(
      book: book,
      chapterEntries: const [chapter],
      paragraphEntries: const [
        Paragraph(
          id: 'tts-gate-paragraph',
          chapterId: 'tts-gate-chapter',
          bookId: 'tts-gate-book',
          paragraphIndex: 0,
          content: 'Connect a voice provider before playback.',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          manifestStoreProvider.overrideWithValue(manifestStore),
          luminaAudioHandlerProvider.overrideWith((ref) async => audioHandler),
          activeTtsProviderProvider.overrideWithValue(
            _UnconfiguredCloudTtsProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const PlayerScreen(book: book, initialChapter: chapter),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const ValueKey('player-primary-audio-action')));
    await tester.pumpAndSettle();

    expect(find.text('Connect a voice provider'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-tts-settings')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-tts-settings')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TtsServiceScreen), findsOneWidget);
  });

  test('primary audio action shows preparation while streaming', () {
    expect(
      resolvePlayerPrimaryAudioAction(playing: false, playbackRequested: false),
      PlayerPrimaryAudioAction.play,
    );
    expect(
      resolvePlayerPrimaryAudioAction(playing: false, playbackRequested: true),
      PlayerPrimaryAudioAction.loading,
    );
    expect(
      resolvePlayerPrimaryAudioAction(playing: true, playbackRequested: false),
      PlayerPrimaryAudioAction.pause,
    );
    expect(
      resolvePlayerPrimaryAudioAction(
        playing: true,
        playbackRequested: false,
        buffering: true,
      ),
      PlayerPrimaryAudioAction.loading,
      reason: 'a stream with no audio yet must not claim to be playing',
    );
    expect(
      resolvePlayerPrimaryAudioAction(
        playing: false,
        playbackRequested: false,
        buffering: true,
      ),
      PlayerPrimaryAudioAction.play,
      reason: 'buffering nobody asked for is not a pending play request',
    );
  });

  testWidgets('progress slider follows drag and seeks only on release', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final temp = Directory.systemTemp.createTempSync('lumina_seek_test_');
    final manifestStore = _TestManifestStore(temp);
    final audioHandler = _TestAudioHandler();
    addTearDown(database.close);
    addTearDown(audioHandler.dispose);
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    const book = Book(
      id: 'seek-book',
      title: 'Seek Book',
      format: 'epub',
      sourcePath: '/tmp/seek.epub',
      chapterCount: 1,
      paragraphCount: 1,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 1,
      isRead: false,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );
    const chapter = Chapter(
      id: 'seek-chapter',
      bookId: 'seek-book',
      chapterIndex: 0,
      title: 'Seek Chapter',
      textOffset: 0,
      isHidden: false,
    );
    const paragraph = Paragraph(
      id: 'seek-paragraph',
      chapterId: 'seek-chapter',
      bookId: 'seek-book',
      paragraphIndex: 0,
      content: 'Opening sentence. Seekable text.',
    );
    await database.replaceBookData(
      book: book,
      chapterEntries: const [chapter],
      paragraphEntries: const [paragraph],
    );
    manifestStore.manifest = const ChapterManifest(
      chapterId: 'seek-chapter',
      bookId: 'seek-book',
      providerId: 'tts',
      voiceId: 'voice',
      speed: 1,
      updatedAt: 1,
      segments: [
        SegmentEntry(
          paragraphId: 'seek-paragraph',
          audioFile: 'seek-chapter/seek-paragraph.mp3',
          durationMs: 1329000,
          state: ParagraphAudioState.ready,
          timings: [
            AudioTextTiming(
              text: 'Opening sentence.',
              startMs: 0,
              endMs: 797400,
            ),
            AudioTextTiming(
              text: 'Seekable text.',
              startMs: 797400,
              endMs: 1329000,
            ),
          ],
        ),
      ],
    );
    audioHandler.startLoadedChapter(
      bookId: book.id,
      chapterId: chapter.id,
      paragraphId: paragraph.id,
    );
    audioHandler.pendingSeek = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          manifestStoreProvider.overrideWithValue(manifestStore),
          luminaAudioHandlerProvider.overrideWith((ref) async => audioHandler),
        ],
        child: const MaterialApp(
          home: PlayerScreen(book: book, initialChapter: chapter),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sliderFinder = find.byKey(
      const ValueKey('player-cache-playback-progress'),
    );
    var slider = tester.widget<Slider>(sliderFinder);
    slider.onChangeStart!(0);
    slider.onChanged!(0.6);
    await tester.pump();

    slider = tester.widget<Slider>(sliderFinder);
    expect(slider.value, closeTo(0.6, 0.001));
    expect(audioHandler.seekCalls, 0);

    // Cache growth can change the duration while the finger is down. The
    // displayed target must retain the timeline captured at drag start.
    audioHandler.changeChapterDuration(const Duration(minutes: 24));
    await tester.pump();
    await tester.pump();
    expect(find.text('13:17'), findsOneWidget);
    slider = tester.widget<Slider>(sliderFinder);
    slider.onChangeEnd!(0.6);
    await tester.pump();
    expect(audioHandler.seekCalls, 1);
    expect(
      audioHandler.soughtPosition,
      const Duration(minutes: 13, seconds: 17, milliseconds: 400),
    );
    expect(tester.widget<Slider>(sliderFinder).value, closeTo(0.6, 0.001));

    audioHandler.deferSeekPositionEvent = true;
    audioHandler.pendingSeek!.complete();
    await tester.pump();
    expect(find.text('13:17'), findsOneWidget);
    expect(
      tester.widget<Slider>(sliderFinder).value,
      closeTo(797400 / 1440000, 0.001),
    );

    // Exercise real pointer events, including the enlarged touch area and
    // release before the next position event. Callback-only tests miss this.
    for (final distance in [55.0, -80.0, 30.0]) {
      final rect = tester.getRect(sliderFinder);
      final gesture = await tester.startGesture(
        Offset(rect.center.dx, rect.top + 5),
      );
      await tester.pump(const Duration(milliseconds: 160));
      await gesture.moveBy(Offset(distance, 0));
      await tester.pump();
      await gesture.moveBy(Offset(distance / 2, 0));
      await tester.pump();
      final preview = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('player-playback-controls')),
              matching: find.byType(Text),
            ),
          )
          .firstWhere(
            (text) => RegExp(r'^\d+:\d{2}$').hasMatch(text.data ?? ''),
          );
      final parts = preview.data!.split(':').map(int.parse).toList();
      final previewSeconds = parts[0] * 60 + parts[1];
      await gesture.up();
      await tester.pump();
      expect(audioHandler.soughtPosition!.inSeconds, previewSeconds);
      expect(find.text(preview.data!), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('player-backward-one-line')));
    await tester.pump();
    expect(audioHandler.soughtPosition, Duration.zero);
    await tester.tap(find.byKey(const ValueKey('player-forward-three-lines')));
    await tester.pump();
    expect(audioHandler.soughtPosition, const Duration(milliseconds: 797400));
  });

  test('audiobook chapter position prefers per-chapter progress', () {
    const manifest = ChapterManifest(
      chapterId: 'chapter',
      bookId: 'book',
      providerId: 'test',
      voiceId: 'voice',
      speed: 1,
      updatedAt: 1,
      segments: [
        SegmentEntry(
          paragraphId: 'p1',
          audioFile: 'p1.mp3',
          durationMs: 10000,
          state: ParagraphAudioState.ready,
        ),
        SegmentEntry(
          paragraphId: 'p2',
          audioFile: 'p2.mp3',
          durationMs: 12000,
          state: ParagraphAudioState.ready,
        ),
      ],
    );

    expect(
      resolveAudiobookChapterPositionMs(
        manifest: manifest,
        savedPositionMs: 17500,
        legacyParagraphIndex: 0,
        legacyParagraphOffsetMs: 500,
      ),
      17500,
    );
    expect(
      resolveAudiobookChapterPositionMs(
        manifest: manifest,
        savedPositionMs: null,
        legacyParagraphIndex: 1,
        legacyParagraphOffsetMs: 2500,
      ),
      12500,
    );
  });

  testWidgets('audiobook chapters show index badges without rewriting titles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final temp = Directory.systemTemp.createTempSync('lumina_divider_test_');
    final manifestStore = ManifestStore(documentsDirectory: () async => temp);
    addTearDown(database.close);
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    const book = Book(
      id: 'divider-book',
      title: 'Divider Book',
      format: 'epub',
      sourcePath: '/tmp/missing-divider-book.epub',
      chapterCount: 2,
      paragraphCount: 0,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 0,
      isRead: false,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );
    const chapters = [
      Chapter(
        id: 'free-form-chapter',
        bookId: 'divider-book',
        chapterIndex: 0,
        title: 'Opening — 2026 / Untitled',
        textOffset: 0,
        isHidden: false,
      ),
      Chapter(
        id: 'part-title-chapter',
        bookId: 'divider-book',
        chapterIndex: 1,
        title: '第Ⅱ部',
        textOffset: 0,
        isHidden: false,
      ),
    ];
    await database.replaceBookData(
      book: book,
      chapterEntries: chapters,
      paragraphEntries: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          manifestStoreProvider.overrideWithValue(manifestStore),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const AlbumScreen(book: book),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Opening — 2026 / Untitled'), findsOneWidget);
    expect(find.text('第Ⅱ部'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);

    await tester.longPress(find.text('第Ⅱ部'));
    await tester.pumpAndSettle();
    expect(find.text('Change narrator'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });

  testWidgets('book detail lazily loads manifests for visible chapters only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final temp = Directory.systemTemp.createTempSync('lumina_lazy_book_test_');
    final manifestStore = _CountingManifestStore(temp);
    addTearDown(database.close);
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    final chapters = List<Chapter>.generate(
      60,
      (index) => Chapter(
        id: 'lazy-chapter-$index',
        bookId: 'lazy-book',
        chapterIndex: index,
        title: 'Chapter ${index + 1}',
        textOffset: 0,
        isHidden: false,
      ),
    );
    final book = Book(
      id: 'lazy-book',
      title: 'Lazy Book',
      format: 'epub',
      sourcePath: '/tmp/missing-lazy-book.epub',
      chapterCount: chapters.length,
      paragraphCount: 0,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 0,
      isRead: false,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );
    await database.replaceBookData(
      book: book,
      chapterEntries: chapters,
      paragraphEntries: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          manifestStoreProvider.overrideWithValue(manifestStore),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: AlbumScreen(book: book),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(manifestStore.loadedChapterIds, isNotEmpty);
    expect(manifestStore.loadedChapterIds.length, lessThan(20));
    expect(manifestStore.loadedChapterIds.length, lessThan(chapters.length));
    expect(find.text('Chapter 60'), findsNothing);
  });

  testWidgets('opening a chapter covers the outer app navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final temp = Directory.systemTemp.createTempSync('lumina_nav_test_');
    final manifestStore = _TestManifestStore(temp);
    final audioHandler = _TestAudioHandler();
    addTearDown(database.close);
    addTearDown(audioHandler.dispose);
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    const book = Book(
      id: 'navigation-book',
      title: 'Navigation Book',
      author: 'Reader',
      format: 'epub',
      sourcePath: '/tmp/navigation.epub',
      chapterCount: 1,
      paragraphCount: 1,
      currentChapterId: 'navigation-chapter',
      currentParagraphIndex: 0,
      playbackOffsetMs: 1000,
      importedAt: 1,
      lastReadAt: 0,
      isRead: false,
      kind: 'book',
      rightsStatus: 'user_uploaded',
      externalMetadataJson:
          '{"raw":{"summaries":["A real publisher summary."]}}',
    );
    const chapter = Chapter(
      id: 'navigation-chapter',
      bookId: 'navigation-book',
      chapterIndex: 0,
      title: 'Open Immediately',
      textOffset: 0,
      isHidden: false,
    );
    await database.replaceBookData(
      book: book,
      chapterEntries: const [chapter],
      paragraphEntries: const [
        Paragraph(
          id: 'navigation-paragraph',
          chapterId: 'navigation-chapter',
          bookId: 'navigation-book',
          paragraphIndex: 0,
          content: 'The player opens before audio is prepared.',
        ),
      ],
    );
    await database.updateReadingProgress(
      book.id,
      chapterId: chapter.id,
      paragraphIndex: 0,
      offsetMs: 1000,
      chapterPositionMs: 1000,
    );
    manifestStore.manifest = const ChapterManifest(
      chapterId: 'navigation-chapter',
      bookId: 'navigation-book',
      providerId: 'test',
      voiceId: 'test',
      speed: 1,
      updatedAt: 1,
      segments: [
        SegmentEntry(
          paragraphId: 'navigation-paragraph',
          audioFile: 'navigation-chapter/navigation-paragraph.mp3',
          durationMs: 2000,
          state: ParagraphAudioState.ready,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          manifestStoreProvider.overrideWithValue(manifestStore),
          luminaAudioHandlerProvider.overrideWith((ref) async => audioHandler),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const AlbumScreen(book: book),
              ),
            ),
            bottomNavigationBar: const SizedBox(
              key: ValueKey('outer-navigation-chrome'),
              height: 80,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('book-detail-scroll-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('collapsing-page-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('book-chapter-navigation-chapter')),
      findsOneWidget,
    );
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.text('A real publisher summary.'), findsOneWidget);
    expect(find.textContaining('Read by'), findsNothing);
    expect(find.text('1. Open Immediately'), findsNothing);
    expect(find.text('Open Immediately'), findsOneWidget);
    final chapterProgress = tester.widget<LinearProgressIndicator>(
      find.byKey(
        const ValueKey('book-chapter-playback-progress-navigation-chapter'),
      ),
    );
    expect(chapterProgress.value, 0.5);
    expect(find.byIcon(Icons.arrow_circle_down_outlined), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppIcon && widget.icon == AppIcons.checkmarkCircle02,
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('book-detail-more-menu')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppIcon && widget.icon == AppIcons.viewOff,
      ),
      findsNothing,
    );
    await expectLater(
      find.byType(AlbumScreen),
      matchesGoldenFile('goldens/book_detail_podcast_style_430.png'),
    );
    await tester.tap(find.byKey(const ValueKey('book-detail-more-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Hidden chapters'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppIcon && widget.icon == AppIcons.viewOff,
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(20, 700));
    await tester.pumpAndSettle();
    expect(find.text('Hidden chapters'), findsNothing);

    expect(find.byTooltip('章节操作'), findsNothing);
    await tester.longPress(
      find.byKey(const ValueKey('book-chapter-navigation-chapter')),
    );
    await tester.pumpAndSettle();
    expect(find.text('清除音频'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppIcon && widget.icon == AppIcons.clean,
      ),
      findsOneWidget,
    );
    final markAsRead = find.text('Mark as read');
    expect(markAsRead, findsWidgets);
    await tester.tap(markAsRead.last);
    await tester.pumpAndSettle();
    final finishedProgress = await database.getChapterPlaybackProgress(
      'navigation-chapter',
    );
    expect(finishedProgress?.isFinished, isTrue);

    await tester.longPress(
      find.byKey(const ValueKey('book-chapter-navigation-chapter')),
    );
    await tester.pumpAndSettle();
    expect(find.text('清除音频'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final chapterTapTarget = find
        .ancestor(
          of: find.text('Open Immediately'),
          matching: find.byType(InkWell),
        )
        .first;
    tester.widget<InkWell>(chapterTapTarget).onTap!.call();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(PlayerScreen, skipOffstage: false), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('outer-navigation-chrome')).hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('player-primary-audio-action')),
      findsOneWidget,
    );
    expect(audioHandler.playCalls, 1);
    expect(audioHandler.loadedInitialPosition, const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _TestManifestStore extends ManifestStore {
  final Directory root;
  ChapterManifest? manifest;

  _TestManifestStore(this.root) : super(documentsDirectory: () async => root);

  @override
  Future<Directory> audioRoot(String bookId) async => root;

  @override
  Future<void> save(ChapterManifest value) async {
    manifest = value;
  }

  @override
  Future<ChapterManifest?> load(String bookId, String chapterId) async {
    final value = manifest;
    if (value?.bookId != bookId || value?.chapterId != chapterId) return null;
    return value;
  }
}

class _MultiManifestStore extends ManifestStore {
  final Map<String, ChapterManifest> manifests = {};

  _MultiManifestStore(Directory root)
    : super(documentsDirectory: () async => root);

  @override
  Future<ChapterManifest?> load(String bookId, String chapterId) async =>
      manifests[chapterId];
}

class _UnconfiguredCloudTtsProvider extends FishAudioApiTtsProvider {
  @override
  String get displayName => 'Cloud TTS';

  @override
  Future<bool> validate() async => false;
}

class _CountingManifestStore extends ManifestStore {
  final Set<String> loadedChapterIds = <String>{};

  _CountingManifestStore(Directory root)
    : super(documentsDirectory: () async => root);

  @override
  Future<ChapterManifest?> load(String bookId, String chapterId) async {
    loadedChapterIds.add(chapterId);
    return null;
  }
}

class _TestAudioHandler extends BaseAudioHandler implements LuminaAudioHandler {
  final _paragraphController = StreamController<String?>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _chapterPositionController = StreamController<Duration>.broadcast();
  String? _bookId;
  String? _chapterId;
  String? _paragraphId;
  Duration _position = Duration.zero;
  Duration _chapterDuration = Duration.zero;
  ChapterManifest? _manifest;
  int playCalls = 0;
  int seekCalls = 0;
  int? skippedQueueIndex;
  Duration? soughtPosition;
  Completer<void>? pendingSeek;
  bool deferSeekPositionEvent = false;
  Completer<void>? pendingLoadChapter;
  Duration? loadedInitialPosition;
  bool _disposed = false;

  bool get hasChapterPositionListener => _chapterPositionController.hasListener;

  void changeChapterDuration(Duration duration) {
    _chapterDuration = duration;
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  void startLoadedChapter({
    required String bookId,
    required String chapterId,
    required String paragraphId,
  }) {
    _bookId = bookId;
    _chapterId = chapterId;
    _paragraphId = paragraphId;
    _position = Duration.zero;
    _chapterDuration = const Duration(minutes: 22, seconds: 9);
    _paragraphController.add(paragraphId);
    _positionController.add(_position);
    _chapterPositionController.add(_position);
    mediaItem.add(
      MediaItem(
        id: paragraphId,
        title: chapterId,
        extras: {
          'bookId': bookId,
          'chapterId': chapterId,
          'paragraphId': paragraphId,
        },
      ),
    );
    playbackState.add(
      playbackState.value.copyWith(
        controls: const [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.skipToNext,
        ],
        processingState: AudioProcessingState.ready,
        playing: true,
        updatePosition: _position,
        bufferedPosition: _chapterDuration,
        speed: 1,
      ),
    );
  }

  @override
  Duration get chapterDuration => _chapterDuration;

  @override
  Duration get chapterPosition => _position;

  @override
  Stream<Duration> get chapterPositionStream =>
      _chapterPositionController.stream;

  @override
  String? get currentBookId => _bookId;

  @override
  String? get currentChapterId => _chapterId;

  @override
  ChapterManifest? get currentManifest => _manifest;

  @override
  String? get currentParagraphId => _paragraphId;

  @override
  Stream<String?> get currentParagraphIdStream => _paragraphController.stream;

  @override
  Duration get position => _position;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> loadChapter({
    required ChapterManifest manifest,
    required String audioRoot,
    String? bookTitle,
    String? chapterTitle,
    String? coverPath,
    String paragraphLabel = 'Paragraph',
    Duration initialPosition = Duration.zero,
  }) async {
    await pendingLoadChapter?.future;
    await loadChapters(
      chapters: [
        ChapterPlaybackSource(
          manifest: manifest,
          chapterTitle: chapterTitle ?? '',
          coverPath: coverPath,
        ),
      ],
      initialChapterId: manifest.chapterId,
      audioRoot: audioRoot,
      bookTitle: bookTitle,
      paragraphLabel: paragraphLabel,
      initialPosition: initialPosition,
    );
  }

  @override
  Future<void> loadChapters({
    required List<ChapterPlaybackSource> chapters,
    required String initialChapterId,
    required String audioRoot,
    String? bookTitle,
    String paragraphLabel = 'Paragraph',
    Duration initialPosition = Duration.zero,
  }) async {
    final selected = chapters.firstWhere(
      (chapter) => chapter.manifest.chapterId == initialChapterId,
    );
    _manifest = selected.manifest;
    _bookId = selected.manifest.bookId;
    _chapterId = selected.manifest.chapterId;
    _paragraphId = selected.manifest.segments.first.paragraphId;
    loadedInitialPosition = initialPosition;
    _position = initialPosition;
    _chapterDuration = Duration(
      milliseconds: selected.manifest.totalDurationMs,
    );
    mediaItem.add(
      MediaItem(
        id: _paragraphId!,
        title: selected.chapterTitle,
        extras: {
          'bookId': _bookId,
          'chapterId': _chapterId,
          'paragraphId': _paragraphId,
        },
      ),
    );
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.ready,
        playing: false,
        updatePosition: initialPosition,
        bufferedPosition: _chapterDuration,
      ),
    );
    _paragraphController.add(_paragraphId);
  }

  @override
  Future<void> play() async {
    playCalls++;
    playbackState.add(
      playbackState.value.copyWith(
        controls: const [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.skipToNext,
        ],
        processingState: AudioProcessingState.ready,
        playing: true,
        updatePosition: _position,
        bufferedPosition: _chapterDuration,
      ),
    );
  }

  @override
  Future<void> pause() async {
    playbackState.add(
      playbackState.value.copyWith(
        controls: const [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
        playing: false,
      ),
    );
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    skippedQueueIndex = index;
    final item = queue.value[index];
    final extras = item.extras!;
    _bookId = extras['bookId'] as String?;
    _chapterId = extras['chapterId'] as String?;
    _paragraphId = extras['paragraphId'] as String?;
    _manifest = null;
    _position = Duration.zero;
    mediaItem.add(item);
    _paragraphController.add(_paragraphId);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls++;
    soughtPosition = position;
    await pendingSeek?.future;
    _position = position;
    if (deferSeekPositionEvent) return;
    _positionController.add(position);
    _chapterPositionController.add(position);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _paragraphController.close();
    await _positionController.close();
    await _chapterPositionController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
