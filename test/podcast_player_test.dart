import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/audio_text_timing.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/presentation/screens/player/player_screen.dart';
import 'package:lumina/presentation/screens/podcast/podcast_episode_screen.dart';
import 'package:lumina/presentation/widgets/podcast_link_text.dart';
import 'package:lumina/presentation/widgets/synced_lyrics_list.dart';
import 'package:lumina/services/lumina_audio_handler.dart';
import 'package:lumina/services/podcast_transcription_service.dart';
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
      transcriptProgressMs: 0,
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
          transcriptProgressMs: 0,
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

  group('joinPodcastTranscriptLines', () {
    AudioTextTiming timing(String text) =>
        AudioTextTiming(text: text, startMs: 0, endMs: 1000);

    test('stitches Whisper segments that stop mid-sentence', () {
      expect(
        joinPodcastTranscriptLines([
          timing('So the thing I wanted'),
          timing('to say is that it never worked.'),
          timing('That was the whole problem.'),
        ]),
        'So the thing I wanted to say is that it never worked.\n'
        'That was the whole problem.',
      );
    });

    test('keeps sentences that end behind a closing quote apart', () {
      expect(
        joinPodcastTranscriptLines([
          timing('He said "we are done."'),
          timing('Then he left.'),
        ]),
        'He said "we are done."\nThen he left.',
      );
    });

    test('joins CJK segments without inserting a space', () {
      expect(
        joinPodcastTranscriptLines([timing('我想说的是'), timing('这件事从来没成过。')]),
        '我想说的是这件事从来没成过。',
      );
    });

    test('keeps a newly cached chunk from reflowing the previous tail', () {
      expect(
        joinPodcastTranscriptLines([
          AudioTextTiming(
            text: 'The unfinished sentence',
            startMs: 179000,
            endMs: 180000,
            chunkStartMs: 0,
          ),
          AudioTextTiming(
            text: 'continues in the next chunk.',
            startMs: 180200,
            endMs: 181000,
            chunkStartMs: 180000,
          ),
        ]),
        'The unfinished sentence\ncontinues in the next chunk.',
      );
    });

    test('bounds speech that Whisper transcribed without punctuation', () {
      final merged = joinPodcastTranscriptLines([
        for (var index = 0; index < 12; index++) timing('word ' * 5),
      ], maxMergedChars: 60);
      final lines = merged.split('\n');
      expect(lines.length, greaterThan(1));
      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(60));
      }
    });

    test('drops blank segments', () {
      expect(
        joinPodcastTranscriptLines([
          timing('First line.'),
          timing('   '),
          timing('Second line.'),
        ]),
        'First line.\nSecond line.',
      );
    });
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
          'At 00:36:33 Luke explores the countryside and shares practical '
          'English while '
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
        durationMs: 3600000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptProgressMs: 0,
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
        find.descendant(
          of: find.byKey(const ValueKey('podcast-shownotes-card')),
          matching: find.byType(PodcastLinkText),
        ),
        findsOneWidget,
      );
      final shownotesText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('podcast-episode-description')),
          matching: find.byType(Text),
        ),
      );
      final timestampSpan = (shownotesText.textSpan! as TextSpan).children!
          .whereType<TextSpan>()
          .firstWhere((span) => span.text == '00:36:33');
      (timestampSpan.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pumpAndSettle();
      expect(handler.loadedPodcastEpisodeId, episode.id);
      expect(handler.soughtPosition, const Duration(minutes: 36, seconds: 33));
      expect(
        find.byKey(const ValueKey('podcast-information-card')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('ai-summary-card')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('podcast-transcript-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('podcast-shownotes-card')),
        findsOneWidget,
      );
      final shownotesTop = tester.getTopLeft(
        find.byKey(const ValueKey('podcast-shownotes-card')),
      );
      final summaryTop = tester.getTopLeft(
        find.byKey(const ValueKey('ai-summary-card')),
      );
      final transcriptTop = tester.getTopLeft(
        find.byKey(const ValueKey('podcast-transcript-card')),
      );
      expect(shownotesTop.dy, lessThan(summaryTop.dy));
      expect(summaryTop.dy, lessThan(transcriptTop.dy));
      expect(find.text('Transcript'), findsOneWidget);
      expect(find.text('First cached chunk.'), findsOneWidget);

      final transcriptList = find.descendant(
        of: find.byKey(const ValueKey('podcast-transcript-card')),
        matching: find.byType(SyncedLyricsList),
      );
      final transcriptState = tester.state(transcriptList);

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
      expect(
        tester.state(transcriptList),
        same(transcriptState),
        reason: 'a cached chunk must not discard the transcript list state',
      );
      final chunkParagraphs = tester
          .widget<SyncedLyricsList>(transcriptList)
          .paragraphs;

      // Whisper rewrites the same segments when it flips the row to complete.
      await database.updatePodcastTranscript(
        episode.id,
        status: 'complete',
        transcriptJson:
            '[{"text":"First cached chunk.","startMs":0,"endMs":1200},'
            '{"text":"Second cached chunk.","startMs":1200,"endMs":2400}]',
        language: 'en',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.state(transcriptList), same(transcriptState));
      expect(
        tester.widget<SyncedLyricsList>(transcriptList).paragraphs,
        same(chunkParagraphs),
        reason: 'an unchanged transcript must not rebuild the lyric lines',
      );

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

  testWidgets('transcript card grows into its first chunk gradually', (
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
        id: 'show-growth',
        feedUrl: 'https://example.com/feed.xml',
        title: 'Example Podcast',
        description: '',
        subscribedAt: 1,
        lastRefreshedAt: 1,
      ),
    );
    await database.upsertPodcastEpisode(
      const PodcastEpisode(
        id: 'episode-growth',
        showId: 'show-growth',
        guid: 'episode-growth-guid',
        title: 'A Growing Transcript',
        description: 'Shownotes.',
        audioUrl: 'https://example.com/episode.mp3',
        publishedAt: 1,
        durationMs: 3600000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptProgressMs: 0,
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
          home: const PodcastEpisodeScreen(episodeId: 'episode-growth'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('podcast-transcript-card'));
    final placeholderHeight = tester.getSize(card).height;

    await database.updatePodcastTranscript(
      'episode-growth',
      status: 'running',
      transcriptJson:
          '[{"text":"First cached chunk.","startMs":0,'
          '"endMs":1200}]',
      language: 'en',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final midHeight = tester.getSize(card).height;

    await tester.pumpAndSettle();
    final settledHeight = tester.getSize(card).height;

    expect(settledHeight, greaterThan(placeholderHeight));
    expect(midHeight, greaterThan(placeholderHeight));
    expect(
      midHeight,
      lessThan(settledHeight),
      reason: 'the card must ease into its taller size instead of snapping',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

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
        transcriptProgressMs: 0,
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

  testWidgets('a running transcription shows progress without card controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final handler = _PodcastTestAudioHandler();
    final sleepTimer = SleepTimerService();
    final service = _FakeTranscriptionService(database, 'episode-running');
    addTearDown(database.close);
    addTearDown(handler.dispose);
    addTearDown(sleepTimer.dispose);
    addTearDown(service.dispose);

    await _insertPodcast(
      database,
      episodeId: 'episode-running',
      transcriptJson:
          '[{"text":"First cached chunk.","startMs":0,'
          '"endMs":1200}]',
      transcriptStatus: 'running',
    );

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-running',
      ),
    );
    // The running state carries an indeterminate progress bar, so this never
    // settles; pump a couple of frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('podcast-transcript-pause')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('podcast-transcript-restart')),
      findsNothing,
      reason: 'transcript actions live in the episode long-press menu',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a paused transcript stays visible without card controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final handler = _PodcastTestAudioHandler();
    final sleepTimer = SleepTimerService();
    final service = _FakeTranscriptionService(database, null);
    addTearDown(database.close);
    addTearDown(handler.dispose);
    addTearDown(sleepTimer.dispose);
    addTearDown(service.dispose);

    await _insertPodcast(
      database,
      episodeId: 'episode-paused',
      transcriptJson:
          '[{"text":"First cached chunk.","startMs":0,'
          '"endMs":1200}]',
      transcriptStatus: podcastTranscriptPausedStatus,
      transcriptProgressMs: 180000,
    );

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-paused',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('podcast-transcript-restart')),
      findsNothing,
      reason: 'transcript actions live in the episode long-press menu',
    );
    expect(find.text('First cached chunk.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> _insertPodcast(
  AppDatabase database, {
  required String episodeId,
  required String transcriptStatus,
  String? transcriptJson,
  int transcriptProgressMs = 0,
}) async {
  await database.upsertPodcastShow(
    const PodcastShow(
      id: 'show-pause-ui',
      feedUrl: 'https://example.com/feed.xml',
      title: 'Example Podcast',
      description: '',
      subscribedAt: 1,
      lastRefreshedAt: 1,
    ),
  );
  await database.upsertPodcastEpisode(
    PodcastEpisode(
      id: episodeId,
      showId: 'show-pause-ui',
      guid: '$episodeId-guid',
      title: 'Interruptible Episode',
      description: 'Shownotes.',
      audioUrl: 'https://example.com/episode.mp3',
      publishedAt: 1,
      durationMs: 3600000,
      playbackPositionMs: 0,
      lastPlayedAt: 0,
      isPlayed: false,
      transcriptJson: transcriptJson,
      transcriptStatus: transcriptStatus,
      transcriptProgressMs: transcriptProgressMs,
    ),
  );
}

Widget _podcastApp({
  required AppDatabase database,
  required _PodcastTestAudioHandler handler,
  required SleepTimerService sleepTimer,
  required _FakeTranscriptionService service,
  required String episodeId,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      luminaAudioHandlerProvider.overrideWith((ref) async => handler),
      sleepTimerServiceProvider.overrideWithValue(sleepTimer),
      podcastTranscriptionServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme(),
      home: PodcastEpisodeScreen(episodeId: episodeId),
    ),
  );
}

/// Stands in for Whisper: it only reports which episode it is working on and
/// records the pause requests the transcript card sends.
class _FakeTranscriptionService extends PodcastTranscriptionService {
  final StreamController<PodcastTranscriptionProgress> _progress =
      StreamController<PodcastTranscriptionProgress>.broadcast();
  String? _activeEpisodeId;
  int pauseCalls = 0;

  _FakeTranscriptionService(super.database, this._activeEpisodeId);

  @override
  String? get activeEpisodeId => _activeEpisodeId;

  @override
  Stream<PodcastTranscriptionProgress> get progressStream => _progress.stream;

  @override
  Future<void> pause() async {
    pauseCalls++;
    final episodeId = _activeEpisodeId;
    _activeEpisodeId = null;
    if (episodeId == null) return;
    _progress.add(
      PodcastTranscriptionProgress(
        episodeId: episodeId,
        stage: PodcastTranscriptionStage.paused,
        message: '本地转写已暂停',
        progress: 0.5,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_progress.close());
    super.dispose();
  }
}

class _PodcastTestAudioHandler extends BaseAudioHandler
    implements LuminaAudioHandler {
  final _paragraphController = StreamController<String?>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  bool _disposed = false;
  String? loadedPodcastEpisodeId;
  Duration? soughtPosition;

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
  String? get currentPodcastEpisodeId => loadedPodcastEpisodeId;

  @override
  Future<void> loadPodcastQueue({
    required List<PodcastPlaybackSource> episodes,
    required String initialEpisodeId,
    Duration initialPosition = Duration.zero,
  }) async {
    loadedPodcastEpisodeId = initialEpisodeId;
  }

  @override
  Stream<String?> get currentParagraphIdStream => _paragraphController.stream;

  @override
  Duration get position => Duration.zero;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<void> seek(Duration position) async {
    soughtPosition = position;
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
