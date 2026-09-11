import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/appearance.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';

void main() {
  test(
    'Reader layout settings survive reopening and clamp invalid values',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final first = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      final controller = first.read(appearanceControllerProvider.notifier);
      await controller.load();
      await controller.setReaderLayout(
        margin: 24,
        lineHeight: 1.8,
        indent: 2,
        scrolled: true,
      );
      first.dispose();
      final second = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      final restored = second.read(appearanceControllerProvider.notifier);
      await restored.load();
      final value = second.read(appearanceControllerProvider);
      expect(value.readerMargin, 24);
      expect(value.readerLineHeight, 1.8);
      expect(value.readerIndent, 2);
      expect(value.readerScrolled, isTrue);
      await restored.setReaderLayout(margin: 100, lineHeight: 0);
      expect(second.read(appearanceControllerProvider).readerMargin, 32);
      expect(second.read(appearanceControllerProvider).readerLineHeight, 1.2);
      second.dispose();
      await db.close();
    },
  );

  test('Font scale clamps to range [16/24, 40/24] matching font size [16, 40]', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    final controller = container.read(appearanceControllerProvider.notifier);
    await controller.load();

    // Below 16 pt
    await controller.setFontScale(0.1);
    expect(container.read(appearanceControllerProvider).fontScale, closeTo(16 / 24, 0.001));

    // Above 40 pt
    await controller.setFontScale(5.0);
    expect(container.read(appearanceControllerProvider).fontScale, closeTo(40 / 24, 0.001));

    // At 24 pt (1.0)
    await controller.setFontScale(1.0);
    expect(container.read(appearanceControllerProvider).fontScale, closeTo(1.0, 0.001));

    container.dispose();
    await db.close();
  });
}
