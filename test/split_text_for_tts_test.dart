import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/generation_orchestrator.dart';

void main() {
  group('splitTextForTts', () {
    test('keeps short text as a single chunk', () {
      expect(splitTextForTts('短文本。', 100), ['短文本。']);
    });

    test('splits by sentence boundaries under max chars', () {
      final chunks = splitTextForTts('第一句。第二句。第三句。', 6);
      expect(chunks, ['第一句。', '第二句。', '第三句。']);
    });

    test('keeps a single sentence intact when it only exceeds soft max', () {
      final chunks = splitTextForTts('abcdefghij.', 4);
      expect(chunks, ['abcdefghij.']);
    });

    test('hard splits a single sentence longer than hard max', () {
      final chunks = splitTextForTts('abcdefghij', 4, hardMaxChars: 4);
      expect(chunks, ['abcd', 'efgh', 'ij']);
    });

    test('supports provider limits above the generic hard limit', () {
      final text = List.filled(5001, 'a').join();
      final chunks = splitTextForTts(text, 4000);
      expect(chunks.map((chunk) => chunk.length), [4000, 1001]);
    });

    test('splits English sentences by periods and preserves inter-sentence spaces', () {
      const text =
          'It was a bright cold day in April. The clocks were striking thirteen. Winston slipped inside.';
      final chunks = splitTextForTts(text, 50);
      expect(chunks, [
        'It was a bright cold day in April.',
        'The clocks were striking thirteen.',
        'Winston slipped inside.',
      ]);
    });

    test('keeps dialogue quotes attached to preceding sentences', () {
      const text =
          '"Is that you, Winston?" asked Mrs. Parsons. '
          '"Yes, it is," he answered.';
      final chunks = splitTextForTts(text, 50);
      expect(chunks, [
        '"Is that you, Winston?" asked Mrs. Parsons.',
        '"Yes, it is," he answered.',
      ]);
    });

    test('does not break on abbreviations or decimal numbers', () {
      const text =
          'Dr. Watson visited H. G. Wells at 3.14 PM. It was a pleasant meeting.';
      final chunks = splitTextForTts(text, 50);
      expect(chunks, [
        'Dr. Watson visited H. G. Wells at 3.14 PM.',
        'It was a pleasant meeting.',
      ]);
    });

    test('preserves whitespace between words when splitting oversized sentences', () {
      const longSentence =
          'The hallway smelt of boiled cabbage and old rag mats, '
          'and at one end of it a coloured poster, too large for indoor display, '
          'had been tacked to the wall, depicting simply an enormous face.';
      final chunks = splitTextForTts(longSentence, 50, hardMaxChars: 100);
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.contains('Thehallway'), isFalse);
        expect(chunk.contains('boiledcabbage'), isFalse);
        expect(chunk.contains(' '), isTrue);
      }
    });
  });
}
