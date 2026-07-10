import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/dictionary/dictionary_repository.dart';
import 'package:lumina/data/dictionary/vocabulary_com_parser.dart';
import 'package:lumina/data/dictionary/vocabulary_com_provider.dart';
import 'package:lumina/domain/models/vocabulary_entry.dart';
import 'package:lumina/main.dart';
import 'package:lumina/presentation/screens/dictionary/dictionary_screen.dart';
import 'package:lumina/presentation/widgets/dictionary_lookup_sheet.dart';
import 'package:lumina/services/reading_level_estimator.dart';

const _fixture = '''
<div class="definitionsContainer">
  <div class="word-area">
    <h1 id="hdr-word-area">mulberry</h1>
    <p class="short">A tree with edible fruit.</p>
  </div>
  <div class="word-definitions">
    <ol>
      <li class="sense">
        <div class="definition"><div class="pos-icon">noun</div>a mulberry tree</div>
      </li>
    </ol>
  </div>
</div>
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'dictionary result is a secondary route that supports iOS back swipe',
    (tester) async {
      tester.view.physicalSize = const Size(430, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DictionaryRepository(
        database,
        provider: _FakeProvider(),
      );
      addTearDown(database.close);
      await repository.lookup('mulberry');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            dictionaryRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(platform: TargetPlatform.iOS),
            home: const DictionaryScreen(),
          ),
        ),
      );
      await _pumpReady(tester);

      expect(
        find.byKey(const ValueKey('dictionary-search-field')),
        findsOneWidget,
      );
      await tester.tap(find.text('mulberry'));
      await _pumpReady(tester);

      expect(
        find.byKey(const ValueKey('dictionary-detail-search-field')),
        findsOneWidget,
      );

      await tester.dragFrom(const Offset(1, 400), const Offset(320, 0));
      await _pumpReady(tester);

      expect(
        find.byKey(const ValueKey('dictionary-search-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dictionary-detail-search-field')),
        findsNothing,
      );
    },
  );

  testWidgets('tapping the active Dictionary tab returns to its root page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DictionaryRepository(
      database,
      provider: _FakeProvider(),
    );
    addTearDown(database.close);
    await repository.lookup('mulberry');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dictionaryRepositoryProvider.overrideWithValue(repository),
        ],
        child: const LuminaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await _pumpReady(tester);
    await tester.tap(find.text('mulberry'));
    await _pumpReady(tester);
    expect(
      find.byKey(const ValueKey('dictionary-detail-search-field')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.menu_book));
    await _pumpReady(tester);

    expect(
      find.byKey(const ValueKey('dictionary-search-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dictionary-detail-search-field')),
      findsNothing,
    );
  });

  testWidgets('dictionary home previews top three and opens full collections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DictionaryRepository(
      database,
      provider: _FakeProvider(),
    );
    addTearDown(database.close);
    for (var index = 0; index < 6; index++) {
      await database.upsertDictionaryEntry(
        DictionaryEntry(
          id: 'entry-$index',
          provider: 'vocabulary_com',
          language: 'en',
          normalizedTerm: 'word$index',
          displayWord: 'word$index',
          status: 'success',
          definitionsJson:
              '[{"partOfSpeech":"noun","meaning":"definition $index"}]',
          otherFormsJson: '[]',
          sourceUrl: 'https://example.com/word$index',
          fetchedAt: index,
          lastAccessedAt: index,
          accessCount: 1,
        ),
      );
      if (index < 5) {
        await database.upsertFavoriteWord(
          FavoriteWord(
            id: 'favorite-$index',
            dictionaryEntryId: 'entry-$index',
            favoritedAt: index,
            updatedAt: index,
          ),
        );
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dictionaryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const DictionaryScreen(),
        ),
      ),
    );
    await _pumpReady(tester);

    expect(find.text('word4'), findsNWidgets(2));
    expect(find.text('word2'), findsOneWidget);
    expect(find.text('word5'), findsOneWidget);
    expect(find.text('word1'), findsNothing);
    expect(find.text('View All'), findsNWidgets(2));

    await tester.tap(find.text('View All').first);
    await _pumpReady(tester);

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('word0'), findsOneWidget);
    expect(find.text('word4'), findsOneWidget);
  });

  testWidgets('context lookup opens in a reusable draggable sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DictionaryRepository(
      database,
      provider: _FakeProvider(),
    );
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dictionaryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDictionaryLookupSheet(
                    context,
                    initialQuery: 'mulberry',
                    lookupContext: const DictionaryLookupContext(
                      bookTitle: 'Born a Crime',
                      chapterTitle: 'Chapter 1',
                      sentence: 'The mulberry tree grew beside the house.',
                      paragraphId: 'paragraph-1',
                      audioStartMs: 12340,
                    ),
                  ),
                  child: const Text('Open lookup'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open lookup'));
    await _pumpReady(tester);

    expect(
      find.byKey(const ValueKey('dictionary-lookup-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dictionary-sheet-search-field')),
      findsNothing,
    );
    expect(find.text('From your audiobook'), findsOneWidget);
    expect(find.text('Play from 00:12'), findsOneWidget);
    expect(find.text('Short explanation'), findsOneWidget);
    expect(find.text('A concise explanation.'), findsOneWidget);
    expect(find.text('Long explanation'), findsOneWidget);
    expect(find.text('A complete long explanation.'), findsOneWidget);
    expect(
      find.textContaining('a second definition', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byType(DictionaryWordScreen), findsNothing);
    expect(
      tester.getTopLeft(find.text('Short explanation')).dy,
      lessThan(tester.getTopLeft(find.text('From your audiobook')).dy),
    );

    await tester.tap(find.byTooltip('Search another word'));
    await _pumpReady(tester);
    expect(
      find.byKey(const ValueKey('dictionary-sheet-search-field')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Hide search'));
    await _pumpReady(tester);
    expect(
      find.byKey(const ValueKey('dictionary-sheet-search-field')),
      findsNothing,
    );
  });
}

Future<void> _pumpReady(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _FakeProvider extends VocabularyComProvider {
  _FakeProvider() : super(dio: Dio());

  @override
  Future<VocabularyEntry> lookup(String term) async {
    final parsed = const VocabularyComParser().parse(
      _fixture,
      requestedTerm: term,
    );
    return VocabularyEntry(
      provider: parsed.provider,
      providerLabel: parsed.providerLabel,
      word: parsed.word,
      normalizedTerm: parsed.normalizedTerm,
      usPhonetic: parsed.usPhonetic,
      ukPhonetic: parsed.ukPhonetic,
      definitions: [
        ...parsed.definitions,
        const VocabularyDefinition(
          partOfSpeech: 'adjective',
          meaning: 'a second definition',
        ),
      ],
      otherForms: parsed.otherForms,
      shortExplanation: 'A concise explanation.',
      longExplanation: 'A complete long explanation.',
      sourceUrl: parsed.sourceUrl,
      readingLevelSystem: cefrJReadingLevelSystem,
      readingLevelCode: 'A2',
      readingLevelSource: cefrJVocabularyProfileSource,
    );
  }
}
