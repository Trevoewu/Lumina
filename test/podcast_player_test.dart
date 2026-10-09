import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart' show CupertinoSheetRoute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/service_settings_controllers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/audio_text_timing.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/presentation/screens/player/player_screen.dart';
import 'package:lumina/presentation/screens/podcast/podcast_episode_screen.dart';
import 'package:lumina/presentation/widgets/podcast_link_text.dart';
import 'package:lumina/presentation/widgets/ai_summary_panel.dart';
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
    test('chapter excerpt keeps complete sentences and protects names', () {
      const text =
          'St. Mael\'s Navigation on the Ocean of Ice. '
          'The devil, having tucked his clothes up to his armpits, '
          'dragged the trough on the sand and fitted the rigging in less than an hour. '
          'As soon as the boat was ready, he left.';
      final result = joinPodcastTranscriptLines([
        const AudioTextTiming(
          text: text,
          startMs: 0,
          endMs: 60000,
          pauseBefore: true,
        ),
      ]);
      expect(
        result.split('\n').first,
        "St. Mael's Navigation on the Ocean of Ice.",
      );
      expect(
        result.split('\n').last,
        'As soon as the boat was ready, he left.',
      );
      expect(result.replaceAll(RegExp(r'\s+'), ' '), text);
      expect(result, isNot(contains('The\n')));
    });

    test('decimals and URLs survive sentence segmentation', () {
      expect(
        joinPodcastTranscriptLines([
          const AudioTextTiming(
            text:
                'Dr. Smith paid 3.14 dollars. Visit example.com/docs. Then leave.',
            startMs: 0,
            endMs: 1000,
          ),
        ]),
        'Dr. Smith paid 3.14 dollars.\nVisit example.com/docs.\nThen leave.',
      );
    });
    test(
      'keeps title abbreviations and sentence starters with their phrase',
      () {
        expect(
          joinPodcastTranscriptLines([
            const AudioTextTiming(
              text: 'Chapter 4. St.',
              startMs: 0,
              endMs: 2000,
            ),
            const AudioTextTiming(
              text: 'Mael on the Ocean of Ice.',
              startMs: 2600,
              endMs: 6000,
            ),
            const AudioTextTiming(text: 'The', startMs: 6000, endMs: 6200),
            const AudioTextTiming(
              text: 'devil walked away.',
              startMs: 6800,
              endMs: 9000,
            ),
          ]),
          'Chapter 4.\nSt. Mael on the Ocean of Ice.\nThe devil walked away.',
        );
      },
    );
    test('continuous slow speech stays together without punctuation', () {
      final lines = joinPodcastTranscriptLines([
        for (var i = 0; i < 10; i++)
          AudioTextTiming(
            text: 'word$i',
            startMs: i * 1000,
            endMs: (i + 1) * 1000,
          ),
      ]);
      expect(
        lines,
        'word0 word1 word2 word3 word4 word5 word6 word7 word8 word9',
      );
    });

    test('prefers a sentence boundary near the duration limit', () {
      expect(
        joinPodcastTranscriptLines([
          const AudioTextTiming(
            text: 'A short sentence.',
            startMs: 0,
            endMs: 5000,
          ),
          const AudioTextTiming(
            text: 'Next thought',
            startMs: 5000,
            endMs: 6500,
          ),
        ]),
        'A short sentence.\nNext thought',
      );
    });

    AudioTextTiming timing(String text) =>
        AudioTextTiming(text: text, startMs: 0, endMs: 1000);

    test('ignores pauses when there is no textual boundary', () {
      expect(
        joinPodcastTranscriptLines([
          AudioTextTiming(text: '我想说的是', startMs: 0, endMs: 1000),
          AudioTextTiming(text: '这件事', startMs: 1299, endMs: 2000),
          AudioTextTiming(text: '需要再想想', startMs: 2500, endMs: 4000),
        ]),
        '我想说的是这件事需要再想想',
      );
    });

    test('overlapping timestamps do not invent a pause', () {
      expect(
        joinPodcastTranscriptLines([
          AudioTextTiming(text: 'We', startMs: 0, endMs: 2000),
          AudioTextTiming(text: 'can', startMs: 500, endMs: 700),
          AudioTextTiming(text: 'continue', startMs: 2000, endMs: 2500),
          AudioTextTiming(text: 'after a pause', startMs: 3200, endMs: 4000),
        ]),
        'We can continue after a pause',
      );
    });

    test('blank segments do not hide silence between spoken words', () {
      expect(
        joinPodcastTranscriptLines([
          AudioTextTiming(text: 'First', startMs: 0, endMs: 1000),
          AudioTextTiming(text: ' ', startMs: 1000, endMs: 2000),
          AudioTextTiming(text: 'then', startMs: 2000, endMs: 3000),
        ]),
        'First then',
      );
    });

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

    test('separates complete sentences regardless of pauses', () {
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

    test('chunk boundaries alone do not split continuous speech', () {
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
        'The unfinished sentence continues in the next chunk.',
      );
    });

    test('uses a nearby sentence ending before exceeding the target', () {
      expect(
        joinPodcastTranscriptLines([
          timing('Short.'),
          timing('Next sentence.'),
        ], maxMergedChars: 16),
        'Short.\nNext sentence.',
      );
    });

    test('wraps unpunctuated Chinese visually without forced blocks', () {
      final lines = joinPodcastTranscriptLines([
        timing('连续说话' * 40),
      ]).split('\n');
      expect(lines, hasLength(1));
      expect(lines.join(), '连续说话' * 40);
    });

    test('audio pause marks do not determine display blocks', () {
      expect(
        joinPodcastTranscriptLines([
          timing('Before'),
          const AudioTextTiming(
            text: 'after',
            startMs: 1000,
            endMs: 2000,
            pauseBefore: true,
          ),
        ]),
        'Before after',
      );
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
            llmSettingsControllerProvider.overrideWith(
              _ReadyChatLlmController.new,
            ),
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
      await tester.drag(
        find.byKey(const ValueKey('podcast-player-scroll-view')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
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
      await tester.ensureVisible(find.byKey(const ValueKey('ai-chatbot-open')));
      await tester.tap(find.byKey(const ValueKey('ai-chatbot-open')));
      await tester.pumpAndSettle();
      final conversation = find.byType(AiConversationSheet);
      expect(conversation, findsOneWidget);
      expect(
        tester.widget<AiConversationSheet>(conversation).scope.id,
        episode.id,
      );
      expect(
        ModalRoute.of(tester.element(conversation)),
        isA<CupertinoSheetRoute<void>>(),
      );
      Navigator.of(tester.element(conversation)).pop();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('podcast-player-scroll-view')),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      expect(transcriptToggle, findsOneWidget);
      await tester.ensureVisible(transcriptToggle);
      await tester.tap(transcriptToggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('podcast-transcript-card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('player-inline-transcript')),
        findsOneWidget,
      );
      expect(find.text('First cached chunk.'), findsOneWidget);

      final transcriptList = find.descendant(
        of: find.byKey(const ValueKey('player-inline-transcript')),
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
      await tester.ensureVisible(
        find.byKey(const ValueKey('podcast-shownotes-card')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('podcast-shownotes-card')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('podcast-shownotes-toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('app-content-sheet-close')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('app-content-sheet-close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('podcast-shownotes-toggle')),
        findsOneWidget,
      );
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
      find.byKey(const ValueKey('player-inline-transcript')),
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

  testWidgets(
    'inline subtitle transitions keep every transport control mounted and fixed',
    (tester) async {
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

      final keys = [
        'player-more-menu',
        'player-transcript-toggle',
        'player-primary-audio-action',
        'player-backward-one-line',
        'player-forward-three-lines',
      ];
      final elements = {
        for (final key in keys) key: tester.element(find.byKey(ValueKey(key))),
      };
      final positions = {
        for (final key in keys)
          key: tester.getCenter(find.byKey(ValueKey(key))),
      };
      for (var toggle = 0; toggle < 4; toggle++) {
        await tester.tap(
          find.byKey(const ValueKey('player-transcript-toggle')),
        );
        await tester.pump();
        for (var frame = 0; frame < 15; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          for (final key in keys) {
            final control = find.byKey(ValueKey(key));
            expect(control, findsOneWidget);
            expect(tester.element(control), same(elements[key]));
            expect(tester.getCenter(control), positions[key]);
            expect(control.hitTestable(), findsOneWidget);
          }
        }
        expect(
          find.byKey(const ValueKey('player-inline-transcript')),
          toggle.isEven ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('player-sticky-mini-player')),
          findsNothing,
        );
        expect(find.byType(Hero), findsNothing);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'iOS subtitle button returns to the cover without another route',
    (tester) async {
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
        find.byKey(const ValueKey('player-inline-transcript')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('player-transcript-toggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('player-inline-transcript')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('podcast-player-scroll-view')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

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

    // With text to read, nothing sits over the transcript; the run's
    // controls are in the more menu.
    expect(
      find.byKey(const ValueKey('podcast-transcription-bar')),
      findsNothing,
    );
    expect(find.text('First cached chunk.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player-more-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('player-menu-transcription-restart')),
      findsOneWidget,
    );
    final pauseButton = find.byKey(
      const ValueKey('player-menu-transcription-pause'),
    );
    expect(pauseButton, findsOneWidget);

    await tester.tap(pauseButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpAndSettle();
    expect(service.pauseCalls, 1);
    expect(pauseButton, findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('before any text arrives the empty transcript shows progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final handler = _PodcastTestAudioHandler();
    final sleepTimer = SleepTimerService();
    final service = _FakeTranscriptionService(database, 'episode-empty');
    addTearDown(database.close);
    addTearDown(handler.dispose);
    addTearDown(sleepTimer.dispose);
    addTearDown(service.dispose);
    await _insertPodcast(
      database,
      episodeId: 'episode-empty',
      transcriptStatus: 'running',
    );

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-empty',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final transcriptToggle = find.byKey(
      const ValueKey('player-transcript-toggle'),
    );
    await tester.ensureVisible(transcriptToggle);
    await tester.tap(transcriptToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Nothing to read yet, so the run's progress and controls fill the
    // empty transcript.
    expect(
      find.byKey(const ValueKey('podcast-transcription-bar')),
      findsOneWidget,
    );
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a run cut off part way offers to resume from the menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final handler = _PodcastTestAudioHandler();
    final sleepTimer = SleepTimerService();
    // Nothing is running now: the app closed while this episode was going.
    final service = _FakeTranscriptionService(database, null);
    addTearDown(database.close);
    addTearDown(handler.dispose);
    addTearDown(sleepTimer.dispose);
    addTearDown(service.dispose);
    await _insertPodcast(
      database,
      episodeId: 'episode-cut-off',
      transcriptStatus: 'running',
      transcriptJson: '[{"text":"Got this far.","startMs":0,"endMs":1200}]',
      transcriptProgressMs: 30000,
    );

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-cut-off',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-more-menu')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('player-menu-transcription-resume')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player-menu-transcription-pause')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('more menu holds actions with no button of their own', (
    tester,
  ) async {
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
      episodeId: 'episode-menu',
      transcriptStatus: 'complete',
      transcriptJson: '[{"text":"A sentence.","startMs":0,"endMs":1200}]',
    );

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-menu',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player-more-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Go to show'), findsOneWidget);
    expect(find.text('Copy episode link'), findsOneWidget);
    // Speed, playlist and sleep timer have buttons on the page already.
    expect(find.text('Playback speed'), findsNothing);
    expect(find.text('Playlist'), findsNothing);
    expect(find.text('Sleep timer'), findsNothing);

    await tester.tap(find.text('Mark as played'));
    await tester.pumpAndSettle();
    expect((await database.getPodcastEpisode('episode-menu'))?.isPlayed, true);

    await tester.pumpWidget(const SizedBox.shrink());
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
      title: 'The Episode That Was Playing',
      publishedAt: 2,
    );
    await _insertPodcast(
      database,
      episodeId: 'episode-next',
      transcriptStatus: 'complete',
      title: 'The Episode That Came Next',
      publishedAt: 1,
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

    expect(
      find.text('The Episode That Came Next'),
      findsWidgets,
      reason: 'the player has to retitle itself when playback moves on',
    );
    expect(find.text('The Episode That Was Playing'), findsNothing);

    final transcriptToggle = find.byKey(
      const ValueKey('player-transcript-toggle'),
    );
    await tester.ensureVisible(transcriptToggle);
    await tester.tap(transcriptToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Transcript from the next episode.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('podcast-transcription-bar')),
      findsNothing,
      reason: 'the ASR job still belongs to the previous episode',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('the up next list switches the player to the tapped episode', (
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
      episodeId: 'episode-current',
      transcriptStatus: 'complete',
      title: 'The Episode Playing Now',
      publishedAt: 2,
    );
    await _insertPodcast(
      database,
      episodeId: 'episode-later',
      transcriptStatus: 'complete',
      title: 'The Episode Up Next',
      publishedAt: 1,
    );

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-current',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final playlistToggle = find.byKey(const ValueKey('player-playlist-toggle'));
    await tester.ensureVisible(playlistToggle);
    await tester.tap(playlistToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Up next takes the cover's place, like the transcript, and the two
    // never show at once.
    expect(
      find.byKey(const ValueKey('player-inline-playlist')),
      findsOneWidget,
    );
    // The episode playing leads the list, marked.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('player-inline-playlist')),
        matching: find.text('The Episode Playing Now'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Now playing'), findsOneWidget);
    final transcriptToggle = find.byKey(
      const ValueKey('player-transcript-toggle'),
    );
    await tester.tap(transcriptToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('player-inline-playlist')), findsNothing);
    expect(
      find.byKey(const ValueKey('player-inline-transcript')),
      findsOneWidget,
    );
    await tester.tap(playlistToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('player-inline-transcript')),
      findsNothing,
    );

    await tester.tap(find.text('The Episode Up Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      handler.loadedPodcastEpisodeId,
      'episode-later',
      reason: 'the tapped episode has to become the one playing',
    );
    expect(
      find.text('The Episode Up Next'),
      findsWidgets,
      reason: 'the player has to follow the episode it just started',
    );
    expect(find.text('The Episode Playing Now'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a buffering stream says so instead of showing pause', (
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
      episodeId: 'episode-stream',
      transcriptStatus: 'complete',
      title: 'A Streamed Episode',
    );

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-stream',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    handler.selectPodcastEpisode('episode-stream');
    handler.setPlaying(true);
    handler.setProcessingState(AudioProcessingState.buffering);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey(PlayerPrimaryAudioAction.loading)),
      findsWidgets,
      reason: 'an uncached episode has to show that it is still buffering',
    );
    expect(
      find.byKey(const ValueKey(PlayerPrimaryAudioAction.pause)),
      findsNothing,
    );

    handler.setProcessingState(AudioProcessingState.ready);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey(PlayerPrimaryAudioAction.pause)),
      findsWidgets,
      reason: 'audio that actually plays has to offer pause again',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('the transport recovers pause when a later load starts playing', (
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
      episodeId: 'episode-selected',
      transcriptStatus: 'complete',
      title: 'The Episode On Screen',
    );

    // Something else is already playing, so `playing` never changes value when
    // this episode takes over. Only the loaded item does.
    handler.setPlaying(true);
    handler.setProcessingState(AudioProcessingState.ready);

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-selected',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Transcript mode is its own route, so it has to watch the handler itself.
    final transcriptToggle = find.byKey(
      const ValueKey('player-transcript-toggle'),
    );
    await tester.ensureVisible(transcriptToggle);
    await tester.tap(transcriptToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    Finder transcriptAction(PlayerPrimaryAudioAction action) =>
        find.byKey(ValueKey(action));

    expect(
      transcriptAction(PlayerPrimaryAudioAction.play),
      findsOneWidget,
      reason: 'another episode playing is not this one playing',
    );

    handler.selectPodcastEpisode('episode-selected');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      transcriptAction(PlayerPrimaryAudioAction.pause),
      findsOneWidget,
      reason: 'the button has to follow the episode that just took over',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a queue load for another episode does not steal the screen', (
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
      episodeId: 'episode-background',
      transcriptStatus: 'complete',
      title: 'The Episode Still Playing',
      publishedAt: 2,
    );
    await _insertPodcast(
      database,
      episodeId: 'episode-opened',
      transcriptStatus: 'complete',
      title: 'The Episode Just Opened',
      publishedAt: 1,
    );

    // The player already holds a different episode when this screen opens.
    handler.loadedPodcastEpisodeId = 'episode-background';

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-opened',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // A late event for the episode that was already loaded must not drag the
    // screen back to it.
    handler.selectPodcastEpisode('episode-background');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('The Episode Still Playing'),
      findsNothing,
      reason: 'the screen has to stay on the episode the user opened',
    );
    expect(find.text('The Episode Just Opened'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'transcript mode keeps rendering timings cached after it opened',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final handler = _PodcastTestAudioHandler();
      final sleepTimer = SleepTimerService();
      final service = _FakeTranscriptionService(database, 'episode-growing');
      addTearDown(database.close);
      addTearDown(handler.dispose);
      addTearDown(sleepTimer.dispose);
      addTearDown(service.dispose);

      await _insertPodcast(
        database,
        episodeId: 'episode-growing',
        transcriptStatus: 'running',
        title: 'A Growing Transcript',
        transcriptJson:
            '[{"text":"First cached chunk.","startMs":0,'
            '"endMs":1200}]',
      );

      await tester.pumpWidget(
        _podcastApp(
          database: database,
          handler: handler,
          sleepTimer: sleepTimer,
          service: service,
          episodeId: 'episode-growing',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final transcriptToggle = find.byKey(
        const ValueKey('player-transcript-toggle'),
      );
      await tester.ensureVisible(transcriptToggle);
      await tester.tap(transcriptToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      final lyricsFinder = find.byKey(
        const ValueKey('transcript-focus:episode-growing'),
      );
      expect(
        tester
            .widget<SyncedLyricsList>(lyricsFinder)
            .manifest
            ?.segments
            .single
            .timings
            .length,
        1,
      );

      await database.upsertPodcastEpisode(
        (await database.getPodcastEpisode('episode-growing'))!.copyWith(
          transcriptJson: const Value(
            '[{"text":"First cached chunk.","startMs":0,"endMs":1200},'
            '{"text":"Second cached chunk.","startMs":1200,"endMs":2400}]',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester
            .widget<SyncedLyricsList>(lyricsFinder)
            .manifest
            ?.segments
            .single
            .timings
            .length,
        2,
        reason:
            'the transcript route must read the manifest again, not the one it '
            'was pushed with, or its lines run against stale timings',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  test('the playback queue window follows the selected episode', () {
    final episodes = [
      for (var index = 0; index < 40; index++)
        PodcastEpisode(
          id: 'episode-$index',
          showId: 'show',
          guid: 'episode-$index-guid',
          title: 'Episode $index',
          description: '',
          audioUrl: 'https://example.com/$index.mp3',
          publishedAt: 40 - index,
          durationMs: 1000,
          playbackPositionMs: 0,
          lastPlayedAt: 0,
          isPlayed: false,
          transcriptProgressMs: 0,
          transcriptStatus: 'none',
        ),
    ];

    final fromTop = podcastPlaybackQueueWindow(episodes, 'episode-0');
    expect(fromTop.first.id, 'episode-0');
    expect(fromTop, hasLength(21), reason: 'nothing precedes the newest one');

    final fromMiddle = podcastPlaybackQueueWindow(episodes, 'episode-10');
    expect(fromMiddle.first.id, 'episode-8');
    expect(fromMiddle.last.id, 'episode-30');

    final fromEnd = podcastPlaybackQueueWindow(episodes, 'episode-39');
    expect(fromEnd.last.id, 'episode-39');
    expect(fromEnd, hasLength(3));

    expect(podcastPlaybackQueueWindow(episodes, 'episode-nope'), isEmpty);
  });

  testWidgets('starting an episode queues a window, not the whole feed', (
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

    for (var index = 0; index < 60; index++) {
      await _insertPodcast(
        database,
        episodeId: 'episode-$index',
        transcriptStatus: 'none',
        title: 'Episode $index',
        publishedAt: 60 - index,
      );
    }

    await tester.pumpWidget(
      _podcastApp(
        database: database,
        handler: handler,
        sleepTimer: sleepTimer,
        service: service,
        episodeId: 'episode-0',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('player-primary-audio-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(handler.loadedPodcastEpisodeId, 'episode-0');
    expect(
      handler.loadedQueueEpisodeIds,
      hasLength(lessThanOrEqualTo(23)),
      reason: 'a whole subscribed feed must not be handed to the platform',
    );
    expect(handler.loadedQueueEpisodeIds.first, 'episode-0');
    expect(
      handler.loadedQueueEpisodeIds[1],
      'episode-1',
      reason: 'auto-advance still needs what comes next',
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

    // The cached chunks are kept and readable; the more menu offers to
    // continue the run.
    expect(
      find.byKey(const ValueKey('podcast-transcription-bar')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('player-more-menu')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('player-menu-transcription-resume')),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('First cached chunk.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });
  testWidgets(
    'reopening automatically loads persisted subtitles without ASR setup',
    (tester) async {
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
        episodeId: 'saved-reopen',
        transcriptStatus: 'complete',
        transcriptProgressMs: 3600000,
        transcriptJson:
            '[{"text":"Saved across opens.","startMs":0,"endMs":1200}]',
      );
      for (var open = 0; open < 2; open++) {
        await tester.pumpWidget(
          _podcastApp(
            database: database,
            handler: handler,
            sleepTimer: sleepTimer,
            service: service,
            episodeId: 'saved-reopen',
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byKey(const ValueKey('player-transcript-toggle'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('Saved across opens.'), findsOneWidget);
        expect(service.modelChecks, 0);
        expect(find.byType(SnackBar), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );
}

class _ReadyChatLlmController extends LlmSettingsController {
  @override
  Future<LlmSettingsState> build() async => const LlmSettingsState(
    providerId: 'test',
    providerName: 'Test AI',
    modelId: 'test-model',
    readiness: ServiceReadiness.ready,
    providers: [],
    configurations: [],
  );
}

Future<void> _insertPodcast(
  AppDatabase database, {
  required String episodeId,
  required String transcriptStatus,
  String? transcriptJson,
  int transcriptProgressMs = 0,
  String title = 'Interruptible Episode',
  int publishedAt = 1,
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
      title: title,
      description: 'Shownotes.',
      audioUrl: 'https://example.com/episode.mp3',
      publishedAt: publishedAt,
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
  int modelChecks = 0;

  @override
  Future<bool> isModelInstalled() async {
    modelChecks++;
    return false;
  }

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
  List<String> loadedQueueEpisodeIds = const [];
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
    loadedQueueEpisodeIds = [for (final episode in episodes) episode.episodeId];
    queue.add([
      for (final episode in episodes)
        MediaItem(
          id: episode.episodeId,
          title: episode.title,
          album: episode.showTitle,
          extras: {
            'mediaType': 'podcast',
            'podcastEpisodeId': episode.episodeId,
            'podcastShowId': episode.showId,
            'audioUrl': episode.audioUrl,
          },
        ),
    ]);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final item = queue.value[index];
    mediaItem.add(item);
    selectPodcastEpisode(item.extras!['podcastEpisodeId'] as String);
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

  void setProcessingState(AudioProcessingState state) {
    playbackState.add(playbackState.value.copyWith(processingState: state));
  }

  void selectPodcastEpisode(String episodeId) {
    loadedPodcastEpisodeId = episodeId;
    // The real handler always publishes the media item alongside the paragraph
    // change; surfaces that branch on "is my episode loaded" watch that stream.
    mediaItem.add(
      MediaItem(
        id: episodeId,
        title: episodeId,
        extras: {
          'mediaType': 'podcast',
          'podcastEpisodeId': episodeId,
          'podcastShowId': 'show-pause-ui',
          'audioUrl': 'https://example.com/episode.mp3',
        },
      ),
    );
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
