import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/app_preferences.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';

void main() {
  test('theme defaults to the system setting', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    expect(
      container.read(appPreferencesProvider).theme,
      AppThemePreference.system,
    );

    await container.read(appPreferencesProvider.notifier).load();

    expect(
      container.read(appPreferencesProvider).theme,
      AppThemePreference.system,
    );
  });

  test('language and theme preferences restore and persist', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await database.setSetting('general_language', 'zhHans');
    await database.setSetting('general_theme_mode', 'light');
    final controller = container.read(appPreferencesProvider.notifier);
    await controller.load();

    expect(container.read(appPreferencesProvider).language, AppLanguage.zhHans);
    expect(
      container.read(appPreferencesProvider).theme,
      AppThemePreference.light,
    );

    await controller.setLanguage(AppLanguage.english);
    await controller.setTheme(AppThemePreference.dark);

    expect(await database.getSetting('general_language'), 'english');
    expect(await database.getSetting('general_theme_mode'), 'dark');
  });

  test('reading scroll speed restores, persists, and stays in range', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await database.setSetting('reading_scroll_speed', '1.50');
    final controller = container.read(appPreferencesProvider.notifier);
    await controller.load();

    expect(container.read(appPreferencesProvider).readingScrollSpeed, 1.5);

    await controller.setReadingScrollSpeed(2.5);

    expect(container.read(appPreferencesProvider).readingScrollSpeed, 2.0);
    expect(await database.getSetting('reading_scroll_speed'), '2.00');
  });

  test(
    'lyric sweep preference restores, persists, and defaults on bad data',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await database.setSetting('reading_lyric_sweep_enabled', 'false');
      final controller = container.read(appPreferencesProvider.notifier);
      await controller.load();

      expect(container.read(appPreferencesProvider).lyricSweepEnabled, isFalse);

      await controller.setLyricSweepEnabled(true);
      expect(container.read(appPreferencesProvider).lyricSweepEnabled, isTrue);
      expect(await database.getSetting('reading_lyric_sweep_enabled'), 'true');
    },
  );
}
