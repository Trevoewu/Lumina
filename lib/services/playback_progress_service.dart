import 'dart:async';

import '../data/database/app_database.dart';
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

  PlaybackProgressService({required this.database, required this.audioHandler});

  void start() {
    _positionSub = audioHandler.positionStream.listen((_) => _queueCurrent());
    _paragraphSub = audioHandler.currentParagraphIdStream.listen(
      (_) => _queueCurrent(force: true),
    );
    _playerStateSub = audioHandler.player.playerStateStream.listen((state) {
      if (!state.playing) _queueCurrent(force: true);
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
      } catch (_) {
        if (_lastQueued == snapshot) _lastQueued = null;
      }
    });
  }

  Future<void> dispose() async {
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
