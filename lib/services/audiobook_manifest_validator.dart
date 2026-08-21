import '../data/database/app_database.dart' as db;
import '../domain/models/chapter_manifest.dart';
import 'generation_task_store.dart';

/// Returns a manifest whose segment order and content version exactly match
/// the chapter text currently stored in the database.
///
/// Audio without a fingerprint, or audio generated from older paragraph text,
/// is deliberately made non-playable. This prevents a stale cache from being
/// paired with newly imported/edited text while the generator refreshes it.
ChapterManifest validateAudiobookManifest(
  ChapterManifest manifest,
  List<db.Paragraph> paragraphs,
) {
  final byParagraphId = <String, SegmentEntry>{
    for (final segment in manifest.segments) segment.paragraphId: segment,
  };
  var changed = manifest.segments.length != paragraphs.length;
  final validated = <SegmentEntry>[];

  for (var index = 0; index < paragraphs.length; index++) {
    final paragraph = paragraphs[index];
    final fingerprint = generationFingerprint([
      paragraph.id,
      paragraph.content,
    ]);
    final segment = byParagraphId[paragraph.id];
    final legacyOrderMatches =
        segment?.contentFingerprint == null &&
        index < manifest.segments.length &&
        manifest.segments[index].paragraphId == paragraph.id;
    if (segment != null &&
        (segment.contentFingerprint == fingerprint || legacyOrderMatches)) {
      validated.add(segment);
      continue;
    }

    changed = true;
    validated.add(
      SegmentEntry(
        paragraphId: paragraph.id,
        audioFile:
            segment?.audioFile ?? '${manifest.chapterId}/${paragraph.id}.mp3',
        durationMs: 0,
        state: ParagraphAudioState.notGenerated,
        format: segment?.format ?? 'mp3',
        contentFingerprint: fingerprint,
      ),
    );
  }

  if (!changed) {
    for (var index = 0; index < validated.length; index++) {
      if (!identical(validated[index], manifest.segments[index])) {
        changed = true;
        break;
      }
    }
  }
  if (!changed) return manifest;

  return ChapterManifest(
    chapterId: manifest.chapterId,
    bookId: manifest.bookId,
    providerId: manifest.providerId,
    voiceId: manifest.voiceId,
    speed: manifest.speed,
    configurationFingerprint: manifest.configurationFingerprint,
    segments: validated,
    updatedAt: manifest.updatedAt,
  );
}

/// Playback may only advance through a continuous prefix. Skipping a missing
/// segment would make the spoken audio jump over visible text.
List<SegmentEntry> contiguousPlayableSegments(ChapterManifest manifest) {
  final playable = <SegmentEntry>[];
  for (final segment in manifest.segments) {
    if (segment.state != ParagraphAudioState.ready) break;
    playable.add(segment);
  }
  return playable;
}
