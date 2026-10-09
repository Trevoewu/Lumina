import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/library/saved_shelf_view.dart';

void main() {
  testWidgets('lists saved books and episodes and unsaves them', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.runAsync(() async {
      await database.upsertBook(
        const Book(
          id: 'book',
          title: 'Saved Book',
          author: 'Writer',
          format: 'epub',
          sourcePath: '/tmp/book.epub',
          chapterCount: 0,
          paragraphCount: 0,
          currentParagraphIndex: 0,
          playbackOffsetMs: 0,
          importedAt: 1,
          lastReadAt: 0,
          isRead: false,
          kind: 'book',
          rightsStatus: 'user_uploaded',
        ),
      );
      await database.upsertPodcastShow(
        const PodcastShow(
          id: 'show',
          feedUrl: 'https://example.com/feed.xml',
          title: 'Saved Show',
          description: '',
          subscribedAt: 1,
          lastRefreshedAt: 1,
        ),
      );
      await database.upsertPodcastEpisode(
        const PodcastEpisode(
          id: 'episode',
          showId: 'show',
          guid: 'guid',
          title: 'Saved Episode',
          description: '',
          audioUrl: 'https://example.com/e.mp3',
          publishedAt: 1,
          durationMs: 60000,
          playbackPositionMs: 0,
          lastPlayedAt: 0,
          isPlayed: false,
          transcriptStatus: 'none',
          transcriptProgressMs: 0,
        ),
      );
      await database.setSaved('book', 'book', true);
      await database.setSaved('episode', 'episode', true);
      // Saved, then deleted: left off the shelf rather than shown broken.
      await database.setSaved('book', 'gone', true);
    });

    var changes = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: SavedShelfView(
              reloadToken: 0,
              scrollController: scroll,
              onOpenBook: (_) {},
              onChanged: () => changes++,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved Book'), findsOneWidget);
    expect(find.text('Saved Episode'), findsOneWidget);
    expect(find.text('Saved Show · 1 min'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('saved-book-book')),
        matching: find.byTooltip('Remove from Saved'),
      ),
    );
    // The delete and the reload both go through the database on real time.
    for (var round = 0; round < 6; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('Saved Book'), findsNothing);
    expect(changes, 1);
    expect(
      await tester.runAsync(() => database.isSaved('book', 'book')),
      false,
    );
  });
}
