import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/book_sources/gutendex_repository.dart';
import 'package:lumina/data/book_sources/librivox_repository.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/podcasts/podcast_index_repository.dart';
import 'package:lumina/presentation/screens/search/search_history.dart';
import 'package:lumina/presentation/screens/search/search_screen.dart';

void main() {
  late AppDatabase database;
  late _FakeGutendex gutendex;
  late _FakeLibrivox librivox;
  late _FakePodcastIndex podcastIndex;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gutendex = _FakeGutendex();
    librivox = _FakeLibrivox();
    podcastIndex = _FakePodcastIndex();
  });
  tearDown(() => database.close());

  Future<void> pumpSearch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gutendexRepositoryProvider.overrideWithValue(gutendex),
          librivoxRepositoryProvider.overrideWithValue(librivox),
          podcastIndexRepositoryProvider.overrideWithValue(podcastIndex),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byKey(const ValueKey('search-field')), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('offers recent searches and authors from the library', (
    tester,
  ) async {
    await database.upsertBook(_book('one', 'Persuasion', 'Jane Austen'));
    await database.upsertBook(_book('two', 'Emma', 'Jane Austen'));
    // Stored the way Gutenberg lists authors.
    await database.upsertBook(_book('three', 'Dracula', 'Stoker, Bram'));
    await SearchHistory(database).record('whales');

    await pumpSearch(tester);

    expect(find.byKey(const ValueKey('search-recent-whales')), findsOneWidget);
    // The author with more books in the library comes first.
    final austen = find.byKey(const ValueKey('search-shortcut-Jane Austen'));
    final stoker = find.byKey(const ValueKey('search-shortcut-Bram Stoker'));
    expect(austen, findsOneWidget);
    expect(stoker, findsOneWidget);
    // Reading order: an earlier row, or further left on the same row.
    final first = tester.getTopLeft(austen);
    final second = tester.getTopLeft(stoker);
    expect(
      first.dy < second.dy || (first.dy == second.dy && first.dx < second.dx),
      isTrue,
    );

    await tester.tap(austen);
    await tester.pumpAndSettle();
    expect(gutendex.queries, ['Jane Austen']);
    expect(librivox.queries, ['Jane Austen']);
    expect(podcastIndex.queries, ['Jane Austen']);
    expect(await SearchHistory(database).load(), ['Jane Austen', 'whales']);
  });

  testWidgets('one query fills every source and a failure stays local', (
    tester,
  ) async {
    await database.upsertBook(_book('mine', 'Moby-Dick', 'Herman Melville'));
    librivox.failWith = DioException(
      requestOptions: RequestOptions(path: '/audiobooks'),
      type: DioExceptionType.receiveTimeout,
    );

    await pumpSearch(tester);
    await search(tester, 'moby');

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('search-section-library')),
        matching: find.text('Moby-Dick'),
      ),
      findsOneWidget,
    );
    // The broken catalog explains itself and offers a retry; the others
    // still show their results.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('search-section-audiobooks')),
        matching: find.text(
          'The server is taking too long to respond. Try again in a moment.',
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.text('Public Book 1'), findsOneWidget);
    expect(find.text('Whale Talk'), findsOneWidget);
    expect(find.text('Powered by Podcast Index'), findsOneWidget);

    // Three rows until the reader asks for the rest.
    expect(find.text('Public Book 4'), findsNothing);
    await tester.tap(find.text('Show all 5'));
    await tester.pumpAndSettle();
    expect(find.text('Public Book 4'), findsOneWidget);

    librivox.failWith = null;
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('search-section-audiobooks')),
        matching: find.text('Retry'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Moby Audiobook'), findsOneWidget);
    expect(await SearchHistory(database).load(), ['moby']);
  });

  testWidgets('clearing the query returns to suggestions', (tester) async {
    await pumpSearch(tester);
    await search(tester, 'moby');
    expect(find.byKey(const ValueKey('search-section-books')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('search-field')), '');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-section-books')), findsNothing);
    expect(find.byKey(const ValueKey('search-recent-moby')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-clear-recent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-recent-moby')), findsNothing);
  });

  testWidgets('the keyboard closes on scroll and on a tap outside', (
    tester,
  ) async {
    await database.upsertBook(_book('one', 'Persuasion', 'Jane Austen'));
    await pumpSearch(tester);
    final field = find.byKey(const ValueKey('search-field'));
    bool focused() => tester.widget<TextField>(field).focusNode!.hasFocus;

    await tester.tap(field);
    await tester.pump();
    expect(focused(), isTrue);

    await tester.drag(
      find.byKey(const ValueKey('search-idle')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(focused(), isFalse);

    await tester.tap(field);
    await tester.pump();
    expect(focused(), isTrue);
    await tester.tapAt(const Offset(200, 900));
    await tester.pump();
    expect(focused(), isFalse);
  });
}

Book _book(String id, String title, String author) => Book(
  id: id,
  title: title,
  author: author,
  format: 'epub',
  sourcePath: '/tmp/$id.epub',
  coverPath: null,
  chapterCount: 0,
  paragraphCount: 0,
  currentChapterId: null,
  currentParagraphIndex: 0,
  playbackOffsetMs: 0,
  voiceId: null,
  importedAt: 1,
  lastReadAt: 0,
  isRead: false,
  kind: 'book',
  rightsStatus: 'user_uploaded',
);

class _FakeGutendex extends GutendexRepository {
  final queries = <String>[];

  @override
  Future<GutendexSearchResult> search({
    required String query,
    int page = 1,
  }) async {
    queries.add(query);
    return GutendexSearchResult(
      count: 5,
      books: [
        for (var index = 1; index <= 5; index++)
          GutendexBook.fromJson({
            'id': index,
            'title': 'Public Book $index',
            'authors': [
              {'name': 'Someone'},
            ],
            'languages': ['en'],
            'copyright': false,
            'formats': {'text/plain': 'https://example.com/$index.txt'},
          }),
      ],
    );
  }
}

class _FakeLibrivox extends LibrivoxRepository {
  final queries = <String>[];
  Object? failWith;

  @override
  Future<LibrivoxSearchResult> search({
    required String query,
    int page = 1,
    int pageSize = 20,
  }) async {
    queries.add(query);
    if (failWith case final error?) throw error;
    return LibrivoxSearchResult(
      hasMore: false,
      books: [
        LibrivoxBook.fromJson({
          'id': '7',
          'title': 'Moby Audiobook',
          'language': 'English',
          'totaltimesecs': '3600',
          'authors': [
            {'first_name': 'Herman', 'last_name': 'Melville'},
          ],
          'sections': [
            {
              'id': '70',
              'section_number': '1',
              'title': 'Chapter 1',
              'listen_url': 'https://example.com/chapter.mp3',
              'playtime': '3600',
              'readers': [
                {'display_name': 'Reader'},
              ],
            },
          ],
        }),
      ],
    );
  }
}

class _FakePodcastIndex extends PodcastIndexRepository {
  final queries = <String>[];

  @override
  Future<List<PodcastIndexPodcast>> search(String query) async {
    queries.add(query);
    return const [
      PodcastIndexPodcast(
        id: 'whale',
        title: 'Whale Talk',
        author: 'Ocean Desk',
        feedUrl: 'https://example.com/whales.xml',
        imageUrl: null,
        genres: ['Science'],
        episodeCount: 3,
      ),
    ];
  }
}
