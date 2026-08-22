import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
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
    final controller = ref.read(appearanceControllerProvider.notifier);

    return CollapsingPageScaffold(
      title: context.tr('外观细节', 'Appearance', '外観の詳細'),
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: context.tr('恢复默认', 'Restore Defaults', 'デフォルトに戻す'),
          icon: const Icon(Icons.restart_alt),
          onPressed: controller.reset,
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
        children: [
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
                      for (var i = 0; i < appearanceFontOptions.length; i++) ...[
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

                _BlockDivider(
                  title: context.tr('强调色', 'Accent Color', 'アクセントカラー'),
                  value: _accentLabel(context, appearance.accentColor),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in appearanceAccentOptions)
                      _AccentDot(
                        color: color,
                        selected:
                            color.toARGB32() ==
                            appearance.accentColor.toARGB32(),
                        onTap: () => controller.setAccentColor(color),
                      ),
                  ],
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

  String _accentLabel(BuildContext context, Color color) {
    return switch (color.toARGB32()) {
      0xFF1DB954 => context.tr('苔绿', 'Moss', 'モス'),
      0xFF3DDC97 => context.tr('薄荷', 'Mint', 'ミント'),
      0xFF56A8FF => context.tr('靛蓝', 'Azure', 'アジュール'),
      0xFFFFC857 => context.tr('琥珀', 'Amber', 'アンバー'),
      0xFFFF6B6B => context.tr('陶红', 'Clay', 'クレイ'),
      0xFFB388FF => context.tr('藤紫', 'Iris', 'アイリス'),
      _ => context.tr('自定义', 'Custom', 'カスタム'),
    };
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

class _AccentDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AccentDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('appearance-accent-${color.toARGB32()}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          // The active swatch shrinks so the ring reads as a separate stroke.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: selected ? 26 : 32,
            height: selected ? 26 : 32,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
