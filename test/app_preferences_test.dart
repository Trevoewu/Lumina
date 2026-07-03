import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/app_preferences.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';

void main() {
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
}
