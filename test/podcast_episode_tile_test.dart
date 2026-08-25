import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/podcast/podcast_episode_tile.dart';

void main() {
  testWidgets('episode rows reveal read, hide, and delete on left swipe', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const episode = PodcastEpisode(
      id: 'swipe-episode',
      showId: 'show-1',
      guid: 'swipe-guid',
      title: 'Swipe episode',
      description: '',
      audioUrl: 'https://example.com/swipe.mp3',
      publishedAt: 1,
      durationMs: 60000,
      playbackPositionMs: 12000,
      lastPlayedAt: 0,
      isPlayed: false,
      transcriptProgressMs: 0,
      transcriptStatus: 'none',
    );
    await database.upsertPodcastEpisode(episode);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: PodcastEpisodeTile(
              episode: episode,
              enableSwipeActions: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var row = find.byKey(const ValueKey('podcast-episode-swipe-swipe-episode'));
    await tester.drag(row, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row, matching: find.text('Mark as read')),
    );
    await tester.pumpAndSettle();
    expect((await database.getPodcastEpisode(episode.id))?.isPlayed, isTrue);

    row = find.byKey(const ValueKey('podcast-episode-swipe-swipe-episode'));
    await tester.drag(row, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: row, matching: find.text('Hide')));
    await tester.pumpAndSettle();
    expect(await database.getPodcastEpisodes(episode.showId), isEmpty);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await database.getPodcastEpisodes(episode.showId), hasLength(1));

    row = find.byKey(const ValueKey('podcast-episode-swipe-swipe-episode'));
    await tester.drag(row, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: row, matching: find.text('Delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete episode?'), findsOneWidget);
  });

  testWidgets('episode actions can mark an episode as finished', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final hapticCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(call);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    const episode = PodcastEpisode(
      id: 'finishable-episode',
      showId: 'show-1',
      guid: 'finishable-guid',
      title: 'A finishable episode',
      description: '',
      audioUrl: 'https://example.com/episode.mp3',
      publishedAt: 1,
      durationMs: 60000,
      playbackPositionMs: 12000,
      lastPlayedAt: 0,
      isPlayed: false,
      transcriptProgressMs: 0,
      transcriptStatus: 'none',
    );
    await database.upsertPodcastEpisode(episode);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: PodcastEpisodeTile(episode: episode, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(
      const ValueKey('podcast-episode-finishable-episode'),
    );
    final scale = find.descendant(
      of: card,
      matching: find.byType(AnimatedScale),
    );
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: card, matching: find.byType(InkWell)),
    );
    inkWell.onHighlightChanged!(true);
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, lessThan(1));
    await tester.pump(const Duration(milliseconds: 75));
    inkWell.onHighlightChanged!(false);
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_horiz), findsNothing);
    await tester.longPress(card);
    await tester.pumpAndSettle();
    expect(
      hapticCalls.any(
        (call) => call.arguments == 'HapticFeedbackType.mediumImpact',
      ),
      isTrue,
    );
    expect(find.text('Mark as finished'), findsOneWidget);
    expect(find.text('Download episode'), findsOneWidget);

    await tester.tap(find.text('Mark as finished'));
    await tester.pumpAndSettle();

    final updated = await database.getPodcastEpisode(episode.id);
    expect(updated?.isPlayed, isTrue);
    expect(updated?.playbackPositionMs, episode.durationMs);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('transcript actions live in the episode long-press menu', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const episode = PodcastEpisode(
      id: 'transcript-menu-episode',
      showId: 'show-1',
      guid: 'transcript-menu-guid',
      title: 'Transcript menu episode',
      description: '',
      audioUrl: 'https://example.com/episode.mp3',
      publishedAt: 1,
      durationMs: 60000,
      playbackPositionMs: 0,
      lastPlayedAt: 0,
      isPlayed: false,
      transcriptProgressMs: 0,
      transcriptJson:
          '[{"text":"A cached transcript.","startMs":0,"endMs":1200}]',
      transcriptStatus: 'complete',
    );
    await database.upsertPodcastEpisode(episode);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: PodcastEpisodeTile(episode: episode, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(
      const ValueKey('podcast-episode-transcript-menu-episode'),
    );
    await tester.longPress(card);
    await tester.pumpAndSettle();
    expect(find.text('Delete transcript'), findsOneWidget);
    expect(find.text('Regenerate transcript'), findsNothing);

    await tester.tap(find.text('Delete transcript'));
    await tester.pumpAndSettle();
    expect(find.text('Delete transcript?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    final cleared = await database.getPodcastEpisode(episode.id);
    expect(cleared?.transcriptJson, isNull);
    expect(cleared?.transcriptStatus, 'none');

    await tester.longPress(card);
    await tester.pumpAndSettle();
    expect(find.text('Delete transcript'), findsNothing);
  });
}
