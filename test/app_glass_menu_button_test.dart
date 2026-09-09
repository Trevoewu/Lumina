import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lumina/presentation/widgets/app_glass_controls.dart';
import 'package:lumina/presentation/widgets/design_system/app_icon.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('more glyph and menu work in $brightness', (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: brightness,
            platform: TargetPlatform.macOS,
          ),
          home: Scaffold(
            body: AppGlassMenuButton<int>(
              tooltip: 'More',
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1, child: Text('Action')),
              ],
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppGlassSurface), findsNothing);
      final icon = tester.widget<HugeIcon>(find.byType(HugeIcon));
      expect(icon.icon, AppIcons.moreHorizontal);
      expect(
        icon.color ?? IconTheme.of(tester.element(find.byType(HugeIcon))).color,
        Theme.of(tester.element(find.byType(HugeIcon))).colorScheme.onSurface,
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
