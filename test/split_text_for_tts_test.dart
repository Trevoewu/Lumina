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
  });
}
