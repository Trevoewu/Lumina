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
import 'package:lumina/services/lumina_audio_handler.dart';
import 'package:lumina/services/manifest_store.dart';
import 'package:lumina/services/sleep_timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(find.text('Text preview'), findsOneWidget);
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
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('lyrics-card')), findsNothing);
      expect(find.text('Live text'), findsOneWidget);
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
      expect(compactArtwork, const Size.square(80));
      final viewportHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final controlsBottom = tester
          .getBottomRight(
            find.byKey(const ValueKey('player-playback-controls')),
          )
          .dy;
      expect(viewportHeight - controlsBottom, inInclusiveRange(12, 20));

      await expectLater(
        find.byType(PlayerScreen),
        matchesGoldenFile('goldens/player_spotify_playing_390.png'),
      );

      await tester.tap(
        find.byKey(const ValueKey('player-primary-audio-action')),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(
        find.byKey(const ValueKey('player-live-lyrics-stage')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('player-artwork'))),
        const Size.square(80),
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
    expect(audioHandler.playCalls, 1);

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
  }) async {
    final selected = chapters.firstWhere(
      (chapter) => chapter.manifest.chapterId == initialChapterId,
    );
    _manifest = selected.manifest;
    _bookId = selected.manifest.bookId;
    _chapterId = selected.manifest.chapterId;
    _paragraphId = selected.manifest.segments.first.paragraphId;
    _position = Duration.zero;
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
        updatePosition: Duration.zero,
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
