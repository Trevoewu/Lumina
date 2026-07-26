import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/book_language.dart';
import 'package:lumina/presentation/widgets/book_card_metadata.dart';

void main() {
  test('infers language from common title scripts', () {
    expect(inferLanguageFromTitle('三体'), 'zh');
    expect(inferLanguageFromTitle('吾輩は猫である'), 'ja');
    expect(inferLanguageFromTitle('Pride and Prejudice'), 'en');
  });

  test('estimated reading progress uses current chapter and paragraph', () {
    const book = Book(
      id: 'book-1',
      title: 'Progress Test',
      format: 'txt',
      sourcePath: '/tmp/progress.txt',
      chapterCount: 4,
      paragraphCount: 100,
      currentChapterId: 'book-1_ch_2',
      currentParagraphIndex: 10,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 2,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );

    expect(estimatedBookReadingProgress(book), 60);
  });

  test('estimated reading progress is zero before a saved position exists', () {
    const book = Book(
      id: 'book-1',
      title: 'Unread Test',
      format: 'txt',
      sourcePath: '/tmp/unread.txt',
      chapterCount: 4,
      paragraphCount: 100,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 1,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );

    expect(estimatedBookReadingProgress(book), 0);
  });

  test('finished chapters contribute to estimated reading progress', () {
    const unreadBook = Book(
      id: 'book-1',
      title: 'Finished Chapter Test',
      format: 'txt',
      sourcePath: '/tmp/finished.txt',
      chapterCount: 4,
      paragraphCount: 100,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 1,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );
    expect(
      estimatedBookReadingProgress(
        unreadBook,
        finishedChapterIndexes: const {2},
      ),
      25,
    );

    final partiallyRead = unreadBook.copyWith(
      currentChapterId: const drift.Value('book-1_ch_1'),
      currentParagraphIndex: 10,
    );
    expect(
      estimatedBookReadingProgress(
        partiallyRead,
        finishedChapterIndexes: const {1, 3},
      ),
      75,
    );
  });

  testWidgets('reading level label marks estimated CEFR values', (
    tester,
  ) async {
    const book = Book(
      id: 'book-1',
      title: 'Level Test',
      format: 'txt',
      sourcePath: '/tmp/level.txt',
      chapterCount: 1,
      paragraphCount: 1,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 1,
      kind: 'book',
      rightsStatus: 'user_uploaded',
      readingLevelSystem: 'cefr_j',
      readingLevelCode: 'B1',
      readingLevelSource: 'estimated',
    );

    expect(normalizeCefrReadingLevel('b2'), 'B2');
    expect(normalizeCefrReadingLevel('C1'), isNull);
    String? label;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            label = bookReadingLevelLabel(context, book);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(label, contains('B1'));
  });
}
