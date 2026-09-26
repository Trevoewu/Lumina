import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/library/home_overview_view.dart';
import 'package:lumina/presentation/widgets/design_system/app_icon.dart';

void main() {
  testWidgets('home overview hero and feed rows do not render progress bars or play buttons', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    // Seed a started book
    await database.upsertBook(
      const Book(
        id: 'book-1',
        title: 'Book One',
        author: 'Author One',
        format: 'epub',
        sourcePath: '/tmp/book-1.epub',
        coverPath: null,
        chapterCount: 10,
        paragraphCount: 100,
        currentChapterId: 'ch-1',
        currentParagraphIndex: 20,
        playbackOffsetMs: 15000,
        lastReadAt: 1000,
        importedAt: 500,
        isRead: false,
        kind: 'book',
        rightsStatus: 'user_uploaded',
      ),
    );

    // Seed a started podcast episode
    await database.upsertPodcastShow(
      const PodcastShow(
        id: 'show-1',
        feedUrl: 'https://example.com/feed.xml',
        title: 'Podcast One',
        description: 'Description',
        subscribedAt: 100,
        lastRefreshedAt: 200,
      ),
    );
    await database.upsertPodcastEpisode(
      const PodcastEpisode(
        id: 'episode-1',
        showId: 'show-1',
        guid: 'guid-1',
        title: 'Episode One',
        description: 'Episode Description',
        audioUrl: 'https://example.com/ep1.mp3',
        publishedAt: 300,
        durationMs: 60000,
        playbackPositionMs: 30000,
        lastPlayedAt: 900,
        isPlayed: false,
        transcriptProgressMs: 0,
        transcriptStatus: 'none',
      ),
    );

    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: HomeOverviewView(
              reloadToken: 1,
              scrollController: scrollController,
              onImportBook: () {},
              onAddPodcast: () {},
              onBookLongPress: (_) {},
              onOpenBook: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify hero card is present
    expect(find.byKey(const ValueKey('home-overview-hero')), findsOneWidget);

    // Verify no LinearProgressIndicator anywhere in the overview
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // Verify no hero play button or play icons
    expect(find.byKey(const ValueKey('home-overview-hero-play')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppIcon && widget.icon == AppIcons.play,
      ),
      findsNothing,
    );

    // Verify feed rows exist
    expect(find.byKey(const ValueKey('home-overview-row-0')), findsOneWidget);
  });
}
