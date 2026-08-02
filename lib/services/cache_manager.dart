import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database/app_database.dart';
import '../domain/models/chapter_manifest.dart';
import 'manifest_store.dart';
import 'generation_orchestrator.dart';

/// 缓存统计。
class CacheUsage {
  final int bytes;
  const CacheUsage(this.bytes);

  double get mb => bytes / 1024 / 1024;

  String get humanReadable {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

/// 本地 TTS 音频缓存管理。
class CacheManager {
  final ManifestStore manifestStore;
  final GenerationOrchestrator generationOrchestrator;
  final AppDatabase database;

  CacheManager(this.manifestStore, this.generationOrchestrator, this.database);

  Future<CacheUsage> usageForBook(String bookId) async {
    return CacheUsage(await manifestStore.bookCacheSizeBytes(bookId));
  }

  Future<CacheUsage> usageForChapter(String bookId, String chapterId) async {
    return CacheUsage(
      await manifestStore.chapterCacheSizeBytes(bookId, chapterId),
    );
  }

  Future<CacheUsage> totalUsage() async {
    final book = await bookAudioUsage();
    final podcast = await podcastAudioUsage();
    return CacheUsage(book.bytes + podcast.bytes);
  }

  Future<CacheUsage> bookAudioUsage() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioRoot = Directory(p.join(dir.path, 'audio'));
    if (!await audioRoot.exists()) return const CacheUsage(0);
    int total = 0;
    await for (final entity in audioRoot.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return CacheUsage(total);
  }

  Future<CacheUsage> podcastAudioUsage() async {
    var total = 0;
    for (final episode in await database.getAllPodcastEpisodes()) {
      total += (await usageForPodcastEpisode(episode)).bytes;
    }
    return CacheUsage(total);
  }

  Future<CacheUsage> usageForPodcastEpisode(PodcastEpisode episode) async {
    final file = await _resolvePodcastAudioFile(episode);
    if (file == null) return const CacheUsage(0);
    return CacheUsage(await file.length());
  }

  Future<CacheUsage> usageForPodcastShow(String showId) async {
    var total = 0;
    for (final episode in await database.getPodcastEpisodes(showId)) {
      total += (await usageForPodcastEpisode(episode)).bytes;
    }
    return CacheUsage(total);
  }

  /// 清理整本书音频。
  Future<void> clearBook(String bookId) =>
      generationOrchestrator.runBookExclusive(bookId, () async {
        await manifestStore.deleteBook(bookId);
        await database.deleteGenerationTasks(kind: 'tts', parentId: bookId);
      });

  /// 清缓存后继续执行重解析或删书，整个过程保持生成封锁。
  Future<T> clearBookAndRun<T>(String bookId, Future<T> Function() action) =>
      generationOrchestrator.runBookExclusive(bookId, () async {
        await manifestStore.deleteBook(bookId);
        await database.deleteGenerationTasks(kind: 'tts', parentId: bookId);
        return action();
      });

  /// 清理某章音频。
  Future<void> clearChapter(String bookId, String chapterId) =>
      generationOrchestrator.runBookExclusive(bookId, () async {
        await manifestStore.deleteChapter(bookId, chapterId);
        await database.deleteGenerationTasks(
          kind: 'tts',
          parentId: bookId,
          scopeId: chapterId,
        );
      });

  /// 清理全部生成音频。
  Future<void> clearAll() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioRoot = Directory(p.join(dir.path, 'audio'));
    await generationOrchestrator.runAllExclusive(() async {
      await _deleteDirectoryContents(audioRoot, removeRoot: true);
      await database.deleteGenerationTasks(kind: 'tts');
    });
    await clearAllPodcastAudio();
  }

  Future<void> clearPodcastEpisodeAudio(String episodeId) async {
    final episode = await database.getPodcastEpisode(episodeId);
    if (episode == null) return;
    final resolvedFile = await _resolvePodcastAudioFile(episode);
    final paths = <String>{
      if (episode.localAudioPath case final path? when path.isNotEmpty) path,
      if (resolvedFile != null) resolvedFile.path,
    };
    for (final path in paths) {
      for (final candidate in <String>{path, '$path.partial', '$path.wav'}) {
        final file = File(candidate);
        if (await file.exists()) await file.delete();
      }
    }
    await database.updatePodcastLocalAudioPath(episodeId, null);
  }

  Future<File?> _resolvePodcastAudioFile(PodcastEpisode episode) async {
    final persistedPath = episode.localAudioPath;
    if (persistedPath == null || persistedPath.isEmpty) return null;

    final persisted = File(persistedPath);
    if (await persisted.exists() && await persisted.length() > 0) {
      return persisted;
    }

    final support = await getApplicationSupportDirectory();
    final audioDirectory = Directory(p.join(support.path, 'podcasts', 'audio'));
    if (!await audioDirectory.exists()) return null;
    await for (final entity in audioDirectory.list(followLinks: false)) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      if (fileName.endsWith('.partial') ||
          !fileName.startsWith('${episode.id}.') ||
          await entity.length() == 0) {
        continue;
      }
      if (entity.path != persistedPath) {
        await database.updatePodcastLocalAudioPath(episode.id, entity.path);
      }
      return entity;
    }
    return null;
  }

