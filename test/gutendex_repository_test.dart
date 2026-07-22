import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/book_sources/gutendex_repository.dart';

void main() {
  test('GutendexBook maps API metadata and import eligibility', () {
    final book = GutendexBook.fromJson({
      'id': 11,
      'title': "Alice's Adventures in Wonderland",
      'authors': [
        {'name': 'Carroll, Lewis', 'birth_year': 1832, 'death_year': 1898},
      ],
      'languages': ['en'],
      'summaries': ['A curious child enters a strange wonderland.'],
      'copyright': false,
      'download_count': 82955,
      'formats': {
        'image/jpeg': 'https://example.test/cover.jpg',
        'application/epub+zip': 'https://example.test/book.epub',
        'text/plain; charset=utf-8': 'https://example.test/book.txt',
      },
    });

    expect(book.id, 11);
    expect(book.authorLabel, 'Carroll, Lewis');
    expect(book.languageLabel, 'en');
    expect(book.downloadCount, 82955);
    expect(book.summary, 'A curious child enters a strange wonderland.');
    expect(book.coverUrl, 'https://example.test/cover.jpg');
    expect(book.preferredDownloadUrl, 'https://example.test/book.epub');
    expect(book.preferredExtension, '.epub');
    expect(book.canImport, isTrue);
  });

  test('GutendexBook rejects copyrighted or undownloadable entries', () {
    final copyrighted = GutendexBook.fromJson({
      'id': 1,
      'title': 'Rights Restricted',
      'authors': [],
      'languages': [],
      'copyright': true,
      'formats': {'text/plain; charset=utf-8': 'https://example.test/book.txt'},
    });
    final undownloadable = GutendexBook.fromJson({
      'id': 2,
      'title': 'No Text',
      'authors': [],
      'languages': [],
      'copyright': false,
      'formats': {'image/jpeg': 'https://example.test/cover.jpg'},
    });

    expect(copyrighted.canImport, isFalse);
    expect(undownloadable.canImport, isFalse);
  });

  test('GutendexBook prefers official mirrors for Gutenberg downloads', () {
    final book = GutendexBook.fromJson({
      'id': 2701,
      'title': 'Moby Dick; Or, The Whale',
      'authors': [],
      'languages': ['en'],
      'copyright': false,
      'formats': {
        'application/epub+zip':
            'https://www.gutenberg.org/ebooks/2701.epub3.images',
        'text/plain; charset=utf-8':
            'https://www.gutenberg.org/ebooks/2701.txt.utf-8',
      },
    });

    expect(
      book.downloadSources.map((source) => source.url),
      containsAllInOrder([
        'https://gutenberg.pglaf.org/cache/epub/2701/pg2701-images-3.epub',
        'https://mirror.cs.odu.edu/gutenberg-epub/2701/pg2701-images-3.epub',
        'https://www.gutenberg.org/ebooks/2701.epub3.images',
        'https://gutenberg.pglaf.org/cache/epub/2701/pg2701.txt',
        'https://mirror.cs.odu.edu/gutenberg-epub/2701/pg2701.txt',
        'https://www.gutenberg.org/ebooks/2701.txt.utf-8',
      ]),
    );
  });
}
