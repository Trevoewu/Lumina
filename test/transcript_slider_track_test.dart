import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/domain/models/audio_text_timing.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/presentation/widgets/transcript_slider_track.dart';

void main() {
  ChapterManifest manifest(List<SegmentEntry> segments) => ChapterManifest(
    chapterId: 'chapter',
    bookId: 'book',
    providerId: 'test',
    voiceId: 'test',
    speed: 1,
    segments: segments,
    updatedAt: 0,
  );
  SegmentEntry segment(int duration, List<AudioTextTiming> timings) =>
      SegmentEntry(
        paragraphId: 'paragraph',
        audioFile: 'audio',
        durationMs: duration,
        state: ParagraphAudioState.ready,
        timings: timings,
      );
  AudioTextTiming timing(int start, int end) =>
      AudioTextTiming(text: 'words', startMs: start, endMs: end);

  test('seek-ahead subtitles preserve gaps and merge overlapping ranges', () {
    final data = manifest([
      segment(10000, [timing(6000, 8000), timing(0, 1000), timing(500, 2000)]),
    ]);
    expect(transcriptCoverage(data, 10000), [
      (start: 0.0, end: 0.2),
      (start: 0.6, end: 0.8),
    ]);
  });
  test('segment offsets use the audio timeline and clamp invalid bounds', () {
    final data = manifest([
      segment(5000, [timing(-500, 1000), timing(3000, 2000)]),
      segment(5000, [timing(1000, 8000)]),
    ]);
    expect(transcriptCoverage(data, 10000), [
      (start: 0.0, end: 0.1),
      (start: 0.6, end: 1.0),
    ]);
    expect(transcriptCoverage(data, 0), isEmpty);
    expect(transcriptCoverage(null, 10000), isEmpty);
  });
}
