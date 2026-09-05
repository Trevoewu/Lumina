import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/book_sources/gutendex_repository.dart';
import 'package:lumina/data/book_sources/librivox_repository.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/discover/discover_screen.dart';

void main() {
  testWidgets('discover scope selector follows the active accent', (
    tester,
  ) async {
    const accent = Color(0xFF56A8FF);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = _SlowGutendexRepository();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gutendexRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme(accentColor: accent),
          home: const DiscoverScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selector = find.byKey(const ValueKey('discover-scope-selector'));
    final colors = Theme.of(tester.element(selector)).colorScheme;

    expect(selector, findsOneWidget);
    expect(colors.primary, accent);
    expect(colors.surfaceTint, accent);
    expect(
      colors.secondaryContainer,
      Color.alphaBlend(accent.withValues(alpha: 0.16), colors.surface),
    );
  });

  testWidgets('online search shows immediate progress feedback', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = _SlowGutendexRepository();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gutendexRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: DiscoverScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('discover-search-field')), 'moby');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('audiobook scope shows human-narrated LibriVox results', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gutendexRepositoryProvider.overrideWithValue(_SlowGutendexRepository()),
          librivoxRepositoryProvider.overrideWithValue(_FakeLibrivoxRepository()),
        ],
        child: const MaterialApp(home: DiscoverScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Audiobooks'));
    await tester.pumpAndSettle();

    expect(find.text('Test Audiobook'), findsOneWidget);
    expect(find.textContaining('Human narrated'), findsOneWidget);
  });
}

class _SlowGutendexRepository extends GutendexRepository {
  int calls = 0;
  final pendingSearch = Completer<GutendexSearchResult>();

  @override
  Future<GutendexSearchResult> search({required String query, int page = 1}) {
    calls++;
    if (calls == 1) return Future.value(_emptyResult);
    return pendingSearch.future;
  }
}

const _emptyResult = GutendexSearchResult(count: 0, books: []);

class _FakeLibrivoxRepository extends LibrivoxRepository {
  @override
  Future<LibrivoxSearchResult> search({
    required String query,
    int page = 1,
    int pageSize = 20,
  }) async => LibrivoxSearchResult(
    hasMore: false,
    books: [
      LibrivoxBook.fromJson({
        'id': '1',
        'title': 'Test Audiobook',
        'language': 'English',
        'totaltimesecs': '3600',
        'authors': [
          {'first_name': 'Test', 'last_name': 'Author'},
        ],
        'sections': [
          {
            'id': '10',
            'section_number': '1',
            'title': 'Chapter 1',
            'listen_url': 'https://example.com/chapter.mp3',
            'playtime': '3600',
            'readers': [
              {'display_name': 'Test Reader'},
            ],
          },
        ],
      }),
    ],
  );
}
