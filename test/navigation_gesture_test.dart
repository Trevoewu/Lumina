import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/theme.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform pages can be popped with a left-edge swipe', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme().copyWith(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('second page')),
                  ),
                ),
                child: const Text('open page'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open page'));
      await tester.pumpAndSettle();
      expect(find.text('second page'), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(1, 300));
      await gesture.moveBy(const Offset(700, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('second page'), findsNothing);
      expect(find.text('open page'), findsOneWidget);
    });
  }
}
