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
        localAudioPath: '/tmp/cached-episode.mp3',
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

    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Podcast'), findsOneWidget);
    expect(find.text('Cached Podcast'), findsOneWidget);
    expect(find.textContaining('Podcast 12.0 MB'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('podcast-cache-cached-show')));
    await tester.pumpAndSettle();
    expect(find.text('Cached Episode'), findsOneWidget);
    expect(find.textContaining('1 transcript'), findsWidgets);

    final episodeTile = find.byKey(
      const ValueKey('podcast-cache-episode-cached-episode'),
    );
    await tester.tap(
      find.descendant(of: episodeTile, matching: find.byTooltip('Clear cache')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete audio'), findsOneWidget);
    expect(find.text('Delete transcript'), findsOneWidget);
    expect(find.text('Delete audio and transcript'), findsOneWidget);
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
  Future<CacheUsage> usageForPodcastEpisode(PodcastEpisode episode) async =>
      const CacheUsage(12 * 1024 * 1024);
}
