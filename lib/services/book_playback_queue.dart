import '../data/database/app_database.dart';
import '../domain/models/chapter_manifest.dart';
import 'lumina_audio_handler.dart';
import 'manifest_store.dart';

Future<void> loadBookPlaybackQueue({
  required LuminaAudioHandler handler,
  required AppDatabase database,
  required ManifestStore manifestStore,
  required String bookId,
  required String bookTitle,
  required ChapterManifest initialManifest,
  String paragraphLabel = 'Paragraph',
}) async {
  final chapters = await database.getChapters(bookId);
  final sources = <ChapterPlaybackSource>[];

  for (final chapter in chapters) {
    final manifest = chapter.id == initialManifest.chapterId
        ? initialManifest
        : await manifestStore.load(bookId, chapter.id);
    if (manifest == null) continue;
    sources.add(
      ChapterPlaybackSource(manifest: manifest, chapterTitle: chapter.title),
    );
  }

  if (!sources.any(
    (source) => source.manifest.chapterId == initialManifest.chapterId,
  )) {
    final chapter = await database.getChapter(initialManifest.chapterId);
    sources.add(
      ChapterPlaybackSource(
        manifest: initialManifest,
        chapterTitle: chapter?.title ?? '',
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
  );
}
