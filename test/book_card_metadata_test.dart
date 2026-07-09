import 'package:flutter_test/flutter_test.dart';
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
}
