import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/appearance.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';

void main() {
  test(
    'subtitle spacing persists, clamps and resets independently of text size',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      final controller = container.read(appearanceControllerProvider.notifier);
      await controller.load();
      expect(container.read(appearanceControllerProvider).subtitleGap, 40);
      await controller.setSubtitleGap(60);
      final restored = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      await restored.read(appearanceControllerProvider.notifier).load();
      expect(restored.read(appearanceControllerProvider).subtitleGap, 60);
      expect(restored.read(appearanceControllerProvider).fontScale, 1);
      await controller.setSubtitleGap(200);
      expect(container.read(appearanceControllerProvider).subtitleGap, 80);
      await controller.reset();
      expect(container.read(appearanceControllerProvider).subtitleGap, 40);
      expect(await db.getSetting('appearance_subtitle_gap'), '40.0');
      restored.dispose();
      container.dispose();
      await db.close();
    },
  );
}
