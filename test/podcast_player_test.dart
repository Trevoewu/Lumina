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

    test('a spoken URL survives joining and line splitting', () {
      final joined = joinPodcastTranscriptLines([
        timing('plus add-free listening and access to the premium community,'),
        timing('sign up to LEP Premium at teacherluke.co.uk/premium.'),
      ]);
      final lines = splitLyricsText(joined);

      final withDomain = lines
          .where((line) => line.contains('teacherluke'))
          .toList();
      expect(withDomain, hasLength(1));
      expect(
        withDomain.single,
        contains('teacherluke.co.uk/premium.'),
        reason: 'the domain must not be split across transcript lines',
      );
      expect(lines, isNot(contains('co.')));
      expect(lines, isNot(contains('uk/premium.')));
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
        find.byKey(const ValueKey('podcast-shownotes-card')),
        findsOneWidget,
      );

      final transcriptToggle = find.byKey(
        const ValueKey('player-transcript-toggle'),
      );
      expect(transcriptToggle, findsOneWidget);
      await tester.ensureVisible(transcriptToggle);
      await tester.tap(transcriptToggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('podcast-transcript-card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('podcast-transcript-focus-viewport')),
        findsOneWidget,
      );
      expect(find.text('First cached chunk.'), findsOneWidget);

      final transcriptList = find.descendant(
        of: find.byKey(const ValueKey('podcast-transcript-focus-viewport')),
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
        find.byKey(const ValueKey('podcast-transcript-scroll-view')),
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

  testWidgets('transcript mode reveals the first cached chunk', (tester) async {
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

    final transcriptToggle = find.byKey(
      const ValueKey('player-transcript-toggle'),
    );
    await tester.ensureVisible(transcriptToggle);
    await tester.tap(transcriptToggle);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('podcast-transcript-focus-viewport')),
      findsOneWidget,
    );

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
    await tester.pumpAndSettle();
    expect(find.text('First cached chunk.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('transcript opens as a page and settles over the cover', (
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
      episodeId: 'episode-fade',
      transcriptStatus: 'complete',
      transcriptJson:
          '[{"text":"A cached sentence.","startMs":0,"endMs":1200}]',
    );

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-fade',
      ),
    );
    await tester.pumpAndSettle();

    final coverScroll = find.byKey(
      const ValueKey('podcast-player-scroll-view'),
    );
    final transcriptScroll = find.byKey(
      const ValueKey('podcast-transcript-scroll-view'),
    );
    expect(coverScroll, findsOneWidget);
    expect(transcriptScroll, findsNothing);

    final transcriptToggle = find.byKey(
      const ValueKey('player-transcript-toggle'),
    );
    final coverControls = find.descendant(
      of: coverScroll,
      matching: find.byKey(const ValueKey('player-cache-playback-progress')),
    );
    final coverControlsTop = tester.getTopLeft(coverControls).dy;
    await tester.ensureVisible(transcriptToggle);
    await tester.tap(transcriptToggle);

    // During the route transition both pages are mounted. The cover remains
    // underneath long enough for the Hero artwork to fly into the mini player;
    // the parent page is removed after the route settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(coverScroll, findsOneWidget);
    expect(transcriptScroll, findsOneWidget);
    final routeControls = find.descendant(
      of: find.byKey(const ValueKey('player-transcript-page')),
      matching: find.byKey(const ValueKey('player-cache-playback-progress')),
    );
    expect(routeControls, findsOneWidget);
    final controlsTopDuringTransition = tester.getTopLeft(routeControls).dy;
    expect(
      controlsTopDuringTransition,
      closeTo(coverControlsTop, 0.1),
      reason: 'cover and transcript controls share the same bottom band',
    );

    await tester.pumpAndSettle();
    expect(coverScroll, findsNothing);
    expect(transcriptScroll, findsOneWidget);
    expect(
      tester.getTopLeft(routeControls).dy,
      closeTo(controlsTopDuringTransition, 0.1),
    );
    expect(
      find.byKey(const ValueKey('player-transcript-page')),
      findsOneWidget,
    );
    final topChrome = tester.widget<KeyedSubtree>(
      find.byKey(const ValueKey('player-transcript-top-chrome')),
    );
    expect(
      topChrome.child,
      isNot(isA<DecoratedBox>()),
      reason: 'the mini player must let the page accent show through',
    );
    final closePlayer = find.byKey(
      const ValueKey('player-transcript-close-player'),
    );
    expect(closePlayer, findsOneWidget);
    final transcriptArtwork = find.descendant(
      of: find.byKey(const ValueKey('player-transcript-page')),
      matching: find.byKey(const ValueKey('player-artwork')),
    );
    expect(transcriptArtwork, findsOneWidget);
    expect(
      tester.getTopLeft(closePlayer).dx,
      lessThan(tester.getTopLeft(transcriptArtwork).dx),
    );
    expect(
      find.byKey(const ValueKey('podcast-transcript-close')),
      findsNothing,
    );

    await tester.tap(closePlayer);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('iOS edge swipe returns from transcript to the cover', (
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
      episodeId: 'episode-edge-pop',
      transcriptStatus: 'complete',
      transcriptJson:
          '[{"text":"Swipe back sentence.","startMs":0,"endMs":1200}]',
    );
    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-edge-pop',
        platform: TargetPlatform.iOS,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player-transcript-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('player-transcript-page')),
      findsOneWidget,
    );

    await tester.timedDragFrom(
      const Offset(5, 420),
      const Offset(360, 0),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player-transcript-page')), findsNothing);
    expect(
      find.byKey(const ValueKey('podcast-player-scroll-view')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('transcript mode keeps its chrome visible while playing', (
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
      episodeId: 'episode-idle',
      transcriptStatus: 'complete',
      transcriptJson:
          '[{"text":"A cached sentence.","startMs":0,"endMs":1200},'
          '{"text":"And another one.","startMs":1200,"endMs":2400}]',
    );

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-idle',
      ),
    );
    await tester.pumpAndSettle();

    final transcriptToggle = find.byKey(
      const ValueKey('player-transcript-toggle'),
    );
    await tester.ensureVisible(transcriptToggle);
    handler.loadedPodcastEpisodeId = 'episode-idle';
    await tester.tap(transcriptToggle);
    await tester.pumpAndSettle();

    // The floating controls start visible and reachable.
    expect(transcriptToggle.hitTestable(), findsOneWidget);

    // A paused episode never starts the idle timer.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(transcriptToggle.hitTestable(), findsOneWidget);

    // Playing no longer starts an idle timer; both chrome bands stay visible.
    handler.setPlaying(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 500));
    expect(transcriptToggle.hitTestable(), findsOneWidget);
    expect(find.text('Tap anywhere to bring the controls back'), findsNothing);

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

  testWidgets('a running transcription can be paused from transcript mode', (
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

    final transcriptToggle = find.byKey(
      const ValueKey('player-transcript-toggle'),
    );
    await tester.ensureVisible(transcriptToggle);
    await tester.tap(transcriptToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final pauseButton = find.byKey(const ValueKey('podcast-transcript-pause'));
    expect(pauseButton, findsOneWidget);
    expect(
      find.byKey(const ValueKey('podcast-transcript-restart')),
      findsNothing,
      reason: 'a running job offers pause, not another start',
    );

    await tester.ensureVisible(pauseButton);
    await tester.pump();
    await tester.tap(pauseButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.pauseCalls, 1);
    expect(pauseButton, findsNothing);
    expect(
      find.byKey(const ValueKey('podcast-transcript-restart')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('automatic episode changes rebind transcript and running state', (
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
      transcriptStatus: 'running',
    );
    await _insertPodcast(
      database,
      episodeId: 'episode-next',
      transcriptStatus: 'complete',
      transcriptJson:
          '[{"text":"Transcript from the next episode.",'
          '"startMs":0,"endMs":1200}]',
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    handler.selectPodcastEpisode('episode-next');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final transcriptToggle = find.byKey(
      const ValueKey('player-transcript-toggle'),
    );
    await tester.ensureVisible(transcriptToggle);
    await tester.tap(transcriptToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Transcript from the next episode.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('podcast-transcript-pause')),
      findsNothing,
      reason: 'the ASR job still belongs to the previous episode',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a paused episode offers to resume in transcript mode', (
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

    final transcriptToggle = find.byKey(
      const ValueKey('player-transcript-toggle'),
    );
    await tester.ensureVisible(transcriptToggle);
    await tester.tap(transcriptToggle);
    await tester.pumpAndSettle();

    final restart = find.byKey(const ValueKey('podcast-transcript-restart'));
    expect(restart, findsOneWidget);
    expect(
      tester.widget<IconButton>(restart).tooltip,
      'Resume transcription',
      reason: 'the cached chunks are kept, so this continues the run',
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
  TargetPlatform? platform,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      luminaAudioHandlerProvider.overrideWith((ref) async => handler),
      sleepTimerServiceProvider.overrideWithValue(sleepTimer),
      podcastTranscriptionServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme().copyWith(platform: platform),
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

  void setPlaying(bool playing) {
    playbackState.add(playbackState.value.copyWith(playing: playing));
  }

  void selectPodcastEpisode(String episodeId) {
    loadedPodcastEpisodeId = episodeId;
    _paragraphController.add(episodeId);
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
