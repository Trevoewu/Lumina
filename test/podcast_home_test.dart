import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/podcasts/podcast_index_repository.dart';
import 'package:lumina/data/podcasts/podcast_repository.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/presentation/screens/library/library_screen.dart';
import 'package:lumina/presentation/screens/player/player_screen.dart';
import 'package:lumina/presentation/screens/podcast/podcast_episode_tile.dart';
import 'package:lumina/presentation/screens/podcast/podcast_show_screen.dart';
import 'package:lumina/presentation/widgets/book_list_card.dart';
import 'package:lumina/presentation/widgets/podcast_link_text.dart';
import 'package:lumina/services/lumina_audio_handler.dart';
import 'package:lumina/services/sleep_timer_service.dart';

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
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          podcastIndexRepositoryProvider.overrideWithValue(
            _FakePodcastIndexRepository(),
          ),
        ],
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
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          podcastIndexRepositoryProvider.overrideWithValue(
            _FakePodcastIndexRepository(),
          ),
        ],
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

  testWidgets('podcast library previews five episodes and shows discovery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final handler = _PreviewAudioHandler();
    final sleepTimer = SleepTimerService();
    addTearDown(database.close);
    addTearDown(handler.dispose);
    addTearDown(sleepTimer.dispose);
    await _seedScrollableHome(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          podcastIndexRepositoryProvider.overrideWithValue(
            _FakePodcastIndexRepository(),
          ),
          podcastRepositoryProvider.overrideWithValue(
            _FakePodcastRepository(database),
          ),
          luminaAudioHandlerProvider.overrideWith((ref) async => handler),
          sleepTimerServiceProvider.overrideWithValue(sleepTimer),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pages = find.byKey(const ValueKey('home-section-pages'));
    await tester.drag(pages, const Offset(-330, 0));
    await tester.pumpAndSettle();
    await tester.drag(pages, const Offset(-330, 0));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('podcast-latest-preview')),
        matching: find.byType(PodcastEpisodeTile),
      ),
      findsNWidgets(5),
    );
    expect(
      find.byKey(const ValueKey('podcast-latest-see-all')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('podcast-latest-see-all')));
    await tester.pumpAndSettle();
    final allEpisodes = tester.widget<ListView>(
      find.byKey(const ValueKey('podcast-all-episodes-list')),
    );
    expect(allEpisodes.childrenDelegate.estimatedChildCount, 8);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const PageStorageKey('podcast-library-list')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('podcast-discover-section')),
      findsOneWidget,
    );
    expect(find.text('Fresh Discovery'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('podcast-discover-follow-index-2')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('podcast-discover-card-index-2')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('podcast-discovery-detail')),
      findsOneWidget,
    );
    expect(find.text(_longPodcastDescription), findsOneWidget);
    expect(find.text('Preview Episode'), findsOneWidget);
    expect(find.textContaining('Preview available'), findsOneWidget);
    final previewTile = tester.widget<InkWell>(
      find.byKey(const ValueKey('podcast-preview-episode-preview-episode')),
    );
    expect(previewTile.onTap, isNotNull);
    expect(
      find.byKey(const ValueKey('podcast-description-toggle')),
      findsOneWidget,
    );
    expect(find.text('Follow'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('podcast-preview-episode-preview-episode')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(handler.playCalled, isTrue);
    final previewShow = await database.getPodcastShowByFeedUrl(
      'https://discover.example.com/feed.xml',
    );
    expect(previewShow?.subscribedAt, 0);
    expect(
      (await database.getPodcastShows()).map((show) => show.id),
      isNot(contains(previewShow?.id)),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('subscribed podcast shows categories and folds introduction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.upsertPodcastShow(
      const PodcastShow(
        id: 'tagged-show',
        feedUrl: 'https://example.com/tagged.xml',
        title: 'Tagged Show',
        description: _longPodcastDescription,
        categoriesJson: '["Comedy","News","Podcast"]',
        subscribedAt: 1,
        lastRefreshedAt: 1,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: const PodcastShowScreen(showId: 'tagged-show'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Comedy'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Podcast'), findsOneWidget);
    expect(find.byType(PodcastLinkText), findsOneWidget);
    expect(
      find.byKey(const ValueKey('podcast-description-toggle')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('podcast-description-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
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
          podcastRepositoryProvider.overrideWithValue(
            _FakePodcastRepository(database),
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
    expect(find.text('Follow'), findsNothing);
    await tester.tap(find.text('Flutter Example Show'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('podcast-discovery-detail')),
      findsOneWidget,
    );
    expect(find.text('Follow'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('podcast-index-search-field')),
      findsOneWidget,
    );
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
    if (query.trim().toLowerCase() == 'flutter') {
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
      PodcastIndexPodcast(
        id: 'index-2',
        title: 'Fresh Discovery',
        author: 'Discovery Author',
        feedUrl: 'https://discover.example.com/feed.xml',
        imageUrl: null,
        genres: ['Education'],
        episodeCount: 24,
      ),
    ];
  }
}

class _FakePodcastRepository extends PodcastRepository {
  _FakePodcastRepository(super.database);

  @override
  Future<ParsedPodcastFeed> preview(String input) async {
    return const ParsedPodcastFeed(
      title: 'Fresh Discovery',
      author: 'Discovery Author',
      description: _longPodcastDescription,
      imageUrl: null,
      language: 'en',
      websiteUrl: null,
      categories: ['Comedy', 'News'],
      episodes: [
        ParsedPodcastEpisode(
          guid: 'preview-episode',
          title: 'Preview Episode',
          description: 'Episode preview notes.',
          audioUrl: 'https://discover.example.com/episode.mp3',
          imageUrl: null,
          publishedAt: 1,
          durationMs: 60000,
          sourceTranscriptUrl: null,
        ),
      ],
    );
  }
}

const _longPodcastDescription =
    'A detailed podcast introduction with daily stories, thoughtful analysis, '
    'and conversations from different perspectives. This deliberately long '
    'description continues with background about the hosts, recurring topics, '
    'special guests, production notes, community updates, and several more '
    'sentences so that the introduction exceeds the collapsed line limit on '
    'a compact phone screen while remaining useful when expanded.';

class _PreviewAudioHandler extends BaseAudioHandler
    implements LuminaAudioHandler {
  final _paragraphController = StreamController<String?>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  String? _episodeId;
  bool playCalled = false;
  bool _disposed = false;

  @override
  Duration get chapterDuration => const Duration(minutes: 1);

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
  String? get currentParagraphId => _episodeId;

  @override
  String? get currentPodcastEpisodeId => _episodeId;

  @override
  Stream<String?> get currentParagraphIdStream => _paragraphController.stream;

  @override
  Duration get position => Duration.zero;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<void> loadPodcastQueue({
    required List<PodcastPlaybackSource> episodes,
    required String initialEpisodeId,
    Duration initialPosition = Duration.zero,
  }) async {
    _episodeId = initialEpisodeId;
    _paragraphController.add(initialEpisodeId);
  }

  @override
  Future<void> play() async {
    playCalled = true;
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _paragraphController.close();
    await _positionController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
