import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/dictionary/dictionary_repository.dart';
import 'package:lumina/data/dictionary/vocabulary_com_parser.dart';
import 'package:lumina/data/dictionary/vocabulary_com_provider.dart';
import 'package:lumina/domain/models/vocabulary_entry.dart';
import 'package:lumina/main.dart';
import 'package:lumina/presentation/screens/dictionary/dictionary_screen.dart';

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
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dictionary-search-field')),
        findsOneWidget,
      );
      await tester.tap(find.text('mulberry'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dictionary-detail-search-field')),
        findsOneWidget,
      );

      await tester.dragFrom(const Offset(1, 400), const Offset(320, 0));
      await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    await tester.tap(find.text('mulberry'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('dictionary-detail-search-field')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.menu_book));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dictionary-search-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dictionary-detail-search-field')),
      findsNothing,
    );
  });
}

class _FakeProvider extends VocabularyComProvider {
  _FakeProvider() : super(dio: Dio());

  @override
  Future<VocabularyEntry> lookup(String term) async {
    return const VocabularyComParser().parse(_fixture, requestedTerm: term);
  }
}
