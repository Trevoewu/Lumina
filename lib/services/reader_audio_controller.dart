import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

import '../domain/models/chapter_manifest.dart';

/// 当前播放状态（供 UI 同步高亮）。
class ReaderPlaybackState {
  final bool playing;
  final String? bookId;
  final String? chapterId;
  final String? paragraphId;
  final Duration position;
  final Duration duration;
  final double speed;

  const ReaderPlaybackState({
    required this.playing,
    this.bookId,
    this.chapterId,
    this.paragraphId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
  });

  ReaderPlaybackState copyWith({
    bool? playing,
    String? bookId,
    String? chapterId,
    String? paragraphId,
    Duration? position,
    Duration? duration,
    double? speed,
  }) {
    return ReaderPlaybackState(
      playing: playing ?? this.playing,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      paragraphId: paragraphId ?? this.paragraphId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
    );
  }
}

/// 阅读器播放控制器。
///
/// 使用 just_audio ConcatenatingAudioSource 把每段音频作为 playlist item。
/// UI 点击段落时：seek(Duration.zero, index: paragraphIndex)。
/// 播放时：通过 currentIndexStream + positionStream 推导当前段落并高亮。
class ReaderAudioController {
  final AudioPlayer _player;

  ChapterManifest? _manifest;
  List<String> _paragraphIds = [];
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _indexSub;

  final _stateController = StreamController<ReaderPlaybackState>.broadcast();
  ReaderPlaybackState _state = const ReaderPlaybackState(playing: false);

  ReaderAudioController({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  Stream<ReaderPlaybackState> get stateStream => _stateController.stream;

  ReaderPlaybackState get state => _state;

  /// 加载某章 manifest。
  /// [audioRoot] 是 app_data/audio/{bookId} 目录。
  Future<void> loadChapter({
    required ChapterManifest manifest,
    required String audioRoot,
  }) async {
    _manifest = manifest;
    final readySegments = manifest.segments
        .where((s) => s.state == ParagraphAudioState.ready)
        .toList(growable: false);
    _paragraphIds = readySegments
        .map((s) => s.paragraphId)
        .toList(growable: false);

    final sources = readySegments
        .map((s) {
          final file = File('$audioRoot/${s.audioFile}');
          return AudioSource.uri(file.uri, tag: s.paragraphId);
        })
        .toList(growable: false);

    await _player.setAudioSources(sources);
    _emit(
      _state.copyWith(
        bookId: manifest.bookId,
        chapterId: manifest.chapterId,
        paragraphId: _paragraphIds.isEmpty ? null : _paragraphIds.first,
        duration: Duration(milliseconds: manifest.totalDurationMs),
      ),
    );

    _bindStreams();
  }

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> toggle() => _player.playing ? pause() : play();

  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 3.0).toDouble();
    await _player.setSpeed(clamped);
    _emit(_state.copyWith(speed: clamped));
  }

  /// 用户点击段落 → 从该段落开头播放。
  Future<void> playFromParagraph(String paragraphId) async {
    final index = _paragraphIds.indexOf(paragraphId);
    if (index < 0) return;
    await _player.seek(Duration.zero, index: index);
    await _player.play();
    _emit(_state.copyWith(paragraphId: paragraphId, playing: true));
  }

  /// 跳到章节内绝对偏移。用于恢复播放进度。
  Future<void> seekToChapterOffset(Duration offset) async {
    final manifest = _manifest;
    if (manifest == null) return;

    int acc = 0;
    for (var i = 0; i < manifest.segments.length; i++) {
      final seg = manifest.segments[i];
      if (seg.state != ParagraphAudioState.ready) continue;
      final next = acc + seg.durationMs;
      if (offset.inMilliseconds < next) {
        await _player.seek(
          Duration(milliseconds: offset.inMilliseconds - acc),
          index: i,
        );
        return;
      }
      acc = next;
    }
  }

  Future<void> dispose() async {
    await _positionSub?.cancel();
    await _playerStateSub?.cancel();
    await _indexSub?.cancel();
    await _stateController.close();
    await _player.dispose();
  }

  void _bindStreams() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _indexSub?.cancel();

    _positionSub = _player.positionStream.listen((pos) {
      _emit(_state.copyWith(position: pos));
    });

    _playerStateSub = _player.playerStateStream.listen((s) {
      _emit(_state.copyWith(playing: s.playing));
    });

    _indexSub = _player.currentIndexStream.listen((idx) {
      if (idx == null || idx < 0 || idx >= _paragraphIds.length) return;
      _emit(_state.copyWith(paragraphId: _paragraphIds[idx]));
    });
  }

  void _emit(ReaderPlaybackState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }
}
