import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/book_introduction_service.dart';

void main() {
  test('reads and normalizes a Gutendex summary', () {
    final introduction = bookIntroductionFromMetadataJson(
      jsonEncode({
        'source': 'gutendex',
        'raw': {
          'summaries': [
            '<p>A curious child enters a <b>strange</b> wonderland.</p>',
          ],
        },
      }),
    );

    expect(introduction, 'A curious child enters a strange wonderland.');
  });

  test('prefers a cached EPUB description', () {
    final introduction = bookIntroductionFromMetadataJson(
      jsonEncode({
        'description': '  A publisher-provided\n\nbook description.  ',
        'raw': {
          'summaries': ['A secondary summary.'],
        },
      }),
    );

    expect(introduction, 'A publisher-provided book description.');
  });

  test('caching an EPUB description preserves existing metadata', () {
    final updated = metadataJsonWithBookIntroduction(
      jsonEncode({'source': 'epub', 'language': 'en'}),
      '<p>An embedded description.</p>',
    );
    final decoded = jsonDecode(updated) as Map<String, dynamic>;

    expect(decoded['source'], 'epub');
    expect(decoded['language'], 'en');
    expect(decoded['description'], 'An embedded description.');
  });
}
