import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';

void main() {
  test(
    'deleteChapterCascade removes chapter data and resets book progress',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      const book = Book(
        id: 'delete-chapter-book',
        title: 'Delete Chapter Book',
        format: 'txt',
        sourcePath: '/delete.txt',
        chapterCount: 1,
        paragraphCount: 1,
        currentChapterId: 'delete-chapter',
        currentParagraphIndex: 3,
        playbackOffsetMs: 500,
        importedAt: 1,
        lastReadAt: 1,
        isRead: false,
        kind: 'book',
        rightsStatus: 'user_uploaded',
      );
      const chapter = Chapter(
        id: 'delete-chapter',
        bookId: 'delete-chapter-book',
        chapterIndex: 0,
        title: 'Delete me',
        textOffset: 0,
        isHidden: false,
      );
      await database.upsertBook(book);
      await database.insertChapters(const [chapter]);
      await database.insertParagraphs(const [
        Paragraph(
          id: 'delete-paragraph',
          chapterId: 'delete-chapter',
          bookId: 'delete-chapter-book',
          paragraphIndex: 0,
          content: 'Delete me too',
        ),
      ]);
      await database.markChapterFinished(book.id, chapter.id);

      await database.deleteChapterCascade(chapter.id);

      expect(await database.getChapter(chapter.id), isNull);
      expect(await database.getParagraphs(chapter.id), isEmpty);
      expect(await database.getChapterPlaybackProgress(chapter.id), isNull);
      final updatedBook = await database.getBook(book.id);
      expect(updatedBook?.chapterCount, 0);
      expect(updatedBook?.paragraphCount, 0);
      expect(updatedBook?.currentChapterId, isNull);
      expect(updatedBook?.currentParagraphIndex, 0);
      expect(updatedBook?.playbackOffsetMs, 0);
    },
  );

  test(
    'replaceBookData rolls back the entire import when a write fails',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      const originalBook = Book(
        id: 'book-1',
        title: 'Original',
        format: 'txt',
        sourcePath: '/original.txt',
        chapterCount: 1,
        paragraphCount: 1,
        currentParagraphIndex: 0,
        playbackOffsetMs: 0,
        importedAt: 1,
        lastReadAt: 0,
        isRead: false,
        kind: 'book',
        rightsStatus: 'user_uploaded',
      );
      const originalChapter = Chapter(
        id: 'old-chapter',
        bookId: 'book-1',
        chapterIndex: 0,
        title: 'Original chapter',
        textOffset: 0,
        isHidden: false,
      );
      const originalParagraph = Paragraph(
        id: 'old-paragraph',
        chapterId: 'old-chapter',
        bookId: 'book-1',
        paragraphIndex: 0,
        content: 'Original paragraph',
      );

      await database.replaceBookData(
        book: originalBook,
        chapterEntries: const [originalChapter],
        paragraphEntries: const [originalParagraph],
      );

      final replacementBook = originalBook.copyWith(title: 'Replacement');
      await expectLater(
        database.replaceBookData(
          book: replacementBook,
          chapterEntries: const [
            Chapter(
              id: 'new-chapter-1',
              bookId: 'book-1',
              chapterIndex: 0,
              title: 'New chapter 1',
              textOffset: 0,
              isHidden: false,
            ),
            Chapter(
              id: 'new-chapter-2',
              bookId: 'book-1',
              chapterIndex: 0,
              title: 'Conflicting chapter',
              textOffset: 10,
              isHidden: false,
            ),
          ],
          paragraphEntries: const [],
        ),
        throwsA(anything),
      );

      expect(await database.getBook('book-1'), originalBook);
      expect(await database.getChapters('book-1', includeHidden: true), const [
        originalChapter,
      ]);
      expect(await database.getParagraphs('old-chapter'), const [
        originalParagraph,
      ]);
    },
  );
}
