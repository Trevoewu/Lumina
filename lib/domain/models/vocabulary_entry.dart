import 'dart:convert';

class VocabularyDefinition {
  final String partOfSpeech;
  final String meaning;

  const VocabularyDefinition({
    required this.partOfSpeech,
    required this.meaning,
  });

  Map<String, Object?> toJson() => {
    'partOfSpeech': partOfSpeech,
    'meaning': meaning,
  };

  factory VocabularyDefinition.fromJson(Map<String, Object?> json) {
    return VocabularyDefinition(
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
    );
  }
}

class VocabularyEntry {
  static const providerId = 'vocabulary_com';

  final String provider;
  final String providerLabel;
  final String word;
  final String normalizedTerm;
  final String? usPhonetic;
  final String? ukPhonetic;
  final List<VocabularyDefinition> definitions;
  final List<String> otherForms;
  final String? shortExplanation;
  final String? longExplanation;
  final String sourceUrl;
  final String? readingLevelSystem;
  final String? readingLevelCode;
  final String? readingLevelSource;

  const VocabularyEntry({
    this.provider = providerId,
    this.providerLabel = 'Vocabulary.com',
    required this.word,
    required this.normalizedTerm,
    required this.definitions,
    required this.otherForms,
    required this.sourceUrl,
    this.usPhonetic,
    this.ukPhonetic,
    this.shortExplanation,
    this.longExplanation,
    this.readingLevelSystem,
    this.readingLevelCode,
    this.readingLevelSource,
  });

  String get definitionsJson =>
      jsonEncode([for (final definition in definitions) definition.toJson()]);

  String get otherFormsJson => jsonEncode(otherForms);

  static List<VocabularyDefinition> decodeDefinitions(String? value) {
    if (value == null || value.isEmpty) return const [];
    final decoded = jsonDecode(value) as List<dynamic>;
    return [
      for (final item in decoded)
        VocabularyDefinition.fromJson(
          Map<String, Object?>.from(item as Map<dynamic, dynamic>),
        ),
    ];
  }

  static List<String> decodeOtherForms(String? value) {
    if (value == null || value.isEmpty) return const [];
    return [for (final item in jsonDecode(value) as List<dynamic>) '$item'];
  }
}

class DictionaryLookupContext {
  final String bookTitle;
  final String chapterTitle;
  final String sentence;
  final String? bookId;
  final String? chapterId;
  final String? paragraphId;
  final String? lineId;
  final int? selectionStart;
  final int? selectionEnd;
  final int? audioStartMs;
  final int? audioEndMs;

  const DictionaryLookupContext({
    required this.bookTitle,
    required this.chapterTitle,
    required this.sentence,
    this.bookId,
    this.chapterId,
    this.paragraphId,
    this.lineId,
    this.selectionStart,
    this.selectionEnd,
    this.audioStartMs,
    this.audioEndMs,
  });

  String get cacheMaterial => '$bookTitle\n$chapterTitle\n$sentence';
}

String normalizeDictionaryTerm(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
