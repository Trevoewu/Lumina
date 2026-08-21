import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/models/chapter_manifest.dart';
import 'app_log_service.dart';
import 'audiobook_manifest_validator.dart';

class ChapterPlaybackSource {
  final ChapterManifest manifest;
  final String chapterTitle;
  final String? coverPath;

  const ChapterPlaybackSource({
    required this.manifest,
    required this.chapterTitle,
    this.coverPath,
  });
}

class PodcastPlaybackSource {
  final String episodeId;
  final String showId;
  final String showTitle;
  final String title;
  final String audioUrl;
  final String? imageUrl;
  final int durationMs;

  const PodcastPlaybackSource({
    required this.episodeId,
    required this.showId,
    required this.showTitle,
    required this.title,
    required this.audioUrl,
    required this.imageUrl,
    required this.durationMs,
  });
}

class _QueueEntry {
  final ChapterManifest manifest;
  final SegmentEntry segment;
  final int chapterOffsetMs;
  final int chapterDurationMs;

  const _QueueEntry({
    required this.manifest,
    required this.segment,
    required this.chapterOffsetMs,
    required this.chapterDurationMs,
  });
}

int nextChapterQueueIndex(List<String> chapterIds, int currentIndex) {
  if (currentIndex < 0 || currentIndex >= chapterIds.length) return -1;
  final currentChapterId = chapterIds[currentIndex];
  return chapterIds.indexWhere(
    (chapterId) => chapterId != currentChapterId,
    currentIndex + 1,
  );
}

int previousChapterQueueIndex(List<String> chapterIds, int currentIndex) {
  if (currentIndex < 0 || currentIndex >= chapterIds.length) return -1;
  final currentChapterStart = chapterIds.indexOf(chapterIds[currentIndex]);
  if (currentChapterStart <= 0) return currentChapterStart;
  return chapterIds.indexOf(chapterIds[currentChapterStart - 1]);
}

