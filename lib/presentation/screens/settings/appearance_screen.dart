import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/app_preferences.dart';
import '../../../core/appearance.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/settings_components.dart';
import 'app_icon_picker.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final scheme = Theme.of(context).colorScheme;
    final appearance = ref.watch(appearanceControllerProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final controller = ref.read(appearanceControllerProvider.notifier);

    return CollapsingPageScaffold(
      title: context.tr('外观细节', 'Appearance', '外観の詳細'),
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: context.tr('恢复默认', 'Restore Defaults', 'デフォルトに戻す'),
          icon: const AppIcon(AppIcons.reload),
          onPressed: controller.reset,
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
        children: [
          // ── Appearance / Theme ─────────────────────────────────────────
          _SectionTitle(title: context.tr('外观', 'Appearance', '外観')),
          SettingsCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('主题', 'Theme', 'テーマ'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _ThemeSegmentedSwitch(
                  selected: preferences.theme,
                  onSelected: ref
                      .read(appPreferencesProvider.notifier)
                      .setTheme,
                ),
              ],
            ),
          ),

          // ── Light Theme ────────────────────────────────────────────────
          _SectionTitle(title: context.tr('浅色主题', 'Light Theme', 'ライトテーマ')),
          _ThemePaletteCard(
            palette: appearance.lightPalette,
            presets: lightThemePresets,
            onSelectPreset: controller.setLightPreset,
            onResetPreset: controller.resetLightPalette,
            onUpdateColor: ({background, foreground, accent}) =>
                controller.setLightColor(
                  background: background,
                  foreground: foreground,
                  accent: accent,
                ),
          ),

          // ── Dark Theme ─────────────────────────────────────────────────
          _SectionTitle(title: context.tr('深色主题', 'Dark Theme', 'ダークテーマ')),
          _ThemePaletteCard(
            palette: appearance.darkPalette,
            presets: darkThemePresets,
            onSelectPreset: controller.setDarkPreset,
            onResetPreset: controller.resetDarkPalette,
            onUpdateColor: ({background, foreground, accent}) =>
                controller.setDarkColor(
                  background: background,
                  foreground: foreground,
                  accent: accent,
                ),
          ),

          // ── Typography & Reading ───────────────────────────────────────
          _SectionTitle(
            title: context.tr('排版与正文', 'Typography & Reading', '本文のフォントと文字'),
          ),
          SettingsCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BlockHeader(
                  title: context.tr('正文字体', 'Reading Font', '本文フォント'),
                  value: appearance.fontOption.label,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (
                        var i = 0;
                        i < appearanceFontOptions.length;
                        i++
                      ) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _FontChoice(
                          option: appearanceFontOptions[i],
                          selected:
                              appearance.fontId == appearanceFontOptions[i].id,
                          onTap: () =>
                              controller.setFont(appearanceFontOptions[i].id),
                        ),
                      ],
                    ],
                  ),
                ),

                _BlockDivider(
                  title: context.tr('字幕句间距', 'Subtitle spacing', '字幕の間隔'),
                  value: '${appearance.subtitleGap.round()} pt',
                ),
                Slider(
                  key: const ValueKey('subtitle-spacing-slider'),
                  min: 20,
                  max: 80,
                  divisions: 12,
                  value: appearance.subtitleGap,
                  label: '${appearance.subtitleGap.round()} pt',
                  onChanged: controller.setSubtitleGap,
                ),
                Text(
                  context.tr(
                    '增大间距可减少同屏字幕；当前句保持相同字号。',
                    'More spacing shows fewer subtitles; the current sentence keeps the same text size.',
                    '間隔を広げると表示される字幕が減ります。現在の文も同じ文字サイズです。',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                _BlockDivider(
                  title: context.tr('字号', 'Text Size', '文字サイズ'),
                  value: '${(appearance.fontScale * 100).round()}%',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'A',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        min: 0.85,
                        max: 1.3,
                        divisions: 9,
                        value: appearance.fontScale,
                        onChanged: controller.setFontScale,
                      ),
                    ),
                    Text(
                      'A',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    child: Text(
                      context.tr(
                        '复原力不是天赋，而是一次次刻意选择累积出来的东西。',
                        'The quick brown fox jumps over the lazy dog.',
                        'レジリエンスは才能ではなく、選択の積み重ねです。',
                      ),
                      style: TextStyle(
                        fontSize: 17 * appearance.fontScale,
                        height: 1.65,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                        fontFamily: appearance.fontOption.fontFamily,
                        fontFamilyFallback:
                            appearance.fontOption.fontFamilyFallback,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SettingsSectionLabel(
            title: context.tr('应用图标', 'App Icon', 'アプリアイコン'),
          ),
          const AppIconPicker(),
        ],
      ),
    );
  }
}

