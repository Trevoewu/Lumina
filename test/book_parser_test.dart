import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/book_parser.dart';

void main() {
  test('EPUB html parser keeps inline text in the same paragraph', () {
    final paragraphs = BookParser.htmlToPlainParagraphsForTest('''
      <html>
        <head>
          <style>@page { margin-bottom: 5pt; margin-top: 5pt; }</style>
        </head>
        <body>
          <p>"We have to practice for the athletic meet on Friday-I
            <span>know</span></p>
          <p>Another paragraph.</p>
        </body>
      </html>
    ''');

    expect(paragraphs, [
      '"We have to practice for the athletic meet on Friday-I know',
      'Another paragraph.',
    ]);
  });

  test('EPUB html parser filters CSS text when no block tags are usable', () {
    final paragraphs = BookParser.htmlToPlainParagraphsForTest('''
      @page { margin-bottom: 5pt; margin-top: 5pt; }
      <br />
      Real text.
    ''');

    expect(paragraphs, ['Real text.']);
  });

  test('EPUB html parser merges lowercase continuation blocks', () {
    final paragraphs = BookParser.htmlToPlainParagraphsForTest('''
      <body>
        <p>"We have to practice for the athletic meet on Friday-I</p>
        <p>know</p>
        <p>They started walking home.</p>
      </body>
    ''');

    expect(paragraphs, [
      '"We have to practice for the athletic meet on Friday-I know',
      'They started walking home.',
    ]);
  });

  test('EPUB parser skips obvious non-story front matter sections', () {
    expect(
      BookParser.shouldSkipEpubChapterForTest('Table of Contents', [
        'Chapter One',
        'Chapter Two',
      ]),
      isTrue,
    );
    expect(
      BookParser.shouldSkipEpubChapterForTest('Copyright', [
        'Copyright 1989 by Example Press',
      ]),
      isTrue,
    );
    expect(
      BookParser.shouldSkipEpubChapterForTest('Dedication', ['For my family.']),
      isTrue,
    );
  });

  test('EPUB parser keeps longer chapters even with dedication-like title', () {
    expect(
      BookParser.shouldSkipEpubChapterForTest(
        'Dedication',
        List.filled(8, 'This is a longer narrative paragraph.'),
      ),
      isFalse,
    );
  });
}
