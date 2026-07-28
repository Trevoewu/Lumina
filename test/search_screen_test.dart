import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/book_sources/gutendex_repository.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/search/search_screen.dart';

void main() {
  testWidgets('book search scope selector follows the active accent', (
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
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selector = find.byKey(const ValueKey('book-search-scope-selector'));
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
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('library-search-field')),
      'moby',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
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
