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
import 'package:lumina/services/lumina_audio_handler.dart';
import 'package:lumina/services/manifest_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'an uncached chapter remains readable and offers streaming playback',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final temp = Directory.systemTemp.createTempSync('lumina_reader_test_');
      final manifestStore = ManifestStore(documentsDirectory: () async => temp);
      final audioHandler = _TestAudioHandler();
      addTearDown(database.close);
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
        paragraphCount: 1,
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
            id: 'readable-paragraph',
            chapterId: 'readable-chapter',
            bookId: 'readable-book',
            paragraphIndex: 0,
            content: 'This text is readable before any audio is cached.',
          ),
        ],
      );
      expect(await database.getParagraphs(chapter.id), hasLength(1));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            manifestStoreProvider.overrideWithValue(manifestStore),
            luminaAudioHandlerProvider.overrideWith(
              (ref) async => audioHandler,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme(),
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

  testWidgets('opening a chapter covers the outer app navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final temp = Directory.systemTemp.createTempSync('lumina_nav_test_');
    final manifestStore = ManifestStore(documentsDirectory: () async => temp);
    final audioHandler = _TestAudioHandler();
    addTearDown(database.close);
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
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 0,
      kind: 'book',
      rightsStatus: 'user_uploaded',
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

    expect(find.byIcon(Icons.arrow_circle_down_outlined), findsNothing);
    expect(find.byIcon(Icons.download_done_rounded), findsNothing);
    await tester.tap(find.byTooltip('章节操作'));
    await tester.pumpAndSettle();
    expect(find.text('缓存音频'), findsOneWidget);
    expect(find.byIcon(Icons.download_for_offline_outlined), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final chapterTapTarget = find
        .ancestor(
          of: find.text('1. Open Immediately'),
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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _TestAudioHandler extends BaseAudioHandler implements LuminaAudioHandler {
  @override
  Duration get chapterDuration => Duration.zero;

  @override
  Duration get chapterPosition => Duration.zero;

  @override
  Stream<Duration> get chapterPositionStream => const Stream.empty();

  @override
  String? get currentBookId => null;

  @override
  String? get currentChapterId => null;

  @override
  ChapterManifest? get currentManifest => null;

  @override
  String? get currentParagraphId => null;

  @override
  Stream<String?> get currentParagraphIdStream => const Stream.empty();

  @override
  Duration get position => Duration.zero;

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
