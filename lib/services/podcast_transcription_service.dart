import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import '../data/database/app_database.dart';
import '../domain/models/audio_text_timing.dart';
import 'app_log_service.dart';
import 'generation_task_store.dart';

enum PodcastTranscriptionStage {
  preparing,
  downloadingModel,
  downloadingAudio,
  transcribing,
  complete,
  paused,
}

/// Status stored on the episode row while a run is interrupted on purpose.
/// A paused episode resumes from `transcriptProgressMs`; a failed one does
/// too, but only the paused label offers to continue.
const podcastTranscriptPausedStatus = 'paused';

/// One slice of audio handed to Whisper.
class PodcastChunkWindow {
  final int startMs;
  final int durationMs;
  final int extractionStartMs;
  final int extractionDurationMs;

  const PodcastChunkWindow({
    required this.startMs,
    required this.durationMs,
    int? extractionStartMs,
    int? extractionDurationMs,
  }) : extractionStartMs = extractionStartMs ?? startMs,
       extractionDurationMs = extractionDurationMs ?? durationMs;

  @override
  String toString() => 'PodcastChunkWindow($startMs, $durationMs)';
}

/// Chunk schedule for one run.
///
/// [startFromMs] is the offset a paused run already covered, so resuming never
/// hands Whisper the same audio twice and never skips a gap between the two
/// runs — even if the chunk size setting changed in between. A feed without a
/// usable duration falls back to a bounded number of fixed-size chunks; the
/// loop stops early once FFmpeg runs out of audio.
List<PodcastChunkWindow> planPodcastChunks({
  required int durationMs,
  required int startFromMs,
  required int chunkDurationMs,
  int maxUnknownChunks = 480,
  int overlapMs = 0,
}) {
  if (chunkDurationMs <= 0) return const [];
  final start = math.max(0, startFromMs);
  final overlap = math.max(0, overlapMs);
  if (durationMs <= 0) {
    final windows = <PodcastChunkWindow>[];
    for (var index = 0; index < maxUnknownChunks; index++) {
      final logicalStart = start + index * chunkDurationMs;
      final extractionStart = math.max(0, logicalStart - overlap);
      windows.add(
        PodcastChunkWindow(
          startMs: logicalStart,
          durationMs: chunkDurationMs,
          extractionStartMs: extractionStart,
          extractionDurationMs:
              chunkDurationMs + logicalStart - extractionStart,
        ),
      );
    }
    return windows;
  }

  final windows = <PodcastChunkWindow>[];
  for (var offset = start; offset < durationMs; offset += chunkDurationMs) {
    final logicalDuration = math.min(chunkDurationMs, durationMs - offset);
    final extractionStart = math.max(0, offset - overlap);
    final extractionEnd = math.min(
      durationMs,
      offset + logicalDuration + overlap,
    );
    windows.add(
      PodcastChunkWindow(
        startMs: offset,
        durationMs: logicalDuration,
        extractionStartMs: extractionStart,
        extractionDurationMs: extractionEnd - extractionStart,
      ),
    );
  }
  return windows;
}

class _ChunkRun {
  final List<AudioTextTiming> segments;
  final int completedMs;
  final bool paused;

  const _ChunkRun({
    required this.segments,
    required this.completedMs,
    required this.paused,
  });
}

class _WhisperPrefix {
  final List<AudioTextTiming> segments;
  final int endMs;

  const _WhisperPrefix({required this.segments, required this.endMs});
}

class _ActiveTranscription {
  final String episodeId;
  final Completer<void> finished = Completer<void>();
  bool cancelled = false;

  _ActiveTranscription(this.episodeId);
}

class PodcastTranscriptionProgress {
  final String episodeId;
  final PodcastTranscriptionStage stage;
  final String message;
  final double? progress;

  const PodcastTranscriptionProgress({
    required this.episodeId,
    required this.stage,
    required this.message,
    this.progress,
  });

  bool get running =>
      stage != PodcastTranscriptionStage.complete &&
      stage != PodcastTranscriptionStage.paused;
}

class PodcastAsrModelInfo {
  final bool installed;
  final String path;
  final int installedBytes;
  final int partialBytes;
  final int expectedBytes;

  const PodcastAsrModelInfo({
    required this.installed,
    required this.path,
    required this.installedBytes,
    required this.partialBytes,
    required this.expectedBytes,
  });
}

