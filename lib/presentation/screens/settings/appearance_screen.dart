import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/appearance.dart';
import '../../widgets/collapsing_page_scaffold.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceControllerProvider);
    final controller = ref.read(appearanceControllerProvider.notifier);
    final accent = Theme.of(context).colorScheme.primary;

    return CollapsingPageScaffold(
      title: context.tr('外观', 'Appearance'),
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: context.tr('恢复默认', 'Restore Defaults'),
          icon: Icon(Icons.restart_alt),
          onPressed: controller.reset,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _SectionHeader(context.tr('字体', 'Font')),
          _SurfaceGroup(
            children: [
              for (final option in appearanceFontOptions)
                ListTile(
                  leading: Icon(
                    appearance.fontId == option.id
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: appearance.fontId == option.id
                        ? accent
                        : context.appSurfaceHighlight,
                  ),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontFamily: option.fontFamily,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _fontSubtitle(option),
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontFamily: option.fontFamily,
                    ),
                  ),
                  onTap: () => controller.setFont(option.id),
                ),
            ],
          ),
          _SectionHeader(context.tr('字号', 'Text Size')),
          _SurfaceGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.format_size, color: context.appTextSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${(appearance.fontScale * 100).round()}%',
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Slider(
                min: 0.85,
                max: 1.3,
                divisions: 9,
                value: appearance.fontScale,
                onChanged: controller.setFontScale,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(
                  'The quick brown fox jumps over the lazy dog.\n播放界面歌词预览',
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 18,
                    height: 1.35,
                    fontFamily: appearance.fontOption.fontFamily,
                  ),
                ),
              ),
            ],
          ),
          _SectionHeader(context.tr('主题色', 'Accent Color')),
          _SurfaceGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final color in appearanceAccentOptions)
                      _ColorSwatch(
                        color: color,
                        selected:
                            color.toARGB32() ==
                            appearance.accentColor.toARGB32(),
                        onTap: () => controller.setAccentColor(color),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fontSubtitle(AppearanceFontOption option) {
    return switch (option.id) {
      'system' => '跟随系统默认字体',
      'inter' => '现代、紧凑的界面字体',
      'serif' => '更接近传统书籍排版',
      'mono' => '等宽字体，适合检查文本',
      _ => option.fontFamily ?? 'System',
    };
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          color: context.appTextSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SurfaceGroup extends StatelessWidget {
  final List<Widget> children;

  const _SurfaceGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selected ? '当前主题色' : '应用主题色',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? context.appTextPrimary : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? Icon(Icons.check, color: Colors.black, size: 22)
              : null,
        ),
      ),
    );
  }
}
