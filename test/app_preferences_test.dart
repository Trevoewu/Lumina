import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lumina/core/app_localizations.dart';
import 'package:lumina/core/app_preferences.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';

void main() {
  testWidgets('Japanese locale selects the Japanese UI string', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Text(
            context.tr('语言', 'Language', '言語'),
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );

    expect(find.text('言語'), findsOneWidget);
  });

  test('UI and AI languages resolve independently', () {
    const japanese = AppPreferences(
      language: AppLanguage.japanese,
      aiLanguage: AppLanguage.english,
    );
    const chinese = AppPreferences(
      language: AppLanguage.zhHans,
      aiLanguage: AppLanguage.japanese,
    );
    const system = AppPreferences(
      language: AppLanguage.english,
      aiLanguage: AppLanguage.system,
    );

    expect(japanese.locale, const Locale('ja'));
    expect(japanese.resolvedAiLanguageCode(const Locale('ja')), 'en');
    expect(chinese.locale, const Locale('zh', 'CN'));
    expect(chinese.resolvedAiLanguageCode(const Locale('en')), 'ja');
    expect(system.locale, const Locale('en'));
    expect(system.resolvedAiLanguageCode(const Locale('ja')), 'ja');
    expect(system.resolvedAiLanguageCode(const Locale('fr')), 'en');
  });

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
    await database.setSetting('ai_service_language', 'japanese');
    await database.setSetting('general_theme_mode', 'light');
    final controller = container.read(appPreferencesProvider.notifier);
    await controller.load();

    expect(container.read(appPreferencesProvider).language, AppLanguage.zhHans);
    expect(
      container.read(appPreferencesProvider).aiLanguage,
      AppLanguage.japanese,
    );
    expect(
      container.read(dictionaryRepositoryProvider).outputLanguageCode,
      'ja',
    );
    expect(
      container.read(appPreferencesProvider).theme,
      AppThemePreference.light,
    );

    await controller.setLanguage(AppLanguage.english);
    await controller.setAiLanguage(AppLanguage.zhHans);
    await controller.setTheme(AppThemePreference.dark);

    expect(await database.getSetting('general_language'), 'english');
    expect(await database.getSetting('ai_service_language'), 'zhHans');
    expect(await database.getSetting('general_theme_mode'), 'dark');

    await controller.reset();
    expect(container.read(appPreferencesProvider).language, AppLanguage.system);
    expect(
      container.read(appPreferencesProvider).aiLanguage,
      AppLanguage.system,
    );
    expect(await database.getSetting('ai_service_language'), 'system');
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
