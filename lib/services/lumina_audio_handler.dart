import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/models/chapter_manifest.dart';
import 'app_log_service.dart';

/// AudioService 后台播放 Handler。
///
/// 每个段落作为一个 MediaItem / AudioSource queue item，便于锁屏控制、通知栏
/// 控制和段落级高亮同步。UI 仍可通过 [currentParagraphIdStream] 做同步高亮。
class LuminaAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player;

  ChapterManifest? _manifest;
  List<String> _paragraphIds = const [];
  List<int> _paragraphStartOffsetsMs = const [];
  int _chapterDurationMs = 0;
  StreamSubscription? _playbackEventSub;
  StreamSubscription? _currentIndexSub;

  final _currentParagraphController = StreamController<String?>.broadcast();

  LuminaAudioHandler({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _playbackEventSub = _player.playbackEventStream.listen(_broadcastState);
    _currentIndexSub = _player.currentIndexStream.listen((index) {
      if (index == null || index < 0 || index >= _paragraphIds.length) return;
      final item = queue.value[index];
      mediaItem.add(item);
      _currentParagraphController.add(_paragraphIds[index]);
    });
  }

  Stream<String?> get currentParagraphIdStream =>
      _currentParagraphController.stream;

  AudioPlayer get player => _player;
  Duration get position => _player.position;
  Stream<Duration> get positionStream => _player.positionStream;
  Duration get chapterPosition => _chapterPositionFrom(_player.position);
  Duration get chapterDuration => Duration(milliseconds: _chapterDurationMs);
  Stream<Duration> get chapterPositionStream =>
      _player.positionStream.map(_chapterPositionFrom);
  String? get currentParagraphId =>
      mediaItem.valueOrNull?.extras?['paragraphId'] as String? ??
      mediaItem.valueOrNull?.id;
  String? get currentBookId => _manifest?.bookId;
  String? get currentChapterId => _manifest?.chapterId;
  ChapterManifest? get currentManifest => _manifest;
  int? get currentParagraphIndex {
    final manifest = _manifest;
    final paragraphId = currentParagraphId;
    if (manifest == null || paragraphId == null) return null;
    final index = manifest.segments.indexWhere(
      (segment) => segment.paragraphId == paragraphId,
    );
    return index < 0 ? null : index;
  }

  Future<void> loadChapter({
    required ChapterManifest manifest,
    required String audioRoot,
    String? bookTitle,
    String? chapterTitle,
  }) async {
    AppLogger.info(
      'Playback',
      '加载章节 book=${manifest.bookId} chapter=${manifest.chapterId} '
          'segments=${manifest.segments.length}',
    );
    final readySegments = manifest.segments
        .where((segment) => segment.state == ParagraphAudioState.ready)
        .toList(growable: false);

    final playableSegments = <SegmentEntry>[];
    for (final segment in readySegments) {
      final file = File('$audioRoot/${segment.audioFile}');
      if (await file.exists() && await file.length() > 64) {
        playableSegments.add(segment);
      }
    }

    if (playableSegments.isEmpty) {
      throw StateError('这一章没有可播放的缓存音频，请重新生成。');
    }

    var offsetMs = 0;
    final offsets = <int>[];
    for (final segment in playableSegments) {
      offsets.add(offsetMs);
      offsetMs += segment.durationMs;
    }

    final items = <MediaItem>[];
    final sources = <AudioSource>[];
    for (var i = 0; i < playableSegments.length; i++) {
      final segment = playableSegments[i];
      final file = File('$audioRoot/${segment.audioFile}');
      final item = MediaItem(
        id: segment.paragraphId,
        album: bookTitle ?? 'Lumina',
        title: chapterTitle == null
            ? '段落 ${i + 1}'
            : '$chapterTitle · 段落 ${i + 1}',
        duration: Duration(milliseconds: segment.durationMs),
        extras: {
          'bookId': manifest.bookId,
          'chapterId': manifest.chapterId,
          'paragraphId': segment.paragraphId,
          'audioFile': segment.audioFile,
        },
      );
      items.add(item);
      sources.add(AudioSource.uri(file.uri, tag: item));
    }

    queue.add(items);
    try {
      await _player.setAudioSources(sources);
    } catch (error, stackTrace) {
      try {
        await _player.stop();
        await _player.clearAudioSources();
      } catch (_) {}
      await _resetLoadedState();
      AppLogger.error(
        'Playback',
        '播放器加载音频源失败 chapter=${manifest.chapterId}',
        error: error,
        stackTrace: stackTrace,
      );
      throw StateError('音频缓存无法播放，请清除后重新生成。$error');
    }

    _manifest = manifest;
    _paragraphIds = playableSegments
        .map((segment) => segment.paragraphId)
        .toList(growable: false);
    _paragraphStartOffsetsMs = offsets;
    _chapterDurationMs = playableSegments.fold<int>(
      0,
      (total, segment) => total + segment.durationMs,
    );
    mediaItem.add(items.first);
    _currentParagraphController.add(items.first.id);
    _broadcastState(_player.playbackEvent);
    AppLogger.info(
      'Playback',
      '章节加载完成 chapter=${manifest.chapterId} '
          'playable=${playableSegments.length} durationMs=$_chapterDurationMs',
    );
  }

  Future<void> playFromParagraph(String paragraphId) async {
    await playFromParagraphOffset(paragraphId, Duration.zero);
  }

  Future<void> playFromParagraphOffset(
    String paragraphId,
    Duration position,
  ) async {
    final index = _paragraphIds.indexOf(paragraphId);
    if (index < 0) return;
    final segment = _manifest?.segments
        .where((entry) => entry.paragraphId == paragraphId)
        .firstOrNull;
    final endMs = segment?.durationMs ?? position.inMilliseconds;
    final offsetMs = position.inMilliseconds.clamp(0, endMs);
    await _player.seek(Duration(milliseconds: offsetMs), index: index);
    unawaited(play());
  }

  Future<bool> seekToProgress({
    required int paragraphIndex,
    required Duration position,
  }) async {
    final manifest = _manifest;
    if (manifest == null ||
        paragraphIndex < 0 ||
        paragraphIndex >= manifest.segments.length) {
      return false;
    }

    final segment = manifest.segments[paragraphIndex];
    final queueIndex = _paragraphIds.indexOf(segment.paragraphId);
    if (queueIndex < 0) return false;

    final offsetMs = position.inMilliseconds.clamp(0, segment.durationMs);
    await _player.seek(Duration(milliseconds: offsetMs), index: queueIndex);
    return true;
  }

  Future<void> seekToChapterOffset(Duration offset) async {
    if (_paragraphStartOffsetsMs.isEmpty || _chapterDurationMs <= 0) return;

    final targetMs = offset.inMilliseconds.clamp(0, _chapterDurationMs);
    for (var index = 0; index < _paragraphStartOffsetsMs.length; index++) {
      final startMs = _paragraphStartOffsetsMs[index];
      final endMs = index + 1 < _paragraphStartOffsetsMs.length
          ? _paragraphStartOffsetsMs[index + 1]
          : _chapterDurationMs;
      final isLast = index == _paragraphStartOffsetsMs.length - 1;
      if (targetMs < endMs || isLast) {
        await _player.seek(
          Duration(
            milliseconds: (targetMs - startMs).clamp(0, endMs - startMs),
          ),
          index: index,
        );
        return;
      }
    }
  }

  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed &&
        _paragraphIds.isNotEmpty) {
      await _player.seek(Duration.zero, index: 0);
    }
    if (!_player.playing) {
      AppLogger.info(
        'Playback',
        '开始播放 chapter=${_manifest?.chapterId} paragraph=$currentParagraphId',
      );
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (_player.playing) {
      AppLogger.info(
        'Playback',
        '暂停播放 chapter=${_manifest?.chapterId} '
            'positionMs=${chapterPosition.inMilliseconds}',
      );
    }
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  Future<void> unloadIfBook(String bookId) async {
    if (_manifest?.bookId != bookId) return;
    await unload();
  }

  Future<void> unloadIfChapter(String bookId, String chapterId) async {
    if (_manifest?.bookId != bookId || _manifest?.chapterId != chapterId) {
      return;
    }
    await unload();
  }

  Future<void> unload() async {
    AppLogger.info(
      'Playback',
      '卸载章节 book=${_manifest?.bookId} chapter=${_manifest?.chapterId}',
    );
    await _player.stop();
    await _player.clearAudioSources();
    await _resetLoadedState();
    _broadcastState(_player.playbackEvent);
  }

  Future<void> _resetLoadedState() async {
    _manifest = null;
    _paragraphIds = const [];
    _paragraphStartOffsetsMs = const [];
    _chapterDurationMs = 0;
    queue.add(const []);
    mediaItem.add(null);
    _currentParagraphController.add(null);
  }

  @override
  Future<void> seek(Duration position) => seekToChapterOffset(position);

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setSpeed(double speed) async {
    final appliedSpeed = speed.clamp(0.5, 3.0);
    AppLogger.info('Playback', '设置倍速 speed=$appliedSpeed');
    await _player.setSpeed(appliedSpeed);
  }

  Future<void> dispose() async {
    await _playbackEventSub?.cancel();
    await _currentIndexSub?.cancel();
    await _currentParagraphController.close();
    await _player.dispose();
  }

  void _broadcastState(PlaybackEvent event) {
    // just_audio keeps `playing` true when playback reaches the end. Expose the
    // completed state as paused so every UI surface and system notification
    // switches back to a play action.
    final isPlaying =
        _player.playing && _player.processingState != ProcessingState.completed;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setSpeed,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessingState(_player.processingState),
        playing: isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  Duration _chapterPositionFrom(Duration paragraphPosition) {
    if (_paragraphStartOffsetsMs.isEmpty || _chapterDurationMs <= 0) {
      return paragraphPosition;
    }

    final index = _player.currentIndex ?? 0;
    if (index < 0 || index >= _paragraphStartOffsetsMs.length) {
      return Duration(
        milliseconds: paragraphPosition.inMilliseconds.clamp(
          0,
          _chapterDurationMs,
        ),
      );
    }

    final positionMs =
        _paragraphStartOffsetsMs[index] + paragraphPosition.inMilliseconds;
    return Duration(milliseconds: positionMs.clamp(0, _chapterDurationMs));
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }
}

Future<LuminaAudioHandler> initLuminaAudioHandler() async {
  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration.speech());

  return AudioService.init(
    builder: LuminaAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.lumina.audio',
      androidNotificationChannelName: 'Lumina Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
