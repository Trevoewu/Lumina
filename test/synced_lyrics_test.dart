import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/audio_text_timing.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/presentation/widgets/synced_lyrics_list.dart';

void main() {
  test('long paragraphs split at sentence and weak boundaries', () {
    final lines = splitLyricsText(
      'First sentence. Second sentence is deliberately much longer, '
      'so it must be wrapped without filling the screen.',
      maxChars: 30,
    );

    expect(lines.first, 'First sentence.');
    expect(lines, hasLength(greaterThan(2)));
    expect(lines.every((line) => line.length <= 30), isTrue);
  });

  test('keeps closing quotes and dialogue tags with their sentence', () {
    final lines = splitLyricsText(
      '"Go!" shouted Annemarie, and the girls ran. '
      '"Oh, all right. Ready," she said.',
      maxChars: 55,
    );

    expect(lines, [
      '"Go!" shouted Annemarie, and the girls ran.',
      '"Oh, all right. Ready," she said.',
    ]);
    expect(lines, isNot(contains('"')));
  });

  test('does not split common abbreviations', () {
    final lines = splitLyricsText(
      'Where is Mrs. Hirsch? Dr. Smith knows.',
      maxChars: 100,
    );

    expect(lines, ['Where is Mrs. Hirsch? Dr. Smith knows.']);
  });

  test('splits long sentences at clause boundaries before spaces', () {
    final lines = splitLyricsText(
      'Annemarie outdistanced her friend quickly, even though one of her '
      'shoes came untied as she sped along the street called Osterbrogade, '
      'past the small shops and cafes of her neighborhood.',
      maxChars: 100,
    );

    expect(lines, [
      'Annemarie outdistanced her friend quickly,',
      'even though one of her shoes came untied as she sped along the street '
          'called Osterbrogade,',
      'past the small shops and cafes of her neighborhood.',
    ]);
  });

  test('Fish timestamps map display lines to exact audio offsets', () {
    const paragraph = Paragraph(
      id: 'p1',
      chapterId: 'c1',
      bookId: 'b1',
      paragraphIndex: 0,
      content: 'Hello world. Again.',
    );
    final manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'fish_audio_api',
      voiceId: 'default',
      speed: 1,
      updatedAt: 1,
      segments: const [
        SegmentEntry(
          paragraphId: 'p1',
          audioFile: 'c1/p1.wav',
          durationMs: 2000,
          state: ParagraphAudioState.ready,
          timings: [
            AudioTextTiming(text: 'Hello', startMs: 100, endMs: 400),
            AudioTextTiming(text: 'world', startMs: 450, endMs: 900),
            AudioTextTiming(text: 'Again', startMs: 1100, endMs: 1600),
          ],
        ),
      ],
    );

    final lines = buildSyncedLyricLines([paragraph], manifest, maxChars: 12);

    expect(lines.map((line) => line.text), ['Hello world.', 'Again.']);
    expect((lines.first.startMs, lines.first.endMs), (100, 900));
    expect((lines.last.startMs, lines.last.endMs), (1100, 1600));
  });

  test('legacy cached audio gets proportional line offsets', () {
    const paragraph = Paragraph(
      id: 'p1',
      chapterId: 'c1',
      bookId: 'b1',
      paragraphIndex: 0,
      content: 'One. Two.',
    );
    final manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'kokoro',
      voiceId: 'default',
      speed: 1,
      updatedAt: 1,
      segments: const [
        SegmentEntry(
          paragraphId: 'p1',
          audioFile: 'c1/p1.wav',
          durationMs: 1000,
          state: ParagraphAudioState.ready,
        ),
      ],
    );

    final lines = buildSyncedLyricLines([paragraph], manifest, maxChars: 6);

    expect(lines, hasLength(2));
    expect(lines.first.startMs, 0);
    expect(lines.first.endMs, greaterThan(0));
    expect(lines.last.startMs, lines.first.endMs);
    expect(lines.last.endMs, 1000);
  });
}
