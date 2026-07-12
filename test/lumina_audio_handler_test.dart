import 'package:flutter_test/flutter_test.dart';
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
}
