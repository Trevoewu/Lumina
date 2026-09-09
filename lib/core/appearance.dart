import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'providers.dart';

const _fontKey = 'appearance_font_family';
const _scaleKey = 'appearance_font_scale';
const _accentKey = 'appearance_accent_color';

const _lightPresetKey = 'appearance_light_preset';
const _lightBgKey = 'appearance_light_bg';
const _lightFgKey = 'appearance_light_fg';
const _lightAccentKey = 'appearance_light_accent';

const _darkPresetKey = 'appearance_dark_preset';
const _darkBgKey = 'appearance_dark_bg';
const _darkFgKey = 'appearance_dark_fg';
const _darkAccentKey = 'appearance_dark_accent';

/// Makes the current 100% setting visually match the previous 85% size.
const appTextScaleBaseline = 0.85;

class AppearanceFontOption {
  final String id;
  final String label;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;

  const AppearanceFontOption({
    required this.id,
    required this.label,
    required this.fontFamily,
    this.fontFamilyFallback,
  });
}

const appearanceFontOptions = [
  AppearanceFontOption(id: 'system', label: 'System', fontFamily: null),
  AppearanceFontOption(
    id: 'serif',
    label: 'Georgia',
    fontFamily: 'Georgia',
    fontFamilyFallback: ['Literata'],
  ),
  AppearanceFontOption(
    id: 'mono',
    label: 'Menlo',
    fontFamily: 'Menlo',
    fontFamilyFallback: ['JetBrainsMono'],
  ),
];

const appearanceAccentOptions = [
  AppColors.defaultAccent,
  Color(0xFF3DDC97),
  Color(0xFF56A8FF),
  Color(0xFFFFC857),
  Color(0xFFFF6B6B),
  Color(0xFFB388FF),
];

class ThemePreset {
  final String id;
  final String label;
  final Color background;
  final Color foreground;
  final Color accent;

  const ThemePreset({
    required this.id,
    required this.label,
    required this.background,
    required this.foreground,
    required this.accent,
  });
}

const lightThemePresets = <ThemePreset>[
  ThemePreset(
    id: 'default_light',
    label: 'Default Light',
    background: Color(0xFFFAF9F5),
    foreground: Color(0xFF1F1E1D),
    accent: Color(0xFFC96442),
  ),
  ThemePreset(
    id: 'pure_white',
    label: 'Pure White',
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF151515),
    accent: Color(0xFF1DB954),
  ),
  ThemePreset(
    id: 'warm_paper',
    label: 'Warm Paper',
    background: Color(0xFFF7F2E8),
    foreground: Color(0xFF2C2523),
    accent: Color(0xFFD97706),
  ),
  ThemePreset(
    id: 'cool_gray',
    label: 'Cool Gray',
    background: Color(0xFFF3F4F6),
    foreground: Color(0xFF1F2937),
    accent: Color(0xFF2563EB),
  ),
];

const darkThemePresets = <ThemePreset>[
  ThemePreset(
    id: 'default_dark',
    label: 'Default Dark',
    background: Color(0xFF101010),
    foreground: Color(0xFFCCCCCC),
    accent: Color(0xFF007ACC),
  ),
  ThemePreset(
    id: 'spotify_green',
    label: 'Spotify Green',
    background: Color(0xFF121212),
    foreground: Color(0xFFFFFFFF),
    accent: Color(0xFF1DB954),
  ),
  ThemePreset(
    id: 'oled_black',
    label: 'OLED Black',
    background: Color(0xFF000000),
    foreground: Color(0xFFE5E5E5),
    accent: Color(0xFF3DDC97),
  ),
  ThemePreset(
    id: 'midnight_blue',
    label: 'Midnight Blue',
    background: Color(0xFF0D1117),
    foreground: Color(0xFFC9D1D9),
    accent: Color(0xFF58A6FF),
  ),
];

const defaultLightPalette = ThemePalette(
  presetId: 'default_light',
  background: Color(0xFFFAF9F5),
  foreground: Color(0xFF1F1E1D),
  accent: Color(0xFFC96442),
);

const defaultDarkPalette = ThemePalette(
  presetId: 'default_dark',
  background: Color(0xFF101010),
  foreground: Color(0xFFCCCCCC),
  accent: Color(0xFF007ACC),
);

extension ColorHexFormatting on Color {
  String toHexRgb() =>
      (toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
}

class ThemePalette {
  final String presetId;
  final Color background;
  final Color foreground;
  final Color accent;

  const ThemePalette({
    required this.presetId,
    required this.background,
    required this.foreground,
    required this.accent,
  });

  bool matchesPreset(ThemePreset preset) =>
      background.toARGB32() == preset.background.toARGB32() &&
      foreground.toARGB32() == preset.foreground.toARGB32() &&
      accent.toARGB32() == preset.accent.toARGB32();

  ThemePalette copyWith({
    String? presetId,
    Color? background,
    Color? foreground,
    Color? accent,
  }) {
    return ThemePalette(
      presetId: presetId ?? this.presetId,
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      accent: accent ?? this.accent,
    );
  }
}

class AppearanceSettings {
  final String fontId;
  final double fontScale;
  final Color accentColor;
  final ThemePalette lightPalette;
  final ThemePalette darkPalette;
  final bool loaded;

  const AppearanceSettings({
    this.fontId = 'system',
    this.fontScale = 1.0,
    this.accentColor = AppColors.defaultAccent,
    this.lightPalette = defaultLightPalette,
    this.darkPalette = defaultDarkPalette,
    this.loaded = false,
  });

  AppearanceFontOption get fontOption {
    return appearanceFontOptions.firstWhere(
      (option) => option.id == fontId,
      orElse: () => appearanceFontOptions.first,
    );
  }

  AppearanceSettings copyWith({
    String? fontId,
    double? fontScale,
    Color? accentColor,
    ThemePalette? lightPalette,
    ThemePalette? darkPalette,
    bool? loaded,
  }) {
    return AppearanceSettings(
      fontId: fontId ?? this.fontId,
      fontScale: fontScale ?? this.fontScale,
      accentColor: accentColor ?? this.accentColor,
      lightPalette: lightPalette ?? this.lightPalette,
      darkPalette: darkPalette ?? this.darkPalette,
      loaded: loaded ?? this.loaded,
    );
  }
}

class AppearanceController extends Notifier<AppearanceSettings> {
  @override
  AppearanceSettings build() => const AppearanceSettings();

  Future<void> load() async {
    if (state.loaded) return;
    final db = ref.read(appDatabaseProvider);
    final fontId = await db.getSetting(_fontKey);
    // Older builds used "inter" as an app-wide UI font. It was never bundled,
    // so migrate that value to the platform system reading font.
    final migratedFontId = fontId == 'inter' ? 'system' : fontId;
    final scale = double.tryParse(await db.getSetting(_scaleKey) ?? '');
    final accent = _parseColor(await db.getSetting(_accentKey));

    final lightPreset = await db.getSetting(_lightPresetKey);
    final lightBg = _parseColor(await db.getSetting(_lightBgKey));
    final lightFg = _parseColor(await db.getSetting(_lightFgKey));
    final lightAccent = _parseColor(await db.getSetting(_lightAccentKey));

    final darkPreset = await db.getSetting(_darkPresetKey);
    final darkBg = _parseColor(await db.getSetting(_darkBgKey));
    final darkFg = _parseColor(await db.getSetting(_darkFgKey));
    final darkAccent = _parseColor(await db.getSetting(_darkAccentKey));

    final resolvedLightPalette = ThemePalette(
      presetId: lightPreset ?? defaultLightPalette.presetId,
      background: lightBg ?? defaultLightPalette.background,
      foreground: lightFg ?? defaultLightPalette.foreground,
      accent: lightAccent ?? defaultLightPalette.accent,
    );

    final resolvedDarkPalette = ThemePalette(
      presetId: darkPreset ?? defaultDarkPalette.presetId,
      background: darkBg ?? defaultDarkPalette.background,
      foreground: darkFg ?? defaultDarkPalette.foreground,
      accent: darkAccent ?? defaultDarkPalette.accent,
    );

    state = state.copyWith(
      fontId: appearanceFontOptions.any((option) => option.id == migratedFontId)
          ? migratedFontId
          : state.fontId,
      fontScale: (scale ?? state.fontScale).clamp(0.85, 1.3),
      accentColor: accent ?? state.accentColor,
      lightPalette: resolvedLightPalette,
      darkPalette: resolvedDarkPalette,
      loaded: true,
    );
  }

  Future<void> setFont(String fontId) async {
    if (!appearanceFontOptions.any((option) => option.id == fontId)) return;
    state = state.copyWith(fontId: fontId, loaded: true);
    await ref.read(appDatabaseProvider).setSetting(_fontKey, fontId);
  }

  Future<void> setFontScale(double scale) async {
    final value = scale.clamp(0.85, 1.3);
    state = state.copyWith(fontScale: value, loaded: true);
    await ref
        .read(appDatabaseProvider)
        .setSetting(_scaleKey, value.toStringAsFixed(2));
  }

  Future<void> setAccentColor(Color color) async {
    state = state.copyWith(accentColor: color, loaded: true);
    await ref
        .read(appDatabaseProvider)
        .setSetting(
          _accentKey,
          color.toARGB32().toRadixString(16).padLeft(8, '0'),
        );
  }

  Future<void> setLightPreset(String presetId) async {
    final preset = lightThemePresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => lightThemePresets.first,
    );
    final newPalette = ThemePalette(
      presetId: preset.id,
      background: preset.background,
      foreground: preset.foreground,
      accent: preset.accent,
    );
    state = state.copyWith(lightPalette: newPalette, loaded: true);
    final db = ref.read(appDatabaseProvider);
    await db.setSetting(_lightPresetKey, preset.id);
    await db.setSetting(_lightBgKey, _colorToHex(preset.background));
    await db.setSetting(_lightFgKey, _colorToHex(preset.foreground));
    await db.setSetting(_lightAccentKey, _colorToHex(preset.accent));
  }

