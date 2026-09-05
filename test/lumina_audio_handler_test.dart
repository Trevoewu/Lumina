import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lumina/services/app_log_service.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/services/lumina_audio_handler.dart';

void main() {
  const chapterIds = ['chapter-1', 'chapter-1', 'chapter-2', 'chapter-2'];

  test('next skips to the first paragraph of the next chapter', () {
    expect(nextChapterQueueIndex(chapterIds, 0), 2);
    expect(nextChapterQueueIndex(chapterIds, 1), 2);
    expect(nextChapterQueueIndex(chapterIds, 3), -1);
  });

  test('previous skips to the first paragraph of the previous chapter', () {
    expect(previousChapterQueueIndex(chapterIds, 3), 0);
    expect(previousChapterQueueIndex(chapterIds, 2), 0);
    expect(previousChapterQueueIndex(chapterIds, 1), 0);
    expect(previousChapterQueueIndex(chapterIds, 0), 0);
  });

  test('player stream errors are recorded with their stream name', () async {
    final logs = AppLogService.instance;
    await logs.clear();

    logPlaybackStreamError(
      'playbackEvent',
      StateError('decoder failed'),
      StackTrace.current,
    );

    expect(logs.entries.value, hasLength(1));
    final entry = logs.entries.value.single;
    expect(entry.level, AppLogLevel.error);
    expect(entry.source, 'Playback');
    expect(entry.message, contains('stream=playbackEvent'));
    expect(entry.error, contains('decoder failed'));
    expect(entry.stackTrace, isNotEmpty);
  });

  test(
    'a queue swap ignores the index repeats of the playlist it replaces',
    () async {
      final player = _FakeAudioPlayer();
      final handler = LuminaAudioHandler(player: player);
      addTearDown(handler.dispose);

      final announced = <String?>[];
      final announcedSub = handler.currentParagraphIdStream.listen(
        announced.add,
      );
      addTearDown(announcedSub.cancel);

      final episodes = [
        for (var index = 0; index < 3; index++)
          PodcastPlaybackSource(
            episodeId: 'episode-$index',
            showId: 'show',
            showTitle: 'Show',
            title: 'Episode $index',
            audioUrl: 'https://example.com/$index.mp3',
            imageUrl: null,
            durationMs: 60000,
          ),
      ];

      await handler.loadPodcastQueue(
        episodes: episodes,
        initialEpisodeId: 'episode-0',
      );
      await pumpEventQueue();
      announced.clear();

      // just_audio keeps repeating the outgoing playlist's index until the new
      // sources finish loading. Those repeats must not be read against the queue
      // that is replacing it.
      player.emitIndexWhileLoading = 0;
      await handler.loadPodcastQueue(
        episodes: episodes,
        initialEpisodeId: 'episode-2',
      );
      await pumpEventQueue();

      expect(announced, [
        'episode-2',
      ], reason: 'a load may only announce the episode it settled on');
      expect(handler.currentPodcastEpisodeId, 'episode-2');
    },
  );

  test('the paragraph stream only reports genuine changes', () async {
    final player = _FakeAudioPlayer();
    final handler = LuminaAudioHandler(player: player);
    addTearDown(handler.dispose);

    final announced = <String?>[];
    final announcedSub = handler.currentParagraphIdStream.listen(announced.add);
    addTearDown(announcedSub.cancel);

    await handler.loadPodcastQueue(
      episodes: [
        for (var index = 0; index < 2; index++)
          PodcastPlaybackSource(
            episodeId: 'episode-$index',
            showId: 'show',
            showTitle: 'Show',
            title: 'Episode $index',
            audioUrl: 'https://example.com/$index.mp3',
            imageUrl: null,
            durationMs: 60000,
          ),
      ],
      initialEpisodeId: 'episode-0',
    );
    await pumpEventQueue();

    player.emitIndex(0);
    player.emitIndex(0);
    player.emitIndex(1);
    player.emitIndex(1);
    await pumpEventQueue();

    expect(
      announced,
      ['episode-0', 'episode-1'],
      reason: 'currentIndexStream repeats itself on every playback event',
    );
  });

  test('book queues accept LibriVox remote chapter audio', () async {
    final player = _FakeAudioPlayer();
    final handler = LuminaAudioHandler(player: player);
    addTearDown(handler.dispose);

    await handler.loadChapter(
      manifest: ChapterManifest(
        chapterId: 'chapter-remote',
        bookId: 'librivox-47',
        providerId: 'librivox',
        voiceId: 'Volunteer',
        speed: 1,
        segments: const [
          SegmentEntry(
            paragraphId: 'chapter-remote-audio',
            audioFile: 'https://archive.org/download/book/chapter.mp3',
            durationMs: 60000,
            state: ParagraphAudioState.ready,
          ),
        ],
        updatedAt: 1,
      ),
      audioRoot: '/path/that/does/not/exist',
      bookTitle: 'Public domain book',
      chapterTitle: 'Chapter 1',
    );

    expect(handler.currentBookId, 'librivox-47');
    expect(handler.currentChapterId, 'chapter-remote');
  });
}

/// Stands in for just_audio so the queue-swap ordering can be driven directly.
class _FakeAudioPlayer implements AudioPlayer {
  final _currentIndex = StreamController<int?>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playbackEvents = StreamController<PlaybackEvent>.broadcast();

  /// Replayed once during the next [setAudioSources], the way just_audio keeps
  /// reporting the outgoing playlist's index while the new one loads.
  int? emitIndexWhileLoading;
  int? _index;

  void emitIndex(int? index) {
    _index = index;
    _currentIndex.add(index);
  }

  @override
  Stream<int?> get currentIndexStream => _currentIndex.stream;

  @override
  int? get currentIndex => _index;

  @override
  Stream<Duration?> get durationStream => _duration.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _playbackEvents.stream;

  @override
  PlaybackEvent get playbackEvent => PlaybackEvent(currentIndex: _index);

  @override
  Stream<Duration> createPositionStream({
    int steps = 800,
    Duration minPeriod = const Duration(milliseconds: 200),
    Duration maxPeriod = const Duration(milliseconds: 200),
  }) => const Stream<Duration>.empty();

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    final stale = emitIndexWhileLoading;
    emitIndexWhileLoading = null;
    if (stale != null) {
      _currentIndex.add(stale);
      await pumpEventQueue();
    }
    emitIndex(initialIndex ?? 0);
    return null;
  }

  @override
  Duration get position => Duration.zero;

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  ProcessingState get processingState => ProcessingState.ready;

  @override
  bool get playing => false;

  @override
  double get speed => 1;

  @override
  Future<void> dispose() async {
    await _currentIndex.close();
    await _duration.close();
    await _playbackEvents.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
