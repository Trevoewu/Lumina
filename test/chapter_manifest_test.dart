import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/domain/models/audio_text_timing.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';

void main() {
  group('ChapterManifest offsets', () {
    test(
      'offsetOf returns accumulated ready segment duration before paragraph',
      () {
        final manifest = ChapterManifest(
          chapterId: 'c1',
          bookId: 'b1',
          providerId: 'minimax',
          voiceId: 'v1',
          speed: 1.0,
          updatedAt: 1,
          segments: const [
            SegmentEntry(
              paragraphId: 'p1',
              audioFile: 'c1/p1.mp3',
              durationMs: 1000,
              state: ParagraphAudioState.ready,
            ),
            SegmentEntry(
              paragraphId: 'p2',
              audioFile: 'c1/p2.mp3',
              durationMs: 2000,
              state: ParagraphAudioState.ready,
            ),
            SegmentEntry(
              paragraphId: 'p3',
              audioFile: 'c1/p3.mp3',
              durationMs: 3000,
              state: ParagraphAudioState.ready,
            ),
          ],
        );

        expect(manifest.offsetOf('p1'), 0);
        expect(manifest.offsetOf('p2'), 1000);
        expect(manifest.offsetOf('p3'), 3000);
      },
    );

    test(
      'paragraphAtOffset returns current paragraph for playback position',
      () {
        final manifest = ChapterManifest(
          chapterId: 'c1',
          bookId: 'b1',
          providerId: 'minimax',
          voiceId: 'v1',
          speed: 1.0,
          updatedAt: 1,
          segments: const [
            SegmentEntry(
              paragraphId: 'p1',
              audioFile: 'c1/p1.mp3',
              durationMs: 1000,
              state: ParagraphAudioState.ready,
            ),
            SegmentEntry(
              paragraphId: 'p2',
              audioFile: 'c1/p2.mp3',
              durationMs: 2000,
              state: ParagraphAudioState.ready,
            ),
          ],
        );

        expect(manifest.paragraphAtOffset(0), 'p1');
        expect(manifest.paragraphAtOffset(999), 'p1');
        expect(manifest.paragraphAtOffset(1000), 'p2');
        expect(manifest.paragraphAtOffset(2999), 'p2');
      },
    );
  });

  test('segment timing JSON is backward compatible', () {
    const segment = SegmentEntry(
      paragraphId: 'p1',
      audioFile: 'c1/p1.wav',
      durationMs: 1000,
      state: ParagraphAudioState.ready,
      timings: [AudioTextTiming(text: 'Hello', startMs: 100, endMs: 500)],
    );

    final restored = SegmentEntry.fromJson(segment.toJson());
    expect(restored.timings, hasLength(1));
    expect(restored.timings.single.text, 'Hello');
    expect(restored.timings.single.startMs, 100);

    final legacyJson = Map<String, dynamic>.from(segment.toJson())
      ..remove('timings');
    expect(SegmentEntry.fromJson(legacyJson).timings, isEmpty);
  });
}
