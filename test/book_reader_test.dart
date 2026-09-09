import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumina/core/appearance.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/presentation/screens/reader/book_reader_screen.dart';
import 'package:lumina/presentation/screens/reader/widgets/reader_paragraph_view.dart';
import 'package:lumina/services/lumina_audio_handler.dart';

class _FakeLuminaAudioHandler extends BaseAudioHandler implements LuminaAudioHandler {
  final _positionController = StreamController<Duration>.broadcast();
  final _playbackStateController = StreamController<PlaybackState>.broadcast();
  bool _disposed = false;

  _FakeLuminaAudioHandler() {
    playbackState.add(
      PlaybackState(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
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
      PlaybackState(
        playing: true,
        processingState: AudioProcessingState.ready,
      ),
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

  testWidgets('BookReaderScreen renders chapter title, paragraphs, and nav bars', (
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
          luminaAudioHandlerProvider.overrideWith((ref) async => fakeAudioHandler),
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
    expect(find.byIcon(Icons.format_size_rounded), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.headphones_outlined), findsOneWidget);

    // Verify Next Chapter button exists at bottom
    expect(find.text('Next Chapter'), findsOneWidget);
  });

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
          luminaAudioHandlerProvider.overrideWith((ref) async => fakeAudioHandler),
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
    await tester.tap(find.byIcon(Icons.menu_book_rounded));
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

  testWidgets('ReaderAppearanceSheet opens and allows changing font and scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        luminaAudioHandlerProvider.overrideWith((ref) async => fakeAudioHandler),
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
    await tester.tap(find.byIcon(Icons.format_size_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Typography & Theme'), findsOneWidget);
    expect(find.text('Georgia'), findsOneWidget);
    expect(find.text('Menlo'), findsOneWidget);

    // Tap Georgia
    await tester.tap(find.text('Georgia'));
    await tester.pumpAndSettle();

    expect(container.read(appearanceControllerProvider).fontId, 'serif');

    // Tap add font size (+)
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(container.read(appearanceControllerProvider).fontScale, closeTo(1.05, 0.01));
  });

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
            body: ReaderParagraphView(
              paragraph: p,
              isPlaying: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reading aloud'), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
  });
}
