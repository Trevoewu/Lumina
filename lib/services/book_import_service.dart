import 'package:path_provider/path_provider.dart';

import '../data/database/app_database.dart' as drift_db;
import '../domain/models/book_language.dart';
import '../domain/models/book_rights.dart';
import 'app_log_service.dart';
import 'book_parser.dart';
import 'reading_level_estimator.dart';

class BookImportResult {
  final drift_db.Book book;
  final int chapterCount;
  final int paragraphCount;

  const BookImportResult({
    required this.book,
    required this.chapterCount,
    required this.paragraphCount,
  });
}

/// Imports a user-provided book through the same parsing and persistence path,
/// regardless of whether it came from the picker or another iOS app.
class BookImportService {
  final drift_db.AppDatabase database;

  const BookImportService(this.database);

  Future<BookImportResult> importFile(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final parsed = await BookParser.parse(
      sourcePath: sourcePath,
      appDir: appDir.path,
    );
    final language = inferLanguageFromTitle(parsed.book.title);
    final readingLevel = await _estimateReadingLevel(
      language: language,
      paragraphTexts: parsed.paragraphs.map((paragraph) => paragraph.text),
    );

    final book = drift_db.Book(
      id: parsed.book.id,
      title: parsed.book.title,
      author: parsed.book.author,
      language: language,
      format: parsed.book.format.name,
      sourcePath: parsed.book.sourcePath,
      coverPath: parsed.book.coverPath,
      chapterCount: parsed.book.chapterCount,
      paragraphCount: parsed.book.paragraphCount,
      currentChapterId: parsed.book.currentChapterId,
      currentParagraphIndex: parsed.book.currentParagraphIndex,
      playbackOffsetMs: parsed.book.playbackOffsetMs,
      voiceId: parsed.book.voiceId,
      importedAt: parsed.book.importedAt,
      lastReadAt: parsed.book.lastReadAt,
      isRead: false,
      kind: 'book',
      rightsStatus: userUploadedRightsStatus,
      readingLevelSystem: readingLevel?.system,
      readingLevelCode: readingLevel?.code,
      readingLevelSource: readingLevel?.source,
    );

    await database.replaceBookData(
      book: book,
      chapterEntries: parsed.chapters
          .map(
            (chapter) => drift_db.Chapter(
              id: chapter.id,
              bookId: chapter.bookId,
              chapterIndex: chapter.index,
              title: chapter.title,
              textOffset: chapter.textOffset,
              isHidden: false,
            ),
          )
          .toList(),
      paragraphEntries: parsed.paragraphs
          .map(
            (paragraph) => drift_db.Paragraph(
              id: paragraph.id,
              chapterId: paragraph.chapterId,
              bookId: paragraph.bookId,
              paragraphIndex: paragraph.index,
              content: paragraph.text,
            ),
          )
          .toList(),
    );

    return BookImportResult(
      book: book,
      chapterCount: parsed.chapters.length,
      paragraphCount: parsed.paragraphs.length,
    );
  }

  Future<ReadingLevelEstimate?> _estimateReadingLevel({
    required String? language,
    required Iterable<String> paragraphTexts,
  }) async {
    if (normalizeBookLanguage(language) != 'en') return null;
    try {
      return await ReadingLevelEstimator.instance.estimateEnglish(
        paragraphTexts,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'BookImport',
        '阅读难度估算失败',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
