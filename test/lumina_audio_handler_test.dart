import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/app_log_service.dart';
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
}
