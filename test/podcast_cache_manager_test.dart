import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/services/cache_manager.dart';
import 'package:lumina/services/generation_orchestrator.dart';
import 'package:lumina/services/manifest_store.dart';
import 'package:lumina/services/podcast_transcription_service.dart';

void main() {
  test('podcast audio and transcripts can be cleared independently', () async {
    final tempDir = Directory.systemTemp.createTempSync('podcast_cache_');
    final audio = File('${tempDir.path}/episode.mp3')
      ..writeAsBytesSync(List<int>.filled(2048, 1));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final manifestStore = ManifestStore();
    final cache = CacheManager(
      manifestStore,
      GenerationOrchestrator(database: database, manifestStore: manifestStore),
      database,
      transcriptionService: PodcastTranscriptionService(database),
      supportDirectory: () async => tempDir,
    );
    addTearDown(() async {
      await database.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    await database.upsertPodcastShow(
      const PodcastShow(
        id: 'cache-show',
        feedUrl: 'https://example.com/cache.xml',
        title: 'Cache Show',
        description: '',
        subscribedAt: 1,
        lastRefreshedAt: 1,
      ),
    );
    await database.upsertPodcastEpisode(
      PodcastEpisode(
        id: 'cache-episode',
        showId: 'cache-show',
        guid: 'cache-guid',
        title: 'Cache Episode',
        description: '',
        audioUrl: 'https://example.com/cache.mp3',
        publishedAt: 1,
        durationMs: 60000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptProgressMs: 0,
        localAudioPath: audio.path,
        transcriptJson: '[{"text":"cached","startMs":0,"endMs":1}]',
        transcriptLanguage: 'en',
        transcriptStatus: 'complete',
      ),
    );

    final episode = (await database.getPodcastEpisode('cache-episode'))!;
    expect((await cache.usageForPodcastEpisode(episode)).bytes, 2048);
    final downloadedPath = await PodcastTranscriptionService(
      database,
    ).downloadEpisodeAudio(episode);
    expect(downloadedPath, audio.path);

    await cache.clearPodcastEpisodeAudio(episode.id);
    final audioCleared = await database.getPodcastEpisode(episode.id);
    expect(audio.existsSync(), isFalse);
    expect(audioCleared?.localAudioPath, isNull);
    expect(audioCleared?.transcriptJson, isNotNull);

    await cache.clearPodcastEpisodeTranscript(episode.id);
    final transcriptCleared = await database.getPodcastEpisode(episode.id);
    expect(transcriptCleared?.transcriptJson, isNull);
    expect(transcriptCleared?.transcriptLanguage, isNull);
    expect(transcriptCleared?.transcriptStatus, 'none');
  });
}