  Future<void> clearPodcastEpisodeTranscript(String episodeId) async {
    await database.clearPodcastTranscript(episodeId);
    await database.deleteGenerationTasks(kind: 'whisper', scopeId: episodeId);
  }

  Future<void> clearPodcastEpisodeData(String episodeId) async {
    await clearPodcastEpisodeAudio(episodeId);
    await clearPodcastEpisodeTranscript(episodeId);
  }

  Future<void> clearPodcastShowAudio(String showId) async {
    for (final episode in await database.getPodcastEpisodes(showId)) {
      await clearPodcastEpisodeAudio(episode.id);
    }
  }

  Future<void> clearPodcastShowTranscripts(String showId) async {
    for (final episode in await database.getPodcastEpisodes(showId)) {
      await clearPodcastEpisodeTranscript(episode.id);
    }
  }

  Future<void> clearPodcastShowData(String showId) async {
    await clearPodcastShowAudio(showId);
    await clearPodcastShowTranscripts(showId);
  }

  Future<void> clearAllPodcastAudio() async {
    for (final episode in await database.getAllPodcastEpisodes()) {
      await clearPodcastEpisodeAudio(episode.id);
    }
  }

  /// 清理某书中除最近 N 章以外的音频。
  /// 调用方传入要保留的 chapterIds。
  Future<void> clearBookExcept(
    String bookId,
    Set<String> keepChapterIds,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(dir.path, 'audio', bookId));
    if (!await root.exists()) return;

    await for (final entity in root.list(followLinks: false)) {
      final base = p.basename(entity.path);
      if (entity is File && base.endsWith('.manifest.json')) {
        final chapterId = base.replaceFirst('.manifest.json', '');
        if (!keepChapterIds.contains(chapterId)) {
          await entity.delete();
        }
      } else if (entity is Directory) {
        final chapterId = p.basename(entity.path);
        if (!keepChapterIds.contains(chapterId)) {
          await entity.delete(recursive: true);
        }
      }
    }
  }

  /// 把一个 manifest 标记成未生成状态，用于 UI 清理后刷新。
  ChapterManifest resetManifest(ChapterManifest manifest) {
    return ChapterManifest(
      chapterId: manifest.chapterId,
      bookId: manifest.bookId,
      providerId: manifest.providerId,
      voiceId: manifest.voiceId,
      speed: manifest.speed,
      configurationFingerprint: manifest.configurationFingerprint,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      segments: manifest.segments
          .map(
            (s) => s.copyWith(
              durationMs: 0,
              state: ParagraphAudioState.notGenerated,
              billedCharacters: null,
              generatedAt: null,
              error: null,
            ),
          )
          .toList(),
    );
  }

  Future<void> _deleteDirectoryContents(
    Directory dir, {
    required bool removeRoot,
  }) async {
    if (!await dir.exists()) return;

    final failures = <String>[];
    final directories = <Directory>[];

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is Directory) {
        directories.add(entity);
        continue;
      }
      try {
        await entity.delete();
      } catch (e) {
        failures.add('${entity.path}: $e');
      }
    }

    directories.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final child in directories) {
      try {
        if (await child.exists()) await child.delete();
      } catch (e) {
        failures.add('${child.path}: $e');
      }
    }

    if (removeRoot) {
      try {
        if (await dir.exists()) await dir.delete();
      } catch (e) {
        failures.add('${dir.path}: $e');
      }
    }

    if (failures.isNotEmpty) {
      throw FileSystemException(
        '部分缓存未能删除，可能仍在生成或播放中',
        failures.take(3).join('\n'),
      );
    }
  }
}
