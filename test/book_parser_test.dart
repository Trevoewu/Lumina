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

  test('EPUB html parser prefers paragraph tags inside large containers', () {
    final paragraphs = BookParser.htmlToPlainParagraphsForTest('''
      <body>
        <div class="chapter">
          <p>Like most small children, I learned my home address.</p>
          <p>In kindergarten, my teacher asked where I lived.</p>
          <p>My address was where I spent most of my time.</p>
        </div>
      </body>
    ''');

    expect(paragraphs, [
      'Like most small children, I learned my home address.',
      'In kindergarten, my teacher asked where I lived.',
      'My address was where I spent most of my time.',
    ]);
  });

  test(
    'EPUB parser splits Gutenberg chapter headings inside one html file',
    () {
      final html = '''
      <body>
        <h1>MOBY-DICK; or, THE WHALE.</h1>
        <p>CONTENTS</p>
        <p>CHAPTER 1. Loomings.</p>
        <p>CHAPTER 2. The Carpet-Bag.</p>
        <h2>CHAPTER 1. Loomings.</h2>
        <p>Call me Ishmael.</p>
        <p>Some years ago-never mind how long precisely.</p>
        <h2>CHAPTER 2. The Carpet-Bag.</h2>
        <p>I stuffed a shirt or two into my old carpet-bag.</p>
      </body>
    ''';

      expect(BookParser.epubHtmlChapterTitlesForTest(html), [
        'CHAPTER 1. Loomings.',
        'CHAPTER 2. The Carpet-Bag.',
      ]);
      expect(BookParser.epubHtmlChapterParagraphsForTest(html), [
        ['Call me Ishmael.', 'Some years ago-never mind how long precisely.'],
        ['I stuffed a shirt or two into my old carpet-bag.'],
      ]);
    },
  );

  test('EPUB parser extracts chapter heading after illustration caption', () {
    final html = '''
      <body>
        <h2>
          <span class="caption">I hope Mr. Bingley will like it.</span>
          <br />
          <br />
          CHAPTER II.
        </h2>
        <p>Mr. Bennet was among the earliest of those who waited on Mr. Bingley.</p>
      </body>
    ''';

    expect(BookParser.epubHtmlChapterTitlesForTest(html), ['CHAPTER II.']);
    expect(BookParser.epubHtmlChapterParagraphsForTest(html), [
      ['Mr. Bennet was among the earliest of those who waited on Mr. Bingley.'],
    ]);
  });

  test('EPUB parser treats semantic paragraph chapter labels as headings', () {
    final html = '''
      <body>
        <p class="chapter">CHAPTER III.</p>
        <p>Not all that Mrs. Bennet, however, with the assistance of her five daughters, could ask on the subject.</p>
      </body>
    ''';

    expect(BookParser.epubHtmlChapterTitlesForTest(html), ['CHAPTER III.']);
    expect(BookParser.epubHtmlChapterParagraphsForTest(html), [
      [
        'Not all that Mrs. Bennet, however, with the assistance of her five daughters, could ask on the subject.',
      ],
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
