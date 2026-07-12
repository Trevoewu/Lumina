import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';

void main() {
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