/// Title on the left, current value in muted mono on the right.
class _BlockHeader extends StatelessWidget {
  final String title;
  final String value;

  const _BlockHeader({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A [_BlockHeader] preceded by the hairline that separates two blocks inside
/// the same card.
class _BlockDivider extends StatelessWidget {
  final String title;
  final String value;

  const _BlockDivider({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Divider(
          height: 1,
          thickness: 1,
          color: scheme.onSurface.withValues(alpha: 0.06),
        ),
        const SizedBox(height: 18),
        _BlockHeader(title: title, value: value),
      ],
    );
  }
}

class _FontChoice extends StatelessWidget {
  final AppearanceFontOption option;
  final bool selected;
  final VoidCallback onTap;

  const _FontChoice({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.12)
          : scheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('appearance-font-${option.id}'),
        onTap: onTap,
        child: Container(
          width: 96,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('Aa 阅读', 'Aa Read', 'Aa 読む'),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.2,
                  color: scheme.onSurface,
                  fontFamily: option.fontFamily,
                  fontFamilyFallback: option.fontFamilyFallback,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ThemeSegmentedSwitch extends StatelessWidget {
  final AppThemePreference selected;
  final ValueChanged<AppThemePreference> onSelected;

  const _ThemeSegmentedSwitch({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            context,
            icon: AppIcons.laptop,
            preference: AppThemePreference.system,
            tooltip: context.tr('跟随系统', 'System', 'システム'),
          ),
          _segment(
            context,
            icon: AppIcons.sun03,
            preference: AppThemePreference.light,
            tooltip: context.tr('浅色模式', 'Light', 'ライト'),
          ),
          _segment(
            context,
            icon: AppIcons.moon02,
            preference: AppThemePreference.dark,
            tooltip: context.tr('深色模式', 'Dark', 'ダーク'),
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required AppIconData icon,
    required AppThemePreference preference,
    required String tooltip,
  }) {
    final isSelected = selected == preference;
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(preference),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 38,
          height: 30,
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.surfaceContainerHighest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: AppIcon(
            icon,
            size: 17,
            color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ThemePaletteCard extends StatelessWidget {
  final ThemePalette palette;
  final List<ThemePreset> presets;
  final ValueChanged<String> onSelectPreset;
  final VoidCallback onResetPreset;
  final void Function({Color? background, Color? foreground, Color? accent})
  onUpdateColor;

  const _ThemePaletteCard({
    required this.palette,
    required this.presets,
    required this.onSelectPreset,
    required this.onResetPreset,
    required this.onUpdateColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentPreset = presets.firstWhere(
      (p) => p.id == palette.presetId,
      orElse: () => presets.first,
    );
    final isModified = !palette.matchesPreset(currentPreset);

    return SettingsCard(
      child: Column(
        children: [
          // Preset Row
          _paletteRow(
            context,
            label: context.tr('预设', 'Preset', 'プリセット'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isModified) ...[
                  IconButton(
                    icon: const AppIcon(AppIcons.arrowTurnBackward, size: 18),
                    tooltip: context.tr('还原预设', 'Restore Preset', 'プリセットに戻す'),
                    style: IconButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(28, 28),
                    ),
                    onPressed: onResetPreset,
                  ),
                  const SizedBox(width: 4),
                ],
                PopupMenuButton<String>(
                  initialValue: palette.presetId,
                  tooltip: context.tr('选择预设', 'Select Preset', 'プリセットを選択'),
                  onSelected: onSelectPreset,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    for (final preset in presets)
                      PopupMenuItem(
                        value: preset.id,
                        child: Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: preset.background,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(preset.label)),
                            if (preset.id == palette.presetId)
                              AppIcon(
                                AppIcons.tick02,
                                size: 16,
                                color: scheme.primary,
                              ),
                          ],
                        ),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentPreset.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AppIcon(
                          AppIcons.arrowDown01,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.onSurface.withValues(alpha: 0.06),
          ),
          // Background Row
          _paletteRow(
            context,
            label: context.tr('背景', 'Background', '背景'),
            trailing: _ColorChip(
              color: palette.background,
              onTap: () => _showColorEditor(
                context,
                title: context.tr('背景颜色', 'Background Color', '背景色'),
                currentColor: palette.background,
                onColorChanged: (c) => onUpdateColor(background: c),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.onSurface.withValues(alpha: 0.06),
          ),
          // Foreground Row
          _paletteRow(
            context,
            label: context.tr('前景', 'Foreground', '前景'),
            trailing: _ColorChip(
              color: palette.foreground,
              onTap: () => _showColorEditor(
                context,
                title: context.tr('前景颜色', 'Foreground Color', '前景色'),
                currentColor: palette.foreground,
                onColorChanged: (c) => onUpdateColor(foreground: c),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.onSurface.withValues(alpha: 0.06),
          ),
          // Accent Row
          _paletteRow(
            context,
            label: context.tr('强调色', 'Accent', 'アクセント'),
            trailing: _ColorChip(
              color: palette.accent,
              onTap: () => _showColorEditor(
                context,
                title: context.tr('强调色', 'Accent Color', 'アクセントカラー'),
                currentColor: palette.accent,
                onColorChanged: (c) => onUpdateColor(accent: c),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paletteRow(
    BuildContext context, {
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ColorChip({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hexCode = color.toHexRgb();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 6, 12, 6),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.12),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '# ',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    TextSpan(
                      text: hexCode,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showColorEditor(
  BuildContext context, {
  required String title,
  required Color currentColor,
  required ValueChanged<Color> onColorChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ColorPickerDialog(
      title: title,
      initialColor: currentColor,
      onColorSelected: onColorChanged,
    ),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final String title;
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorPickerDialog({
    required this.title,
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _previewColor;
  late final TextEditingController _hexController;
  String? _error;

  static const _sampleColors = [
    Color(0xFFFAF9F5),
    Color(0xFFFFFFFF),
    Color(0xFFF3F4F6),
    Color(0xFF1F1E1D),
    Color(0xFF101010),
    Color(0xFF0D1117),
    Color(0xFFCCCCCC),
    Color(0xFFC96442),
    Color(0xFF007ACC),
    Color(0xFF1DB954),
    Color(0xFF56A8FF),
    Color(0xFFFF6B6B),
  ];

  @override
  void initState() {
    super.initState();
    _previewColor = widget.initialColor;
    _hexController = TextEditingController(
      text: widget.initialColor.toHexRgb(),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _onHexChanged(String text) {
    final clean = text.replaceAll('#', '').trim();
    if (clean.length != 6) {
      setState(() => _error = '请输入 6 位 HEX 色值');
      return;
    }
    final val = int.tryParse('FF$clean', radix: 16);
    if (val == null) {
      setState(() => _error = '无效的色值格式');
      return;
    }
    setState(() {
      _previewColor = Color(val);
      _error = null;
    });
  }

  void _pickSample(Color color) {
    setState(() {
      _previewColor = color;
      _hexController.text = color.toHexRgb();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview & Live Sample
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _previewColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Hex Code Input
            TextField(
              controller: _hexController,
              autofocus: false,
              maxLength: 6,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                labelText: context.tr('HEX 颜色', 'HEX Code', 'HEXカラー'),
                prefixText: '# ',
                counterText: '',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onHexChanged,
            ),
            const SizedBox(height: 18),

            // Quick Samples
            Text(
              context.tr('预设推荐', 'Suggested Colors', 'おすすめカラー'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in _sampleColors)
                  GestureDetector(
                    onTap: () => _pickSample(color),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == _previewColor
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.2),
                          width: color == _previewColor ? 2.5 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
        ),
        FilledButton(
          onPressed: _error == null
              ? () {
                  widget.onColorSelected(_previewColor);
                  Navigator.of(context).pop();
                }
              : null,
          child: Text(context.tr('确定', 'Done', '完了')),
        ),
      ],
    );
  }
}
