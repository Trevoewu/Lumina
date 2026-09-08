import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

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
  for (final audiobook in [false, true]) {
    final source = audiobook ? 'LibriVox' : 'Gutendex';
    for (final leaveScreen in [false, true]) {
      testWidgets(
        '$source failure is handled ${leaveScreen ? 'after disposal' : 'and retry succeeds'}',
        (tester) async {
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          final online = _ControlledGutendexRepository();
          final audio = _ControlledLibrivoxRepository();
          addTearDown(database.close);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(database),
                gutendexRepositoryProvider.overrideWithValue(online),
                librivoxRepositoryProvider.overrideWithValue(audio),
              ],
              child: const MaterialApp(home: DiscoverScreen()),
            ),
          );
          await _waitForSearch(tester, () => online.calls > 0);
          if (audiobook) {
            // Leave the initial online request pending while switching scopes.
            await tester.tap(find.text('Audiobooks'));
            await tester.pump();
            await _waitForSearch(tester, () => audio.calls > 0);
            online.pending.completeError(_networkError(false));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
          if (leaveScreen) {
            await tester.pumpWidget(const SizedBox.shrink());
          }

          final error = _networkError(audiobook);
          if (audiobook) {
            audio.pending.completeError(error);
          } else {
            online.pending.completeError(error);
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          if (!leaveScreen) {
            expect(find.text(error.toString()), findsOneWidget);
            expect(find.byType(CircularProgressIndicator), findsNothing);
            await tester.tap(find.text('Retry'));
            await tester.pump();
            await _waitForSearch(
              tester,
              () => audiobook ? audio.calls == 2 : online.calls == 2,
            );
            await tester.pumpAndSettle();
            expect(find.text('Retry'), findsNothing);
            expect(find.byType(CircularProgressIndicator), findsNothing);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

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

    await tester.enterText(
      find.byKey(const ValueKey('discover-search-field')),
      'moby',
    );
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
          gutendexRepositoryProvider.overrideWithValue(
            _SlowGutendexRepository(),
          ),
          librivoxRepositoryProvider.overrideWithValue(
            _FakeLibrivoxRepository(),
          ),
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

DioException _networkError(bool handshake) => DioException(
  requestOptions: RequestOptions(path: '/books'),
  type: handshake ? DioExceptionType.unknown : DioExceptionType.receiveTimeout,
  error: handshake
      ? const HandshakeException('Connection terminated during handshake')
      : null,
);

Future<void> _waitForSearch(
  WidgetTester tester,
  bool Function() started,
) async {
  for (var attempt = 0; attempt < 100 && !started(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(started(), isTrue);
}

class _ControlledGutendexRepository extends GutendexRepository {
  int calls = 0;
  final pending = Completer<GutendexSearchResult>();

  @override
  Future<GutendexSearchResult> search({required String query, int page = 1}) {
    calls++;
    return calls == 1 ? pending.future : Future.value(_emptyResult);
  }
}

class _ControlledLibrivoxRepository extends LibrivoxRepository {
  int calls = 0;
  final pending = Completer<LibrivoxSearchResult>();

  @override
  Future<LibrivoxSearchResult> search({
    required String query,
    int page = 1,
    int pageSize = 20,
  }) {
    calls++;
    return calls == 1
        ? pending.future
        : Future.value(const LibrivoxSearchResult(books: [], hasMore: false));
  }
}
