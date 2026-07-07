import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/presentation/widgets/collapsing_page_scaffold.dart';

void main() {
  testWidgets('page header stays neutral and collapses its single title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(accentColor: Colors.redAccent),
        home: CollapsingPageScaffold(
          title: 'Library',
          body: ListView.builder(
            itemCount: 40,
            itemBuilder: (_, index) =>
                SizedBox(height: 64, child: Text('Item $index')),
          ),
        ),
      ),
    );

    final header = tester.widget<Material>(
      find.byKey(const ValueKey('collapsing-page-header')),
    );
    expect(header.color, Colors.transparent);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('collapsing-page-title')))
          .style
          ?.fontSize,
      34,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('collapsing-page-title')))
          .style
          ?.fontWeight,
      FontWeight.w700,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('collapsing-page-title'))).dx,
      closeTo(24, 0.1),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();

    final collapsedTitle = tester.widget<Text>(
      find.byKey(const ValueKey('collapsing-page-title')),
    );
    expect(collapsedTitle.style?.fontSize, closeTo(18, 0.1));
    expect(collapsedTitle.style?.fontWeight, FontWeight.w700);
    expect(find.text('Library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
