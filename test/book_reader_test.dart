import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lumina/core/appearance.dart';
import 'package:lumina/core/app_preferences.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/presentation/screens/reader/book_reader_screen.dart';
import 'package:lumina/presentation/screens/reader/widgets/reader_audio_bar.dart';
import 'package:lumina/presentation/screens/reader/widgets/reader_bottom_bar.dart';
import 'package:lumina/presentation/screens/reader/widgets/reader_paragraph_view.dart';
import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:lumina/presentation/widgets/design_system/macos_toolbar_providers.dart';
import 'package:lumina/services/lumina_audio_handler.dart';

class _FakeLuminaAudioHandler extends BaseAudioHandler
    implements LuminaAudioHandler {
  final _positionController = StreamController<Duration>.broadcast();
  final _playbackStateController = StreamController<PlaybackState>.broadcast();
  bool _disposed = false;

  _FakeLuminaAudioHandler() {
    playbackState.add(
      PlaybackState(playing: false, processingState: AudioProcessingState.idle),
    );
  }

  @override
  Duration get chapterDuration => Duration.zero;

  @override
  Duration get chapterPosition => Duration.zero;

  @override
  Stream<Duration> get chapterPositionStream => _positionController.stream;

  @override
  String? get currentBookId => null;

  @override
  String? get currentChapterId => null;

  @override
  ChapterManifest? get currentManifest => null;

  @override
  String? get currentParagraphId => null;

  @override
  int? get currentParagraphIndex => null;

  @override
  Future<void> play() async {
    playbackState.add(
      PlaybackState(playing: true, processingState: AudioProcessingState.ready),
    );
  }

  @override
  Future<void> pause() async {
    playbackState.add(
      PlaybackState(
        playing: false,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _positionController.close();
    await _playbackStateController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late _FakeLuminaAudioHandler fakeAudioHandler;

  final testBook = Book(
    id: 'test_book_1',
    title: 'The Great Adventure',
    author: 'Arthur Conan Doyle',
    language: 'english',
    format: 'epub',
    sourcePath: '/path/to/test.epub',
    chapterCount: 2,
    paragraphCount: 4,
    currentChapterId: 'ch_1',
    currentParagraphIndex: 0,
    playbackOffsetMs: 0,
    importedAt: 1000,
    lastReadAt: 1000,
    isRead: false,
    kind: 'book',
    rightsStatus: 'public_domain',
  );

  final testChapters = [
    const Chapter(
      id: 'ch_1',
      bookId: 'test_book_1',
      chapterIndex: 0,
      title: 'Chapter 1: The Beginning',
      textOffset: 0,
      isHidden: false,
    ),
    const Chapter(
      id: 'ch_2',
      bookId: 'test_book_1',
      chapterIndex: 1,
      title: 'Chapter 2: The Journey',
      textOffset: 100,
      isHidden: false,
    ),
  ];

  final testParagraphsCh1 = [
    const Paragraph(
      id: 'p_1_1',
      chapterId: 'ch_1',
      bookId: 'test_book_1',
      paragraphIndex: 0,
      content: 'It was the best of times, it was the worst of times.',
    ),
    const Paragraph(
      id: 'p_1_2',
      chapterId: 'ch_1',
      bookId: 'test_book_1',
      paragraphIndex: 1,
      content: 'We had everything before us, we had nothing before us.',
    ),
  ];

  final testParagraphsCh2 = [
    const Paragraph(
      id: 'p_2_1',
      chapterId: 'ch_2',
      bookId: 'test_book_1',
      paragraphIndex: 0,
      content: 'The journey began on a crisp autumn morning.',
    ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeAudioHandler = _FakeLuminaAudioHandler();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.replaceBookData(
      book: testBook,
      chapterEntries: testChapters,
      paragraphEntries: [...testParagraphsCh1, ...testParagraphsCh2],
    );
  });

  tearDown(() async {
    await fakeAudioHandler.dispose();
    await database.close();
  });

  testWidgets(
    'BookReaderScreen renders chapter title, paragraphs, and nav bars',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            luminaAudioHandlerProvider.overrideWith(
              (ref) async => fakeAudioHandler,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: BookReaderScreen(
              book: testBook,
              initialChapter: testChapters.first,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Verify Chapter 1 Title is displayed
      expect(find.text('Chapter 1: The Beginning'), findsWidgets);
      expect(
        find.text('It was the best of times, it was the worst of times.'),
        findsOneWidget,
      );
      expect(
        find.text('We had everything before us, we had nothing before us.'),
        findsOneWidget,
      );

      // Verify Top Action Icons (Aa format_size, menu_book TOC, player headphones)
      expect(find.byTooltip('Typography'), findsOneWidget);
      expect(find.byTooltip('Table of Contents'), findsOneWidget);
      expect(find.byTooltip('Player'), findsOneWidget);

      // Verify Next Chapter button exists at bottom
      expect(find.text('Next Chapter'), findsOneWidget);
    },
  );

  testWidgets('ReaderTocSheet displays chapters and allows navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          luminaAudioHandlerProvider.overrideWith(
            (ref) async => fakeAudioHandler,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: BookReaderScreen(
            book: testBook,
            initialChapter: testChapters.first,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open TOC sheet
    await tester.tap(find.byTooltip('Table of Contents'));
    await tester.pumpAndSettle();

    // Check sheet content
    expect(find.text('Table of Contents'), findsOneWidget);
    expect(find.text('Chapter 1: The Beginning'), findsWidgets);
    expect(find.text('Chapter 2: The Journey'), findsOneWidget);

    // Tap Chapter 2
    await tester.tap(find.text('Chapter 2: The Journey'));
    await tester.pumpAndSettle();

    // Should now be on Chapter 2
    expect(find.text('Chapter 2: The Journey'), findsWidgets);
    expect(
      find.text('The journey began on a crisp autumn morning.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'ReaderAppearanceSheet opens and allows changing font and scale',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          luminaAudioHandlerProvider.overrideWith(
            (ref) async => fakeAudioHandler,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: BookReaderScreen(
              book: testBook,
              initialChapter: testChapters.first,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap typography settings button
      await tester.tap(find.byTooltip('Typography'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reader-appearance-panel')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reader-font-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Literata'), findsOneWidget);
      expect(find.text('Menlo'), findsOneWidget);

      // Tap Literata
      await tester.tap(
        find.ancestor(
          of: find.text('Literata'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuEntry),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(appearanceControllerProvider).fontId, 'serif');
      expect(find.byKey(const Key('reader-margin-slider')), findsOneWidget);
      expect(find.byKey(const Key('reader-line-slider')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reader-indent-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('Two characters'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuEntry),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(appearanceControllerProvider).readerIndent, 2);
      await tester.tap(find.byKey(const Key('reader-flow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('Scroll'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuEntry),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(appearanceControllerProvider).readerScrolled,
        isTrue,
      );

      tester
          .widget<Slider>(find.byKey(const Key('reader-font-slider')))
          .onChanged!(1.05);
      await tester.pumpAndSettle();

      expect(
        container.read(appearanceControllerProvider).fontScale,
        closeTo(1.05, 0.01),
      );
    },
  );

  testWidgets('ReaderParagraphView highlights when playing', (tester) async {
    const p = Paragraph(
      id: 'p_test',
      chapterId: 'ch_1',
      bookId: 'test_book_1',
      paragraphIndex: 0,
      content: 'Highlight me when playing.',
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReaderParagraphView(paragraph: p, isPlaying: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reading aloud'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppIcon && widget.icon == AppIcons.audioWave01,
      ),
      findsOneWidget,
    );
  });

  for (final desktop in [false, true]) {
    testWidgets('EPUB controls overlay a stable page (desktop: $desktop)', (
      tester,
    ) async {
      tester.view.physicalSize = desktop
          ? const Size(1000, 800)
          : const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('epub_test_');
      final epubFile = File('${tempDir.path}/sample.epub');
      epubFile.writeAsBytesSync([0, 1, 2, 3]);

      final fileBook = testBook.copyWith(sourcePath: epubFile.path);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            luminaAudioHandlerProvider.overrideWith(
              (ref) async => fakeAudioHandler,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Builder(
              builder: (context) {
                final screen = BookReaderScreen(
                  book: fileBook,
                  initialChapter: testChapters.first,
                  epubReaderBuilder: (context, file) =>
                      const SizedBox(key: Key('mock_epub_view')),
                );
                return desktop
                    ? MacosPersistentToolbarScope(child: screen)
                    : screen;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('mock_epub_view')), findsOneWidget);

      final reader = find.byKey(const Key('mock_epub_view'));
      expect(tester.getRect(reader).top, desktop ? 0 : 55);
      final pageRect = tester.getRect(reader);
      await tester.tap(find.byTooltip('Progress'));
      await tester.pumpAndSettle();
      expect(tester.getRect(reader), pageRect);
      expect(
        tester.getRect(reader).bottom,
        greaterThan(tester.getRect(find.byType(Slider)).top),
      );
      await tester.tap(find.byTooltip('Typography'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader-appearance-panel')), findsOneWidget);
      expect(tester.getRect(reader), pageRect);
      await tester.tap(find.byTooltip('Typography'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader-appearance-panel')), findsNothing);
      expect(tester.getRect(reader), pageRect);
      expect(tester.takeException(), isNull);

      tempDir.deleteSync(recursive: true);
    });
  }

  testWidgets(
    'BookReaderScreen hides ReaderAudioBar when hasPersistentToolbar is true and sets toolbar middle',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          luminaAudioHandlerProvider.overrideWith(
            (ref) async => fakeAudioHandler,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: MacosPersistentToolbarScope(
              child: BookReaderScreen(
                book: testBook,
                initialChapter: testChapters.first,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // On desktop with persistent toolbar, ReaderAudioBar should NOT be rendered (preventing duplicate miniplayer)
      expect(find.byType(ReaderAudioBar), findsNothing);

      // Verify macosToolbarMiddleProvider has the chapter switcher
      expect(container.read(macosToolbarMiddleProvider), isNotNull);
    },
  );

  testWidgets(
    'BookReaderScreen supports three-zone tap to toggle menus and interact with ReaderBottomBar',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            luminaAudioHandlerProvider.overrideWith(
              (ref) async => fakeAudioHandler,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: BookReaderScreen(
              book: testBook,
              initialChapter: testChapters.first,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Initially, bars are visible
      expect(find.byType(ReaderBottomBar), findsOneWidget);
      expect(find.text('AI'), findsNothing);
      expect(find.text('译'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is HugeIcon && w.icon == HugeIcons.strokeRoundedHeadphones,
        ),
        findsOneWidget,
      );

      // Tap middle zone (x = 400, y = 500) to toggle bars off
      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();

      // Check that ReaderBottomBar receives isVisible: false
      final bottomBarFinder = find.byType(ReaderBottomBar);
      expect(bottomBarFinder, findsOneWidget);
      final bottomBar = tester.widget<ReaderBottomBar>(bottomBarFinder);
      expect(bottomBar.isVisible, isFalse);

      // Minimal page indicator is present at bottom-right
      expect(find.text('1 / 1'), findsOneWidget);

      // Tap middle zone again to show bars
      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();

      final bottomBarShown = tester.widget<ReaderBottomBar>(bottomBarFinder);
      expect(bottomBarShown.isVisible, isTrue);

      // Tap progress compass icon in bottom bar to open slider scrubber
      await tester.tap(find.byTooltip('Progress'));
      await tester.pumpAndSettle();

      // Progress percentage text should now be visible
      expect(find.text('0.0%'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BookReaderScreen)),
      );
      await tester.tap(find.byTooltip('Theme'));
      await tester.pumpAndSettle();
      expect(
        container.read(appPreferencesProvider).theme,
        AppThemePreference.dark,
      );
    },
  );
}
