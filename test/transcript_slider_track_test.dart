import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/domain/models/audio_text_timing.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/presentation/widgets/transcript_slider_track.dart';

void main() {
  test('two-hour subtitles keep visible gaps at narrow track widths', () {
    // One subtitle every two seconds on a two-hour episode: 3600 marks
    // previously overlapped when drawn as 1pt cuts on a 320pt track.
    final ticks = [
      for (var second = 0; second < 7200; second += 2) second / 7200,
    ];
    final original = List<double>.of(ticks);
    for (final width in [240.0, 320.0, 768.0]) {
      final visible = visibleSubtitleTicks(ticks, width);
      expect(visible.length, greaterThan(20));
      expect(visible.length, lessThanOrEqualTo((width / 4).ceil() + 1));
      for (var i = 1; i < visible.length; i++) {
        expect((visible[i] - visible[i - 1]) * width, greaterThanOrEqualTo(4));
      }
    }
    expect(ticks, original, reason: 'Every subtitle must remain seekable');
  });

  test('sparse subtitles retain their exact tick positions', () {
    expect(visibleSubtitleTicks([0, 0.2, 0.5, 1], 320), [0, 0.2, 0.5, 1]);
    expect(visibleSubtitleTicks([0, 0.5], 0), isEmpty);
  });
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
