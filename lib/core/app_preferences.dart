import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

const _languageKey = 'general_language';
const _themeModeKey = 'general_theme_mode';

enum AppLanguage { system, zhHans, english }

enum AppThemePreference { system, light, dark }

class AppPreferences {
  final AppLanguage language;
  final AppThemePreference theme;
  final bool loaded;

  const AppPreferences({
    this.language = AppLanguage.system,
    this.theme = AppThemePreference.system,
    this.loaded = false,
  });

  Locale? get locale => switch (language) {
    AppLanguage.system => null,
    AppLanguage.zhHans => const Locale('zh', 'CN'),
    AppLanguage.english => const Locale('en'),
  };

  ThemeMode get themeMode => switch (theme) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  AppPreferences copyWith({
    AppLanguage? language,
    AppThemePreference? theme,
    bool? loaded,
  }) {
    return AppPreferences(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      loaded: loaded ?? this.loaded,
    );
  }
}

class AppPreferencesController extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => const AppPreferences();

  Future<void> load() async {
    if (state.loaded) return;
    final database = ref.read(appDatabaseProvider);
    final languageValue = await database.getSetting(_languageKey);
    final themeValue = await database.getSetting(_themeModeKey);
    state = AppPreferences(
      language: _parseLanguage(languageValue),
      theme: _parseTheme(themeValue),
      loaded: true,
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language, loaded: true);
    await ref.read(appDatabaseProvider).setSetting(_languageKey, language.name);
  }

  Future<void> setTheme(AppThemePreference theme) async {
    state = state.copyWith(theme: theme, loaded: true);
    await ref.read(appDatabaseProvider).setSetting(_themeModeKey, theme.name);
  }

  Future<void> reset() async {
    const defaults = AppPreferences(loaded: true);
    state = defaults;
    final database = ref.read(appDatabaseProvider);
    await database.setSetting(_languageKey, defaults.language.name);
    await database.setSetting(_themeModeKey, defaults.theme.name);
  }

  AppLanguage _parseLanguage(String? value) {
    return AppLanguage.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppLanguage.system,
    );
  }

  AppThemePreference _parseTheme(String? value) {
    return AppThemePreference.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppThemePreference.system,
    );
  }
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );
