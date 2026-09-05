import '../data/database/app_database.dart';

/// Persistence boundary shared by podcast and audiobook ASR jobs.
class TranscriptionStorage {
  final AppDatabase database;
  TranscriptionStorage(this.database);

  Future<PodcastEpisode?> read(String id) => database.getPodcastEpisode(id);

  Future<void> update(
    String id, {
    required String status,
    String? transcriptJson,
    String? language,
    String? error,
    int? progressMs,
  }) => database.updatePodcastTranscript(
    id,
    status: status,
    transcriptJson: transcriptJson,
    language: language,
    error: error,
    progressMs: progressMs,
  );

  Future<void> clear(String id) => database.clearPodcastTranscript(id);

  Future<void> saveAudioPath(String id, String path) =>
      database.updatePodcastLocalAudioPath(id, path);

  String get audioDirectory => 'podcasts';
}