/// AudioService 后台播放 Handler。
///
/// 每个段落作为一个 MediaItem / AudioSource queue item，便于锁屏控制、通知栏
/// 控制和段落级高亮同步。UI 仍可通过 [currentParagraphIdStream] 做同步高亮。
class LuminaAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player;

  ChapterManifest? _manifest;
  List<_QueueEntry> _queueEntries = const [];
  List<PodcastPlaybackSource> _podcastEntries = const [];
  List<String> _paragraphIds = const [];
  int _chapterDurationMs = 0;
  StreamSubscription? _playbackEventSub;
  StreamSubscription? _currentIndexSub;
  StreamSubscription? _durationSub;

  final _currentParagraphController = StreamController<String?>.broadcast();

  LuminaAudioHandler({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _playbackEventSub = _player.playbackEventStream.listen(_broadcastState);
    _currentIndexSub = _player.currentIndexStream.listen((index) {
      if (index == null || index < 0) return;
      if (_podcastEntries.isNotEmpty) {
        if (index >= _podcastEntries.length || index >= queue.value.length) {
          return;
        }
        _manifest = null;
        _chapterDurationMs = _podcastEntries[index].durationMs;
        mediaItem.add(queue.value[index]);
        _currentParagraphController.add(_podcastEntries[index].episodeId);
        _broadcastState(_player.playbackEvent);
        return;
      }
      if (index >= _queueEntries.length) return;
      _applyCurrentEntry(index);
      final item = queue.value[index];
      mediaItem.add(item);
      _currentParagraphController.add(_queueEntries[index].segment.paragraphId);
      _broadcastState(_player.playbackEvent);
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (_podcastEntries.isEmpty || duration == null) return;
      _chapterDurationMs = duration.inMilliseconds;
      final index = _player.currentIndex;
      if (index == null || index < 0 || index >= queue.value.length) return;
      final currentQueue = [...queue.value];
      currentQueue[index] = currentQueue[index].copyWith(duration: duration);
      queue.add(currentQueue);
      mediaItem.add(currentQueue[index]);
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
  bool get isPodcast =>
      mediaItem.valueOrNull?.extras?['mediaType'] == 'podcast';
  String? get currentParagraphId => isPodcast
      ? currentPodcastEpisodeId
      : mediaItem.valueOrNull?.extras?['paragraphId'] as String? ??
            mediaItem.valueOrNull?.id;
  String? get currentBookId => currentManifest?.bookId;
  String? get currentPodcastEpisodeId =>
      mediaItem.valueOrNull?.extras?['podcastEpisodeId'] as String?;
  String? get currentPodcastShowId =>
      mediaItem.valueOrNull?.extras?['podcastShowId'] as String?;
  String? get currentChapterId => currentManifest?.chapterId;
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
    String? coverPath,
    String paragraphLabel = 'Paragraph',
    Duration initialPosition = Duration.zero,
  }) async {
    await loadChapters(
      chapters: [
        ChapterPlaybackSource(
          manifest: manifest,
          chapterTitle: chapterTitle ?? '',
          coverPath: coverPath,
        ),
      ],
      initialChapterId: manifest.chapterId,
      audioRoot: audioRoot,
      bookTitle: bookTitle,
      paragraphLabel: paragraphLabel,
      initialPosition: initialPosition,
    );
  }

  Future<void> loadChapters({
    required List<ChapterPlaybackSource> chapters,
    required String initialChapterId,
    required String audioRoot,
    String? bookTitle,
    String paragraphLabel = 'Paragraph',
    Duration initialPosition = Duration.zero,
  }) async {
    if (chapters.isEmpty) {
      throw StateError('没有可播放的章节。');
    }
    _podcastEntries = const [];
    AppLogger.info(
      'Playback',
      '加载连续章节 book=${chapters.first.manifest.bookId} '
          'initialChapter=$initialChapterId chapters=${chapters.length}',
    );

    final items = <MediaItem>[];
    final sources = <AudioSource>[];
    final entries = <_QueueEntry>[];
    final artworkUris = <String, Uri?>{};
    var initialIndex = -1;
    for (final chapter in chapters) {
      final playable = <SegmentEntry>[];
      for (final segment in contiguousPlayableSegments(chapter.manifest)) {
        final file = File('$audioRoot/${segment.audioFile}');
        if (!await file.exists() || await file.length() <= 64) break;
        playable.add(segment);
      }
      final chapterDurationMs = playable.fold<int>(
        0,
        (total, segment) => total + segment.durationMs,
      );
      final coverPath = chapter.coverPath;
      Uri? artUri;
      if (coverPath != null) {
        if (!artworkUris.containsKey(coverPath)) {
          artworkUris[coverPath] = await _localArtworkUri(coverPath);
        }
        artUri = artworkUris[coverPath];
      }
      var chapterOffsetMs = 0;
      for (var i = 0; i < playable.length; i++) {
        final segment = playable[i];
        if (chapter.manifest.chapterId == initialChapterId &&
            initialIndex < 0) {
          initialIndex = entries.length;
        }
        final item = _mediaItemForSegment(
          manifest: chapter.manifest,
          segment: segment,
          paragraphNumber: i + 1,
          bookTitle: bookTitle,
          chapterTitle: chapter.chapterTitle,
          paragraphLabel: paragraphLabel,
          chapterDurationMs: chapterDurationMs,
          artUri: artUri,
        );
        entries.add(
          _QueueEntry(
            manifest: chapter.manifest,
            segment: segment,
            chapterOffsetMs: chapterOffsetMs,
            chapterDurationMs: chapterDurationMs,
          ),
        );
        items.add(item);
        sources.add(
          AudioSource.uri(
            File('$audioRoot/${segment.audioFile}').uri,
            tag: item,
          ),
        );
        chapterOffsetMs += segment.durationMs;
      }
    }

    if (initialIndex < 0) {
      throw StateError('这一章没有可播放的缓存音频，请重新生成。');
    }

    _queueEntries = entries;
    _paragraphIds = entries
        .map((entry) => entry.segment.paragraphId)
        .toList(growable: false);
    queue.add(items);
    try {
      await _player.setAudioSources(sources, initialIndex: initialIndex);
    } catch (error, stackTrace) {
      try {
        await _player.stop();
        await _player.clearAudioSources();
      } catch (_) {}
      await _resetLoadedState();
      AppLogger.error(
        'Playback',
        '播放器加载音频源失败 chapter=$initialChapterId',
        error: error,
        stackTrace: stackTrace,
      );
      throw StateError('音频缓存无法播放，请清除后重新生成。$error');
    }

    var loadedIndex = initialIndex;
    _applyCurrentEntry(loadedIndex);
    if (initialPosition > Duration.zero) {
      await seekToChapterOffset(initialPosition);
      loadedIndex = _player.currentIndex ?? loadedIndex;
      _applyCurrentEntry(loadedIndex);
    }
    mediaItem.add(items[loadedIndex]);
    _currentParagraphController.add(items[loadedIndex].id);
    _broadcastState(_player.playbackEvent);
    AppLogger.info(
      'Playback',
      '连续章节加载完成 chapter=$initialChapterId '
          'queueItems=${entries.length} durationMs=$_chapterDurationMs',
    );
  }

  Future<void> loadPodcastQueue({
    required List<PodcastPlaybackSource> episodes,
    required String initialEpisodeId,
    Duration initialPosition = Duration.zero,
  }) async {
    if (episodes.isEmpty) throw StateError('没有可播放的 Podcast 单集。');
    final initialIndex = episodes.indexWhere(
      (episode) => episode.episodeId == initialEpisodeId,
    );
    if (initialIndex < 0) throw StateError('找不到要播放的 Podcast 单集。');

    AppLogger.info(
      'Playback',
      '加载 Podcast 队列 episode=$initialEpisodeId count=${episodes.length}',
    );
    final items = <MediaItem>[
      for (final episode in episodes)
        MediaItem(
          id: episode.episodeId,
          album: episode.showTitle,
          title: episode.title,
          artUri: episode.imageUrl == null
              ? null
              : Uri.tryParse(episode.imageUrl!),
          duration: episode.durationMs <= 0
              ? null
              : Duration(milliseconds: episode.durationMs),
          extras: {
            'mediaType': 'podcast',
            'podcastEpisodeId': episode.episodeId,
            'podcastShowId': episode.showId,
            'audioUrl': episode.audioUrl,
            if (episode.imageUrl != null) 'imageUrl': episode.imageUrl,
          },
        ),
    ];
    final sources = <AudioSource>[
      for (var index = 0; index < episodes.length; index++)
        AudioSource.uri(Uri.parse(episodes[index].audioUrl), tag: items[index]),
    ];

    _manifest = null;
    _queueEntries = const [];
    _paragraphIds = const [];
    _podcastEntries = episodes;
    _chapterDurationMs = episodes[initialIndex].durationMs;
    queue.add(items);
    try {
      await _player.setAudioSources(sources, initialIndex: initialIndex);
      if (initialPosition > Duration.zero) {
        await _player.seek(initialPosition, index: initialIndex);
      }
    } catch (error, stackTrace) {
      try {
        await _player.stop();
        await _player.clearAudioSources();
      } catch (_) {}
      await _resetLoadedState();
      AppLogger.error(
        'Playback',
        'Podcast 音频加载失败 episode=$initialEpisodeId',
        error: error,
        stackTrace: stackTrace,
      );
      throw StateError('无法加载 Podcast 音频：$error');
    }

    mediaItem.add(items[initialIndex]);
    _currentParagraphController.add(initialEpisodeId);
    _broadcastState(_player.playbackEvent);
  }

  /// 把新缓存好的连续段落追加到当前章节播放队列。
  ///
  /// [manifest] 应只包含从章节开头起连续就绪的分段；这样播放不会
  /// 跳过尚未生成的段落。新音频会在下一章之前插入，不重载当前播放位置。
  Future<bool> appendChapterSegments({
    required ChapterManifest manifest,
    required String audioRoot,
    required String chapterTitle,
    String? bookTitle,
    String paragraphLabel = 'Paragraph',
  }) async {
    if (currentBookId != manifest.bookId ||
        currentChapterId != manifest.chapterId) {
      return false;
    }

    final chapterStart = _queueEntries.indexWhere(
      (entry) => entry.manifest.chapterId == manifest.chapterId,
    );
    if (chapterStart < 0) return false;
    final chapterEnd =
        _queueEntries.lastIndexWhere(
          (entry) => entry.manifest.chapterId == manifest.chapterId,
        ) +
        1;
    final existing = _queueEntries.sublist(chapterStart, chapterEnd);

    final playable = <SegmentEntry>[];
    for (final segment in contiguousPlayableSegments(manifest)) {
      final file = File('$audioRoot/${segment.audioFile}');
      if (!await file.exists() || await file.length() <= 64) break;
      playable.add(segment);
    }
    if (playable.length <= existing.length) return false;
    for (var i = 0; i < existing.length; i++) {
      if (existing[i].segment.paragraphId != playable[i].paragraphId) {
        return false;
      }
    }

    final additions = playable.skip(existing.length).toList(growable: false);
    final chapterDurationMs = playable.fold<int>(
      0,
      (total, segment) => total + segment.durationMs,
    );
    final currentArtUri = mediaItem.valueOrNull?.artUri;
    final wasWaitingAtCacheBoundary =
        _player.processingState == ProcessingState.completed;
    final additionSources = additions
        .map(
          (segment) => AudioSource.uri(
            File('$audioRoot/${segment.audioFile}').uri,
            tag: _mediaItemForSegment(
              manifest: manifest,
              segment: segment,
              paragraphNumber: manifest.segments.indexOf(segment) + 1,
              bookTitle: bookTitle,
              chapterTitle: chapterTitle,
              paragraphLabel: paragraphLabel,
              chapterDurationMs: chapterDurationMs,
              artUri: currentArtUri,
            ),
          ),
        )
        .toList(growable: false);
    await _player.insertAudioSources(chapterEnd, additionSources);

    var chapterOffsetMs = 0;
    final chapterEntries = <_QueueEntry>[];
    final chapterItems = <MediaItem>[];
    for (var i = 0; i < playable.length; i++) {
      final segment = playable[i];
      chapterEntries.add(
        _QueueEntry(
          manifest: manifest,
          segment: segment,
          chapterOffsetMs: chapterOffsetMs,
          chapterDurationMs: chapterDurationMs,
        ),
      );
      chapterItems.add(
        _mediaItemForSegment(
          manifest: manifest,
          segment: segment,
          paragraphNumber: i + 1,
          bookTitle: bookTitle,
          chapterTitle: chapterTitle,
          paragraphLabel: paragraphLabel,
          chapterDurationMs: chapterDurationMs,
          artUri: currentArtUri,
        ),
      );
      chapterOffsetMs += segment.durationMs;
    }

    _queueEntries = [
      ..._queueEntries.take(chapterStart),
      ...chapterEntries,
      ..._queueEntries.skip(chapterEnd),
    ];
    _paragraphIds = _queueEntries
        .map((entry) => entry.segment.paragraphId)
        .toList(growable: false);
    final updatedQueue = [...queue.value]
      ..replaceRange(chapterStart, chapterEnd, chapterItems);
    queue.add(updatedQueue);

    if (wasWaitingAtCacheBoundary) {
      await _player.seek(Duration.zero, index: chapterEnd);
    }

    final currentIndex = _player.currentIndex;
    if (currentIndex != null) {
      _applyCurrentEntry(currentIndex);
      if (currentIndex < updatedQueue.length) {
        mediaItem.add(updatedQueue[currentIndex]);
      }
    }
    _broadcastState(_player.playbackEvent);
    AppLogger.info(
      'Playback',
      '流式追加章节缓存 chapter=${manifest.chapterId} '
          'added=${additions.length} playable=${playable.length}',
    );
    return true;
  }

  MediaItem _mediaItemForSegment({
    required ChapterManifest manifest,
    required SegmentEntry segment,
    required int paragraphNumber,
    required String chapterTitle,
    required String paragraphLabel,
    required int chapterDurationMs,
    Uri? artUri,
    String? bookTitle,
  }) {
    return MediaItem(
      id: segment.paragraphId,
      album: bookTitle ?? 'Lumina',
      title: chapterTitle.isEmpty
          ? '$paragraphLabel $paragraphNumber'
          : '$chapterTitle · $paragraphLabel $paragraphNumber',
      artUri: artUri,
      // Playback remains split into paragraph-sized audio sources for
      // highlighting, while system media surfaces expose a chapter timeline.
      duration: Duration(milliseconds: chapterDurationMs),
      extras: {
        'bookId': manifest.bookId,
        'chapterId': manifest.chapterId,
        'paragraphId': segment.paragraphId,
        'audioFile': segment.audioFile,
      },
    );
  }

  Future<void> playFromParagraph(String paragraphId) async {
    await playFromParagraphOffset(paragraphId, Duration.zero);
  }

  Future<void> playFromParagraphOffset(
    String paragraphId,
    Duration position,
  ) async {
    if (_podcastEntries.isNotEmpty) {
      if (currentPodcastEpisodeId != paragraphId) return;
      final durationMs = _chapterDurationMs;
      final offsetMs = durationMs <= 0
          ? position.inMilliseconds.clamp(0, 1 << 31)
          : position.inMilliseconds.clamp(0, durationMs);
      await _player.seek(Duration(milliseconds: offsetMs));
      unawaited(play());
      return;
    }
    final index = _paragraphIds.indexOf(paragraphId);
    if (index < 0) return;
    final segment = index < 0 ? null : _queueEntries[index].segment;
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
    final queueIndex = _queueEntries.indexWhere(
      (entry) =>
          entry.manifest.chapterId == manifest.chapterId &&
          entry.segment.paragraphId == segment.paragraphId,
    );
    if (queueIndex < 0) return false;

    final offsetMs = position.inMilliseconds.clamp(0, segment.durationMs);
    await _player.seek(Duration(milliseconds: offsetMs), index: queueIndex);
    return true;
  }

  Future<void> seekToChapterOffset(Duration offset) async {
    if (_podcastEntries.isNotEmpty) {
      final knownDurationMs = _chapterDurationMs > 0
          ? _chapterDurationMs
          : _player.duration?.inMilliseconds ?? 0;
      final requestedMs = offset.inMilliseconds;
      final targetMs = knownDurationMs > 0
          ? requestedMs.clamp(0, knownDurationMs)
          : requestedMs < 0
          ? 0
          : requestedMs;
      await _player.seek(Duration(milliseconds: targetMs));
      return;
    }
    final chapterId = currentChapterId;
    if (chapterId == null || _chapterDurationMs <= 0) return;

    final targetMs = offset.inMilliseconds.clamp(0, _chapterDurationMs);
    final chapterIndices = <int>[
      for (var i = 0; i < _queueEntries.length; i++)
        if (_queueEntries[i].manifest.chapterId == chapterId) i,
    ];
    for (var localIndex = 0; localIndex < chapterIndices.length; localIndex++) {
      final queueIndex = chapterIndices[localIndex];
      final entry = _queueEntries[queueIndex];
      final startMs = entry.chapterOffsetMs;
      final endMs = startMs + entry.segment.durationMs;
      final isLast = localIndex == chapterIndices.length - 1;
      if (targetMs < endMs || isLast) {
        await _player.seek(
          Duration(
            milliseconds: (targetMs - startMs).clamp(0, endMs - startMs),
          ),
          index: queueIndex,
        );
        return;
      }
    }
  }

  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed &&
        (_paragraphIds.isNotEmpty || _podcastEntries.isNotEmpty)) {
      await _player.seek(
        Duration.zero,
        index: _podcastEntries.isNotEmpty ? _player.currentIndex : 0,
      );
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
    if (!_queueEntries.any(
      (entry) =>
          entry.manifest.bookId == bookId &&
          entry.manifest.chapterId == chapterId,
    )) {
      return;
    }
    await unload();
  }

  Future<void> unloadIfPodcastEpisode(String episodeId) async {
    if (currentPodcastEpisodeId != episodeId) return;
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
    _queueEntries = const [];
    _podcastEntries = const [];
    _paragraphIds = const [];
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
  Future<void> skipToNext() async {
    final index = _player.currentIndex;
    if (index == null || index < 0) return;
    if (_podcastEntries.isNotEmpty) {
      if (index + 1 < _podcastEntries.length) {
        await _player.seek(Duration.zero, index: index + 1);
      }
      return;
    }
    if (index >= _queueEntries.length) return;
    final nextIndex = nextChapterQueueIndex(
      _queueEntries
          .map((entry) => entry.manifest.chapterId)
          .toList(growable: false),
      index,
    );
    if (nextIndex >= 0) {
      await _player.seek(Duration.zero, index: nextIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final index = _player.currentIndex;
    if (index == null || index < 0) return;
    if (_podcastEntries.isNotEmpty) {
      if (_player.position > const Duration(seconds: 5) || index == 0) {
        await _player.seek(Duration.zero, index: index);
      } else {
        await _player.seek(Duration.zero, index: index - 1);
      }
      return;
    }
    if (index >= _queueEntries.length) return;
    final previousChapterStart = previousChapterQueueIndex(
      _queueEntries
          .map((entry) => entry.manifest.chapterId)
          .toList(growable: false),
      index,
    );
    if (previousChapterStart >= 0) {
      await _player.seek(Duration.zero, index: previousChapterStart);
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    final appliedSpeed = speed.clamp(0.5, 3.0);
    AppLogger.info('Playback', '设置倍速 speed=$appliedSpeed');
    await _player.setSpeed(appliedSpeed);
  }

  Future<void> dispose() async {
    await _playbackEventSub?.cancel();
    await _currentIndexSub?.cancel();
    await _durationSub?.cancel();
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
        updatePosition: chapterPosition,
        bufferedPosition: _chapterBufferedPositionFrom(
          _player.bufferedPosition,
        ),
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  Duration _chapterPositionFrom(Duration paragraphPosition) {
    if (_podcastEntries.isNotEmpty) return paragraphPosition;
    if (_queueEntries.isEmpty || _chapterDurationMs <= 0) {
      return paragraphPosition;
    }

    final index = _player.currentIndex ?? 0;
    if (index < 0 || index >= _queueEntries.length) {
      return Duration(
        milliseconds: paragraphPosition.inMilliseconds.clamp(
          0,
          _chapterDurationMs,
        ),
      );
    }

    final positionMs =
        _queueEntries[index].chapterOffsetMs + paragraphPosition.inMilliseconds;
    return Duration(milliseconds: positionMs.clamp(0, _chapterDurationMs));
  }

  Duration _chapterBufferedPositionFrom(Duration paragraphBufferedPosition) {
    if (_podcastEntries.isNotEmpty) return paragraphBufferedPosition;
    if (_queueEntries.isEmpty || _chapterDurationMs <= 0) {
      return paragraphBufferedPosition;
    }

    final index = _player.currentIndex ?? 0;
    if (index < 0 || index >= _queueEntries.length) {
      return chapterPosition;
    }
    final bufferedMs =
        _queueEntries[index].chapterOffsetMs +
        paragraphBufferedPosition.inMilliseconds;
    return Duration(milliseconds: bufferedMs.clamp(0, _chapterDurationMs));
  }

  void _applyCurrentEntry(int index) {
    if (index < 0 || index >= _queueEntries.length) return;
    final entry = _queueEntries[index];
    _manifest = entry.manifest;
    _chapterDurationMs = entry.chapterDurationMs;
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

Future<Uri?> _localArtworkUri(String path) async {
  if (path.trim().isEmpty) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  return file.uri;
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
