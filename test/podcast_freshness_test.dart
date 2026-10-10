import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/podcasts/podcast_repository.dart';
import 'package:lumina/presentation/screens/podcast/podcast_episode_tile.dart';
import 'package:lumina/presentation/screens/podcast/podcast_show_screen.dart';

const _now = 1_800_000_000_000;

PodcastShow _show(String id, {required int lastRefreshedAt}) => PodcastShow(
  id: id,
  feedUrl: 'https://example.com/$id.xml',
  title: 'Show $id',
  description: '',
  subscribedAt: 1,
  lastRefreshedAt: lastRefreshedAt,
  // Known genres, so the page does not refresh to fill them in.
  categoriesJson: '[]',
);

PodcastEpisode _episode(int index) => PodcastEpisode(
  id: 'episode-$index',
  showId: 'show',
  guid: 'guid-$index',
  title: 'Episode $index',
  description: '',
  audioUrl: 'https://example.com/$index.mp3',
  publishedAt: _now - (100 - index) * 3600000,
  durationMs: 60000,
  playbackPositionMs: 0,
  lastPlayedAt: 0,
  isPlayed: false,
  transcriptStatus: 'none',
  transcriptProgressMs: 0,
);

/// Refreshes without the network, and fails for one chosen show.
class _RecordingRepository extends PodcastRepository {
  _RecordingRepository(super.database, {this.failing});

  final String? failing;
  final refreshed = <String>[];

  @override
  Future<PodcastImportResult> refresh(PodcastShow show) async {
    refreshed.add(show.id);
    if (show.id == failing) throw StateError('feed unavailable');
    return PodcastImportResult(show: show, importedEpisodes: 0);
  }
}

void main() {
  test('a feed counts as stale after the auto-refresh age', () {
    final now = DateTime.fromMillisecondsSinceEpoch(_now);
    final fresh = _show('a', lastRefreshedAt: _now - 10 * 60000);
    final stale = _show(
      'b',
      lastRefreshedAt: _now - podcastAutoRefreshAge.inMilliseconds,
    );
    expect(isPodcastShowStale(fresh, now: now), isFalse);
    expect(isPodcastShowStale(stale, now: now), isTrue);
  });

  test('refreshStale skips fresh shows and gets past a failing feed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.upsertPodcastShow(_show('fresh', lastRefreshedAt: _now));
    await database.upsertPodcastShow(_show('broken', lastRefreshedAt: 1));
    await database.upsertPodcastShow(_show('stale', lastRefreshedAt: 1));
    final repository = _RecordingRepository(database, failing: 'broken');

    final count = await repository.refreshStale(
      now: DateTime.fromMillisecondsSinceEpoch(_now),
    );

    expect(repository.refreshed, unorderedEquals(['broken', 'stale']));
    expect(count, 1);
  });

  test('episodes are read a page at a time in either order', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.upsertPodcastShow(_show('show', lastRefreshedAt: _now));
    for (var index = 0; index < 5; index++) {
      await database.upsertPodcastEpisode(_episode(index));
    }

    final newest = await database.watchPodcastEpisodes('show', limit: 2).first;
    final oldest = await database
        .watchPodcastEpisodes('show', limit: 2, newestFirst: false)
        .first;

    expect([for (final e in newest) e.id], ['episode-4', 'episode-3']);
    expect([for (final e in oldest) e.id], ['episode-0', 'episode-1']);
  });

  testWidgets('a show loads its episodes page by page as it scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(() async {
      // Fresh, so opening the page does not try to refresh it.
      await database.upsertPodcastShow(
        _show('show', lastRefreshedAt: DateTime.now().millisecondsSinceEpoch),
      );
      for (var index = 0; index < 45; index++) {
        await database.upsertPodcastEpisode(_episode(index));
      }
    });
    final repository = _RecordingRepository(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          podcastRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const PodcastShowScreen(showId: 'show'),
        ),
      ),
    );
    Future<void> settle() async {
      for (var round = 0; round < 5; round++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    await settle();
    expect(find.text('Episode 44'), findsOneWidget);
    expect(repository.refreshed, isEmpty);
    // Only the tiles on screen are built, not all 45.
    expect(
      tester.widgetList(find.byType(PodcastEpisodeTile)).length,
      lessThan(30),
    );

    // The oldest episode is past the first page; scrolling reaches it.
    final list = find.byType(Scrollable).first;
    for (
      var step = 0;
      step < 40 && find.text('Episode 0').evaluate().isEmpty;
      step++
    ) {
      await tester.drag(list, const Offset(0, -600));
      await settle();
    }
    expect(find.text('Episode 0'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await settle();
  });

  testWidgets('opening a stale show checks for new episodes by itself', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(
      () => database.upsertPodcastShow(_show('show', lastRefreshedAt: 1)),
    );
    final repository = _RecordingRepository(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          podcastRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const PodcastShowScreen(showId: 'show'),
        ),
      ),
    );
    for (var round = 0; round < 5; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(repository.refreshed, ['show']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });
}
