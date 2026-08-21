import '../data/database/app_database.dart';
import '../domain/models/chapter_manifest.dart';
import 'audiobook_manifest_validator.dart';
import 'lumina_audio_handler.dart';
import 'manifest_store.dart';

Future<void> loadBookPlaybackQueue({
  required LuminaAudioHandler handler,
  required AppDatabase database,
  required ManifestStore manifestStore,
  required String bookId,
  required String bookTitle,
  String? coverPath,
  required ChapterManifest initialManifest,
  String paragraphLabel = 'Paragraph',
  Duration initialPosition = Duration.zero,
}) async {
  final chapters = await database.getChapters(bookId);
  final sources = <ChapterPlaybackSource>[];

  for (final chapter in chapters) {
    final storedManifest = chapter.id == initialManifest.chapterId
        ? initialManifest
        : await manifestStore.load(bookId, chapter.id);
    if (storedManifest == null) continue;
    final paragraphs = await database.getParagraphs(chapter.id);
    final manifest = validateAudiobookManifest(storedManifest, paragraphs);
    if (contiguousPlayableSegments(manifest).isEmpty) continue;
    sources.add(
      ChapterPlaybackSource(
        manifest: manifest,
        chapterTitle: chapter.title,
        coverPath: coverPath,
      ),
    );
  }

  if (!sources.any(
    (source) => source.manifest.chapterId == initialManifest.chapterId,
  )) {
    final chapter = await database.getChapter(initialManifest.chapterId);
    final paragraphs = await database.getParagraphs(initialManifest.chapterId);
    final validatedInitialManifest = validateAudiobookManifest(
      initialManifest,
      paragraphs,
    );
    if (contiguousPlayableSegments(validatedInitialManifest).isEmpty) {
      throw StateError('这一章还没有可播放的缓存音频。');
    }
    sources.add(
      ChapterPlaybackSource(
        manifest: validatedInitialManifest,
        chapterTitle: chapter?.title ?? '',
        coverPath: coverPath,
      ),
    );
  }

  final audioRoot = await manifestStore.audioRoot(bookId);
  await handler.loadChapters(
    chapters: sources,
    initialChapterId: initialManifest.chapterId,
    audioRoot: audioRoot.path,
    bookTitle: bookTitle,
    paragraphLabel: paragraphLabel,
    initialPosition: initialPosition,
  );
}
