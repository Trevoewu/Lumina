import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/podcast/podcast_episode_tile.dart';
import 'package:lumina/presentation/screens/podcast/podcast_show_screen.dart';

void main() {
  testWidgets('podcast show screen sorts episodes by newest or oldest', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database.upsertPodcastShow(
      const PodcastShow(
        id: 'show-sort-test',
        title: 'Sort Test Show',
        feedUrl: 'https://example.com/feed.xml',
        description: 'Testing episode sorting',
        subscribedAt: 100,
        lastRefreshedAt: 100,
      ),
    );

    // Insert 3 episodes with different publishedAt timestamps
    await database.upsertPodcastEpisode(
      const PodcastEpisode(
        id: 'ep-1',
        showId: 'show-sort-test',
        guid: 'guid-1',
        title: 'Episode 1 (Oldest)',
        description: '',
        audioUrl: 'https://example.com/ep1.mp3',
        publishedAt: 1000,
        durationMs: 60000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptProgressMs: 0,
        transcriptStatus: 'none',
      ),
    );
    await database.upsertPodcastEpisode(
      const PodcastEpisode(
        id: 'ep-2',
        showId: 'show-sort-test',
        guid: 'guid-2',
        title: 'Episode 2 (Middle)',
        description: '',
        audioUrl: 'https://example.com/ep2.mp3',
        publishedAt: 2000,
        durationMs: 60000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptProgressMs: 0,
        transcriptStatus: 'none',
      ),
    );
    await database.upsertPodcastEpisode(
      const PodcastEpisode(
        id: 'ep-3',
        showId: 'show-sort-test',
        guid: 'guid-3',
        title: 'Episode 3 (Newest)',
        description: '',
        audioUrl: 'https://example.com/ep3.mp3',
        publishedAt: 3000,
        durationMs: 60000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptProgressMs: 0,
        transcriptStatus: 'none',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.darkTheme(),
          home: const PodcastShowScreen(showId: 'show-sort-test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify sort button is present with default '从新到旧'
    final sortButton = find.byKey(
      const ValueKey('podcast-episodes-sort-button'),
    );
    expect(sortButton, findsOneWidget);
    expect(find.text('从新到旧'), findsOneWidget);

    // Check initial order: newest first (ep-3, ep-2, ep-1)
    List<PodcastEpisodeTile> tiles = tester
        .widgetList<PodcastEpisodeTile>(find.byType(PodcastEpisodeTile))
        .toList();
    expect(tiles.map((t) => t.episode.id).toList(), ['ep-3', 'ep-2', 'ep-1']);

    // Tap sort button to open menu
    await tester.tap(sortButton);
    await tester.pumpAndSettle();

    // Select '从旧到新'
    final oldestOption = find.byKey(const ValueKey('sort-order-oldestFirst'));
    expect(oldestOption, findsOneWidget);
    await tester.tap(oldestOption);
    await tester.pumpAndSettle();

    // Check updated button label and order: oldest first (ep-1, ep-2, ep-3)
    expect(find.text('从旧到新'), findsOneWidget);
    tiles = tester
        .widgetList<PodcastEpisodeTile>(find.byType(PodcastEpisodeTile))
        .toList();
    expect(tiles.map((t) => t.episode.id).toList(), ['ep-1', 'ep-2', 'ep-3']);

    // Switch back to newest first
    await tester.tap(sortButton);
    await tester.pumpAndSettle();
    final newestOption = find.byKey(const ValueKey('sort-order-newestFirst'));
    expect(newestOption, findsOneWidget);
    await tester.tap(newestOption);
    await tester.pumpAndSettle();

    // Verify restored order
    expect(find.text('从新到旧'), findsOneWidget);
    tiles = tester
        .widgetList<PodcastEpisodeTile>(find.byType(PodcastEpisodeTile))
        .toList();
    expect(tiles.map((t) => t.episode.id).toList(), ['ep-3', 'ep-2', 'ep-1']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
