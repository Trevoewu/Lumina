import 'package:html/parser.dart' as html_parser;

import '../../domain/models/vocabulary_entry.dart';

class VocabularyNotFoundException implements Exception {
  final String term;

  const VocabularyNotFoundException(this.term);

  @override
  String toString() => 'Vocabulary.com did not find "$term".';
}

class VocabularyParseException implements Exception {
  final String message;

  const VocabularyParseException(this.message);

  @override
  String toString() => message;
}

class VocabularyComParser {
  const VocabularyComParser();

  VocabularyEntry parse(String html, {required String requestedTerm}) {
    final document = html_parser.parse(html);
    if (document.querySelector('.wordnotfound-wrapper') != null) {
      throw VocabularyNotFoundException(requestedTerm);
    }

    final normalizedTerm = normalizeDictionaryTerm(requestedTerm);
    final word = document.querySelector('#hdr-word-area')?.text.trim();
    final definitions = <VocabularyDefinition>[];

    for (final sense in document.querySelectorAll(
      '.word-definitions li.sense',
    )) {
      final definition = sense.children
          .where((element) => element.classes.contains('definition'))
          .firstOrNull;
      if (definition == null) continue;
      final part = definition.querySelector('.pos-icon')?.text.trim() ?? '';
      var meaning = definition.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (part.isNotEmpty && meaning.startsWith(part)) {
        meaning = meaning.substring(part.length).trim();
      }
      if (meaning.isEmpty) continue;
      definitions.add(
        VocabularyDefinition(partOfSpeech: part, meaning: meaning),
      );
    }

    if (definitions.isEmpty) {
      throw const VocabularyParseException(
        'Vocabulary.com response did not contain definitions.',
      );
    }

    final phonetics = document
        .querySelectorAll('.ipa-section .ipa-with-audio .span-replace-h3')
        .map((element) => element.text.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final otherForms = document
        .querySelectorAll('.word-area .word-forms b')
        .map((element) => element.text.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return VocabularyEntry(
      word: word?.isNotEmpty == true ? word! : requestedTerm.trim(),
      normalizedTerm: normalizedTerm,
      usPhonetic: phonetics.firstOrNull,
      ukPhonetic: phonetics.length > 1 ? phonetics[1] : null,
      definitions: definitions,
      otherForms: otherForms,
      shortExplanation: _text(
        document.querySelector('.word-area .short')?.text,
      ),
      longExplanation: _text(document.querySelector('.word-area .long')?.text),
      sourceUrl: 'https://www.vocabulary.com/dictionary/$normalizedTerm',
    );
  }

  String? _text(String? value) {
    final normalized = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
