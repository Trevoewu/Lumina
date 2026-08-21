import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

const _languageKey = 'general_language';
const _themeModeKey = 'general_theme_mode';
const _readingScrollSpeedKey = 'reading_scroll_speed';
const _lyricSweepEnabledKey = 'reading_lyric_sweep_enabled';

enum AppLanguage { system, zhHans, english, japanese }

enum AppThemePreference { system, light, dark }

class AppPreferences {
  final AppLanguage language;
  final AppThemePreference theme;

  /// Multiplier for the synchronized text auto-scroll animation.
  ///
  /// A value of 1.0 is the current/default timing. Higher values make the
  /// animation complete faster; lower values make it more relaxed.
  final double readingScrollSpeed;
  final bool lyricSweepEnabled;
  final bool loaded;

  const AppPreferences({
    this.language = AppLanguage.system,
    this.theme = AppThemePreference.system,
    this.readingScrollSpeed = 1.0,
    this.lyricSweepEnabled = true,
    this.loaded = false,
  });

  Locale? get locale => switch (language) {
    AppLanguage.system => null,
    AppLanguage.zhHans => const Locale('zh', 'CN'),
    AppLanguage.english => const Locale('en'),
    AppLanguage.japanese => const Locale('ja'),
  };

  String resolvedLanguageCode(Locale systemLocale) {
    final code = locale?.languageCode ?? systemLocale.languageCode;
    return switch (code) {
      'zh' => 'zh',
      'ja' => 'ja',
      _ => 'en',
    };
  }

  ThemeMode get themeMode => switch (theme) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  AppPreferences copyWith({
    AppLanguage? language,
    AppThemePreference? theme,
    double? readingScrollSpeed,
    bool? lyricSweepEnabled,
    bool? loaded,
  }) {
    return AppPreferences(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      readingScrollSpeed: readingScrollSpeed ?? this.readingScrollSpeed,
      lyricSweepEnabled: lyricSweepEnabled ?? this.lyricSweepEnabled,
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
    final readingScrollSpeedValue = await database.getSetting(
      _readingScrollSpeedKey,
    );
    final lyricSweepEnabledValue = await database.getSetting(
      _lyricSweepEnabledKey,
    );
    state = AppPreferences(
      language: _parseLanguage(languageValue),
      theme: _parseTheme(themeValue),
      readingScrollSpeed: _parseReadingScrollSpeed(readingScrollSpeedValue),
      lyricSweepEnabled: _parseBool(lyricSweepEnabledValue, defaultValue: true),
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

  Future<void> setReadingScrollSpeed(double speed) async {
    final value = speed.clamp(0.5, 2.0).toDouble();
    state = state.copyWith(readingScrollSpeed: value, loaded: true);
    await ref
        .read(appDatabaseProvider)
        .setSetting(_readingScrollSpeedKey, value.toStringAsFixed(2));
  }

  Future<void> setLyricSweepEnabled(bool enabled) async {
    state = state.copyWith(lyricSweepEnabled: enabled, loaded: true);
    await ref
        .read(appDatabaseProvider)
        .setSetting(_lyricSweepEnabledKey, enabled.toString());
  }

  Future<void> reset() async {
    const defaults = AppPreferences(loaded: true);
    state = defaults;
    final database = ref.read(appDatabaseProvider);
    await database.setSetting(_languageKey, defaults.language.name);
    await database.setSetting(_themeModeKey, defaults.theme.name);
    await database.setSetting(
      _readingScrollSpeedKey,
      defaults.readingScrollSpeed.toStringAsFixed(2),
    );
    await database.setSetting(
      _lyricSweepEnabledKey,
      defaults.lyricSweepEnabled.toString(),
    );
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

  double _parseReadingScrollSpeed(String? value) {
    final parsed = double.tryParse(value ?? '');
    return (parsed ?? 1.0).clamp(0.5, 2.0).toDouble();
  }

  bool _parseBool(String? value, {required bool defaultValue}) {
    if (value == null) return defaultValue;
    return value == 'true'
        ? true
        : value == 'false'
        ? false
        : defaultValue;
  }
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );
