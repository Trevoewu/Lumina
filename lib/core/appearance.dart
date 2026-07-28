import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'providers.dart';

const _fontKey = 'appearance_font_family';
const _scaleKey = 'appearance_font_scale';
const _accentKey = 'appearance_accent_color';

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

class AppearanceSettings {
  final String fontId;
  final double fontScale;
  final Color accentColor;
  final bool loaded;

  const AppearanceSettings({
    this.fontId = 'system',
    this.fontScale = 1.0,
    this.accentColor = AppColors.defaultAccent,
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
    bool? loaded,
  }) {
    return AppearanceSettings(
      fontId: fontId ?? this.fontId,
      fontScale: fontScale ?? this.fontScale,
      accentColor: accentColor ?? this.accentColor,
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
    state = state.copyWith(
      fontId: appearanceFontOptions.any((option) => option.id == migratedFontId)
          ? migratedFontId
          : state.fontId,
      fontScale: (scale ?? state.fontScale).clamp(0.85, 1.3),
      accentColor: accent ?? state.accentColor,
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
  }

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
