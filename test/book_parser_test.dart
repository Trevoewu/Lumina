import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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

  test('EPUB parser imports percent-encoded manifest paths', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'lumina_epub_path_test_',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    final sourceFile = File('${tempDirectory.path}/encoded-path.epub');
    await sourceFile.writeAsBytes(_buildTestEpub());

    final parsed = await BookParser.parse(
      sourcePath: sourceFile.path,
      appDir: tempDirectory.path,
    );

    expect(parsed.book.title, 'Encoded Path Test');
    expect(parsed.chapters.map((chapter) => chapter.title), ['Chapter One']);
    expect(
      parsed.paragraphs.map((paragraph) => paragraph.text),
      contains(
        'The chapter file is present despite its encoded manifest path.',
      ),
    );
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

  test('EPUB parser keeps part introduction before the following chapter', () {
    final html = '''
      <body>
        <h1>PART II</h1>
        <p>Apartheid—the South African government policy of racial segregation—was genius at work.</p>
        <p>It divided people and kept them apart.</p>
        <h2>CHAPTER 9. The Cheese Boys</h2>
        <p>Chapter nine starts here.</p>
      </body>
    ''';

    expect(BookParser.epubHtmlChapterTitlesForTest(html), [
      'PART II',
      'CHAPTER 9. The Cheese Boys',
    ]);
    expect(BookParser.epubHtmlChapterParagraphsForTest(html), [
      [
        'Apartheid—the South African government policy of racial segregation—was genius at work.',
        'It divided people and kept them apart.',
      ],
      ['Chapter nine starts here.'],
    ]);
  });

  test('EPUB parser drops chapter link lists from part sections', () {
    final html = '''
      <body>
        <h1>PART II</h1>
        <p>Chapter 1: RunChapter 2: Born a CrimeChapter 3: Trevor, PrayChapter 4: ChameleonChapter 5: The Second GirlChapter 6: LoopholesChapter 7: FufiChapter 8: Robert</p>
        <p>Apartheid—the South African government policy of racial segregation—was genius at work.</p>
        <h2>CHAPTER 9. The Cheese Boys</h2>
        <p>Chapter nine starts here.</p>
      </body>
    ''';

    expect(BookParser.epubHtmlChapterTitlesForTest(html), [
      'PART II',
      'CHAPTER 9. The Cheese Boys',
    ]);
    expect(BookParser.epubHtmlChapterParagraphsForTest(html), [
      [
        'Apartheid—the South African government policy of racial segregation—was genius at work.',
      ],
      ['Chapter nine starts here.'],
    ]);
  });

  test('EPUB parser follows spine order and merges continuation files', () {
    final sections = BookParser.epubSpineSectionsForTest([
      (
        href: 'xhtml/book_toc_r1.xhtml',
        navigationTitle: 'Contents',
        html: '''
          <body>
            <h1>Contents</h1>
            <p class="toc_part"><a href="p002.xhtml">Part II</a></p>
            <p class="toc_chap"><a href="c009.xhtml">Chapter 9: The Mulberry Tree</a></p>
            <p class="toc_chap"><a href="c010.xhtml">Chapter 10: A Young Man’s Long, Awkward, Occasionally Tragic, and Frequently Humiliating Education in Affairs of the Heart, Part I: Valentine’s Day</a></p>
            <p class="toc_chap"><a href="c013.xhtml">Chapter 13: A Young Man’s Long, Awkward, Occasionally Tragic, and Frequently Humiliating Education in Affairs of the Heart, Part II: The Dance</a></p>
          </body>
        ''',
      ),
      (
        href: 'xhtml/p002.xhtml',
        navigationTitle: 'Part II',
        html: '<body><img alt="PART II" src="part-two.jpg" /></body>',
      ),
      (
        href: 'xhtml/p002-sup.xhtml',
        navigationTitle: null,
        html: '''
          <html><head><title>Continued, Example Book</title></head><body>
            <p>When Dutch colonists landed at the southern tip of Africa, they encountered an indigenous people.</p>
            <p>This is the rest of the Part II introduction.</p>
          </body></html>
        ''',
      ),
      (
        href: 'xhtml/c009.xhtml',
        navigationTitle: 'Chapter 9: The Mulberry Tree',
        html:
            '<body><p>At the end of our street stood a giant mulberry tree.</p></body>',
      ),
      (
        href: 'xhtml/c009-sup.xhtml',
        navigationTitle: null,
        html:
            '<body><p>The chapter continues on the following print page.</p></body>',
      ),
    ]);

    expect(sections.map((section) => section.title), [
      'Part II',
      'Chapter 9: The Mulberry Tree',
    ]);
    expect(sections.map((section) => section.paragraphs), [
      [
        'When Dutch colonists landed at the southern tip of Africa, they encountered an indigenous people.',
        'This is the rest of the Part II introduction.',
      ],
      [
        'At the end of our street stood a giant mulberry tree.',
        'The chapter continues on the following print page.',
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

List<int> _buildTestEpub() {
  final archive = Archive()
    ..add(
      ArchiveFile.noCompress(
        'mimetype',
        'application/epub+zip'.length,
        utf8.encode('application/epub+zip'),
      ),
    )
    ..add(
      ArchiveFile.string('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>'''),
    )
    ..add(
      ArchiveFile.string(
        'OEBPS/content.opf',
        '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="book-id" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">encoded-path-test</dc:identifier>
    <dc:title>Encoded Path Test</dc:title>
    <dc:creator>Test Author</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="chapter" href="Text/Chapter%20001.xhtml" media-type="application/xhtml+xml"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="chapter"/>
  </spine>
</package>''',
      ),
    )
    ..add(
      ArchiveFile.string(
        'OEBPS/toc.ncx',
        '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="encoded-path-test"/></head>
  <docTitle><text>Encoded Path Test</text></docTitle>
  <navMap>
    <navPoint id="chapter" playOrder="1">
      <navLabel><text>Chapter One</text></navLabel>
      <content src="Text/Chapter%20001.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''',
      ),
    )
    ..add(
      ArchiveFile.string(
        'OEBPS/Text/Chapter 001.xhtml',
        '''<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter One</title></head>
<body>
  <h1>Chapter One</h1>
  <p>The chapter file is present despite its encoded manifest path.</p>
</body>
</html>''',
      ),
    );
  return ZipEncoder().encodeBytes(archive);
}
