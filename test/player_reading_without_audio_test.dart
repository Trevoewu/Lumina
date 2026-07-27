import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/presentation/screens/album/album_screen.dart';
import 'package:lumina/presentation/screens/player/player_screen.dart';
import 'package:lumina/presentation/widgets/mini_player.dart';
import 'package:lumina/services/lumina_audio_handler.dart';
import 'package:lumina/services/manifest_store.dart';
import 'package:lumina/services/sleep_timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(find.byKey(const ValueKey('ai-summary-generate')), findsOneWidget);
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
      expect(
        find.text('This text is readable before any audio is cached.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsNothing);
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
        find.byKey(const ValueKey('book-player-scroll-view')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('book-information-card')), findsNothing);
      expect(find.byKey(const ValueKey('ai-summary-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('book-text-card')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('ai-summary-card'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('book-text-card'))).dy,
        ),
      );
      expect(find.text('Synchronized text'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      final background = tester.widget<Container>(
        find.byKey(const ValueKey('player-immersive-background')),
      );
      final backgroundDecoration = background.decoration! as BoxDecoration;
      final backgroundGradient =
          backgroundDecoration.gradient! as LinearGradient;
      expect(
        backgroundGradient.colors.every(
          (color) => color.computeLuminance() < 0.2,
        ),
        isTrue,
      );
      final primaryButtonMaterial = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('player-primary-audio-action')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(primaryButtonMaterial.color, Colors.white);

      await expectLater(
        find.byType(PlayerScreen),
        matchesGoldenFile('goldens/player_spotify_dark_390.png'),
      );

      await tester.tap(find.byIcon(Icons.timer_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Sleep timer'), findsOneWidget);
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
      expect(find.byKey(const ValueKey('book-text-card')), findsOneWidget);
      expect(find.text('Synchronized text'), findsOneWidget);
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
      final compactArtwork = tester.getSize(
        find.byKey(const ValueKey('player-artwork')),
      );
      expect(compactArtwork, const Size.square(320));

      await expectLater(
        find.byType(PlayerScreen),
        matchesGoldenFile('goldens/player_spotify_playing_390.png'),
      );

      await tester.drag(
        find.byKey(const ValueKey('book-player-scroll-view')),
        const Offset(0, -520),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ai-summary-card')).hitTestable(),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('book-text-card')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find
            .text('The current sentence stays bright while it is spoken.')
            .hitTestable(),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const ValueKey('book-player-scroll-view')),
        const Offset(0, 700),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('player-primary-audio-action')),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
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

  test('primary audio action remains play or pause while streaming', () {
    expect(
      resolvePlayerPrimaryAudioAction(playing: false, playbackRequested: false),
      PlayerPrimaryAudioAction.play,
    );
    expect(
      resolvePlayerPrimaryAudioAction(playing: false, playbackRequested: true),
      PlayerPrimaryAudioAction.pause,
    );
    expect(
      resolvePlayerPrimaryAudioAction(playing: true, playbackRequested: false),
      PlayerPrimaryAudioAction.pause,
    );
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
    expect(find.byIcon(Icons.download_done_rounded), findsNothing);
    expect(find.byKey(const ValueKey('book-detail-more-menu')), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    await expectLater(
      find.byType(AlbumScreen),
      matchesGoldenFile('goldens/book_detail_podcast_style_430.png'),
    );
    await tester.tap(find.byKey(const ValueKey('book-detail-more-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Hidden chapters'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tapAt(const Offset(20, 700));
    await tester.pumpAndSettle();
    expect(find.text('Hidden chapters'), findsNothing);

    expect(find.byTooltip('章节操作'), findsNothing);
    await tester.longPress(
      find.byKey(const ValueKey('book-chapter-navigation-chapter')),
    );
    await tester.pumpAndSettle();
    expect(find.text('清除音频'), findsOneWidget);
    expect(find.byIcon(Icons.cleaning_services_outlined), findsOneWidget);
    expect(find.text('Mark as finished'), findsOneWidget);
    await tester.tap(find.text('Mark as finished'));
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
  Future<ChapterManifest?> load(String bookId, String chapterId) async {
    final value = manifest;
    if (value?.bookId != bookId || value?.chapterId != chapterId) return null;
    return value;
  }
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
  Duration? loadedInitialPosition;
  bool _disposed = false;

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
