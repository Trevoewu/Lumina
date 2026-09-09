import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lumina/presentation/widgets/design_system/app_icon.dart';

void main() {
  for (final boxSize in [16.0, 38.0, 44.0]) {
    testWidgets('19pt icon stays centered inside a ${boxSize}pt box', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              key: const ValueKey('box'),
              dimension: boxSize,
              child: const AppIcon(AppIcons.mic01, size: 19),
            ),
          ),
        ),
      );
      final expectedSize = boxSize < 19 ? boxSize : 19.0;
      expect(tester.getSize(find.byType(HugeIcon)), Size.square(expectedSize));
      expect(
        tester.getCenter(find.byType(HugeIcon)),
        tester.getCenter(find.byKey(const ValueKey('box'))),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('box'))),
        Size.square(boxSize),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unconstrained icon keeps its natural themed footprint', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: IconTheme(
            data: IconThemeData(size: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [AppIcon(AppIcons.search01)],
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppIcon)), const Size.square(22));
    expect(tester.getSize(find.byType(HugeIcon)), const Size.square(22));
  });
}
