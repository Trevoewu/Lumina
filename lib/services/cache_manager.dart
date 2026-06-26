import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/models/chapter_manifest.dart';
import 'manifest_store.dart';

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

  CacheManager(this.manifestStore);

  Future<CacheUsage> usageForBook(String bookId) async {
    return CacheUsage(await manifestStore.bookCacheSizeBytes(bookId));
  }

  Future<CacheUsage> usageForChapter(String bookId, String chapterId) async {
    return CacheUsage(
      await manifestStore.chapterCacheSizeBytes(bookId, chapterId),
    );
  }

  Future<CacheUsage> totalUsage() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioRoot = Directory(p.join(dir.path, 'audio'));
    if (!await audioRoot.exists()) return const CacheUsage(0);
    int total = 0;
    await for (final entity in audioRoot.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return CacheUsage(total);
  }

  /// 清理整本书音频。
  Future<void> clearBook(String bookId) => manifestStore.deleteBook(bookId);

  /// 清理某章音频。
  Future<void> clearChapter(String bookId, String chapterId) =>
      manifestStore.deleteChapter(bookId, chapterId);

  /// 清理全部生成音频。
  Future<void> clearAll() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioRoot = Directory(p.join(dir.path, 'audio'));
    await _deleteDirectoryContents(audioRoot, removeRoot: true);
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
