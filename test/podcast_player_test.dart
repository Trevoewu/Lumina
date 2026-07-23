import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/presentation/screens/player/player_screen.dart';
import 'package:lumina/presentation/screens/podcast/podcast_episode_screen.dart';
import 'package:lumina/services/lumina_audio_handler.dart';
import 'package:lumina/services/sleep_timer_service.dart';

void main() {
  test('podcast progress writes do not invalidate transcript presentation', () {
    const episode = PodcastEpisode(
      id: 'episode-refresh',
      showId: 'show-refresh',
      guid: 'episode-refresh-guid',
      title: 'Refresh filtering',
      description: '',
      audioUrl: 'https://example.com/refresh.mp3',
      publishedAt: 1,
      durationMs: 600000,
      playbackPositionMs: 0,
      lastPlayedAt: 0,
      isPlayed: false,
      transcriptJson: '[{"text":"Cached line.","startMs":0,"endMs":1000}]',
      transcriptStatus: 'running',
    );

    expect(
      podcastEpisodeRequiresPlayerRefresh(
        episode,
        episode.copyWith(
          playbackPositionMs: 5000,
          lastPlayedAt: 10,
          isPlayed: true,
        ),
      ),
      isFalse,
    );
    expect(
      podcastEpisodeRequiresPlayerRefresh(
        episode,
        episode.copyWith(
          transcriptJson: const Value(
            '[{"text":"New cached line.","startMs":0,"endMs":1000}]',
          ),
        ),
      ),
      isTrue,
    );
  });

  testWidgets(
    'podcast reuses the audiobook player and reveals persisted chunks live',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final handler = _PodcastTestAudioHandler();
      final sleepTimer = SleepTimerService();
      addTearDown(database.close);
      addTearDown(handler.dispose);
      addTearDown(sleepTimer.dispose);

      const show = PodcastShow(
        id: 'show-player',
        feedUrl: 'https://example.com/feed.xml',
        title: 'Example Podcast',
        description: '',
        subscribedAt: 1,
        lastRefreshedAt: 1,
      );
      const episodeDescription =
          'Luke explores the countryside and shares practical English while '
          'talking about current podcast news, moving house, plans for a future '
          'episode, listener questions, and several stories from family life. '
          'These detailed notes should remain available without crowding the '
          'title and playback controls.';
      const episode = PodcastEpisode(
        id: 'episode-player',
        showId: 'show-player',
        guid: 'episode-player-guid',
        title: 'A Reused Player',
        description: episodeDescription,
        audioUrl: 'https://example.com/episode.mp3',
        publishedAt: 1,
        durationMs: 600000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptJson:
            '[{"text":"First cached chunk.","startMs":0,"endMs":1200}]',
        transcriptStatus: 'running',
      );
      await database.upsertPodcastShow(show);
      await database.upsertPodcastEpisode(episode);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            luminaAudioHandlerProvider.overrideWith((ref) async => handler),
            sleepTimerServiceProvider.overrideWithValue(sleepTimer),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme(),
            home: const PodcastEpisodeScreen(episodeId: 'episode-player'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(find.text('A Reused Player'), findsOneWidget);
      expect(find.text(episodeDescription), findsOneWidget);
      expect(
        find.byKey(const ValueKey('podcast-episode-description')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('player-chapter-metadata')),
          matching: find.byKey(const ValueKey('podcast-episode-description')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('podcast-shownotes-card')),
          matching: find.byKey(const ValueKey('podcast-episode-description')),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('podcast-information-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('podcast-transcript-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('podcast-shownotes-card')),
        findsOneWidget,
      );
      expect(find.text('Transcript'), findsOneWidget);
      expect(find.text('First cached chunk.'), findsOneWidget);

      await database.updatePodcastTranscript(
        episode.id,
        status: 'running',
        transcriptJson:
            '[{"text":"First cached chunk.","startMs":0,"endMs":1200},'
            '{"text":"Second cached chunk.","startMs":1200,"endMs":2400}]',
        language: 'en',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('First cached chunk.'), findsOneWidget);
      expect(find.text('Second cached chunk.'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('podcast-player-scroll-view')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('podcast-shownotes-card')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('podcast-shownotes-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('podcast card entry opens above the tab navigator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final handler = _PodcastTestAudioHandler();
    final sleepTimer = SleepTimerService();
    addTearDown(database.close);
    addTearDown(handler.dispose);
    addTearDown(sleepTimer.dispose);
    await database.upsertPodcastShow(
      const PodcastShow(
        id: 'show-navigation',
        feedUrl: 'https://example.com/navigation.xml',
        title: 'Navigation Podcast',
        description: '',
        subscribedAt: 1,
        lastRefreshedAt: 1,
      ),
    );
    await database.upsertPodcastEpisode(
      const PodcastEpisode(
        id: 'episode-navigation',
        showId: 'show-navigation',
        guid: 'episode-navigation-guid',
        title: 'One Fullscreen Player',
        description: '',
        audioUrl: 'https://example.com/navigation.mp3',
        publishedAt: 1,
        durationMs: 600000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptStatus: 'none',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          luminaAudioHandlerProvider.overrideWith((ref) async => handler),
          sleepTimerServiceProvider.overrideWithValue(sleepTimer),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (nestedContext) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      key: const ValueKey('nested-podcast-card'),
                      onPressed: () => openPodcastEpisodePlayer(
                        nestedContext,
                        episodeId: 'episode-navigation',
                      ),
                      child: const Text('Open episode'),
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: const SizedBox(
              key: ValueKey('outer-navigation-chrome'),
              height: 80,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nested-podcast-card')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.text('One Fullscreen Player'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('outer-navigation-chrome')).hitTestable(),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _PodcastTestAudioHandler extends BaseAudioHandler
    implements LuminaAudioHandler {
  final _paragraphController = StreamController<String?>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  bool _disposed = false;

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
  String? get currentPodcastEpisodeId => null;

  @override
  Stream<String?> get currentParagraphIdStream => _paragraphController.stream;

  @override
  Duration get position => Duration.zero;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

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
