import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../data/database/app_database.dart' as db;
import '../domain/models/audio_text_timing.dart';
import '../domain/models/book_rights.dart';
import '../domain/models/chapter_manifest.dart';
import '../tts/models/tts_chunk.dart';
import '../tts/models/tts_voice.dart';
import '../tts/tts_provider.dart';
import 'app_log_service.dart';
import 'generation_task_store.dart';
import 'manifest_store.dart';

/// 章节生成进度。
class GenerationProgress {
  final String chapterId;
  final int ready;
  final int failed;
  final int generating;
  final int total;
  final String? currentParagraphId;
  final int? currentParagraphIndex;
  final String providerId;
  final String voiceId;
  final String? error;

  const GenerationProgress({
    required this.chapterId,
    required this.ready,
    required this.failed,
    required this.generating,
    required this.total,
    required this.providerId,
    required this.voiceId,
    this.currentParagraphId,
    this.currentParagraphIndex,
    this.error,
  });

  double get percent => total == 0 ? 0 : ready / total;

  int get pending => (total - ready - failed - generating).clamp(0, total);

  int get finished => ready + failed;

  bool get isDone => total > 0 && finished >= total;
}

/// 增量生成调度器。
///
/// 策略：用户打开某章时，只生成该章；不预读下一章。
/// 存储：方案 B，每段一个音频文件 + manifest。
class GenerationOrchestrator {
  final db.AppDatabase database;
  final ManifestStore manifestStore;
  final GenerationTaskStore taskStore;
  final Map<String, _ChapterGenerationJob> _activeChapterJobs = {};
  final Set<String> _blockedBooks = {};
  bool _allBooksBlocked = false;

  GenerationOrchestrator({
    required this.database,
    required this.manifestStore,
    GenerationTaskStore? taskStore,
  }) : taskStore = taskStore ?? GenerationTaskStore(database);

  /// 生成某章音频。若部分段落已生成，则断点续跑。
  Stream<GenerationProgress> generateChapter({
    required String bookId,
    required String chapterId,
    required TtsProvider provider,
    required TtsVoice voice,
    double speed = 1.0,
    int maxRetries = 3,
    int? priorityParagraphIndex,
    int prefetchCount = 3,
  }) {
    if (_allBooksBlocked || _blockedBooks.contains(bookId)) {
      return Stream<GenerationProgress>.error(
        StateError('书籍正在清理、重新解析或删除，暂时不能生成音频'),
      );
    }
    final generationKey = '$bookId\u0000$chapterId';
    final active = _activeChapterJobs[generationKey];
    if (active != null) {
      if (priorityParagraphIndex != null) {
        active.prioritize(priorityParagraphIndex, lookahead: prefetchCount);
      }
      AppLogger.info(
        'Generation',
        '复用同章节已有生成任务 book=$bookId chapter=$chapterId',
      );
      return active.stream;
    }

    final job = _ChapterGenerationJob();
    if (priorityParagraphIndex != null) {
      job.prioritize(priorityParagraphIndex, lookahead: prefetchCount);
    }
    _activeChapterJobs[generationKey] = job;
    unawaited(
      _runChapterGenerationJob(
        generationKey: generationKey,
        job: job,
        bookId: bookId,
        chapterId: chapterId,
        provider: provider,
        voice: voice,
        speed: speed,
        maxRetries: maxRetries,
        priorityParagraphIndex: priorityParagraphIndex,
        prefetchCount: prefetchCount,
      ),
    );
    return job.stream;
  }

  /// Promotes the current listening position and a small safety buffer while
  /// an existing chapter job is running. It never creates a hidden job.
  bool prioritizeChapter({
    required String bookId,
    required String chapterId,
    required int paragraphIndex,
    int lookahead = 3,
  }) {
    final job = _activeChapterJobs['$bookId\u0000$chapterId'];
    if (job == null) return false;
    job.prioritize(paragraphIndex, lookahead: lookahead);
    return true;
  }

  /// 订阅一个已经存在的章节生成任务，不会创建新的生成任务。
  ///
  /// 阅读页可以借此复用从章节列表或“缓存整本书”入口启动的任务，
  /// 并立即收到该任务最近一次的进度。
  Stream<GenerationProgress>? watchChapterGeneration({
    required String bookId,
    required String chapterId,
  }) {
    return _activeChapterJobs['$bookId\u0000$chapterId']?.stream;
  }

  /// 暂停章节生成。当前已发出的 TTS 请求会完成，但不会继续派发新段落。
  bool pauseChapter({required String bookId, required String chapterId}) {
    final job = _activeChapterJobs['$bookId\u0000$chapterId'];
    if (job == null) return false;
    job.pause();
    AppLogger.info('Generation', '暂停章节生成 book=$bookId chapter=$chapterId');
    return true;
  }

  /// 继续已暂停的章节生成。
  bool resumeChapter({required String bookId, required String chapterId}) {
    final job = _activeChapterJobs['$bookId\u0000$chapterId'];
    if (job == null) return false;
    job.resume();
    AppLogger.info('Generation', '继续章节生成 book=$bookId chapter=$chapterId');
    return true;
  }

