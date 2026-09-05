import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database/app_database.dart';
import '../domain/models/audio_text_timing.dart';
import '../domain/models/chapter_manifest.dart';
import 'manifest_store.dart';
import 'transcription_storage.dart';

/// Adapts a recorded chapter to the shared ASR engine without creating a
/// podcast show or episode. Text and timing keep the existing audio identity.
class AudiobookTranscriptionStorage extends TranscriptionStorage {
  final ManifestStore manifests;
  final Book book;
  final Chapter chapter;

  AudiobookTranscriptionStorage(
    super.database, {
    required this.manifests,
    required this.book,
    required this.chapter,
  });

  String get key => 'audiobook_asr:${chapter.id}';

  @override
  String get audioDirectory => 'audiobooks';

  Stream<String?> watch() =>
      (database.select(database.appSettings)
            ..where((row) => row.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value)
          .distinct();

  Future<Map<String, dynamic>> _state() async {
    final raw = await database.getSetting(key);
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<PodcastEpisode?> read(String id) async {
    if (id != chapter.id) throw ArgumentError.value(id, 'chapterId');
    final manifest = await manifests.load(book.id, chapter.id);
    if (manifest == null || manifest.segments.length != 1) {
      throw StateError('This chapter has no original recording.');
    }
    final state = await _state();
    return PodcastEpisode(
      id: chapter.id,
      showId: book.id,
      guid: chapter.id,
      title: chapter.title,
      description: '',
      audioUrl: manifest.segments.single.audioFile,
      publishedAt: 0,
      durationMs: manifest.totalDurationMs,
      playbackPositionMs: 0,
      lastPlayedAt: 0,
      isPlayed: false,
      localAudioPath: state['localAudioPath'] as String?,
      transcriptJson: state['transcriptJson'] as String?,
      transcriptStatus: state['status'] as String? ?? 'none',
      transcriptLanguage: state['language'] as String?,
      transcriptError: state['error'] as String?,
      transcriptProgressMs: state['progressMs'] as int? ?? 0,
    );
  }

  @override
  Future<void> update(
    String id, {
    required String status,
    String? transcriptJson,
    String? language,
    String? error,
    int? progressMs,
  }) async {
    if (id != chapter.id) throw ArgumentError.value(id, 'chapterId');
    // The user may delete this chapter while an ASR chunk is in flight.
    if (await database.getChapter(id) == null) {
      throw StateError('The chapter was removed.');
    }
    final state = await _state();
    state['status'] = status;
    state['error'] = error;
    if (language != null) state['language'] = language;
    if (progressMs != null) state['progressMs'] = progressMs;
    if (transcriptJson != null) {
      state['transcriptJson'] = transcriptJson;
      final timings = (jsonDecode(transcriptJson) as List)
          .map(
            (item) => AudioTextTiming.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      final manifest = await manifests.load(book.id, chapter.id);
      if (manifest == null || manifest.segments.length != 1) {
        throw StateError('The original recording is unavailable.');
      }
      final segment = manifest.segments.single;
      await manifests.save(
        ChapterManifest(
          chapterId: manifest.chapterId,
          bookId: manifest.bookId,
          providerId: manifest.providerId,
          voiceId: manifest.voiceId,
          speed: manifest.speed,
          configurationFingerprint: manifest.configurationFingerprint,
          segments: [segment.copyWith(timings: timings)],
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await (database.update(
        database.paragraphs,
      )..where((row) => row.id.equals(segment.paragraphId))).write(
        ParagraphsCompanion(
          content: Value(timings.map((timing) => timing.text).join(' ')),
        ),
      );
    }
    // Notify only after both text and manifest are durable.
    await database.setSetting(key, jsonEncode(state));
  }

  @override
  Future<void> clear(String id) =>
      update(id, status: 'none', transcriptJson: '[]', progressMs: 0);

  @override
  Future<void> saveAudioPath(String id, String path) async {
    final state = await _state();
    state['localAudioPath'] = path;
    await database.setSetting(key, jsonEncode(state));
  }
}
