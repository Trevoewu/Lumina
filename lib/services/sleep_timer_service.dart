import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'lumina_audio_handler.dart';

enum SleepTimerMode { off, duration, chapterEnd }

class SleepTimerState {
  final SleepTimerMode mode;
  final DateTime? endsAt;
  final Duration? duration;

  const SleepTimerState._({required this.mode, this.endsAt, this.duration});

  const SleepTimerState.off() : this._(mode: SleepTimerMode.off);

  SleepTimerState.duration(Duration duration)
    : this._(mode: SleepTimerMode.duration, duration: duration, endsAt: null);

  const SleepTimerState.chapterEnd() : this._(mode: SleepTimerMode.chapterEnd);

  bool get active => mode != SleepTimerMode.off;

  String get label {
    return switch (mode) {
      SleepTimerMode.off => '关闭',
      SleepTimerMode.duration => '${duration!.inMinutes} 分钟后',
      SleepTimerMode.chapterEnd => '本章结束',
    };
  }
}

class SleepTimerService {
  final _controller = StreamController<SleepTimerState>.broadcast();
  Timer? _timer;
  StreamSubscription<PlaybackState>? _playbackSub;
  SleepTimerState _state = const SleepTimerState.off();

  SleepTimerState get state => _state;
  Stream<SleepTimerState> get stream => _controller.stream;

  Future<void> scheduleDuration(
    Duration duration,
    LuminaAudioHandler handler,
  ) async {
    await cancel();
    _state = SleepTimerState.duration(duration);
    _controller.add(_state);
    _timer = Timer(duration, () async {
      await handler.pause();
      await cancel();
    });
  }

  Future<void> scheduleChapterEnd(LuminaAudioHandler handler) async {
    await cancel();
    _state = const SleepTimerState.chapterEnd();
    _controller.add(_state);
    _playbackSub = handler.playbackState.listen((state) async {
      if (state.processingState == AudioProcessingState.completed) {
        await handler.pause();
        await cancel();
      }
    });
  }

  Future<void> cancel() async {
    _timer?.cancel();
    _timer = null;
    await _playbackSub?.cancel();
    _playbackSub = null;
    _state = const SleepTimerState.off();
    if (!_controller.isClosed) _controller.add(_state);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _playbackSub?.cancel();
    await _controller.close();
  }
}