  /// 取消章节生成，并等待所有已经发出的请求停止落盘。
  Future<bool> cancelChapter({
    required String bookId,
    required String chapterId,
  }) async {
    final job = _activeChapterJobs['$bookId\u0000$chapterId'];
    if (job == null) return false;
    job.cancel();
    await job.done;
    return true;
  }

  /// 在一本书上执行排他的破坏性操作。
  ///
  /// 操作期间禁止启动新生成；已有任务会被取消并完全退出，避免音频或
  /// manifest 在清理、重解析、删书后被异步写回。
  Future<T> runBookExclusive<T>(
    String bookId,
    Future<T> Function() action,
  ) async {
    if (_allBooksBlocked || !_blockedBooks.add(bookId)) {
      throw StateError('书籍已有清理、重新解析或删除任务正在执行');
    }
    try {
      final jobs = _activeChapterJobs.entries
          .where((entry) => entry.key.startsWith('$bookId\u0000'))
          .map((entry) => entry.value)
          .toList();
      for (final job in jobs) {
        job.cancel();
      }
      await Future.wait(jobs.map((job) => job.done));
      return await action();
    } finally {
      _blockedBooks.remove(bookId);
    }
  }

  /// 在全部书籍上执行排他的缓存操作。
  Future<T> runAllExclusive<T>(Future<T> Function() action) async {
    if (_allBooksBlocked || _blockedBooks.isNotEmpty) {
      throw StateError('已有清理、重新解析或删除任务正在执行');
    }
    _allBooksBlocked = true;
    try {
      final jobs = _activeChapterJobs.values.toList();
      for (final job in jobs) {
        job.cancel();
      }
      await Future.wait(jobs.map((job) => job.done));
      return await action();
    } finally {
      _allBooksBlocked = false;
    }
  }

  Future<void> _runChapterGenerationJob({
    required String generationKey,
    required _ChapterGenerationJob job,
    required String bookId,
    required String chapterId,
    required TtsProvider provider,
    required TtsVoice voice,
    required double speed,
    required int maxRetries,
    required int? priorityParagraphIndex,
    required int prefetchCount,
  }) async {
    try {
      await for (final progress in _generateChapterUnlocked(
        job: job,
        bookId: bookId,
        chapterId: chapterId,
        provider: provider,
        voice: voice,
        speed: speed,
        maxRetries: maxRetries,
        priorityParagraphIndex: priorityParagraphIndex,
        prefetchCount: prefetchCount,
      )) {
        job.add(progress);
      }
    } catch (error, stackTrace) {
      if (error is! _GenerationCancelled) {
        job.addError(error, stackTrace);
      }
    } finally {
      await job.close();
      if (identical(_activeChapterJobs[generationKey], job)) {
        _activeChapterJobs.remove(generationKey);
      }
      job.complete();
    }
  }

