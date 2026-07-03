import 'dart:async';

import '../data/database/app_database.dart';
import '../domain/models/listening_statistics.dart';
import 'app_log_service.dart';
import 'lumina_audio_handler.dart';

/// Persists the active audiobook position while playback continues globally.
class PlaybackProgressService {
  final AppDatabase database;
  final LuminaAudioHandler audioHandler;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<String?>? _paragraphSub;
  StreamSubscription? _playerStateSub;
  DateTime? _lastQueuedAt;
  _ProgressSnapshot? _lastQueued;
  Future<void> _writeQueue = Future.value();
  DateTime? _lastListeningTick;
  String? _pendingListeningDate;
  int _pendingListeningMs = 0;
  bool _wasPlaying = false;

  PlaybackProgressService({required this.database, required this.audioHandler});

  void start() {
    _positionSub = audioHandler.positionStream.listen((_) {
      _captureListeningTime(DateTime.now());
      _queueCurrent();
    });
    _paragraphSub = audioHandler.currentParagraphIdStream.listen(
      (_) => _queueCurrent(force: true),
    );
    _playerStateSub = audioHandler.player.playerStateStream.listen((state) {
      final now = DateTime.now();
      if (_wasPlaying) _captureListeningTime(now);
      if (state.playing && !_wasPlaying) {
        _lastListeningTick = now;
        _queueListeningWrite(listeningDateKey(now), 0, newSession: true);
      } else if (!state.playing) {
        _lastListeningTick = null;
        _flushListeningTime();
        _queueCurrent(force: true);
      }
      _wasPlaying = state.playing;
    });
  }

  void _captureListeningTime(DateTime now) {
    if (!_wasPlaying) return;
    final previous = _lastListeningTick;
    _lastListeningTick = now;
    if (previous == null) return;

    final elapsedMs = now.difference(previous).inMilliseconds;
    if (elapsedMs <= 0 || elapsedMs > 5000) return;
    final dateKey = listeningDateKey(previous);
    if (_pendingListeningDate != null && _pendingListeningDate != dateKey) {
      _flushListeningTime();
    }
    _pendingListeningDate = dateKey;
    _pendingListeningMs += elapsedMs;
    if (_pendingListeningMs >= 10000) _flushListeningTime();
  }

  void _flushListeningTime() {
    final dateKey = _pendingListeningDate;
    final listenedMs = _pendingListeningMs;
    _pendingListeningDate = null;
    _pendingListeningMs = 0;
    if (dateKey == null || listenedMs <= 0) return;
    _queueListeningWrite(dateKey, listenedMs);
  }

  void _queueListeningWrite(
    String dateKey,
    int listenedMs, {
    bool newSession = false,
  }) {
    _writeQueue = _writeQueue.then((_) async {
      try {
        await database.addListeningTime(
          dateKey,
          listenedMs,
          newSession: newSession,
        );
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Playback',
          '保存每日收听统计失败 date=$dateKey',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
  }

  void _queueCurrent({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastQueuedAt != null &&
        now.difference(_lastQueuedAt!) < const Duration(seconds: 1)) {
      return;
    }

    final bookId = audioHandler.currentBookId;
    final chapterId = audioHandler.currentChapterId;
    final paragraphIndex = audioHandler.currentParagraphIndex;
    if (bookId == null || chapterId == null || paragraphIndex == null) return;

    final snapshot = _ProgressSnapshot(
      bookId: bookId,
      chapterId: chapterId,
      paragraphIndex: paragraphIndex,
      offsetMs: audioHandler.position.inMilliseconds,
    );
    if (snapshot == _lastQueued) return;

    _lastQueuedAt = now;
    _lastQueued = snapshot;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await database.updateReadingProgress(
          snapshot.bookId,
          chapterId: snapshot.chapterId,
          paragraphIndex: snapshot.paragraphIndex,
          offsetMs: snapshot.offsetMs,
        );
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Playback',
          '保存播放进度失败 book=${snapshot.bookId} '
              'chapter=${snapshot.chapterId}',
          error: error,
          stackTrace: stackTrace,
        );
        if (_lastQueued == snapshot) _lastQueued = null;
      }
    });
  }

  Future<void> dispose() async {
    if (_wasPlaying) _captureListeningTime(DateTime.now());
    _flushListeningTime();
    _queueCurrent(force: true);
    await _positionSub?.cancel();
    await _paragraphSub?.cancel();
    await _playerStateSub?.cancel();
    await _writeQueue;
  }
}

class _ProgressSnapshot {
  final String bookId;
  final String chapterId;
  final int paragraphIndex;
  final int offsetMs;

  const _ProgressSnapshot({
    required this.bookId,
    required this.chapterId,
    required this.paragraphIndex,
    required this.offsetMs,
  });

  @override
  bool operator ==(Object other) =>
      other is _ProgressSnapshot &&
      other.bookId == bookId &&
      other.chapterId == chapterId &&
      other.paragraphIndex == paragraphIndex &&
      other.offsetMs == offsetMs;

  @override
  int get hashCode => Object.hash(bookId, chapterId, paragraphIndex, offsetMs);
}
