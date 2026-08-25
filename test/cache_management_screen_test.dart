import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/settings/cache_management_screen.dart';
import 'package:lumina/services/cache_manager.dart';
import 'package:lumina/services/generation_orchestrator.dart';
import 'package:lumina/services/manifest_store.dart';

void main() {
  testWidgets('audio cache screen includes podcast audio and transcripts', (
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
        id: 'cached-show',
        feedUrl: 'https://example.com/cached.xml',
        title: 'Cached Podcast',
        description: '',
        subscribedAt: 1,
        lastRefreshedAt: 1,
      ),
    );
    await database.upsertPodcastEpisode(
      const PodcastEpisode(
        id: 'cached-episode',
        showId: 'cached-show',
        guid: 'cached-guid',
        title: 'Cached Episode',
        description: '',
        audioUrl: 'https://example.com/cached.mp3',
        publishedAt: 1,
        durationMs: 60000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptProgressMs: 0,
        localAudioPath: '/tmp/cached-episode.mp3',
        transcriptJson: '[{"text":"cached","startMs":0,"endMs":1}]',
        transcriptStatus: 'complete',
      ),
    );
    await database.upsertPodcastShow(
      const PodcastShow(
        id: 'transcript-show',
        feedUrl: 'https://example.com/transcript.xml',
        title: 'Transcript-only Podcast',
        description: '',
        subscribedAt: 2,
        lastRefreshedAt: 2,
      ),
    );
    await database.upsertPodcastEpisode(
      const PodcastEpisode(
        id: 'transcript-episode',
        showId: 'transcript-show',
        guid: 'transcript-guid',
        title: 'Transcript-only Episode',
        description: '',
        audioUrl: 'https://example.com/transcript.mp3',
        publishedAt: 2,
        durationMs: 60000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptProgressMs: 0,
        transcriptJson: '[{"text":"cached","startMs":0,"endMs":1}]',
        transcriptStatus: 'complete',
      ),
    );
    final cache = _FakeCacheManager(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          cacheManagerProvider.overrideWithValue(cache),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: const CacheManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both shows appear as selectable rows, including the transcript-only one.
    expect(find.text('Cached Podcast'), findsOneWidget);
    expect(find.text('Transcript-only Podcast'), findsOneWidget);
    expect(find.byKey(const ValueKey('cache-row-show:cached-show')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cache-row-show:transcript-show')),
      findsOneWidget,
    );
    // The legend reports the podcast total.
    expect(find.textContaining('12.0 MB'), findsWidgets);

    // Nothing is selected, so the delete bar is inert.
    expect(find.byKey(const ValueKey('cache-delete-selection')), findsOneWidget);

    // Selecting a show reveals the selected size and enables deletion.
    await tester.tap(find.byKey(const ValueKey('cache-row-show:cached-show')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Selected'), findsOneWidget);
    expect(find.textContaining('Delete 1'), findsOneWidget);

    // A show still expands to its episodes so one episode can be cleared.
    await tester.tap(
      find.byKey(const ValueKey('cache-expand-show:cached-show')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cached Episode'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cache-row-episode:cached-episode')),
      findsOneWidget,
    );

    // Select-all ticks every row in the group.
    await tester.tap(find.byKey(const ValueKey('cache-select-all-podcasts')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeCacheManager extends CacheManager {
  _FakeCacheManager(AppDatabase database)
    : this._withStore(database, ManifestStore());

  _FakeCacheManager._withStore(
    AppDatabase database,
    ManifestStore manifestStore,
  ) : super(
        manifestStore,
        GenerationOrchestrator(
          database: database,
          manifestStore: manifestStore,
        ),
        database,
      );

  @override
  Future<CacheUsage> bookAudioUsage() async => const CacheUsage(0);

  @override
  Future<CacheUsage> podcastAudioUsage() async =>
      const CacheUsage(12 * 1024 * 1024);

  @override
  Future<CacheUsage> usageForPodcastEpisode(PodcastEpisode episode) async {
    if (episode.localAudioPath == null) return const CacheUsage(0);
    return const CacheUsage(12 * 1024 * 1024);
  }
}
