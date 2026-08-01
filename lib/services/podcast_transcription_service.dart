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

  const PodcastChunkWindow({required this.startMs, required this.durationMs});

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
}) {
  if (chunkDurationMs <= 0) return const [];
  final start = math.max(0, startFromMs);
  if (durationMs <= 0) {
    return [
      for (var index = 0; index < maxUnknownChunks; index++)
        PodcastChunkWindow(
          startMs: start + index * chunkDurationMs,
          durationMs: chunkDurationMs,
        ),
    ];
  }

  final windows = <PodcastChunkWindow>[];
  for (var offset = start; offset < durationMs; offset += chunkDurationMs) {
    windows.add(
      PodcastChunkWindow(
        startMs: offset,
        durationMs: math.min(chunkDurationMs, durationMs - offset),
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
  final Dio _dio;
  final WhisperController _controller;
  final Map<String, Future<String>> _audioDownloads = {};
  final StreamController<PodcastTranscriptionProgress> _progressController =
      StreamController<PodcastTranscriptionProgress>.broadcast();
  _ActiveTranscription? _active;
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

  Future<List<AudioTextTiming>> transcribe(
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
      // The row carries how far an earlier run got. Resuming replays only the
      // audio after that point and keeps the chunks it already cached.
      final stored = await database.getPodcastEpisode(episode.id) ?? episode;
      final resumeFromMs = stored.transcriptStatus == 'complete'
          ? 0
          : stored.transcriptProgressMs
                .clamp(0, math.max(0, durationMs))
                .toInt();
      final cached = resumeFromMs > 0
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
      emit(PodcastTranscriptionStage.complete, '本地转写完成', progress: 1);
      AppLogger.info(
        'Podcast',
        'Whisper 本地转写完成 episode=${episode.id} '
            'segments=${run.segments.length}',
      );
      return run.segments;
    } catch (error, stackTrace) {
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

      final chunkPath = p.join(
        chunkDirectory.path,
        'chunk_${startMs.toString().padLeft(9, '0')}.wav',
      );
      final hasAudio = await _extractAudioChunk(
        sourcePath: audioPath,
        targetPath: chunkPath,
        startMs: startMs,
        durationMs: requestedDurationMs,
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
        final result = await _controller.transcribe(
          model: defaultModel,
          audioPath: chunkPath,
          lang: language,
          withSegments: true,
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
        final chunkSegments = <AudioTextTiming>[
          for (final segment in response.segments ?? const [])
            if (segment.text.trim().isNotEmpty)
              AudioTextTiming(
                text: segment.text.trim(),
                startMs: (startMs + segment.fromTs.inMilliseconds).toInt(),
                endMs: (startMs + segment.toTs.inMilliseconds).toInt(),
              ),
        ];
        if (chunkSegments.isEmpty && response.text.trim().isNotEmpty) {
          chunkSegments.add(
            AudioTextTiming(
              text: response.text.trim(),
              startMs: startMs,
              endMs: startMs + requestedDurationMs,
            ),
          );
        }
        output.addAll(chunkSegments);
        completedMs = startMs + requestedDurationMs;

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
      return [
        for (final value in values)
          AudioTextTiming.fromJson(Map<String, dynamic>.from(value as Map)),
      ];
    } catch (_) {
      return const [];
    }
  }
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
