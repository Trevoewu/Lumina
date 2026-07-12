import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/book_sources/gutendex_repository.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/search/search_screen.dart';

void main() {
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