class PodcastTranscriptionService {
  static const WhisperModel defaultModel = WhisperModel.base;
  static const defaultChunkMinutes = 3;
  static const _chunkOverlapMs = 10000;
  static const chunkMinutesSettingKey = 'asr_chunk_minutes';
  static const languagePreferenceSettingKey = 'asr_language_preference';
  static const podcastLanguagePreference = 'podcast';
  static const automaticLanguagePreference = 'automatic';
  static const baseModelExpectedBytes = 142 * 1024 * 1024;
  static const _maximumUnknownDurationChunks = 480;
  static const _baseModelUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/'
      'ggml-base.bin?download=true';
  static const _baseModelSha1 = '465707469ff3a37a2b9b8d8f89f2f99de7299dac';

  final AppDatabase database;
  late final GenerationTaskStore taskStore = GenerationTaskStore(database);
  final Dio _dio;
  final WhisperController _controller;
  final Map<String, Future<String>> _audioDownloads = {};
  final StreamController<PodcastTranscriptionProgress> _progressController =
      StreamController<PodcastTranscriptionProgress>.broadcast();
  _ActiveTranscription? _active;
  Future<List<AudioTextTiming>>? _activeFuture;
  bool _installingModel = false;

  PodcastTranscriptionService(
    this.database, {
    Dio? dio,
    WhisperController? controller,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 30),
               receiveTimeout: Duration.zero,
               headers: const {
                 'user-agent': 'Lumina/1.0 (+local podcast reader)',
                 'accept': 'audio/*, application/octet-stream, */*',
               },
             ),
           ),
       _controller = controller ?? WhisperController();

  Future<bool> isModelInstalled() async {
    return (await getModelInfo()).installed;
  }

  Future<PodcastAsrModelInfo> getModelInfo() async {
    final path = await _controller.getPath(defaultModel);
    final model = File(path);
    final partial = File('$path.partial');
    final installedBytes = await model.exists() ? await model.length() : 0;
    final partialBytes = await partial.exists() ? await partial.length() : 0;
    return PodcastAsrModelInfo(
      installed: installedBytes > 100000000,
      path: path,
      installedBytes: installedBytes,
      partialBytes: partialBytes,
      expectedBytes: baseModelExpectedBytes,
    );
  }

  /// Episode currently being transcribed, if any. Every screen reads this to
  /// decide whether it owns the running job.
  String? get activeEpisodeId => _active?.episodeId;

  /// Progress for whichever episode is running. Screens filter by episode id
  /// so a run stays visible after navigating away and back.
  Stream<PodcastTranscriptionProgress> get progressStream =>
      _progressController.stream;

  /// Stops the running job at the next chunk boundary and waits for it to
  /// settle. Chunks already cached stay on the episode row.
  Future<void> pause() async {
    final active = _active;
    if (active == null) return;
    active.cancelled = true;
    await active.finished.future;
  }

  void dispose() {
    unawaited(_progressController.close());
  }

  Future<void> installModel({
    void Function(double? progress, String message)? onProgress,
  }) async {
    if (_active != null) {
      throw StateError('Podcast 转写进行中，暂时不能管理 Whisper 模型。');
    }
    await _ensureModel(
      onProgress: (stage, message, {progress}) {
        onProgress?.call(progress, message);
      },
    );
  }

  Future<void> deleteModel() async {
    if (_active != null || _installingModel) {
      throw StateError('Whisper 正在使用或下载中，暂时不能删除模型。');
    }
    final path = await _controller.getPath(defaultModel);
    for (final file in [File(path), File('$path.partial')]) {
      if (await file.exists()) await file.delete();
    }
  }

  _WhisperPrefix _completedWhisperPrefix(List<GenerationTaskChunk> chunks) {
    final output = <AudioTextTiming>[];
    var endMs = 0;
    for (final chunk in chunks) {
      if (chunk.status != GenerationChunkStatus.complete.name ||
          chunk.resultJson?.isNotEmpty != true ||
          chunk.startMs != endMs) {
        break;
      }
      output.addAll(decodeTranscript(chunk.resultJson));
      endMs = chunk.endMs;
    }
    return _WhisperPrefix(
      segments: mergePodcastTranscriptSegments(const [], output),
      endMs: endMs,
    );
  }

  Future<List<AudioTextTiming>> transcribe(
    PodcastEpisode episode, {
    String? languageHint,
    void Function(PodcastTranscriptionProgress progress)? onProgress,
  }) {
    final running = _activeFuture;
    if (running != null) {
      // A repeated tap, a player reopen, and a recovery trigger may all race
      // during the same foreground frame. Reuse the first future instead of
      // pausing and submitting the same episode again.
      if (_active == null || _active?.episodeId == episode.id) return running;
      return running.then(
        (_) => transcribe(
          episode,
          languageHint: languageHint,
          onProgress: onProgress,
        ),
        onError: (Object _, StackTrace _) => transcribe(
          episode,
          languageHint: languageHint,
          onProgress: onProgress,
        ),
      );
    }

    final future = _transcribeInternal(
      episode,
      languageHint: languageHint,
      onProgress: onProgress,
    );
    _activeFuture = future;
    unawaited(
      future.then<void>(
        (_) {
          if (identical(_activeFuture, future)) _activeFuture = null;
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_activeFuture, future)) _activeFuture = null;
        },
      ),
    );
    return future;
  }

  Future<List<AudioTextTiming>> _transcribeInternal(
    PodcastEpisode episode, {
    String? languageHint,
    void Function(PodcastTranscriptionProgress progress)? onProgress,
  }) async {
    // Starting an episode takes over from whatever was running: the previous
    // job pauses at its next chunk boundary and keeps everything it cached.
    await pause();
    final active = _ActiveTranscription(episode.id);
    _active = active;
    void emit(
      PodcastTranscriptionStage stage,
      String message, {
      double? progress,
    }) {
      final event = PodcastTranscriptionProgress(
        episodeId: episode.id,
        stage: stage,
        message: message,
        progress: progress,
      );
      onProgress?.call(event);
      if (!_progressController.isClosed) _progressController.add(event);
    }

    try {
      final storedBeforeRun =
          await database.getPodcastEpisode(episode.id) ?? episode;
      await database.updatePodcastTranscript(
        episode.id,
        status: 'running',
        error: null,
      );
      emit(PodcastTranscriptionStage.preparing, '正在准备本地转写');
      await _ensureModel(onProgress: emit);

      final cachedAudioPath = await downloadEpisodeAudio(
        episode,
        onProgress: (received, total) {
          emit(
            PodcastTranscriptionStage.downloadingAudio,
            '正在缓存单集音频',
            progress: total <= 0 ? null : received / total,
          );
        },
      );
      emit(
        PodcastTranscriptionStage.transcribing,
        'Whisper 正在设备上转写',
        progress: 0,
      );
      final language = resolveWhisperLanguage(
        languageHint,
        fallbackLocale: Platform.localeName,
        // whisper_ggml 2.4.0's Apple wrapper rejects `auto` before it reaches
        // whisper.cpp. Other native wrappers correctly allow auto-detection.
        supportsAuto: !Platform.isIOS && !Platform.isMacOS,
      );

      // Feed duration metadata is often rounded or missing. Probe the cached
      // file so a short feed value cannot truncate the final transcript chunk.
      final probedDurationMs = await _probeDurationMs(cachedAudioPath);
      final durationMs = probedDurationMs > 0
          ? probedDurationMs
          : episode.durationMs;
      final storedChunkMinutes = int.tryParse(
        await database.getSetting(chunkMinutesSettingKey) ?? '',
      );
      final chunkMinutes = (storedChunkMinutes ?? defaultChunkMinutes).clamp(
        1,
        10,
      );
      final stored = storedBeforeRun;
      final sourceEpisode =
          await database.getPodcastEpisode(episode.id) ?? episode;
      final audioFile = File(cachedAudioPath);
      final audioLength = await audioFile.exists()
          ? await audioFile.length()
          : 0;
      final audioModified = await audioFile.exists()
          ? (await audioFile.lastModified()).millisecondsSinceEpoch
          : 0;
      final sourceFingerprint = generationFingerprint([
        episode.id,
        sourceEpisode.audioUrl,
        sourceEpisode.localAudioPath ?? '',
        durationMs.toString(),
        audioLength.toString(),
        audioModified.toString(),
      ]);
      final configFingerprint = generationFingerprint([
        defaultModel.name,
        language,
        chunkMinutes.toString(),
        _chunkOverlapMs.toString(),
      ]);
      final taskId = generationTaskId(
        kind: GenerationTaskKind.whisper,
        parentId: episode.showId,
        scopeId: episode.id,
        contentFingerprint: sourceFingerprint,
        configFingerprint: configFingerprint,
      );
      final taskPlan = planPodcastChunks(
        durationMs: durationMs,
        startFromMs: 0,
        chunkDurationMs: Duration(minutes: chunkMinutes).inMilliseconds,
        maxUnknownChunks: _maximumUnknownDurationChunks,
        overlapMs: _chunkOverlapMs,
      );
      final taskSpecs = [
        for (var index = 0; index < taskPlan.length; index++)
          GenerationChunkSpec(
            id: '$taskId:chunk:${taskPlan[index].startMs}',
            chunkIndex: index,
            sourceKey: taskPlan[index].startMs.toString(),
            startMs: taskPlan[index].startMs,
            endMs: taskPlan[index].startMs + taskPlan[index].durationMs,
            inputFingerprint: generationFingerprint([
              sourceFingerprint,
              language,
              taskPlan[index].startMs.toString(),
              taskPlan[index].durationMs.toString(),
            ]),
          ),
      ];
      final latestTask = await database.getLatestGenerationTask(
        kind: GenerationTaskKind.whisper.name,
        parentId: episode.showId,
        scopeId: episode.id,
      );

      // A completed transcript is a cache hit. Do not redownload the model or
      // submit the same Whisper work merely because the player was reopened.
      if (stored.transcriptStatus == 'complete' &&
          (latestTask == null ||
              (latestTask.id == taskId &&
                  latestTask.status != GenerationChunkStatus.failed.name))) {
        return decodeTranscript(stored.transcriptJson);
      }
      if (latestTask != null && latestTask.id != taskId) {
        // Feed/audio or language configuration changed. Never merge results
        // from the previous version into the new source.
        await database.clearPodcastTranscript(episode.id);
      }

      await taskStore.ensureTask(
        spec: GenerationTaskSpec(
          id: taskId,
          kind: GenerationTaskKind.whisper,
          parentId: episode.showId,
          scopeId: episode.id,
          contentFingerprint: sourceFingerprint,
          configFingerprint: configFingerprint,
          configJson: jsonEncode({
            'model': defaultModel.name,
            'language': language,
            'chunkMinutes': chunkMinutes,
            'overlapMs': _chunkOverlapMs,
          }),
        ),
        chunks: taskSpecs,
      );
      await taskStore.startTask(taskId);
      final taskChunks = await taskStore.chunks(taskId);

      // Prefer durable chunk results. The episode watermark remains a legacy
      // fallback for databases created before the task tables existed.
      final prefix = _completedWhisperPrefix(taskChunks);
      final resumeFromMs = prefix.endMs > 0
          ? prefix.endMs
          : stored.transcriptProgressMs
                .clamp(0, math.max(0, durationMs))
                .toInt();
      final cached = prefix.segments.isNotEmpty
          ? prefix.segments
          : resumeFromMs > 0
          ? decodeTranscript(stored.transcriptJson)
          : const <AudioTextTiming>[];

      final run = await _transcribeInChunks(
        active: active,
        episode: episode,
        audioPath: cachedAudioPath,
        language: language,
        durationMs: durationMs,
        startFromMs: resumeFromMs,
        cachedSegments: cached,
        chunkDuration: Duration(minutes: chunkMinutes),
        taskStore: taskStore,
        taskId: taskId,
        taskChunks: taskChunks,
        emit: emit,
      );

      if (run.paused) {
        await database.updatePodcastTranscript(
          episode.id,
          status: podcastTranscriptPausedStatus,
          transcriptJson: jsonEncode([
            for (final segment in run.segments) segment.toJson(),
          ]),
          language: language,
          error: null,
          progressMs: run.completedMs,
        );
        emit(
          PodcastTranscriptionStage.paused,
          '本地转写已暂停',
          progress: durationMs <= 0 ? null : run.completedMs / durationMs,
        );
        await database.updateGenerationTask(
          taskId,
          status: GenerationChunkStatus.pending.name,
          error: null,
        );
        AppLogger.info(
          'Podcast',
          'Whisper 本地转写暂停 episode=${episode.id} '
              'segments=${run.segments.length} at=${run.completedMs}ms',
        );
        return run.segments;
      }

      if (run.segments.isEmpty) {
        throw StateError('没有识别到可显示的语音内容。');
      }

      await database.updatePodcastTranscript(
        episode.id,
        status: 'complete',
        transcriptJson: jsonEncode([
          for (final segment in run.segments) segment.toJson(),
        ]),
        language: language,
        error: null,
        progressMs: run.completedMs,
      );
      await taskStore.completeTask(taskId);
      emit(PodcastTranscriptionStage.complete, '本地转写完成', progress: 1);
      AppLogger.info(
        'Podcast',
        'Whisper 本地转写完成 episode=${episode.id} '
            'segments=${run.segments.length}',
      );
      return run.segments;
    } catch (error, stackTrace) {
      final latestTask = await database.getLatestGenerationTask(
        kind: GenerationTaskKind.whisper.name,
        parentId: episode.showId,
        scopeId: episode.id,
      );
      if (latestTask != null &&
          latestTask.status == GenerationChunkStatus.running.name) {
        await taskStore.failTask(latestTask.id, error);
      }
      await database.updatePodcastTranscript(
        episode.id,
        status: 'failed',
        error: error.toString(),
      );
      AppLogger.error(
        'Podcast',
        'Whisper 本地转写失败 episode=${episode.id}',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      if (identical(_active, active)) _active = null;
      active.finished.complete();
    }
  }

  Future<String> downloadEpisodeAudio(
    PodcastEpisode episode, {
    void Function(int received, int total)? onProgress,
  }) async {
    final activeDownload = _audioDownloads[episode.id];
    if (activeDownload != null) return activeDownload;

    final download = _ensureEpisodeAudio(
      episode,
      onProgress: onProgress ?? (_, _) {},
    );
    _audioDownloads[episode.id] = download;
    try {
      return await download;
    } finally {
      if (identical(_audioDownloads[episode.id], download)) {
        _audioDownloads.remove(episode.id);
      }
    }
  }

  Future<_ChunkRun> _transcribeInChunks({
    required _ActiveTranscription active,
    required PodcastEpisode episode,
    required String audioPath,
    required String language,
    required int durationMs,
    required int startFromMs,
    required List<AudioTextTiming> cachedSegments,
    required Duration chunkDuration,
    required GenerationTaskStore taskStore,
    required String taskId,
    required List<GenerationTaskChunk> taskChunks,
    required void Function(
      PodcastTranscriptionStage stage,
      String message, {
      double? progress,
    })
    emit,
  }) async {
    final temporary = await getTemporaryDirectory();
    final chunkDirectory = Directory(
      p.join(temporary.path, 'lumina_whisper', episode.id),
    );
    await chunkDirectory.create(recursive: true);

    final chunkDurationMs = chunkDuration.inMilliseconds;
    final plan = planPodcastChunks(
      durationMs: durationMs,
      startFromMs: startFromMs,
      chunkDurationMs: chunkDurationMs,
      maxUnknownChunks: _maximumUnknownDurationChunks,
      overlapMs: _chunkOverlapMs,
    );
    final knownChunkCount = durationMs <= 0 ? null : plan.length;
    final output = <AudioTextTiming>[...cachedSegments];
    var completedMs = startFromMs;

    for (var chunkIndex = 0; chunkIndex < plan.length; chunkIndex++) {
      // Pausing lands between chunks: the one in flight would have to be
      // thrown away otherwise, and its audio re-transcribed on resume.
      if (active.cancelled) {
        return _ChunkRun(
          segments: output,
          completedMs: completedMs,
          paused: true,
        );
      }

      final window = plan[chunkIndex];
      final startMs = window.startMs;
      final requestedDurationMs = window.durationMs;
      // Databases created before chunk tasks used an arbitrary transcript
      // watermark. That watermark may fall inside the canonical plan, so the
      // first resumed window has no task row yet. Keep the legacy watermark
      // as the source of truth for that one window and persist all canonical
      // windows normally.
      final taskChunk = taskChunks
          .where((chunk) => chunk.startMs == startMs)
          .firstOrNull;
      if (taskChunk != null && taskChunk.taskId != taskId) {
        throw StateError('Whisper 分片不属于当前任务');
      }
      if (taskChunk != null &&
          taskChunk.status == GenerationChunkStatus.complete.name &&
          taskChunk.resultJson?.isNotEmpty == true) {
        output.addAll(decodeTranscript(taskChunk.resultJson));
        completedMs = math.max(completedMs, taskChunk.endMs);
        continue;
      }

      final chunkPath = p.join(
        chunkDirectory.path,
        'chunk_${startMs.toString().padLeft(9, '0')}.wav',
      );
      final hasAudio = await _extractAudioChunk(
        sourcePath: audioPath,
        targetPath: chunkPath,
        startMs: window.extractionStartMs,
        durationMs: window.extractionDurationMs,
      );
      if (!hasAudio) {
        if (knownChunkCount == null && chunkIndex > 0) break;
        throw StateError('无法准备第 ${chunkIndex + 1} 个音频分段。');
      }

      final chunkLabel = knownChunkCount == null
          ? '${chunkIndex + 1}'
          : '${chunkIndex + 1}/$knownChunkCount';
      // Progress covers the whole episode, not just this run, so resuming
      // picks the bar up where the paused run left it.
      double? overallProgress(double chunkFraction) => durationMs <= 0
          ? null
          : ((startMs + requestedDurationMs * chunkFraction) / durationMs)
                .clamp(0.0, 1.0);
      emit(
        PodcastTranscriptionStage.transcribing,
        'Whisper 正在设备上转写（$chunkLabel）',
        progress: overallProgress(0),
      );

      try {
        if (taskChunk != null) await taskStore.startChunk(taskChunk.id);
        final result = await _controller.transcribe(
          model: defaultModel,
          audioPath: chunkPath,
          lang: language,
          withSegments: true,
          // whisper_ggml exposes the same timestamp stream at word
          // granularity. Keeping phrase-level markers here forces the UI to
          // invent word timings by character count.
          splitOnWord: true,
          suppressNonSpeechTokens: true,
          onProgress: (percent) {
            emit(
              PodcastTranscriptionStage.transcribing,
              'Whisper 正在设备上转写（$chunkLabel）',
              progress: overallProgress(percent.clamp(0, 100) / 100),
            );
          },
        );
        if (result == null) {
          throw StateError('Whisper 没有返回第 ${chunkIndex + 1} 段的结果。');
        }

        final response = result.transcription;
        final responseSegments = response.segments ?? const [];
        final logicalEndMs = startMs + requestedDurationMs;
        final chunkSegments = <AudioTextTiming>[];
        for (final segment in responseSegments) {
          final absoluteStart =
              window.extractionStartMs + segment.fromTs.inMilliseconds;
          final absoluteEnd =
              window.extractionStartMs + segment.toTs.inMilliseconds;
          // Overlap is context only. Ownership is determined by the segment
          // start: a phrase crossing this boundary belongs to the previous
          // logical chunk, so the next chunk cannot duplicate it. Its end is
          // still clamped to protect the persisted result from bad timestamps.
          if (segment.text.trim().isEmpty ||
              absoluteStart < startMs ||
              absoluteStart >= logicalEndMs) {
            continue;
          }
          final end = math.min(logicalEndMs, absoluteEnd);
          if (end <= absoluteStart) continue;
          chunkSegments.add(
            AudioTextTiming(
              text: segment.text.trim(),
              startMs: absoluteStart,
              endMs: end,
              chunkStartMs: startMs,
            ),
          );
        }
        if (responseSegments.isEmpty && response.text.trim().isNotEmpty) {
          chunkSegments.add(
            AudioTextTiming(
              text: response.text.trim(),
              startMs: startMs,
              endMs: startMs + requestedDurationMs,
              chunkStartMs: startMs,
            ),
          );
        }
        final merged = mergePodcastTranscriptSegments(output, chunkSegments);
        output
          ..clear()
          ..addAll(merged);
        completedMs = startMs + requestedDurationMs;

        if (taskChunk != null) {
          await taskStore.completeChunk(
            taskChunk.id,
            resultJson: jsonEncode([
              for (final segment in chunkSegments) segment.toJson(),
            ]),
          );
        }

        // Each completed chunk is durable immediately. Database watchers can
        // render these lines as lyrics while later chunks are still running,
        // and the offset lets a paused run pick up exactly here.
        await database.updatePodcastTranscript(
          episode.id,
          status: 'running',
          transcriptJson: jsonEncode([
            for (final segment in output) segment.toJson(),
          ]),
          language: language,
          error: null,
          progressMs: completedMs,
        );
      } catch (error) {
        if (taskChunk != null) await taskStore.failChunk(taskChunk.id, error);
        rethrow;
      } finally {
        await _deletePreparedAudio(chunkPath);
      }
    }
    return _ChunkRun(segments: output, completedMs: completedMs, paused: false);
  }

  Future<void> _deletePreparedAudio(String audioPath) async {
    // whisper_ggml asks FFmpeg to create this temporary 16 kHz WAV. Long
    // Podcast WAV files can be much larger than the original compressed file.
    for (final file in [File('$audioPath.wav'), File(audioPath)]) {
      if (!await file.exists()) continue;
      try {
        await file.delete();
      } catch (_) {}
    }
    // File.exists() is false for a stale link whose source was removed.
    final link = Link(audioPath);
    if (await link.exists()) {
      try {
        await link.delete();
      } catch (_) {}
    }
  }

  Future<bool> _extractAudioChunk({
    required String sourcePath,
    required String targetPath,
    required int startMs,
    required int durationMs,
  }) async {
    final target = File(targetPath);
    if (await target.exists()) await target.delete();
    final arguments = <String>[
      '-y',
      '-ss',
      (startMs / 1000).toStringAsFixed(3),
      '-i',
      sourcePath,
      '-t',
      (durationMs / 1000).toStringAsFixed(3),
      '-vn',
      '-sn',
      '-dn',
      '-ar',
      '16000',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      targetPath,
    ];

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      final session = await FFmpegKit.executeWithArguments(arguments);
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        AppLogger.warning(
          'Podcast',
          'FFmpeg 分段失败 code=$returnCode output=${output ?? ''}',
        );
        return false;
      }
    } else {
      final result = await Process.run('ffmpeg', arguments);
      if (result.exitCode != 0) {
        AppLogger.warning(
          'Podcast',
          'FFmpeg 分段失败 code=${result.exitCode} stderr=${result.stderr}',
        );
        return false;
      }
    }
    return await target.exists() && await target.length() > 1024;
  }

  Future<int> _probeDurationMs(String audioPath) async {
    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        final session = await FFprobeKit.getMediaInformation(audioPath);
        final seconds = double.tryParse(
          session.getMediaInformation()?.getDuration() ?? '',
        );
        return seconds == null ? 0 : (seconds * 1000).round();
      }
      final result = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'default=noprint_wrappers=1:nokey=1',
        audioPath,
      ]);
      if (result.exitCode != 0) return 0;
      final seconds = double.tryParse(result.stdout.toString().trim());
      return seconds == null ? 0 : (seconds * 1000).round();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Podcast',
        '读取 Podcast 时长失败，将按流末尾停止分段',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  Future<String> _ensureEpisodeAudio(
    PodcastEpisode episode, {
    required void Function(int received, int total) onProgress,
  }) async {
    final persisted = episode.localAudioPath;
    if (persisted != null) {
      final file = File(persisted);
      if (await file.exists() && await file.length() > 0) return file.path;
    }

    final support = await getApplicationSupportDirectory();
    final uri = Uri.tryParse(episode.audioUrl);
    final sourceExtension = p.extension(uri?.path ?? '').toLowerCase();
    const supportedExtensions = {
      '.mp3',
      '.m4a',
      '.aac',
      '.wav',
      '.ogg',
      '.opus',
      '.mp4',
      '.flac',
    };
    final extension = supportedExtensions.contains(sourceExtension)
        ? sourceExtension
        : '.audio';
    final target = File(
      p.join(support.path, 'podcasts', 'audio', '${episode.id}$extension'),
    );
    await target.parent.create(recursive: true);
    if (await target.exists() && await target.length() > 0) {
      await database.updatePodcastLocalAudioPath(episode.id, target.path);
      return target.path;
    }

    final partial = File('${target.path}.partial');
    await _dio.download(
      episode.audioUrl,
      partial.path,
      deleteOnError: false,
      onReceiveProgress: onProgress,
      options: Options(
        followRedirects: true,
        responseType: ResponseType.stream,
      ),
    );
    if (!await partial.exists() || await partial.length() == 0) {
      throw StateError('单集音频下载为空。');
    }
    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
    await database.updatePodcastLocalAudioPath(episode.id, target.path);
    return target.path;
  }

  Future<void> _ensureModel({
    required void Function(
      PodcastTranscriptionStage stage,
      String message, {
      double? progress,
    })
    onProgress,
  }) async {
    final modelPath = await _controller.getPath(defaultModel);
    final model = File(modelPath);
    if (await model.exists() && await model.length() > 100000000) return;
    if (_installingModel) {
      throw StateError('Whisper 模型正在下载中。');
    }
    _installingModel = true;
    if (await model.exists()) await model.delete();

    final partial = File('$modelPath.partial');
    try {
      await partial.parent.create(recursive: true);
      onProgress(
        PodcastTranscriptionStage.downloadingModel,
        '正在下载 Whisper Base 模型（约 142 MB）',
        progress: 0,
      );
      await _dio.download(
        _baseModelUrl,
        partial.path,
        deleteOnError: false,
        onReceiveProgress: (received, total) {
          onProgress(
            PodcastTranscriptionStage.downloadingModel,
            '正在下载 Whisper Base 模型（约 142 MB）',
            progress: total <= 0 ? null : received / total,
          );
        },
        options: Options(
          followRedirects: true,
          responseType: ResponseType.stream,
        ),
      );
      if (!await partial.exists() || await partial.length() < 100000000) {
        throw StateError('Whisper 模型下载不完整。');
      }
      final digest = await sha1.bind(partial.openRead()).first;
      if (digest.toString() != _baseModelSha1) {
        throw StateError('Whisper 模型校验失败，请重新下载。');
      }
      if (await model.exists()) await model.delete();
      await partial.rename(model.path);
    } catch (_) {
      if (await partial.exists()) {
        try {
          await partial.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      _installingModel = false;
    }
  }

  static List<AudioTextTiming> decodeTranscript(String? source) {
    if (source == null || source.isEmpty) return const [];
    try {
      final values = jsonDecode(source) as List<dynamic>;
      final decoded = <AudioTextTiming>[
        for (final value in values)
          AudioTextTiming.fromJson(Map<String, dynamic>.from(value as Map)),
      ];
      decoded.removeWhere(
        (timing) =>
            timing.text.trim().isEmpty || timing.endMs <= timing.startMs,
      );
      decoded.sort((a, b) {
        final byStart = a.startMs.compareTo(b.startMs);
        return byStart != 0 ? byStart : a.endMs.compareTo(b.endMs);
      });
      return decoded;
    } catch (_) {
      return const [];
    }
  }
}

/// Merges Whisper results idempotently while preserving chronological order.
/// A retry of the same logical chunk cannot add a duplicate timing row.
List<AudioTextTiming> mergePodcastTranscriptSegments(
  Iterable<AudioTextTiming> existing,
  Iterable<AudioTextTiming> incoming,
) {
  final byIdentity = <String, AudioTextTiming>{};
  for (final timing in [...existing, ...incoming]) {
    if (timing.text.trim().isEmpty || timing.endMs <= timing.startMs) continue;
    final key = '${timing.startMs}:${timing.endMs}:${timing.text.trim()}';
    byIdentity[key] = timing;
  }
  final merged = byIdentity.values.toList()
    ..sort((a, b) {
      final byStart = a.startMs.compareTo(b.startMs);
      return byStart != 0 ? byStart : a.endMs.compareTo(b.endMs);
    });
  return merged;
}

const _whisperLanguageCodes = <String>{
  'af',
  'am',
  'ar',
  'as',
  'az',
  'ba',
  'be',
  'bg',
  'bn',
  'bo',
  'br',
  'bs',
  'ca',
  'cs',
  'cy',
  'da',
  'de',
  'el',
  'en',
  'es',
  'et',
  'eu',
  'fa',
  'fi',
  'fo',
  'fr',
  'gl',
  'gu',
  'ha',
  'haw',
  'he',
  'hi',
  'hr',
  'ht',
  'hu',
  'hy',
  'id',
  'is',
  'it',
  'ja',
  'jw',
  'ka',
  'kk',
  'km',
  'kn',
  'ko',
  'la',
  'lb',
  'ln',
  'lo',
  'lt',
  'lv',
  'mg',
  'mi',
  'mk',
  'ml',
  'mn',
  'mr',
  'ms',
  'mt',
  'my',
  'ne',
  'nl',
  'nn',
  'no',
  'oc',
  'pa',
  'pl',
  'ps',
  'pt',
  'ro',
  'ru',
  'sa',
  'sd',
  'si',
  'sk',
  'sl',
  'sn',
  'so',
  'sq',
  'sr',
  'su',
  'sv',
  'sw',
  'ta',
  'te',
  'tg',
  'th',
  'tk',
  'tl',
  'tr',
  'tt',
  'uk',
  'ur',
  'uz',
  'vi',
  'yi',
  'yo',
  'yue',
  'zh',
};

const _whisperLanguageAliases = <String, String>{
  'chinese': 'zh',
  'chi': 'zh',
  'cmn': 'zh',
  'zho': 'zh',
  'dutch': 'nl',
  'dut': 'nl',
  'nld': 'nl',
  'english': 'en',
  'eng': 'en',
  'french': 'fr',
  'fre': 'fr',
  'fra': 'fr',
  'german': 'de',
  'ger': 'de',
  'deu': 'de',
  'italian': 'it',
  'ita': 'it',
  'japanese': 'ja',
  'jpn': 'ja',
  'korean': 'ko',
  'kor': 'ko',
  'portuguese': 'pt',
  'por': 'pt',
  'russian': 'ru',
  'rus': 'ru',
  'spanish': 'es',
  'spa': 'es',
};

String resolveWhisperLanguage(
  String? languageHint, {
  String? fallbackLocale,
  bool supportsAuto = true,
}) {
  String? resolve(String? source) {
    final normalized = source?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    final alias = _whisperLanguageAliases[normalized];
    if (alias != null) return alias;
    final code = normalized.split(RegExp('[-_]')).first;
    if (_whisperLanguageCodes.contains(code)) return code;
    return _whisperLanguageAliases[code];
  }

  final hinted = resolve(languageHint);
  if (hinted != null) return hinted;
  if (supportsAuto) return 'auto';
  return resolve(fallbackLocale) ?? 'en';
}
