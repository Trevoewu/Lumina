import 'package:dio/dio.dart';

import '../../domain/models/vocabulary_entry.dart';
import 'vocabulary_com_parser.dart';

class VocabularyComProvider {
  final Dio _dio;
  final VocabularyComParser _parser;

  VocabularyComProvider({Dio? dio, VocabularyComParser? parser})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              responseType: ResponseType.plain,
            ),
          ),
      _parser = parser ?? const VocabularyComParser();

  Future<VocabularyEntry> lookup(String term) async {
    final normalizedTerm = normalizeDictionaryTerm(term);
    if (normalizedTerm.isEmpty) {
      throw const VocabularyParseException('Enter a word to look up.');
    }

    final response = await _dio.get<String>(
      'https://www.vocabulary.com/dictionary/definition.ajax',
      queryParameters: {'search': normalizedTerm, 'lang': 'en'},
    );
    final html = response.data;
    if (html == null || html.isEmpty) {
      throw const VocabularyParseException(
        'Vocabulary.com returned an empty response.',
      );
    }
    return _parser.parse(html, requestedTerm: normalizedTerm);
  }
}