  Future<void> setLightColor({
    Color? background,
    Color? foreground,
    Color? accent,
  }) async {
    final updated = state.lightPalette.copyWith(
      background: background,
      foreground: foreground,
      accent: accent,
    );
    final matchingPreset = lightThemePresets.where((p) => updated.matchesPreset(p));
    final finalPalette = matchingPreset.isNotEmpty
        ? updated.copyWith(presetId: matchingPreset.first.id)
        : updated;

    state = state.copyWith(lightPalette: finalPalette, loaded: true);
    final db = ref.read(appDatabaseProvider);
    await db.setSetting(_lightPresetKey, finalPalette.presetId);
    if (background != null) {
      await db.setSetting(_lightBgKey, _colorToHex(finalPalette.background));
    }
    if (foreground != null) {
      await db.setSetting(_lightFgKey, _colorToHex(finalPalette.foreground));
    }
    if (accent != null) {
      await db.setSetting(_lightAccentKey, _colorToHex(finalPalette.accent));
    }
  }

  Future<void> resetLightPalette() async {
    final preset = lightThemePresets.firstWhere(
      (p) => p.id == state.lightPalette.presetId,
      orElse: () => lightThemePresets.first,
    );
    await setLightPreset(preset.id);
  }

  Future<void> setDarkPreset(String presetId) async {
    final preset = darkThemePresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => darkThemePresets.first,
    );
    final newPalette = ThemePalette(
      presetId: preset.id,
      background: preset.background,
      foreground: preset.foreground,
      accent: preset.accent,
    );
    state = state.copyWith(darkPalette: newPalette, loaded: true);
    final db = ref.read(appDatabaseProvider);
    await db.setSetting(_darkPresetKey, preset.id);
    await db.setSetting(_darkBgKey, _colorToHex(preset.background));
    await db.setSetting(_darkFgKey, _colorToHex(preset.foreground));
    await db.setSetting(_darkAccentKey, _colorToHex(preset.accent));
  }

  Future<void> setDarkColor({
    Color? background,
    Color? foreground,
    Color? accent,
  }) async {
    final updated = state.darkPalette.copyWith(
      background: background,
      foreground: foreground,
      accent: accent,
    );
    final matchingPreset = darkThemePresets.where((p) => updated.matchesPreset(p));
    final finalPalette = matchingPreset.isNotEmpty
        ? updated.copyWith(presetId: matchingPreset.first.id)
        : updated;

    state = state.copyWith(darkPalette: finalPalette, loaded: true);
    final db = ref.read(appDatabaseProvider);
    await db.setSetting(_darkPresetKey, finalPalette.presetId);
    if (background != null) {
      await db.setSetting(_darkBgKey, _colorToHex(finalPalette.background));
    }
    if (foreground != null) {
      await db.setSetting(_darkFgKey, _colorToHex(finalPalette.foreground));
    }
    if (accent != null) {
      await db.setSetting(_darkAccentKey, _colorToHex(finalPalette.accent));
    }
  }

  Future<void> resetDarkPalette() async {
    final preset = darkThemePresets.firstWhere(
      (p) => p.id == state.darkPalette.presetId,
      orElse: () => darkThemePresets.first,
    );
    await setDarkPreset(preset.id);
  }

  Future<void> reset() async {
    const defaults = AppearanceSettings(loaded: true);
    state = defaults;
    final db = ref.read(appDatabaseProvider);
    await db.setSetting(_fontKey, defaults.fontId);
    await db.setSetting(_scaleKey, defaults.fontScale.toStringAsFixed(2));
    await db.setSetting(
      _accentKey,
      defaults.accentColor.toARGB32().toRadixString(16).padLeft(8, '0'),
    );
    await db.setSetting(_lightPresetKey, defaults.lightPalette.presetId);
    await db.setSetting(_lightBgKey, _colorToHex(defaults.lightPalette.background));
    await db.setSetting(_lightFgKey, _colorToHex(defaults.lightPalette.foreground));
    await db.setSetting(_lightAccentKey, _colorToHex(defaults.lightPalette.accent));
    await db.setSetting(_darkPresetKey, defaults.darkPalette.presetId);
    await db.setSetting(_darkBgKey, _colorToHex(defaults.darkPalette.background));
    await db.setSetting(_darkFgKey, _colorToHex(defaults.darkPalette.foreground));
    await db.setSetting(_darkAccentKey, _colorToHex(defaults.darkPalette.accent));
  }

  String _colorToHex(Color color) =>
      color.toARGB32().toRadixString(16).padLeft(8, '0');

  Color? _parseColor(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}

final appearanceControllerProvider =
    NotifierProvider<AppearanceController, AppearanceSettings>(
      AppearanceController.new,
    );
