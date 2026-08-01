import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/services/podcast_transcription_service.dart';

void main() {
  group('planPodcastChunks', () {
    test('covers the episode from the start when nothing was cached', () {
      final plan = planPodcastChunks(
        durationMs: 500000,
        startFromMs: 0,
        chunkDurationMs: 180000,
      );

      expect(plan.map((window) => window.startMs), [0, 180000, 360000]);
      expect(plan.map((window) => window.durationMs), [180000, 180000, 140000]);
    });

    test('resumes at the watermark without repeating or skipping audio', () {
      final plan = planPodcastChunks(
        durationMs: 500000,
        startFromMs: 360000,
        chunkDurationMs: 180000,
      );

      expect(plan, hasLength(1));
      expect(plan.single.startMs, 360000);
      expect(plan.single.durationMs, 140000);
    });

    test(
      'keeps the seam tight when the chunk size changed since the pause',
      () {
        final plan = planPodcastChunks(
          durationMs: 500000,
          startFromMs: 180000,
          chunkDurationMs: 60000,
        );

        expect(plan.first.startMs, 180000);
        final end = plan.last.startMs + plan.last.durationMs;
        expect(end, 500000);
        for (var index = 1; index < plan.length; index++) {
          final previous = plan[index - 1];
          expect(
            plan[index].startMs,
            previous.startMs + previous.durationMs,
            reason: 'chunks must be contiguous',
          );
        }
      },
    );

    test('is empty once the watermark reached the end', () {
      expect(
        planPodcastChunks(
          durationMs: 500000,
          startFromMs: 500000,
          chunkDurationMs: 180000,
        ),
        isEmpty,
      );
    });

    test('falls back to a bounded schedule without a usable duration', () {
      final plan = planPodcastChunks(
        durationMs: 0,
        startFromMs: 120000,
        chunkDurationMs: 60000,
        maxUnknownChunks: 4,
      );

      expect(plan, hasLength(4));
      expect(plan.first.startMs, 120000);
      expect(plan.last.startMs, 300000);
    });
  });

  group('transcript watermark', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() => database.close());

    Future<void> insertEpisode() async {
      await database.upsertPodcastShow(
        const PodcastShow(
          id: 'show-pause',
          feedUrl: 'https://example.com/feed.xml',
          title: 'Example Podcast',
          description: '',
          subscribedAt: 1,
          lastRefreshedAt: 1,
        ),
      );
      await database.upsertPodcastEpisode(
        const PodcastEpisode(
          id: 'episode-pause',
          showId: 'show-pause',
          guid: 'episode-pause-guid',
          title: 'Paused Episode',
          description: '',
          audioUrl: 'https://example.com/episode.mp3',
          publishedAt: 1,
          durationMs: 500000,
          playbackPositionMs: 0,
          lastPlayedAt: 0,
          isPlayed: false,
          transcriptStatus: 'none',
          transcriptProgressMs: 0,
        ),
      );
    }

    test('a paused run keeps its chunks and its resume offset', () async {
      await insertEpisode();
      await database.updatePodcastTranscript(
        'episode-pause',
        status: podcastTranscriptPausedStatus,
        transcriptJson: '[{"text":"Cached.","startMs":0,"endMs":900}]',
        language: 'en',
        progressMs: 180000,
      );

      final episode = await database.getPodcastEpisode('episode-pause');
      expect(episode?.transcriptStatus, podcastTranscriptPausedStatus);
      expect(episode?.transcriptProgressMs, 180000);
      expect(episode?.transcriptJson, contains('Cached.'));
    });

    test('a status-only write leaves the resume offset alone', () async {
      await insertEpisode();
      await database.updatePodcastTranscript(
        'episode-pause',
        status: podcastTranscriptPausedStatus,
        progressMs: 180000,
      );
      await database.updatePodcastTranscript(
        'episode-pause',
        status: 'failed',
        error: 'boom',
      );

      final episode = await database.getPodcastEpisode('episode-pause');
      expect(episode?.transcriptProgressMs, 180000);
    });

    test('clearing the transcript sends the next run back to zero', () async {
      await insertEpisode();
      await database.updatePodcastTranscript(
        'episode-pause',
        status: podcastTranscriptPausedStatus,
        transcriptJson: '[{"text":"Cached.","startMs":0,"endMs":900}]',
        progressMs: 180000,
      );
      await database.clearPodcastTranscript('episode-pause');

      final episode = await database.getPodcastEpisode('episode-pause');
      expect(episode?.transcriptProgressMs, 0);
      expect(episode?.transcriptStatus, 'none');
      expect(episode?.transcriptJson, isNull);
    });
  });

  test('pausing an idle service is a no-op', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final service = PodcastTranscriptionService(database);
    addTearDown(service.dispose);

    expect(service.activeEpisodeId, isNull);
    await service.pause();
    expect(service.activeEpisodeId, isNull);
  });
}
