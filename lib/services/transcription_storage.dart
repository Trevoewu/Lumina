import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

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

/// A refresh can replace an episode while native ASR or a download is running.
/// Serialize the source check and database write with feed updates.
class TranscriptionSourceChanged implements Exception {
  @override
  String toString() => '音频来源已更新，请重新开始转写。';
}

class SourceBoundTranscriptionStorage extends TranscriptionStorage {
  final TranscriptionStorage delegate;
  final PodcastEpisode source;

  SourceBoundTranscriptionStorage(this.delegate, this.source)
    : super(delegate.database);

  @override
  String get audioDirectory => delegate.audioDirectory;

  @override
  Future<PodcastEpisode?> read(String id) async {
    final current = await delegate.read(id);
    if (current == null || current.audioUrl != source.audioUrl) {
      throw TranscriptionSourceChanged();
    }
    return current;
  }

  Future<void> _write(String id, Future<void> Function() action) =>
      database.transaction(() async {
        await read(id);
        await action();
      });

  @override
  Future<void> update(
    String id, {
    required String status,
    String? transcriptJson,
    String? language,
    String? error,
    int? progressMs,
  }) => _write(
    id,
    () => delegate.update(
      id,
      status: status,
      transcriptJson: transcriptJson,
      language: language,
      error: error,
      progressMs: progressMs,
    ),
  );

  @override
  Future<void> clear(String id) => _write(id, () => delegate.clear(id));

  @override
  Future<void> saveAudioPath(String id, String path) =>
      _write(id, () => delegate.saveAudioPath(id, path));
}

/// Source-specific filenames prevent a changed enclosure from finding the old
/// episode-id-only file after the feed has cleared localAudioPath.
String transcriptionAudioFileName(PodcastEpisode episode) {
  final extension = p
      .extension(Uri.tryParse(episode.audioUrl)?.path ?? '')
      .toLowerCase();
  const supported = {
    '.mp3',
    '.m4a',
    '.aac',
    '.wav',
    '.ogg',
    '.opus',
    '.mp4',
    '.flac',
  };
  final suffix = supported.contains(extension) ? extension : '.audio';
  final source = sha256.convert(utf8.encode(episode.audioUrl));
  return '${episode.id}.$source$suffix';
}
