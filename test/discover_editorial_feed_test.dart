import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/presentation/screens/discover/discover_editorial_feed.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'editorial feed ${dark ? 'dark' : 'light'} at $scale text scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var opened = false;
          String? author;
          var nextPage = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: DiscoverEditorialFeed(
                  books: List.generate(
                    10,
                    (i) => DiscoverEditorialBook(
                      id: '$i',
                      title:
                          'A very long book title about a journey into another world $i',
                      author: 'A writer with a long name',
                      metadata: 'Human narrated · 12h 30m · Added',
                      description:
                          'A story about finding your own way, told across generations and distant places.',
                      onTap: () => opened = true,
                    ),
                  ),
                  audiobooks: false,
                  onExploreAuthor: (value) => author = value,
                  onNextPage: () => nextPage = true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('discover-cover-story')));
          expect(opened, isTrue);
          final scroll = find.byType(CustomScrollView);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('discover-author-feature')),
            220,
            scrollable: find
                .descendant(of: scroll, matching: find.byType(Scrollable))
                .first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.byKey(const ValueKey('discover-author-feature')),
          );
          expect(author, 'A writer with a long name');
          await tester.scrollUntilVisible(
            find.text('Browse more'),
            240,
            scrollable: find
                .descendant(of: scroll, matching: find.byType(Scrollable))
                .first,
          );
          await tester.tap(find.text('Browse more'));
          expect(nextPage, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('one book omits empty shelves and unknown author feature', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscoverEditorialFeed(
            books: [
              DiscoverEditorialBook(
                id: '1',
                title: 'One book',
                author: 'Unknown',
                metadata: 'en',
                onTap: () {},
              ),
            ],
            audiobooks: false,
            onExploreAuthor: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Find your next chapter'), findsNothing);
    expect(find.text('Keep exploring'), findsNothing);
    expect(find.byKey(const ValueKey('discover-author-feature')), findsNothing);
    expect(find.text('Browse more'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
