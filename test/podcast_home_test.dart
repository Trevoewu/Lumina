import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/podcasts/podcast_index_repository.dart';
import 'package:lumina/presentation/screens/library/library_screen.dart';
import 'package:lumina/presentation/widgets/book_list_card.dart';

void main() {
  testWidgets('home header stays fixed through full all-page scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedScrollableHome(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(top: 44)),
            child: child!,
          ),
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('home-fixed-header'));
    final allList = find.descendant(
      of: find.byKey(const PageStorageKey('home-overview-list')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(header, findsOneWidget);
    expect(allList, findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
    expect(find.byType(NestedScrollView), findsNothing);
    expect(find.byKey(const ValueKey('collapsing-page-title')), findsNothing);
    expect(find.byType(BookListCard), findsNWidgets(5));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-section-selector')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              (widget.axisDirection == AxisDirection.left ||
                  widget.axisDirection == AxisDirection.right),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-section-pages')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              (widget.axisDirection == AxisDirection.left ||
                  widget.axisDirection == AxisDirection.right),
        ),
      ),
      findsOneWidget,
    );
    final fixedTop = tester.getTopLeft(header).dy;
    expect(fixedTop, 44);

    final scrollable = tester.state<ScrollableState>(allList);
    for (var i = 0; i < 4; i++) {
      await tester.fling(allList, const Offset(0, -600), 2400);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(header).dy, fixedTop);
      if (scrollable.position.pixels >=
          scrollable.position.maxScrollExtent - 0.5) {
        break;
      }
    }
    expect(
      scrollable.position.pixels,
      closeTo(scrollable.position.maxScrollExtent, 0.5),
    );

    for (var i = 0; i < 4; i++) {
      await tester.fling(allList, const Offset(0, 600), 2400);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(header).dy, fixedTop);
      if (scrollable.position.pixels <=
          scrollable.position.minScrollExtent + 0.5) {
        break;
      }
    }
    expect(
      scrollable.position.pixels,
      closeTo(scrollable.position.minScrollExtent, 0.5),
    );
    await tester.tap(find.byKey(const ValueKey('home-section-books')));
    await tester.pumpAndSettle();
    expect(find.byType(BookListCard), findsNWidgets(5));
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home swipes in order from all to books to podcast', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    bool isSelected(String section) => tester
        .widget<ChoiceChip>(find.byKey(ValueKey('home-section-$section')))
        .selected;

    final pages = find.byKey(const ValueKey('home-section-pages'));
    expect(pages, findsOneWidget);
    expect(isSelected('all'), isTrue);

    await tester.drag(pages, const Offset(-330, 0));
    await tester.pumpAndSettle();
    expect(isSelected('books'), isTrue);

    await tester.drag(pages, const Offset(-330, 0));
    await tester.pumpAndSettle();
    expect(isSelected('podcasts'), isTrue);
    expect(find.text('Add your first podcast'), findsOneWidget);

    await tester.drag(pages, const Offset(330, 0));
    await tester.pumpAndSettle();
    expect(isSelected('books'), isTrue);
  });

  testWidgets('home switches to podcast without adding a bottom tab', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          podcastIndexRepositoryProvider.overrideWithValue(
            _FakePodcastIndexRepository(),
          ),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-section-selector')), findsOneWidget);
    expect(find.text('Podcast'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-section-podcasts')));
    await tester.pumpAndSettle();

    expect(find.text('Add your first podcast'), findsOneWidget);
    expect(find.text('Search Podcast Index'), findsOneWidget);
    expect(find.text('Paste RSS feed URL'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('empty-podcast-index-search')));
    await tester.pumpAndSettle();
    expect(find.text('Discover podcasts'), findsOneWidget);
    expect(find.text('Powered by Podcast Index'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('podcast-index-search-field')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('podcast-index-search-field')),
      'flutter',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Flutter Example Show'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste RSS feed URL'));
    await tester.pumpAndSettle();
    expect(find.text('RSS URL'), findsOneWidget);
  });
}

Future<void> _seedScrollableHome(AppDatabase database) async {
  for (var index = 0; index < 5; index++) {
    await database.upsertBook(
      Book(
        id: 'book-$index',
        title: 'Book $index',
        author: 'Author',
        format: 'epub',
        sourcePath: '/tmp/book-$index.epub',
        coverPath: null,
        chapterCount: 0,
        paragraphCount: 0,
        currentChapterId: null,
        currentParagraphIndex: 0,
        playbackOffsetMs: 0,
        voiceId: null,
        importedAt: index + 1,
        lastReadAt: index + 1,
        kind: 'book',
        rightsStatus: 'user_uploaded',
      ),
    );
  }
  await database.upsertPodcastShow(
    const PodcastShow(
      id: 'scroll-show',
      feedUrl: 'https://example.com/feed.xml',
      title: 'Scrollable Show',
      description: '',
      subscribedAt: 1,
      lastRefreshedAt: 1,
    ),
  );
  for (var index = 0; index < 8; index++) {
    await database.upsertPodcastEpisode(
      PodcastEpisode(
        id: 'scroll-episode-$index',
        showId: 'scroll-show',
        guid: 'scroll-guid-$index',
        title: 'Scrollable Episode $index',
        description: '',
        audioUrl: 'https://example.com/$index.mp3',
        publishedAt: index + 1,
        durationMs: 600000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptStatus: 'none',
      ),
    );
  }
}

class _FakePodcastIndexRepository extends PodcastIndexRepository {
  @override
  Future<List<PodcastIndexPodcast>> search(String query) async {
    return const [
      PodcastIndexPodcast(
        id: 'index-1',
        title: 'Flutter Example Show',
        author: 'Example Author',
        feedUrl: 'https://example.com/feed.xml',
        imageUrl: null,
        genres: ['Technology'],
        episodeCount: 10,
      ),
    ];
  }
}
