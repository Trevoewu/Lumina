import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:lumina/presentation/widgets/app_back_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/presentation/widgets/app_sheet.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Cupertino sheet returns results in $brightness', (
      tester,
    ) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showAppSheet<int>(
                    context: context,
                    builder: (context) => ListView(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(42),
                          child: const Text('Choose'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Choose'));
      expect(ModalRoute.of(context), isA<CupertinoSheetRoute<int>>());
      expect(Theme.of(context).brightness, brightness);
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      expect(result, 42);
      expect(find.text('Choose'), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBackButton), findsOneWidget);
      expect(
        tester.widget<CNButton>(find.byType(CNButton)).icon?.name,
        'chevron.left',
      );
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Choose'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sheet coordinates scrolling, drag dismissal and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                builder: (_) => ListView(
                  children: [
                    const TextField(),
                    for (var i = 0; i < 30; i++)
                      ListTile(title: Text('Row $i')),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.byType(ListView)).dy,
      lessThanOrEqualTo(544),
    );
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.fling(find.text('Row 1'), const Offset(0, 600), 1800);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
