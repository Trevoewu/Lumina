import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/services/audiobook_manifest_validator.dart';
import 'package:lumina/services/generation_task_store.dart';

void main() {
  const paragraph = Paragraph(
    id: 'p1',
    chapterId: 'c1',
    bookId: 'b1',
    paragraphIndex: 0,
    content: 'Current chapter text.',
  );

  test('stale cached audio is not paired with changed text', () {
    final manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'tts',
      voiceId: 'voice',
      speed: 1,
      updatedAt: 1,
      segments: const [
        SegmentEntry(
          paragraphId: 'p1',
          audioFile: 'c1/p1.mp3',
          durationMs: 1200,
          state: ParagraphAudioState.ready,
          contentFingerprint: 'fingerprint-for-older-text',
        ),
      ],
    );

    final validated = validateAudiobookManifest(manifest, const [paragraph]);

    expect(validated.segments.single.state, ParagraphAudioState.notGenerated);
    expect(validated.segments.single.durationMs, 0);
    expect(validated.segments.single.timings, isEmpty);
    expect(
      validated.segments.single.contentFingerprint,
      generationFingerprint([paragraph.id, paragraph.content]),
    );
  });

  test('current cached audio remains playable', () {
    final fingerprint = generationFingerprint([
      paragraph.id,
      paragraph.content,
    ]);
    final segment = SegmentEntry(
      paragraphId: 'p1',
      audioFile: 'c1/p1.mp3',
      durationMs: 1200,
      state: ParagraphAudioState.ready,
      contentFingerprint: fingerprint,
    );
    final manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'tts',
      voiceId: 'voice',
      speed: 1,
      updatedAt: 1,
      segments: [segment],
    );

    final validated = validateAudiobookManifest(manifest, const [paragraph]);

    expect(identical(validated, manifest), isTrue);
    expect(contiguousPlayableSegments(validated), [segment]);
  });

  test('legacy cache remains playable when paragraph order still matches', () {
    const segment = SegmentEntry(
      paragraphId: 'p1',
      audioFile: 'c1/p1.mp3',
      durationMs: 1200,
      state: ParagraphAudioState.ready,
    );
    const manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'tts',
      voiceId: 'voice',
      speed: 1,
      updatedAt: 1,
      segments: [segment],
    );

    final validated = validateAudiobookManifest(manifest, const [paragraph]);

    expect(identical(validated, manifest), isTrue);
  });

  test('playable segments stop at the first cache gap', () {
    const manifest = ChapterManifest(
      chapterId: 'c1',
      bookId: 'b1',
      providerId: 'tts',
      voiceId: 'voice',
      speed: 1,
      updatedAt: 1,
      segments: [
        SegmentEntry(
          paragraphId: 'p1',
          audioFile: 'p1.mp3',
          durationMs: 1000,
          state: ParagraphAudioState.ready,
        ),
        SegmentEntry(
          paragraphId: 'p2',
          audioFile: 'p2.mp3',
          durationMs: 0,
          state: ParagraphAudioState.generating,
        ),
        SegmentEntry(
          paragraphId: 'p3',
          audioFile: 'p3.mp3',
          durationMs: 1000,
          state: ParagraphAudioState.ready,
        ),
      ],
    );

    expect(
      contiguousPlayableSegments(
        manifest,
      ).map((segment) => segment.paragraphId),
      ['p1'],
    );
  });
}
