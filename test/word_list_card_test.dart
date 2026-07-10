import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/domain/models/vocabulary_entry.dart';
import 'package:lumina/presentation/widgets/word_list_card.dart';
import 'package:lumina/services/reading_level_estimator.dart';

void main() {
  testWidgets('WordListCard displays CEFR metadata', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordListCard(
            entry: const VocabularyEntry(
              word: 'abandon',
              normalizedTerm: 'abandon',
              definitions: [
                VocabularyDefinition(
                  partOfSpeech: 'verb',
                  meaning: 'to leave behind',
                ),
              ],
              otherForms: [],
              sourceUrl: 'https://example.com/abandon',
              readingLevelSystem: cefrJReadingLevelSystem,
              readingLevelCode: 'B1',
              readingLevelSource: cefrJVocabularyProfileSource,
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('CEFR B1'), findsOneWidget);
    expect(find.text('verb'), findsOneWidget);
  });
}