  Stream<GenerationProgress> _generateChapterUnlocked({
    required _ChapterGenerationJob job,
    required String bookId,
    required String chapterId,
    required TtsProvider provider,
    required TtsVoice voice,
    required double speed,
    required int maxRetries,
    required int? priorityParagraphIndex,
    required int prefetchCount,
  }) async* {
    job.throwIfCancelled();
    final book = await database.getBook(bookId);
    if (book == null) {
      throw StateError('找不到书籍：$bookId');
    }
    if (!canGenerateAudioForRights(book.rightsStatus)) {
      throw StateError('版权状态不允许生成音频：${book.rightsStatus}');
    }

    final paragraphs = await database.getParagraphs(chapterId);
    final paragraphFingerprints = [
      for (final paragraph in paragraphs)
        generationFingerprint([paragraph.id, paragraph.content]),
    ];
    final contentFingerprint = generationFingerprint(paragraphFingerprints);
    final providerConfiguration = provider is TtsGenerationConfiguration
        ? await (provider as TtsGenerationConfiguration)
              .generationConfigurationFingerprint
        : provider.id;
    final configJson = ttsConfigJson(
      providerId: provider.id,
      voiceId: voice.id,
      speed: speed,
      providerConfiguration: providerConfiguration,
    );
    final configFingerprint = generationFingerprint([
      provider.id,
      voice.id,
      speed.toStringAsFixed(4),
      providerConfiguration,
    ]);
    final taskId = generationTaskId(
      kind: GenerationTaskKind.tts,
      parentId: bookId,
      scopeId: chapterId,
      contentFingerprint: contentFingerprint,
      configFingerprint: configFingerprint,
    );
    final taskSpecs = [
      for (var index = 0; index < paragraphs.length; index++)
        GenerationChunkSpec(
          id: '$taskId:paragraph:${paragraphs[index].id}',
          chunkIndex: index,
          sourceKey: paragraphs[index].id,
          startMs: 0,
          endMs: 0,
          inputFingerprint: paragraphFingerprints[index],
        ),
    ];
    await taskStore.ensureTask(
      spec: GenerationTaskSpec(
        id: taskId,
        kind: GenerationTaskKind.tts,
        parentId: bookId,
        scopeId: chapterId,
        contentFingerprint: contentFingerprint,
        configFingerprint: configFingerprint,
        configJson: configJson,
        priority: priorityParagraphIndex ?? 0,
      ),
      chunks: taskSpecs,
    );
    await taskStore.startTask(taskId, priority: priorityParagraphIndex ?? 0);
    var taskChunks = await taskStore.chunks(taskId);

    final existing = await manifestStore.load(bookId, chapterId);
    final fadeInEnabled =
        await database.getSetting('audio_fade_in_enabled') != 'false';

    var segments = <SegmentEntry>[];
    if (existing != null &&
        existing.providerId == provider.id &&
        existing.voiceId == voice.id &&
        existing.speed == speed &&
        existing.configurationFingerprint == configFingerprint &&
        existing.segments.length == paragraphs.length) {
      segments = [
        for (var index = 0; index < paragraphs.length; index++)
          existing.segments[index].contentFingerprint ==
                  paragraphFingerprints[index]
              ? existing.segments[index]
              : SegmentEntry(
                  paragraphId: paragraphs[index].id,
                  audioFile: '$chapterId/${paragraphs[index].id}.mp3',
                  durationMs: 0,
                  state: ParagraphAudioState.notGenerated,
                  contentFingerprint: paragraphFingerprints[index],
                ),
      ];
    } else {
      segments = paragraphs.map((p) {
        final index = paragraphs.indexOf(p);
        return SegmentEntry(
          paragraphId: p.id,
          audioFile: '$chapterId/${p.id}.mp3',
          durationMs: 0,
          state: ParagraphAudioState.notGenerated,
          contentFingerprint: paragraphFingerprints[index],
        );
      }).toList();
    }

    ChapterManifest manifest() => ChapterManifest(
      chapterId: chapterId,
      bookId: bookId,
      providerId: provider.id,
      voiceId: voice.id,
      speed: speed,
      configurationFingerprint: configFingerprint,
      segments: segments,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    job.throwIfCancelled();
    await manifestStore.save(manifest());
    yield _progressFromSegments(
      chapterId: chapterId,
      providerId: provider.id,
      voiceId: voice.id,
      segments: segments,
    );

    final pendingIndexes = <int>[];
    var restoredFromTaskResults = false;
    for (var i = 0; i < paragraphs.length; i++) {
      final current = segments[i];
      final taskChunk = taskChunks.firstWhere((chunk) => chunk.chunkIndex == i);
      final fileExists =
          current.state == ParagraphAudioState.ready &&
          await File(await _absoluteSegmentPath(bookId, current)).exists();
      if (fileExists &&
          current.contentFingerprint == paragraphFingerprints[i]) {
        if (taskChunk.status != GenerationChunkStatus.complete.name) {
          await taskStore.completeChunk(
            taskChunk.id,
            resultRef: current.audioFile,
          );
        }
        continue;
      }

      // The task row is written immediately after the atomic audio write. If
      // the process is killed in the small window before the manifest update,
      // the durable chunk metadata is still enough to restore the segment
      // without submitting the TTS request again.
      final durableSegment = _segmentFromTaskChunk(
        taskChunk,
        paragraphId: paragraphs[i].id,
        contentFingerprint: paragraphFingerprints[i],
      );
      if (durableSegment != null &&
          await File(
            await _absoluteSegmentPath(bookId, durableSegment),
          ).exists()) {
        segments[i] = durableSegment;
        restoredFromTaskResults = true;
        continue;
      }

      if (current.state == ParagraphAudioState.ready) {
        segments[i] = current.copyWith(
          durationMs: 0,
          state: ParagraphAudioState.notGenerated,
          error: null,
        );
      }
      if (taskChunk.status == GenerationChunkStatus.complete.name) {
        await taskStore.resetChunk(taskChunk.id);
      }
      pendingIndexes.add(i);
    }
    taskChunks = await taskStore.chunks(taskId);

    if (priorityParagraphIndex != null) {
      _sortPendingIndexes(
        pendingIndexes,
        priorityParagraphIndex,
        lookahead: prefetchCount,
      );
    }
    await manifestStore.save(manifest());
    if (restoredFromTaskResults) {
      yield _progressFromSegments(
        chapterId: chapterId,
        providerId: provider.id,
        voiceId: voice.id,
        segments: segments,
      );
    }

    var concurrency = 1;
    try {
      if (provider is TtsConcurrencyPolicy) {
        final policy = provider as TtsConcurrencyPolicy;
        concurrency = (await policy.generationConcurrency).clamp(1, 8).toInt();
      }
    } catch (_) {
      concurrency = 1;
    }
    if (pendingIndexes.isNotEmpty) {
      concurrency = concurrency.clamp(1, pendingIndexes.length);
    }

    AppLogger.info(
      'Generation',
      '生成任务启动 book=$bookId chapter=$chapterId provider=${provider.id} '
          'pending=${pendingIndexes.length} concurrency=$concurrency',
    );

    final active = <int, Future<_SegmentGenerationResult>>{};
    var nextPending = 0;
    Object? stopGenerationError;
    StackTrace? stopGenerationStackTrace;
    try {
      while (nextPending < pendingIndexes.length || active.isNotEmpty) {
        await job.waitIfPaused();
        job.throwIfCancelled();
        final launchedIndexes = <int>[];
        while (stopGenerationError == null &&
            active.length < concurrency &&
            nextPending < pendingIndexes.length) {
          if (job.priorityParagraphIndex != null) {
            _sortPendingIndexes(
              pendingIndexes,
              job.priorityParagraphIndex!,
              lookahead: job.prefetchCount,
              startAt: nextPending,
            );
          }
          final index = pendingIndexes[nextPending++];
          final paragraph = paragraphs[index];
          final current = segments[index];
          final taskChunk = taskChunks.firstWhere(
            (chunk) => chunk.chunkIndex == index,
          );
          await taskStore.startChunk(taskChunk.id);

          segments[index] = current.copyWith(
            state: ParagraphAudioState.generating,
            error: null,
          );
          active[index] =
              _generateParagraph(
                job: job,
                index: index,
                bookId: bookId,
                chapterId: chapterId,
                paragraph: paragraph,
                current: current,
                provider: provider,
                voice: voice,
                speed: speed,
                maxRetries: maxRetries,
                fadeInEnabled: fadeInEnabled,
                contentFingerprint: paragraphFingerprints[index],
              ).then((result) async {
                if (result.segment.state == ParagraphAudioState.ready) {
                  await taskStore.completeChunk(
                    taskChunk.id,
                    resultRef: result.segment.audioFile,
                    resultJson: jsonEncode(result.segment.toJson()),
                  );
                } else if (result.segment.state == ParagraphAudioState.failed) {
                  await taskStore.failChunk(
                    taskChunk.id,
                    result.segment.error ?? 'TTS 分片生成失败',
                  );
                }
                return result;
              });
          launchedIndexes.add(index);
        }

        if (launchedIndexes.isNotEmpty) {
          final first = launchedIndexes.first;
          job.throwIfCancelled();
          await manifestStore.save(manifest());
          yield _progressFromSegments(
            chapterId: chapterId,
            providerId: provider.id,
            voiceId: voice.id,
            segments: segments,
            currentParagraphId: paragraphs[first].id,
            currentParagraphIndex: first,
          );
        }

        if (active.isEmpty) continue;
        final completed = await Future.any(active.values);
        active.remove(completed.index);
        job.throwIfCancelled();
        segments[completed.index] = completed.segment;
        if (stopGenerationError == null &&
            completed.stopGenerationError != null) {
          stopGenerationError = completed.stopGenerationError;
          stopGenerationStackTrace = completed.stopGenerationStackTrace;
          nextPending = pendingIndexes.length;
          AppLogger.error(
            'Generation',
            '检测到不可恢复的语音服务错误，停止章节后续生成 '
                'book=$bookId chapter=$chapterId provider=${provider.id}',
            error: stopGenerationError,
            stackTrace: stopGenerationStackTrace,
          );
        }

        if (completed.billedCharacters > 0) {
          await database.recordCost(
            db.CostRecordsCompanion.insert(
              bookId: bookId,
              chapterId: chapterId,
              providerId: provider.id,
              characters: completed.billedCharacters,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }

        await manifestStore.save(manifest());
        yield _progressFromSegments(
          chapterId: chapterId,
          providerId: provider.id,
          voiceId: voice.id,
          segments: segments,
          currentParagraphId: paragraphs[completed.index].id,
          currentParagraphIndex: completed.index,
          error: completed.segment.error,
        );
      }
      if (stopGenerationError != null) {
        await taskStore.failTask(taskId, stopGenerationError);
        Error.throwWithStackTrace(
          stopGenerationError,
          stopGenerationStackTrace ?? StackTrace.current,
        );
      }
      final failedCount = segments
          .where((segment) => segment.state == ParagraphAudioState.failed)
          .length;
      if (failedCount == 0) {
        await taskStore.completeTask(taskId);
      } else {
        await taskStore.failTask(taskId, '有 $failedCount 个 TTS 分片可重试');
      }
    } finally {
      // Future.any only waits for the first request. A cancelled job must not be
      // considered finished until every in-flight provider call has returned
      // and discarded its result.
      await Future.wait(
        active.values,
        eagerError: false,
      ).catchError((_) => <_SegmentGenerationResult>[]);
    }
    AppLogger.info(
      'Generation',
      '生成任务完成 book=$bookId chapter=$chapterId '
          'ready=${segments.where((segment) => segment.state == ParagraphAudioState.ready).length} '
          'failed=${segments.where((segment) => segment.state == ParagraphAudioState.failed).length}',
    );
  }

  Future<_SegmentGenerationResult> _generateParagraph({
    required _ChapterGenerationJob job,
    required int index,
    required String bookId,
    required String chapterId,
    required db.Paragraph paragraph,
    required SegmentEntry current,
    required TtsProvider provider,
    required TtsVoice voice,
    required double speed,
    required int maxRetries,
    required bool fadeInEnabled,
    required String contentFingerprint,
  }) async {
    try {
      final chunks = await _synthesizePossiblySplit(
        job: job,
        provider: provider,
        voice: voice,
        text: paragraph.content,
        speed: speed,
        maxRetries: maxRetries,
      );
      job.throwIfCancelled();
      if (chunks.isEmpty) throw StateError('TTS 未返回音频');

      final format = chunks.first.format;
      final bytes = format == 'wav'
          ? _prepareWavForCache(
              chunks.map((chunk) => chunk.audioBytes).toList(),
              fadeInEnabled: fadeInEnabled,
            )
          : chunks.expand((chunk) => chunk.audioBytes).toList(growable: false);
      final duration = chunks.fold<int>(
        0,
        (sum, chunk) => sum + chunk.durationMs,
      );
      final timings = <AudioTextTiming>[];
      var timingOffsetMs = 0;
      for (final chunk in chunks) {
        timings.addAll(
          chunk.timings.map((timing) => timing.shifted(timingOffsetMs)),
        );
        timingOffsetMs += chunk.durationMs;
      }
      final billed = chunks.fold<int>(
        0,
        (sum, chunk) => sum + (chunk.billedCharacters ?? 0),
      );

      final absPath = await manifestStore.segmentPath(
        bookId: bookId,
        chapterId: chapterId,
        paragraphId: paragraph.id,
        format: format,
      );
      await _writeFileAtomically(File(absPath), bytes);
      if (job.isCancelled) {
        final file = File(absPath);
        if (await file.exists()) await file.delete();
        throw const _GenerationCancelled();
      }

      final safeTimings = sanitizeAudioTextTimings(
        timings,
        durationMs: duration,
      );

      return _SegmentGenerationResult(
        index: index,
        billedCharacters: billed,
        segment: SegmentEntry(
          paragraphId: paragraph.id,
          audioFile: '$chapterId/${paragraph.id}.$format',
          durationMs: duration,
          state: ParagraphAudioState.ready,
          format: format,
          billedCharacters: billed == 0 ? null : billed,
          generatedAt: DateTime.now().millisecondsSinceEpoch,
          timings: safeTimings,
          contentFingerprint: contentFingerprint,
        ),
      );
    } on _GenerationCancelled {
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Generation',
        '段落音频生成失败 '
            '(book=$bookId, chapter=$chapterId, paragraph=${paragraph.id}, '
            'provider=${provider.id})',
        error: error,
        stackTrace: stackTrace,
      );
      return _SegmentGenerationResult(
        index: index,
        billedCharacters: 0,
        stopGenerationError:
            error is TtsProviderException && error.shouldStopGeneration
            ? error
            : null,
        stopGenerationStackTrace:
            error is TtsProviderException && error.shouldStopGeneration
            ? stackTrace
            : null,
        segment: current.copyWith(
          state: ParagraphAudioState.failed,
          error: error.toString(),
          contentFingerprint: contentFingerprint,
        ),
      );
    }
  }

  GenerationProgress _progressFromSegments({
    required String chapterId,
    required String providerId,
    required String voiceId,
    required List<SegmentEntry> segments,
    String? currentParagraphId,
    int? currentParagraphIndex,
    String? error,
  }) {
    return GenerationProgress(
      chapterId: chapterId,
      ready: segments.where((s) => s.state == ParagraphAudioState.ready).length,
      failed: segments
          .where((s) => s.state == ParagraphAudioState.failed)
          .length,
      generating: segments
          .where((s) => s.state == ParagraphAudioState.generating)
          .length,
      total: segments.length,
      providerId: providerId,
      voiceId: voiceId,
      currentParagraphId: currentParagraphId,
      currentParagraphIndex: currentParagraphIndex,
      error: error,
    );
  }

  SegmentEntry? _segmentFromTaskChunk(
    db.GenerationTaskChunk taskChunk, {
    required String paragraphId,
    required String contentFingerprint,
  }) {
    if (taskChunk.status != GenerationChunkStatus.complete.name ||
        taskChunk.resultJson?.isNotEmpty != true) {
      return null;
    }
    try {
      final json = jsonDecode(taskChunk.resultJson!) as Map<dynamic, dynamic>;
      final segment = SegmentEntry.fromJson(json.cast<String, dynamic>());
      if (segment.paragraphId != paragraphId ||
          segment.contentFingerprint != contentFingerprint ||
          segment.state != ParagraphAudioState.ready) {
        return null;
      }
      return segment;
    } catch (_) {
      return null;
    }
  }

  /// 将多段 WAV 文件的 PCM 数据拼接成单个合法 WAV。
  ///
  /// 保留第一段的 WAV 头（含 fmt chunk），去掉后续段的 header，
  /// 只把 data chunk 的原始 PCM 字节追加进去，并修正 RIFF/data size。
  static Uint8List concatWavPcm(List<Uint8List> wavs) {
    if (wavs.length == 1) return wavs.first;

    final first = wavs.first;
    if (first.length < 44) return first;

    final firstData = ByteData.sublistView(first);
    final sampleRate = firstData.getUint32(24, Endian.little);
    final channels = firstData.getUint16(22, Endian.little);
    final bitsPerSample = firstData.getUint16(34, Endian.little);
    final byteRate = firstData.getUint32(28, Endian.little);
    final blockAlign = firstData.getUint16(32, Endian.little);

    // 找到第一段的 data chunk 起始位置
    int dataOffset = 12;
    while (dataOffset + 8 <= first.length) {
      final chunkId = String.fromCharCodes(
        first.sublist(dataOffset, dataOffset + 4),
      );
      final chunkSize = firstData
          .getUint32(dataOffset + 4, Endian.little)
          .toInt();
      if (chunkId == 'data') break;
      dataOffset += 8 + chunkSize;
      if (chunkSize.isOdd) dataOffset += 1;
    }
    if (dataOffset + 8 > first.length) return first;

    final firstDataSize = firstData
        .getUint32(dataOffset + 4, Endian.little)
        .toInt();
    final firstPcmStart = dataOffset + 8;
    final firstPcm = first.sublist(
      firstPcmStart,
      firstPcmStart + firstDataSize,
    );

    // 收集后续段的 PCM 数据
    final pcmParts = <List<int>>[firstPcm];
    for (var i = 1; i < wavs.length; i++) {
      final wav = wavs[i];
      if (wav.length < 44) continue;
      final wd = ByteData.sublistView(wav);
      int off = 12;
      while (off + 8 <= wav.length) {
        final cid = String.fromCharCodes(wav.sublist(off, off + 4));
        final csz = wd.getUint32(off + 4, Endian.little).toInt();
        if (cid == 'data') {
          final pcmStart = off + 8;
          pcmParts.add(wav.sublist(pcmStart, pcmStart + csz));
          break;
        }
        off += 8 + csz;
        if (csz.isOdd) off += 1;
      }
    }

    final totalPcmSize = pcmParts.fold<int>(0, (sum, p) => sum + p.length);
    final headerSize = 44;
    final out = Uint8List(headerSize + totalPcmSize);
    final od = ByteData.sublistView(out);

    // RIFF header
    out[0] = 0x52; // R
    out[1] = 0x49; // I
    out[2] = 0x46; // F
    out[3] = 0x46; // F
    od.setUint32(4, 36 + totalPcmSize, Endian.little);
    out[8] = 0x57; // W
    out[9] = 0x41; // A
    out[10] = 0x56; // V
    out[11] = 0x45; // E

    // fmt chunk
    out[12] = 0x66; // f
    out[13] = 0x6D; // m
    out[14] = 0x74; // t
    out[15] = 0x20; // (space)
    od.setUint32(16, 16, Endian.little);
    od.setUint16(20, 1, Endian.little); // PCM
    od.setUint16(22, channels, Endian.little);
    od.setUint32(24, sampleRate, Endian.little);
    od.setUint32(28, byteRate, Endian.little);
    od.setUint16(32, blockAlign, Endian.little);
    od.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    out[36] = 0x64; // d
    out[37] = 0x61; // a
    out[38] = 0x74; // t
    out[39] = 0x61; // a
    od.setUint32(40, totalPcmSize, Endian.little);

    var pos = headerSize;
    for (final part in pcmParts) {
      out.setRange(pos, pos + part.length, part);
      pos += part.length;
    }

    return out;
  }

  static Uint8List _prepareWavForCache(
    List<Uint8List> wavs, {
    required bool fadeInEnabled,
  }) {
    final wav = concatWavPcm(wavs);
    return fadeInEnabled ? applyWavFadeIn(wav) : wav;
  }

  /// 对标准 16-bit PCM WAV 添加段首淡入，降低段落切换时的突兀感。
  ///
  /// 当前云端 Provider 优先输出 WAV PCM。无法识别或非
  /// 16-bit PCM 的 WAV 保持原样，避免破坏文件。
  static Uint8List applyWavFadeIn(Uint8List wav, {int fadeInMs = 80}) {
    if (fadeInMs <= 0 || wav.length < 44) return wav;
    if (String.fromCharCodes(wav.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(wav.sublist(8, 12)) != 'WAVE') {
      return wav;
    }

    final data = ByteData.sublistView(wav);
    int? formatCode;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? blockAlign;
    int? dataOffset;
    int? dataSize;

    var offset = 12;
    while (offset + 8 <= wav.length) {
      final chunkId = String.fromCharCodes(wav.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little).toInt();
      final chunkDataOffset = offset + 8;
      if (chunkDataOffset + chunkSize > wav.length) return wav;

      if (chunkId == 'fmt ' && chunkSize >= 16) {
        formatCode = data.getUint16(chunkDataOffset, Endian.little);
        channels = data.getUint16(chunkDataOffset + 2, Endian.little);
        sampleRate = data.getUint32(chunkDataOffset + 4, Endian.little);
        blockAlign = data.getUint16(chunkDataOffset + 12, Endian.little);
        bitsPerSample = data.getUint16(chunkDataOffset + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = chunkDataOffset;
        dataSize = chunkSize;
      }

      offset += 8 + chunkSize;
      if (chunkSize.isOdd) offset += 1;
    }

    if (formatCode != 1 ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample != 16 ||
        blockAlign == null ||
        dataOffset == null ||
        dataSize == null ||
        dataSize <= 0) {
      return wav;
    }

    final frameCount = dataSize ~/ blockAlign;
    if (frameCount <= 1) return wav;
    final fadeFrames = ((sampleRate * fadeInMs) / 1000)
        .round()
        .clamp(1, frameCount)
        .toInt();
    if (fadeFrames <= 1) return wav;

    final out = Uint8List.fromList(wav);
    final outData = ByteData.sublistView(out);
    for (var frame = 0; frame < fadeFrames; frame++) {
      final gain = frame / (fadeFrames - 1);
      final frameOffset = dataOffset + frame * blockAlign;
      for (var channel = 0; channel < channels; channel++) {
        final sampleOffset = frameOffset + channel * 2;
        final sample = outData.getInt16(sampleOffset, Endian.little);
        outData.setInt16(
          sampleOffset,
          (sample * gain).round().clamp(-32768, 32767).toInt(),
          Endian.little,
        );
      }
    }
    return out;
  }

  Future<List<TtsChunk>> _synthesizePossiblySplit({
    required _ChapterGenerationJob job,
    required TtsProvider provider,
    required TtsVoice voice,
    required String text,
    required double speed,
    required int maxRetries,
  }) async {
    // The user's slice length, never above what the provider accepts per call.
    final preferredChars = await _preferredChunkChars();
    final pieces = splitTextForTts(
      text,
      min(preferredChars, provider.capabilities.maxCharsPerCall),
    );
    final chunks = <TtsChunk>[];
    for (final piece in pieces) {
      job.throwIfCancelled();
      chunks.add(
        await _retry(
          () => provider.synthesize(text: piece, voice: voice, speed: speed),
          maxRetries,
        ),
      );
      job.throwIfCancelled();
    }
    return chunks;
  }

  /// Slice length chosen in settings, falling back to the default.
  Future<int> _preferredChunkChars() async {
    const supported = <int>[200, 500, 1000, 2000];
    final stored = int.tryParse(
      await database.getSetting('tts_chunk_chars') ?? '',
    );
    return supported.contains(stored) ? stored! : 500;
  }

  Future<T> _retry<T>(Future<T> Function() fn, int maxRetries) async {
    final attempts = max(1, maxRetries);
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await fn();
      } catch (e) {
        if (e is TtsProviderException && !e.isRetryable) rethrow;
        if (attempt + 1 >= attempts) rethrow;
        final backoffMs = 500 * (1 << attempt) + Random().nextInt(250);
        await Future<void>.delayed(Duration(milliseconds: backoffMs));
      }
    }
    throw StateError('unreachable retry state');
  }

  Future<String> _absoluteSegmentPath(String bookId, SegmentEntry entry) async {
    return manifestStore.segmentPath(
      bookId: bookId,
      chapterId: entry.audioFile.split('/').first,
      paragraphId: entry.paragraphId,
      format: entry.format,
    );
  }
}

class _ChapterGenerationJob {
  final StreamController<GenerationProgress> _controller =
      StreamController<GenerationProgress>.broadcast();
  GenerationProgress? _latest;
  Completer<void>? _resumeCompleter;
  final Completer<void> _done = Completer<void>();
  bool _cancelled = false;
  int? priorityParagraphIndex;
  int prefetchCount = 3;

  Future<void> get done => _done.future;
  bool get isCancelled => _cancelled;

  Stream<GenerationProgress> get stream =>
      Stream<GenerationProgress>.multi((listener) {
        final latest = _latest;
        if (latest != null) listener.add(latest);
        final subscription = _controller.stream.listen(
          listener.add,
          onError: listener.addError,
          onDone: listener.close,
        );
        listener.onCancel = subscription.cancel;
      });

  void add(GenerationProgress progress) {
    _latest = progress;
    if (!_controller.isClosed) _controller.add(progress);
  }

  void pause() {
    _resumeCompleter ??= Completer<void>();
  }

  void resume() {
    final completer = _resumeCompleter;
    _resumeCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void cancel() {
    _cancelled = true;
    resume();
  }

  void prioritize(int paragraphIndex, {int lookahead = 3}) {
    priorityParagraphIndex = paragraphIndex;
    prefetchCount = lookahead.clamp(0, 32).toInt();
  }

  void throwIfCancelled() {
    if (_cancelled) throw const _GenerationCancelled();
  }

  void complete() {
    if (!_done.isCompleted) _done.complete();
  }

  Future<void> waitIfPaused() async {
    while (true) {
      final completer = _resumeCompleter;
      if (completer == null) {
        throwIfCancelled();
        return;
      }
      await completer.future;
    }
  }

  void addError(Object error, StackTrace stackTrace) {
    if (!_controller.isClosed) _controller.addError(error, stackTrace);
  }

  Future<void> close() => _controller.close();
}

void _sortPendingIndexes(
  List<int> indexes,
  int priorityIndex, {
  required int lookahead,
  int startAt = 0,
}) {
  if (startAt >= indexes.length) return;
  final boundedLookahead = lookahead.clamp(0, 32).toInt();
  final remaining = indexes.sublist(startAt)
    ..sort((a, b) {
      int rank(int value) {
        if (value == priorityIndex) return 0;
        final distance = value - priorityIndex;
        if (distance > 0 && distance <= boundedLookahead) return distance;
        if (distance > 0) return 100 + distance;
        return 1000 + (priorityIndex - value);
      }

      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.compareTo(b);
    });
  indexes.setRange(startAt, indexes.length, remaining);
}

class _GenerationCancelled implements Exception {
  const _GenerationCancelled();
}

Future<void> _writeFileAtomically(File destination, List<int> bytes) async {
  final temporary = File('${destination.path}.part');
  await temporary.writeAsBytes(bytes, flush: true);
  try {
    await temporary.rename(destination.path);
  } on FileSystemException {
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
  }
}

/// Keeps provider timestamps local to one audio segment and bounded by the
/// actual decoded WAV duration. Some concurrent Fish responses have returned
/// a request-external offset; rebasing those markers avoids a permanently
/// stale lyric highlight. Unusable markers are discarded so the UI falls back
/// to its duration-based estimate.
List<AudioTextTiming> sanitizeAudioTextTimings(
  List<AudioTextTiming> timings, {
  required int durationMs,
}) {
  if (timings.isEmpty || durationMs <= 0) return const [];

  final ordered = [...timings]
    ..sort((a, b) {
      final byStart = a.startMs.compareTo(b.startMs);
      return byStart != 0 ? byStart : a.endMs.compareTo(b.endMs);
    });
  final firstStart = ordered.first.startMs;
  final lastEnd = ordered.fold<int>(
    0,
    (value, timing) => max(value, timing.endMs),
  );
  final toleranceMs = max(500, (durationMs * 0.1).round());
  final hasExternalOffset =
      firstStart > toleranceMs && lastEnd > durationMs + toleranceMs;
  final offsetMs = hasExternalOffset ? firstStart : 0;

  final sanitized = <AudioTextTiming>[];
  var previousEnd = 0;
  for (final timing in ordered) {
    if (timing.text.trim().isEmpty || timing.endMs <= timing.startMs) continue;
    final start = (timing.startMs - offsetMs).clamp(0, durationMs).toInt();
    final end = (timing.endMs - offsetMs).clamp(start, durationMs).toInt();
    if (end <= start || start + toleranceMs < previousEnd) return const [];
    sanitized.add(
      AudioTextTiming(text: timing.text, startMs: start, endMs: end),
    );
    previousEnd = max(previousEnd, end);
  }
  if (sanitized.isEmpty) return const [];

  final coveredMs = sanitized.last.endMs - sanitized.first.startMs;
  if (coveredMs <= 0 || sanitized.last.startMs >= durationMs) return const [];
  return sanitized;
}

/// 按 TTS 单次字符上限切分文本。
///
/// [maxChars] 是软上限：优先保证一句话不被拆成多个音频请求。
/// 只有当单句长到明显异常时，才按逗号/空格等弱边界兜底，最后才硬切。
List<String> splitTextForTts(String text, int maxChars, {int? hardMaxChars}) {
  final trimmed = text.trim();
  if (trimmed.length <= maxChars) return [trimmed];
  final hardLimit =
      hardMaxChars ??
      (maxChars <= 1000 ? (maxChars * 4).clamp(maxChars, 4000) : maxChars);

  final sentences = trimmed
      .split(RegExp(r'(?<=[。！？!?；;\n])'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final out = <String>[];
  final buffer = StringBuffer();

  for (final sentence in sentences) {
    if (buffer.isNotEmpty && buffer.length + sentence.length > maxChars) {
      out.add(buffer.toString());
      buffer.clear();
    }

    if (sentence.length > hardLimit) {
      out.addAll(_splitOversizedSentence(sentence, hardLimit));
      continue;
    }

    buffer.write(sentence);
  }

  if (buffer.isNotEmpty) out.add(buffer.toString());
  return out;
}

List<String> _splitOversizedSentence(String sentence, int hardLimit) {
  final parts = sentence
      .split(RegExp(r'(?<=[，,、：:])|\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (parts.length <= 1) {
    return _hardSplit(sentence, hardLimit);
  }

  final out = <String>[];
  final buffer = StringBuffer();
  for (final part in parts) {
    if (part.length > hardLimit) {
      if (buffer.isNotEmpty) {
        out.add(buffer.toString());
        buffer.clear();
      }
      out.addAll(_hardSplit(part, hardLimit));
      continue;
    }

    if (buffer.isNotEmpty && buffer.length + part.length > hardLimit) {
      out.add(buffer.toString());
      buffer.clear();
    }
    buffer.write(part);
  }
  if (buffer.isNotEmpty) out.add(buffer.toString());
  return out;
}

List<String> _hardSplit(String text, int limit) {
  final out = <String>[];
  for (var i = 0; i < text.length; i += limit) {
    out.add(text.substring(i, (i + limit).clamp(0, text.length)));
  }
  return out;
}

class _SegmentGenerationResult {
  final int index;
  final SegmentEntry segment;
  final int billedCharacters;
  final Object? stopGenerationError;
  final StackTrace? stopGenerationStackTrace;

  const _SegmentGenerationResult({
    required this.index,
    required this.segment,
    required this.billedCharacters,
    this.stopGenerationError,
    this.stopGenerationStackTrace,
  });
}
