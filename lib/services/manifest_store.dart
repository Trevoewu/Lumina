import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/models/chapter_manifest.dart';
import 'app_log_service.dart';
import 'wav_audio_utils.dart';

/// ChapterManifest 的本地持久化服务。
///
/// 存储布局：
/// app_data/audio/{bookId}/{chapterId}.manifest.json
/// app_data/audio/{bookId}/{chapterId}/{paragraphId}.mp3
class ManifestStore {
  Future<Directory> _audioRoot(String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(dir.path, 'audio', bookId));
    await root.create(recursive: true);
    return root;
  }

  /// app_data/audio/{bookId}，用于播放器按 manifest 中的相对路径加载分片。
  Future<Directory> audioRoot(String bookId) => _audioRoot(bookId);

  Future<File> manifestFile(String bookId, String chapterId) async {
    final root = await _audioRoot(bookId);
    return File(p.join(root.path, '$chapterId.manifest.json'));
  }

  Future<Directory> chapterAudioDir(String bookId, String chapterId) async {
    final root = await _audioRoot(bookId);
    final dir = Directory(p.join(root.path, chapterId));
    await dir.create(recursive: true);
    return dir;
  }

  Future<String> segmentPath({
    required String bookId,
    required String chapterId,
    required String paragraphId,
    required String format,
  }) async {
    final dir = await chapterAudioDir(bookId, chapterId);
    return p.join(dir.path, '$paragraphId.$format');
  }

  Future<ChapterManifest?> load(String bookId, String chapterId) async {
    final file = await manifestFile(bookId, chapterId);
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final manifest = ChapterManifest.fromJson(json);
    final repaired = await repairManifestWavDurations(
      manifest,
      await _audioRoot(bookId),
    );
    if (!identical(repaired, manifest)) await save(repaired);
    return repaired;
  }

  Future<void> save(ChapterManifest manifest) async {
    final file = await manifestFile(manifest.bookId, manifest.chapterId);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
  }

  Future<void> deleteChapter(String bookId, String chapterId) async {
    final file = await manifestFile(bookId, chapterId);
    if (await file.exists()) await file.delete();
    final dir = await chapterAudioDir(bookId, chapterId);
    await _deleteDirectoryIfExists(dir);
  }

  Future<void> deleteBook(String bookId) async {
    final root = await _audioRoot(bookId);
    await _deleteDirectoryIfExists(root);
  }

  Future<int> bookCacheSizeBytes(String bookId) async {
    final root = await _audioRoot(bookId);
    if (!await root.exists()) return 0;
    int total = 0;
    await for (final entity in root.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<int> chapterCacheSizeBytes(String bookId, String chapterId) async {
    final root = await _audioRoot(bookId);
    int total = 0;
    final manifest = File(p.join(root.path, '$chapterId.manifest.json'));
    if (await manifest.exists()) total += await manifest.length();

    final chapterDir = Directory(p.join(root.path, chapterId));
    if (!await chapterDir.exists()) return total;
    await for (final entity in chapterDir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> _deleteDirectoryIfExists(Directory dir) async {
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

    try {
      if (await dir.exists()) await dir.delete();
    } catch (e) {
      failures.add('${dir.path}: $e');
    }

    if (failures.isNotEmpty) {
      throw FileSystemException(
        '部分缓存未能删除，可能仍在生成或播放中',
        failures.take(3).join('\n'),
      );
    }
  }
}

Future<ChapterManifest> repairManifestWavDurations(
  ChapterManifest manifest,
  Directory audioRoot,
) async {
  var changed = false;
  final repairedSegments = <SegmentEntry>[];

  for (final segment in manifest.segments) {
    final isWav =
        segment.format.toLowerCase() == 'wav' ||
        segment.audioFile.toLowerCase().endsWith('.wav');
    if (!isWav || segment.state != ParagraphAudioState.ready) {
      repairedSegments.add(segment);
      continue;
    }

    final audioFile = File(p.join(audioRoot.path, segment.audioFile));
    if (!await audioFile.exists()) {
      repairedSegments.add(segment);
      continue;
    }

    final fileLength = await audioFile.length();
    if (fileLength < 44) {
      repairedSegments.add(segment);
      continue;
    }
    final handle = await audioFile.open();
    late final List<int> header;
    try {
      header = await handle.read(math.min(fileLength, 64 * 1024));
    } finally {
      await handle.close();
    }
    final actualDurationMs = wavDurationMs(
      Uint8List.fromList(header),
      totalBytes: fileLength,
    );
    final toleranceMs = math.max(1000, (actualDurationMs * 0.2).round());
    if (actualDurationMs <= 0 ||
        (segment.durationMs - actualDurationMs).abs() <= toleranceMs) {
      repairedSegments.add(segment);
      continue;
    }

    changed = true;
    repairedSegments.add(segment.copyWith(durationMs: actualDurationMs));
    AppLogger.warning(
      'Cache',
      '修复 WAV 时长 chapter=${manifest.chapterId} '
          'paragraph=${segment.paragraphId} '
          '${segment.durationMs}ms -> ${actualDurationMs}ms',
    );
  }

  if (!changed) return manifest;
  return ChapterManifest(
    chapterId: manifest.chapterId,
    bookId: manifest.bookId,
    providerId: manifest.providerId,
    voiceId: manifest.voiceId,
    speed: manifest.speed,
    segments: repairedSegments,
    updatedAt: manifest.updatedAt,
  );
}
