import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/presentation/widgets/design_system/app_search_field.dart';
import 'package:lumina/presentation/widgets/design_system/page_control_tabs.dart';
import 'package:lumina/presentation/widgets/design_system/page_toolbar_search.dart';

void main() {
  testWidgets('toolbar search adapts, focuses, and preserves query on resize', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? submitted;
    Widget build(double width) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 36,
            child: PageToolbarSearch<int>(
              tabs: PageControlTabs<int>(
                labels: const {
                  0: 'Books',
                  1: 'Audiobooks',
                  2: 'Podcasts',
                  3: 'Library',
                },
                selected: 0,
                onSelected: (_) {},
              ),
              searchBuilder: (autofocus) => AppSearchField(
                compact: true,
                autofocus: autofocus,
                controller: controller,
                hintText: 'Search books',
                onSubmitted: (value) => submitted = value,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(build(1100));
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byType(TextField)).dy,
      lessThanOrEqualTo(36),
    );
    await tester.enterText(find.byType(TextField), 'Whale');
    await tester.pumpWidget(build(430));
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('page-toolbar-search-open')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(controller.text, 'Whale');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submitted, 'Whale');
    await tester.tap(find.byKey(const ValueKey('page-toolbar-search-close')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Books'), findsOneWidget);
    await tester.pumpWidget(build(1100));
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, 'Whale');
    expect(tester.takeException(), isNull);
  });
}
