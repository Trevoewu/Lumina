// Run: flutter test tool/generate_native_icons_test.dart
// Native controls accept image assets; render the same licensed HugeIcons
// vectors used by Flutter at 1x, 2x and 3x for crisp template tinting.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

void main() {
  testWidgets('generate native HugeIcons assets', (tester) async {
    const icons = {
      'home': HugeIcons.strokeRoundedHome01,
      'discover': HugeIcons.strokeRoundedCompass,
      'dictionary': HugeIcons.strokeRoundedBookOpen01,
      'me': HugeIcons.strokeRoundedUser,
      'more': HugeIcons.strokeRoundedMoreHorizontal,
      'back': HugeIcons.strokeRoundedArrowLeft01,
    };
    for (final entry in icons.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: HugeIcon(icon: entry.value, size: 25, color: Colors.black),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      for (final scale in [1.0, 2.0, 3.0]) {
        final image = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: scale),
        ))!;
        final bytes = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        );
        final directory = scale == 1
            ? 'assets/ui_icons'
            : 'assets/ui_icons/${scale}x';
        await tester.runAsync(() async {
          await Directory(directory).create(recursive: true);
          await File(
            '$directory/${entry.key}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
      }
    }
  });
}
